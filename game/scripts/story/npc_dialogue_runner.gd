extends Node
class_name NpcDialogueRunner

## 节点图对话驱动：读取 data/dialogues/*.json，执行 actions 与分支。

signal quest_accepted(story_id: String)
signal dialogue_updated
signal story_completed(story_id: String, result: Dictionary)

enum Phase { IDLE, LINE, OPTIONS }

var phase: int = Phase.IDLE
var story_id: String = ""
var npc_bubble: String = ""
var player_bubble: String = ""
var panel_text: String = ""

var _data: Dictionary = {}
var _nodes: Dictionary = {}
var _current_node_id: String = ""
var _pending_options: Array[Dictionary] = []
var _pending_encounter_id: String = ""
var _pending_reward_loot_key: String = ""
var _context: Dictionary = {}


func is_active() -> bool:
	return phase != Phase.IDLE


func get_option_labels() -> Array[String]:
	var out: Array[String] = []
	for opt in _pending_options:
		out.append(str(opt.get("text", "")))
	return out


func start_dialogue(p_story_id: String, entry_node: String = "", ctx: Dictionary = {}) -> void:
	var path: String = StoryData.dialogue_path(p_story_id)
	if path == "":
		return
	if not _load_dialogue(path):
		return
	if is_active() and story_id == p_story_id:
		if phase == Phase.LINE:
			advance_line()
		elif phase == Phase.OPTIONS:
			dialogue_updated.emit()
		return
	story_id = p_story_id
	_context = ctx.duplicate(true)
	_pending_encounter_id = ""
	_pending_reward_loot_key = ""
	var node_id := entry_node
	if node_id == "":
		node_id = _resume_node_id()
	if node_id == "":
		node_id = str(_data.get("start_node", ""))
	if node_id == "":
		return
	_enter_node(node_id)


func _resume_node_id() -> String:
	var getter: Callable = _context.get("get_checkpoint", Callable())
	if not getter.is_valid():
		return ""
	var saved := str(getter.call())
	if saved == "" or not _nodes.has(saved):
		if saved != "":
			_clear_checkpoint()
		return ""
	if _is_terminal_node(saved):
		return ""
	return saved


func _is_terminal_node(node_id: String) -> bool:
	return node_id in [
		"intro_done_close",
		"gate_decline_done",
		"story_done_close",
		"quest_remind",
	]


func get_current_node_id() -> String:
	return _current_node_id


func advance_line() -> void:
	if phase != Phase.LINE or story_id == "":
		return
	var node: Dictionary = _nodes.get(_current_node_id, {})
	var next_id := str(node.get("next", ""))
	if next_id == "":
		if _pending_encounter_id != "":
			_finish_story()
		_close_session()
		return
	_enter_node(next_id)


func choose_option(index: int) -> void:
	if phase != Phase.OPTIONS or index < 0 or index >= _pending_options.size():
		return
	var opt: Dictionary = _pending_options[index]
	var option_text := str(opt.get("text", ""))
	if option_text != "":
		player_bubble = option_text
		npc_bubble = ""
	var next_id := str(opt.get("next", ""))
	_pending_options.clear()
	_clear_checkpoint()
	if next_id == "":
		_close_session()
		return
	_enter_node(next_id)


func _enter_node(node_id: String) -> void:
	if not _nodes.has(node_id):
		push_warning("[NpcDialogue] 缺少节点: %s" % node_id)
		_close_session()
		return
	_current_node_id = node_id
	var node: Dictionary = _nodes[node_id]
	if _should_save_checkpoint(node_id, node):
		_save_checkpoint(node_id)
	var routed := _resolve_condition(node)
	if routed != "":
		_enter_node(routed)
		return
	if _execute_actions(node.get("actions", {})):
		return
	var speaker := str(node.get("speaker", ""))
	var bubble := str(node.get("bubble", node.get("text", "")))
	var full_text := str(node.get("text", bubble))
	panel_text = full_text
	if speaker.to_lower() in ["player", "我"]:
		player_bubble = bubble
		npc_bubble = ""
	elif speaker == "System" or full_text == "":
		player_bubble = ""
		npc_bubble = ""
	else:
		npc_bubble = bubble
		player_bubble = ""
	var options: Array = _read_options(node)
	_pending_options.clear()
	if not options.is_empty():
		for opt_var in options:
			if typeof(opt_var) != TYPE_DICTIONARY:
				continue
			var opt: Dictionary = opt_var
			if not _option_available(opt):
				continue
			_pending_options.append(opt.duplicate(true))
		if _pending_options.is_empty():
			push_warning("[NpcDialogue] 节点 %s 没有可用选项" % node_id)
			panel_text = "（当前没有可用选项，请检查背包或任务进度。）"
			phase = Phase.LINE
			dialogue_updated.emit()
			return
		phase = Phase.OPTIONS
		dialogue_updated.emit()
		return
	if bool(node.get("actions", {}).get("close_dialogue", false)):
		return
	var next_id := str(node.get("next", ""))
	if next_id == "":
		_close_session()
		return
	if speaker == "System" and full_text == "":
		_enter_node(next_id)
		return
	phase = Phase.LINE
	dialogue_updated.emit()


func _read_options(node: Dictionary) -> Array:
	var raw: Variant = node.get("options", [])
	if typeof(raw) == TYPE_ARRAY:
		return raw
	return []


func _resolve_condition(node: Dictionary) -> String:
	var cond: Variant = node.get("condition", {})
	if typeof(cond) != TYPE_DICTIONARY or (cond as Dictionary).is_empty():
		return ""
	var need_item := _resolve_item_id(str(cond.get("has_item", "")))
	var need_count := int(cond.get("count", 1))
	var has := _count_item(need_item)
	if has >= need_count:
		return str(cond.get("if_true", ""))
	return str(cond.get("if_false", ""))


func _option_available(opt: Dictionary) -> bool:
	if not opt.has("condition_check"):
		return true
	var check: Variant = opt.get("condition_check")
	if typeof(check) != TYPE_DICTIONARY:
		return true
	var cond: Dictionary = check
	if cond.is_empty() or str(cond.get("has_item", "")).strip_edges() == "":
		return true
	var need_item := _resolve_item_id(str(cond.get("has_item", "")))
	var need_count := int(cond.get("count", 1))
	return _count_item(need_item) >= need_count


func _execute_actions(actions: Variant) -> bool:
	if typeof(actions) != TYPE_DICTIONARY:
		return false
	var act: Dictionary = actions
	if bool(act.get("open_gate", false)) or act.has("trigger_quest"):
		quest_accepted.emit(story_id)
	if act.has("set_variable"):
		var vars: Variant = act.get("set_variable", {})
		if typeof(vars) == TYPE_DICTIONARY:
			for key in (vars as Dictionary).keys():
				run_state_set_variable(str(key), (vars as Dictionary)[key])
	if act.has("remove_item"):
		var item_id := _resolve_item_id(str(act.get("remove_item", "")))
		var count := int(act.get("count", 1))
		_remove_item(item_id, count)
	if act.has("give_item"):
		var give_id := _resolve_item_id(str(act.get("give_item", "")))
		var give_count := int(act.get("count", 1))
		_give_item(give_id, give_count)
	if act.has("unlock_journal_entry"):
		_pending_encounter_id = _resolve_journal_encounter(str(act.get("unlock_journal_entry", "")))
	if act.has("spawn_reward_loot"):
		_pending_reward_loot_key = str(act.get("spawn_reward_loot", ""))
	if bool(act.get("clear_checkpoint", false)):
		_clear_checkpoint()
	if bool(act.get("end_dialogue", false)):
		_finish_story()
		_clear_checkpoint()
	if bool(act.get("close_dialogue", false)):
		_close_session()
		return true
	return false


func _resolve_journal_encounter(entry_key: String) -> String:
	var journal_map_var: Variant = _data.get("journal_map", {})
	if typeof(journal_map_var) != TYPE_DICTIONARY:
		return entry_key
	var journal_map: Dictionary = journal_map_var as Dictionary
	var mapping_var: Variant = journal_map.get(entry_key, {})
	if typeof(mapping_var) != TYPE_DICTIONARY:
		return entry_key
	var mapping: Dictionary = mapping_var as Dictionary
	var var_name: String = str(mapping.get("variable", ""))
	var raw_value: Variant = run_state_get_variable(var_name)
	var var_key: String = ""
	if raw_value is int or raw_value is float:
		var_key = str(int(raw_value))
	elif raw_value != null:
		var_key = str(raw_value)
	var resolved: String = str(mapping.get(var_key, ""))
	if resolved != "":
		return resolved
	push_warning("[NpcDialogue] 日记映射失败: %s var=%s key=%s" % [entry_key, var_name, var_key])
	return entry_key


func _finish_story() -> void:
	var result := {
		"encounter_id": _pending_encounter_id,
		"reward_loot_key": _pending_reward_loot_key,
	}
	story_completed.emit(story_id, result)


func _should_save_checkpoint(node_id: String, node: Dictionary) -> bool:
	if _is_terminal_node(node_id):
		return false
	return _read_options(node).is_empty()


func _save_checkpoint(node_id: String) -> void:
	var setter: Callable = _context.get("set_checkpoint", Callable())
	if setter.is_valid():
		setter.call(node_id)


func _clear_checkpoint() -> void:
	var clearer: Callable = _context.get("clear_checkpoint", Callable())
	if clearer.is_valid():
		clearer.call()


func _close_session() -> void:
	phase = Phase.IDLE
	story_id = ""
	_current_node_id = ""
	_pending_options.clear()
	npc_bubble = ""
	player_bubble = ""
	panel_text = ""
	dialogue_updated.emit()


func reset_session() -> void:
	_close_session()
	_context.clear()


func _load_dialogue(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_warning("[NpcDialogue] 找不到对话文件: %s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[NpcDialogue] 对话 JSON 解析失败: %s" % path)
		return false
	_data = parsed
	var nodes_var: Variant = _data.get("nodes", {})
	if typeof(nodes_var) != TYPE_DICTIONARY:
		_nodes = {}
		return false
	_nodes = (nodes_var as Dictionary).duplicate(true)
	return not _nodes.is_empty()


func _resolve_item_id(raw: String) -> String:
	var aliases: Variant = _data.get("item_aliases", {})
	if typeof(aliases) == TYPE_DICTIONARY and (aliases as Dictionary).has(raw):
		return str((aliases as Dictionary)[raw])
	return raw


func _count_item(item_id: String) -> int:
	var backpack: InventoryData = _context.get("backpack") as InventoryData
	var backpack_count := 0
	if backpack != null:
		backpack_count = backpack.count(item_id)
	if backpack_count > 0:
		return backpack_count
	for quest_alias in ["battery", "memory"]:
		if item_id == _resolve_item_id(quest_alias):
			var getter: Callable = _context.get("get_quest_collect_count", Callable())
			if getter.is_valid():
				return int(getter.call())
			break
	return backpack_count


func _give_item(item_id: String, count: int) -> void:
	var backpack: InventoryData = _context.get("backpack") as InventoryData
	if backpack == null or count <= 0:
		return
	backpack.add(item_id, count)


func _remove_item(item_id: String, count: int) -> void:
	var backpack: InventoryData = _context.get("backpack") as InventoryData
	if backpack == null or count <= 0:
		return
	backpack.remove(item_id, count)


func run_state_get_variable(key: String) -> Variant:
	var getter: Callable = _context.get("get_variable", Callable())
	if getter.is_valid():
		return getter.call(key)
	return null


func run_state_set_variable(key: String, value: Variant) -> void:
	var setter: Callable = _context.get("set_variable", Callable())
	if setter.is_valid():
		setter.call(key, value)
