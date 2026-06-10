extends Node
class_name StoryController

const _NpcDialogueRunner := preload("res://scripts/story/npc_dialogue_runner.gd")

const FOOT_WALK_LOOT_RADIUS := 30.0
const FOOT_INTERACT_LOOT_RADIUS := 36.0
const FOOT_INTERACT_HINT_RADIUS := 44.0
const PROP_DIG_DURATION := 0.85
const THUNDER_LEITING_STORY_ID := "thunder_leiting"

signal ui_refresh_requested
signal thunder_boss_requested(district_index: int)

var run_state := StoryRunState.new()
var gate_dialogue: StoryGateDialogue
var npc_dialogue: _NpcDialogueRunner
var _host: Node
var _quest_nodes: Array[Area2D] = []
var _unlocked_loot_nodes: Array[Area2D] = []
var _gate_entrance_world: Vector2 = Vector2.ZERO
var _active_story_id: String = ""
var _ui_locked := false
var _prop_dig_fx: Dictionary = {}


func setup(host: Node) -> void:
	_host = host
	gate_dialogue = StoryGateDialogue.new()
	gate_dialogue.name = "StoryGateDialogue"
	add_child(gate_dialogue)
	gate_dialogue.quest_accepted.connect(_on_quest_accepted)
	gate_dialogue.quest_declined.connect(_on_quest_declined)
	gate_dialogue.reward_chosen.connect(_on_reward_chosen)
	gate_dialogue.dialogue_updated.connect(func(): ui_refresh_requested.emit())
	npc_dialogue = _NpcDialogueRunner.new()
	npc_dialogue.name = "NpcDialogueRunner"
	add_child(npc_dialogue)
	npc_dialogue.quest_accepted.connect(_on_quest_accepted)
	npc_dialogue.story_completed.connect(_on_npc_story_completed)
	npc_dialogue.dialogue_updated.connect(_on_npc_dialogue_updated)


func reset_for_new_run() -> void:
	run_state.clear()
	_clear_quest_nodes()
	_clear_unlocked_loot_nodes()
	_prop_dig_fx.clear()
	_gate_entrance_world = Vector2.ZERO
	_active_story_id = ""
	_ui_locked = false
	if is_instance_valid(gate_dialogue):
		gate_dialogue.phase = StoryGateDialogue.Phase.IDLE
	if is_instance_valid(npc_dialogue):
		npc_dialogue.reset_session()


func is_ui_locked() -> bool:
	return _ui_locked or _any_dialogue_active()


func _any_dialogue_active() -> bool:
	if is_instance_valid(npc_dialogue) and npc_dialogue.is_active():
		return true
	return is_instance_valid(gate_dialogue) and gate_dialogue.is_active()


func _uses_dialogue_file(story_id: String) -> bool:
	return StoryData.dialogue_path(story_id) != ""


func story_id_at_node(node_index: int) -> String:
	var map: WorldMapData = _map()
	if map == null or not map.is_valid_index(node_index):
		return ""
	for district_index in map.get_roadside_districts(node_index):
		var sid := _story_id_of_district(district_index)
		if sid != "":
			return sid
	return ""


func district_for_story_at_node(node_index: int, story_id: String) -> int:
	var map: WorldMapData = _map()
	if map == null:
		return -1
	for district_index in map.get_roadside_districts(node_index):
		if _story_id_of_district(district_index) == story_id:
			return district_index
	return -1


func can_enter_district(district_index: int) -> bool:
	var story_id := _story_id_of_district(district_index)
	if story_id == "":
		return true
	if is_thunder_blocking_district(district_index):
		return false
	if run_state.is_completed(story_id):
		return false
	if StoryData.is_interior_encounter(story_id):
		return true
	if _uses_dialogue_file(story_id):
		return run_state.is_quest_active(story_id) and _quest_collect_remaining(story_id) > 0
	if run_state.is_reward_pending(story_id):
		return false
	if not run_state.is_quest_active(story_id):
		return false
	return _quest_collect_remaining(story_id) > 0


func _quest_collect_remaining(story_id: String) -> int:
	var quest: Dictionary = StoryData.quest_def(story_id)
	var need := int(quest.get("collect_count", 0))
	return need - run_state.get_collect_count(story_id)


func handle_drive_interact(node_index: int) -> bool:
	var story_id := story_id_at_node(node_index)
	if story_id == "" or run_state.is_completed(story_id):
		return false
	if _uses_dialogue_file(story_id):
		if StoryData.is_interior_encounter(story_id):
			return false
		# 任务进行中且尚未集齐物品时，E 应进入建筑而非弹出门口复读对话
		if run_state.is_quest_active(story_id) and _quest_collect_remaining(story_id) > 0:
			return false
		return _handle_npc_dialogue_interact(story_id, node_index)
	if not is_instance_valid(gate_dialogue):
		return false
	if gate_dialogue.is_active():
		if gate_dialogue.phase == StoryGateDialogue.Phase.INTRO:
			gate_dialogue.advance_intro()
		elif gate_dialogue.phase == StoryGateDialogue.Phase.REWARD_CHOICE:
			pass
		return true
	if not run_state.is_quest_active(story_id) and not run_state.is_reward_pending(story_id):
		_begin_gate_talk(story_id, district_for_story_at_node(node_index, story_id))
		return true
	if run_state.is_reward_pending(story_id):
		_begin_reward_talk(story_id)
		return true
	return false


func _handle_npc_dialogue_interact(story_id: String, node_index: int) -> bool:
	if not is_instance_valid(npc_dialogue):
		return false
	if is_instance_valid(gate_dialogue):
		gate_dialogue.phase = StoryGateDialogue.Phase.IDLE
		gate_dialogue.npc_bubble = ""
		gate_dialogue.player_bubble = ""
	if npc_dialogue.is_active():
		if npc_dialogue.phase == _NpcDialogueRunner.Phase.LINE:
			npc_dialogue.advance_line()
		ui_refresh_requested.emit()
		return true
	var district := district_for_story_at_node(node_index, story_id)
	if district >= 0:
		run_state.set_district(story_id, district)
		_cache_gate_entrance(district)
	_active_story_id = story_id
	_ui_locked = true
	var entry := ""
	if run_state.is_quest_active(story_id):
		var quest: Dictionary = StoryData.quest_def(story_id)
		var need := int(quest.get("collect_count", 0))
		if run_state.get_collect_count(story_id) >= need:
			entry = "return_start"
		else:
			entry = "quest_remind"
	elif not run_state.is_completed(story_id):
		entry = ""
	entry = _normalize_dialogue_entry(story_id, entry)
	npc_dialogue.start_dialogue(story_id, entry, _dialogue_context(story_id))
	return true


func try_enter_district(district_index: int) -> bool:
	if is_thunder_blocking_district(district_index):
		begin_thunder_gate_encounter(district_index)
		return false
	if not can_enter_district(district_index):
		var story_id := _story_id_of_district(district_index)
		if story_id != "":
			_begin_gate_talk(story_id, district_index)
		return false
	return true


func is_thunder_blocking_district(district_index: int) -> bool:
	if district_index < 0 or is_thunder_defeated():
		return false
	if not _is_final_layer():
		return false
	var map: WorldMapData = _map()
	if map == null:
		return false
	return map.district_has_kunlun_control(district_index)


func is_thunder_defeated() -> bool:
	if _host == null:
		return true
	return bool(_host.get("_thunder_leiting_defeated"))


func should_show_thunder_gate_boss(district_index: int) -> bool:
	return is_thunder_blocking_district(district_index)


func advance_active_drive_dialogue() -> bool:
	if not is_instance_valid(npc_dialogue) or not npc_dialogue.is_active():
		return false
	if npc_dialogue.phase == _NpcDialogueRunner.Phase.LINE:
		npc_dialogue.advance_line()
		ui_refresh_requested.emit()
		return true
	if npc_dialogue.phase == _NpcDialogueRunner.Phase.OPTIONS:
		ui_refresh_requested.emit()
		return true
	return false


func begin_thunder_gate_encounter(district_index: int) -> void:
	if not is_thunder_blocking_district(district_index):
		return
	var checkpoint := str(run_state.get_dialogue_node(THUNDER_LEITING_STORY_ID))
	var ready_for_battle := bool(
		run_state.get_variable(THUNDER_LEITING_STORY_ID, "pre_battle_done", false)
	) or checkpoint in ["combat_ready", "combat_start"]
	if ready_for_battle:
		_active_story_id = ""
		_ui_locked = false
		run_state.clear_dialogue_node(THUNDER_LEITING_STORY_ID)
		thunder_boss_requested.emit(district_index)
		ui_refresh_requested.emit()
		return
	if not is_instance_valid(npc_dialogue):
		return
	if npc_dialogue.is_active() and npc_dialogue.story_id == THUNDER_LEITING_STORY_ID:
		advance_active_drive_dialogue()
		return
	if npc_dialogue.is_active():
		return
	run_state.set_district(THUNDER_LEITING_STORY_ID, district_index)
	_cache_gate_entrance(district_index)
	_active_story_id = THUNDER_LEITING_STORY_ID
	_ui_locked = true
	var ctx := _dialogue_context(THUNDER_LEITING_STORY_ID)
	ctx["get_thunder_recognition"] = Callable(self, "thunder_recognition")
	ctx["start_thunder_boss"] = func() -> void:
		thunder_boss_requested.emit(district_index)
	npc_dialogue.start_dialogue(THUNDER_LEITING_STORY_ID, "", ctx)
	ui_refresh_requested.emit()


func thunder_recognition() -> String:
	var journal: RunJournal = _journal()
	if journal == null:
		return "enemy"
	if journal.has_encounter("chronicler_plunder"):
		return "enemy"
	if (
		journal.has_encounter("sentinel_s09_parts_gave1")
		or journal.has_encounter("sentinel_s09_blueprint_gave1")
	):
		return "enemy"
	if journal.has_encounter("chronicler_repair"):
		return "ally"
	if (
		journal.has_encounter("sentinel_s09_parts_gave2")
		or journal.has_encounter("sentinel_s09_blueprint_gave2")
	):
		return "ally"
	return "enemy"


func _is_final_layer() -> bool:
	if _host == null:
		return false
	var layer := int(_host.get("_current_layer"))
	var total := int(_host.get("total_layers"))
	return layer >= total


func start_story_talk(story_id: String, district_index: int = -1) -> void:
	if story_id == "" or run_state.is_completed(story_id):
		return
	if district_index >= 0:
		run_state.set_district(story_id, district_index)
		_cache_gate_entrance(district_index)
	_active_story_id = story_id
	if _uses_dialogue_file(story_id):
		_handle_npc_dialogue_interact(story_id, _current_node_index())
		return
	_begin_gate_talk(story_id, district_index)


func on_entered_district_foot(district_index: int) -> void:
	var story_id := _story_id_of_district(district_index)
	if story_id == "":
		return
	run_state.set_district(story_id, district_index)
	if StoryData.is_interior_encounter(story_id):
		if run_state.is_quest_active(story_id):
			_sync_quest_pickups(story_id, district_index)
			fix_foot_loot_positions(district_index)
		if not run_state.is_completed(story_id) and not run_state.is_quest_active(story_id):
			call_deferred("_begin_interior_encounter", story_id)
		_sync_ambient_loot(story_id, district_index)
		return
	if not run_state.is_quest_active(story_id):
		return
	_sync_quest_pickups(story_id, district_index)
	fix_foot_loot_positions(district_index)


func _interior_dialogue_entry(story_id: String) -> String:
	if story_id == "staff_officer_07" and not run_state.is_completed(story_id):
		var backpack: InventoryData = _backpack()
		if backpack != null and backpack.has("data_chip_echo_operation", 1):
			return _normalize_dialogue_entry(story_id, "choice")
	if run_state.is_quest_active(story_id):
		return ""
	if run_state.is_completed(story_id):
		return ""
	return _normalize_dialogue_entry(story_id, "")


func _begin_interior_encounter(story_id: String) -> void:
	if not is_instance_valid(npc_dialogue) or run_state.is_completed(story_id):
		return
	if npc_dialogue.is_active() and npc_dialogue.story_id == story_id:
		ui_refresh_requested.emit()
		return
	if StoryData.dialogue_path(story_id) == "":
		push_warning("[Story] 室内遭遇缺少对话文件: %s" % story_id)
		return
	var entry := _interior_dialogue_entry(story_id)
	if entry == "" and run_state.is_quest_active(story_id):
		ui_refresh_requested.emit()
		return
	_active_story_id = story_id
	_ui_locked = true
	npc_dialogue.start_dialogue(story_id, entry, _dialogue_context(story_id))
	if not npc_dialogue.is_active():
		_ui_locked = false
		push_warning("[Story] 室内遭遇对话未能启动: %s" % story_id)
		return
	ui_refresh_requested.emit()


func try_interior_story_interact(district_index: int, player_local: Vector2 = Vector2.ZERO) -> bool:
	var story_id := _story_id_of_district(district_index)
	if story_id == "" or not StoryData.is_interior_encounter(story_id):
		return false
	if run_state.is_completed(story_id) or not run_state.is_quest_active(story_id):
		return false
	var need := int(StoryData.quest_def(story_id).get("collect_count", 0))
	if run_state.get_collect_count(story_id) < need:
		return false
	if not is_near_interior_npc(story_id, district_index, player_local):
		return false
	if not is_instance_valid(npc_dialogue) or npc_dialogue.is_active():
		return false
	return _handle_npc_dialogue_interact(story_id, _current_node_index())


func ensure_interior_encounter_at(district_index: int) -> void:
	var story_id := _story_id_of_district(district_index)
	if story_id == "":
		return
	if not StoryData.is_interior_encounter(story_id):
		return
	if run_state.is_completed(story_id):
		return
	_begin_interior_encounter(story_id)


func story_id_of_district(district_index: int) -> String:
	return _story_id_of_district(district_index)


func blocks_foot_exit(district_index: int) -> bool:
	var story_id := _story_id_of_district(district_index)
	if story_id == "" or run_state.is_completed(story_id):
		return false
	return StoryData.locks_exit_until_resolved(story_id)


func on_exited_district_to_drive(district_index: int) -> bool:
	var story_id := _story_id_of_district(district_index)
	if story_id == "":
		return false
	if _uses_dialogue_file(story_id):
		var quest: Dictionary = StoryData.quest_def(story_id)
		var need := int(quest.get("collect_count", 0))
		return run_state.is_quest_active(story_id) and run_state.get_collect_count(story_id) >= need
	return run_state.is_reward_pending(story_id)


func fix_foot_loot_positions(district_index: int) -> void:
	var map: WorldMapData = _map()
	if map == null or district_index < 0:
		return
	var walkable: Array[Vector2] = map.get_walkable_world_positions(district_index)
	if walkable.is_empty():
		return
	var cell := map.get_cell(district_index)
	var foot_origin := map.get_foot_origin(district_index)
	var spot_idx := 0
	for node in _quest_nodes:
		_snap_loot_node(node, district_index, map, cell, foot_origin, walkable, spot_idx)
		spot_idx += 1
	for node in _unlocked_loot_nodes:
		_snap_loot_node(node, district_index, map, cell, foot_origin, walkable, spot_idx)
		spot_idx += 1


func try_collect_foot_loot(
	district_index: int,
	player_local: Vector2,
	radius: float = FOOT_WALK_LOOT_RADIUS,
) -> void:
	_prune_invalid_quest_nodes()
	_prune_invalid_unlocked_loot_nodes()
	for node in _quest_nodes.duplicate():
		if bool(node.get_meta("interact_only", false)):
			continue
		_try_collect_node(node, district_index, player_local, radius)
	for node in _unlocked_loot_nodes.duplicate():
		_try_collect_node(node, district_index, player_local, radius)


func try_interact_foot_loot(
	district_index: int,
	player_local: Vector2,
	radius: float = FOOT_INTERACT_LOOT_RADIUS,
) -> bool:
	var story_id := _story_id_of_district(district_index)
	if story_id == "" or not run_state.is_quest_active(story_id):
		return false
	if _prop_dig_fx.has(district_index):
		return false
	var prop := interior_quest_prop_display(story_id, district_index)
	if prop.is_empty():
		return false
	var prop_local: Vector2 = prop.get("local", Vector2.ZERO)
	if player_local.distance_to(prop_local) > radius:
		return false
	var item_id := str(prop.get("item_id", ""))
	if item_id == "":
		return false
	_start_prop_dig(district_index, story_id, prop_local, item_id)
	_clear_quest_nodes_for_story(story_id)
	return true


func tick_prop_dig_fx(delta: float) -> void:
	if _prop_dig_fx.is_empty():
		return
	var finished: Array[int] = []
	for key in _prop_dig_fx.keys():
		var district_index := int(key)
		var fx: Dictionary = _prop_dig_fx[district_index]
		var time_left := float(fx.get("time_left", 0.0)) - delta
		fx["time_left"] = time_left
		_prop_dig_fx[district_index] = fx
		if time_left <= 0.0:
			finished.append(district_index)
		elif _host != null:
			_host.queue_redraw()
	for district_index in finished:
		_finish_prop_dig(district_index)


func get_prop_dig_fx(district_index: int) -> Dictionary:
	if not _prop_dig_fx.has(district_index):
		return {}
	var fx: Dictionary = _prop_dig_fx[district_index]
	return {
		"local": fx.get("local", Vector2.ZERO),
		"item_id": str(fx.get("item_id", "scrap")),
		"time_left": float(fx.get("time_left", 0.0)),
	}


func _start_prop_dig(district_index: int, story_id: String, local: Vector2, item_id: String) -> void:
	_prop_dig_fx[district_index] = {
		"story_id": story_id,
		"local": local,
		"item_id": item_id,
		"time_left": PROP_DIG_DURATION,
	}
	if _host != null:
		_host.queue_redraw()


func _finish_prop_dig(district_index: int) -> void:
	if not _prop_dig_fx.has(district_index):
		return
	var fx: Dictionary = _prop_dig_fx[district_index]
	_prop_dig_fx.erase(district_index)
	var item_id := str(fx.get("item_id", "scrap"))
	if _host != null and _host.has_method("_on_resource_collected"):
		_host.call("_on_resource_collected", district_index, item_id, null)
	if _host != null:
		_host.queue_redraw()


func _clear_quest_nodes_for_story(story_id: String) -> void:
	for node in _quest_nodes.duplicate():
		if not is_instance_valid(node):
			continue
		if str(node.get_meta("story_id", "")) != story_id:
			continue
		_quest_nodes.erase(node)
		node.queue_free()


func foot_loot_prop_id(node: Area2D) -> String:
	if not is_instance_valid(node):
		return ""
	return str(node.get_meta("pickup_prop", ""))


func quest_interact_hint(
	district_index: int,
	player_local: Vector2,
	radius: float = FOOT_INTERACT_HINT_RADIUS,
) -> Dictionary:
	var story_id := _story_id_of_district(district_index)
	if story_id == "" or not run_state.is_quest_active(story_id):
		return {}
	if not bool(StoryData.quest_def(story_id).get("interact_to_collect", false)):
		return {}
	var need := int(StoryData.quest_def(story_id).get("collect_count", 0))
	if run_state.get_collect_count(story_id) >= need:
		return {}
	if _prop_dig_fx.has(district_index):
		return {}
	var prop := interior_quest_prop_display(story_id, district_index)
	if prop.is_empty():
		return {}
	var prop_local: Vector2 = prop.get("local", Vector2.ZERO)
	if player_local.distance_to(prop_local) > radius:
		return {}
	var hint := str(StoryData.quest_def(story_id).get("interact_hint", "E 交互"))
	return {
		"text": hint,
		"local": prop_local,
	}


func is_near_interior_npc(story_id: String, district_index: int, player_local: Vector2) -> bool:
	if story_id == "" or district_index < 0:
		return false
	if not StoryData.is_interior_encounter(story_id):
		return true
	var map: WorldMapData = _map()
	if map == null:
		return false
	var area := map.get_foot_area_rect(district_index)
	if area.size == Vector2.ZERO:
		return false
	var anchor := _interior_npc_foot_local(story_id, area.size)
	var radius := maxf(area.size.x, area.size.y) * 0.20
	return player_local.distance_to(anchor) <= radius


func interior_npc_interact_hint(story_id: String, district_index: int, player_local: Vector2) -> Dictionary:
	if story_id == "" or not StoryData.is_interior_encounter(story_id):
		return {}
	if not run_state.is_quest_active(story_id):
		return {}
	var need := int(StoryData.quest_def(story_id).get("collect_count", 0))
	if run_state.get_collect_count(story_id) < need:
		return {}
	if not is_near_interior_npc(story_id, district_index, player_local):
		return {}
	var hint := StoryData.prompt_return(story_id)
	if hint.strip_edges() == "":
		hint = "E 交谈"
	return {"text": hint}


func _interior_npc_foot_local(story_id: String, area_size: Vector2) -> Vector2:
	match story_id:
		"ad_1_radar":
			return area_size * Vector2(0.5, 0.46)
		"marian_k142":
			return area_size * Vector2(0.52, 0.36)
		"chronicler_04":
			return area_size * Vector2(0.5, 0.42)
		"furnace_qc":
			return area_size * Vector2(0.5, 0.42)
		"staff_officer_07":
			return area_size * Vector2(0.5, 0.48)
		_:
			return area_size * 0.5


func interior_quest_prop_display(story_id: String, district_index: int) -> Dictionary:
	if story_id == "" or district_index < 0 or run_state.is_completed(story_id):
		return {}
	if _prop_dig_fx.has(district_index):
		return {}
	var quest: Dictionary = StoryData.quest_def(story_id)
	var prop_id := str(quest.get("pickup_prop", ""))
	if prop_id == "":
		return {}
	var need := int(quest.get("collect_count", 1))
	if run_state.get_collect_count(story_id) >= need:
		return {}
	var local := _quest_prop_local(quest)
	if local == Vector2.ZERO:
		return {}
	return {
		"local": local,
		"prop": prop_id,
		"item_id": str(quest.get("collect_item_id", "")),
	}


func _quest_prop_local(quest: Dictionary) -> Vector2:
	var offsets: Variant = quest.get("interior_offsets", [])
	if typeof(offsets) != TYPE_ARRAY or (offsets as Array).is_empty():
		return Vector2.ZERO
	var first: Variant = (offsets as Array)[0]
	if typeof(first) != TYPE_ARRAY or (first as Array).size() < 2:
		return Vector2.ZERO
	var arr: Array = first
	return Vector2(float(arr[0]), float(arr[1]))


func is_foot_loot_visible(node: Area2D, district_index: int) -> bool:
	if not is_instance_valid(node):
		return false
	if int(node.get_meta("district_index", -1)) != district_index:
		return false
	if node in _quest_nodes:
		var story_id := str(node.get_meta("story_id", ""))
		return run_state.is_quest_active(story_id)
	return true


func foot_loot_label(node: Area2D) -> String:
	if node in _quest_nodes:
		var story_id := str(node.get_meta("story_id", ""))
		if story_id != "":
			return str(StoryData.quest_def(story_id).get("pickup_label", "任务物品"))
	return ItemIconFactory.loot_display_name(str(node.get_meta("item_id", "scrap")))


func _try_collect_node(node: Node, district_index: int, player_local: Vector2, radius: float) -> void:
	if not (node is Area2D):
		return
	var pickup := node as Area2D
	if not is_instance_valid(pickup):
		return
	if bool(pickup.get_meta("picked_up", false)):
		return
	if int(pickup.get_meta("district_index", -1)) != district_index:
		return
	if not is_foot_loot_visible(pickup, district_index):
		return
	var loot_local := _foot_local_of_pickup(pickup, district_index)
	if loot_local.distance_to(player_local) > radius:
		return
	if pickup in _quest_nodes:
		_quest_nodes.erase(pickup)
	if pickup in _unlocked_loot_nodes:
		_unlocked_loot_nodes.erase(pickup)
	if _host != null:
		_host.queue_redraw()
	pickup.set_meta("picked_up", true)
	var item_id := str(pickup.get_meta("item_id", "scrap"))
	if _host != null and _host.has_method("_on_resource_collected"):
		_host.call("_on_resource_collected", district_index, item_id, pickup)


func _foot_local_of_pickup(pickup: Area2D, district_index: int) -> Vector2:
	if pickup.has_meta("foot_local"):
		return pickup.get_meta("foot_local") as Vector2
	var map: WorldMapData = _map()
	if map == null:
		return Vector2.ZERO
	return pickup.global_position - map.get_foot_origin(district_index)


func _snap_loot_node(
	node: Area2D,
	district_index: int,
	map: WorldMapData,
	cell: Dictionary,
	foot_origin: Vector2,
	walkable: Array[Vector2],
	spot_idx: int,
) -> void:
	if not is_instance_valid(node):
		return
	if int(node.get_meta("district_index", -1)) != district_index:
		return
	# 任务电池使用 stories.json 中的固定坐标，不要被 snap 到其它 walkable 点
	if bool(node.get_meta("story_quest", false)):
		_set_pickup_foot_local(node, district_index, foot_origin)
		return
	if map.is_foot_tile_blocked(cell, foot_origin, node.global_position):
		node.global_position = walkable[spot_idx % walkable.size()]
	_set_pickup_foot_local(node, district_index, foot_origin)


func _set_pickup_foot_local(pickup: Area2D, district_index: int, foot_origin: Vector2) -> void:
	if not is_instance_valid(pickup):
		return
	var map: WorldMapData = _map()
	if map == null:
		return
	if foot_origin == Vector2.ZERO:
		foot_origin = map.get_foot_origin(district_index)
	pickup.set_meta("foot_local", pickup.global_position - foot_origin)


func on_quest_item_collected(item_id: String, district_index: int) -> bool:
	if not item_id.begins_with("quest:"):
		return false
	var story_id := _story_id_of_district(district_index)
	if story_id == "":
		return false
	var quest: Dictionary = StoryData.quest_def(story_id)
	if str(quest.get("collect_item_id", "")) != item_id:
		return false
	if not run_state.is_quest_active(story_id):
		return false
	var count := run_state.get_collect_count(story_id) + 1
	run_state.set_collect_count(story_id, count)
	_prune_invalid_quest_nodes()
	var need := int(quest.get("collect_count", 1))
	if count >= need and not _uses_dialogue_file(story_id):
		run_state.set_phase(story_id, StoryRunState.PHASE_REWARD)
		_clear_quest_nodes()
	elif count >= need:
		_clear_quest_nodes()
	ui_refresh_requested.emit()
	return true


func accept_gate_choice() -> void:
	if is_instance_valid(gate_dialogue):
		gate_dialogue.accept_quest()


func decline_gate_choice() -> void:
	if is_instance_valid(gate_dialogue):
		gate_dialogue.decline_quest()


func choose_reward_index(index: int) -> void:
	if is_instance_valid(gate_dialogue):
		gate_dialogue.choose_reward_by_index(index)


func choose_dialogue_option(index: int) -> void:
	if is_instance_valid(npc_dialogue) and npc_dialogue.is_active():
		npc_dialogue.choose_option(index)


func refresh_quest_pickups(_mode_foot: bool, current_district: int) -> void:
	for node in _quest_nodes:
		if not is_instance_valid(node):
			continue
		# 营内拾取物由 _draw_interior_story_loot 绘制，Area2D 仅作逻辑锚点
		node.visible = false
		var story_id := str(node.get_meta("story_id", ""))
		var district_index := int(node.get_meta("district_index", -1))
		var pickup_label := node.get_node_or_null("Label") as Label
		if is_instance_valid(pickup_label):
			pickup_label.visible = false
			if run_state.is_quest_active(story_id) and district_index == current_district:
				var quest: Dictionary = StoryData.quest_def(story_id)
				pickup_label.text = str(quest.get("pickup_label", "任务物品"))


func refresh_unlocked_loot(_mode_foot: bool, _current_district: int) -> void:
	for node in _unlocked_loot_nodes:
		if is_instance_valid(node):
			node.visible = false


func should_show_gate_npc(story_id: String) -> bool:
	if story_id == "":
		return false
	if not DayTopdownRender.has_gate_npc_sprite(story_id):
		return false
	if story_id == WorldMapData.SENTINEL_STORY_ID:
		return true
	return not run_state.is_completed(story_id)


func get_gate_npc_anchor(district_index: int) -> Vector2:
	var map: WorldMapData = _map()
	if map == null or district_index < 0:
		return Vector2.ZERO
	var story_id := _story_id_of_district(district_index)
	var entrance := map.get_building_entrance_world_pos(district_index)
	if entrance == Vector2.ZERO:
		return Vector2.ZERO
	return DayTopdownRender.gate_npc_anchor(
		entrance,
		story_id,
		map.district_toward_road_vector(district_index),
	)


func draw_gate_bubbles(canvas: CanvasItem, vehicle_pos: Vector2, draw_bubble: Callable) -> void:
	var npc_text := ""
	var player_text := ""
	if is_instance_valid(npc_dialogue) and npc_dialogue.is_active():
		npc_text = npc_dialogue.npc_bubble
		player_text = npc_dialogue.player_bubble
	elif is_instance_valid(gate_dialogue) and gate_dialogue.is_active():
		npc_text = gate_dialogue.npc_bubble
		player_text = gate_dialogue.player_bubble
	else:
		return
	var district := run_state.get_district(_active_story_id)
	var gate := _gate_entrance_world
	if gate == Vector2.ZERO and district >= 0 and _map() != null:
		gate = _map().get_building_entrance_world_pos(district)
	var toward_road := Vector2.ZERO
	if district >= 0 and _map() != null:
		toward_road = _map().district_toward_road_vector(district)
	if _active_story_id == THUNDER_LEITING_STORY_ID and gate != Vector2.ZERO:
		DayTopdownRender.draw_thunder_gate_boss(canvas, gate, 1.0, toward_road)
	elif should_show_gate_npc(_active_story_id):
		DayTopdownRender.draw_gate_npc(canvas, gate, _active_story_id, 1.0, toward_road)
	if npc_text != "":
		var bubble_anchor := gate
		if should_show_gate_npc(_active_story_id):
			bubble_anchor = get_gate_npc_anchor(run_state.get_district(_active_story_id))
			if bubble_anchor == Vector2.ZERO:
				bubble_anchor = gate
		draw_bubble.call(bubble_anchor + Vector2(0.0, -52.0), npc_text, Color("#dce8f4"), Color("#5a7a98"))
	if player_text != "":
		draw_bubble.call(vehicle_pos + Vector2(0.0, -42.0), player_text, Color("#f0e8d0"), Color("#c8a060"))


func should_hide_map_loot(district_index: int) -> bool:
	var story_id := _story_id_of_district(district_index)
	if story_id != "":
		return true
	return false


func build_prompt(story_id: String) -> Dictionary:
	var out := {
		"text": "",
		"disembark": "",
		"decline": "",
		"show_disembark": false,
		"show_decline": false,
		"show_story_choice": false,
		"show_reward_choice": false,
		"show_dialogue_options": false,
		"dialogue_options": [],
	}
	if story_id == "" or run_state.is_completed(story_id):
		return out
	if _uses_dialogue_file(story_id) and is_instance_valid(npc_dialogue) and npc_dialogue.is_active():
		if npc_dialogue.phase == _NpcDialogueRunner.Phase.OPTIONS:
			out["text"] = npc_dialogue.panel_text
			out["show_dialogue_options"] = true
			out["dialogue_options"] = npc_dialogue.get_option_labels()
			out["speaker"] = npc_dialogue.current_speaker
		elif npc_dialogue.phase == _NpcDialogueRunner.Phase.LINE:
			var body := npc_dialogue.panel_text.strip_edges()
			out["text"] = body if body != "" else "……"
			out["continue_hint"] = "按 E 继续"
			out["speaker"] = npc_dialogue.current_speaker
		return out
	if StoryData.is_interior_encounter(story_id):
		if run_state.is_quest_active(story_id):
			var quest: Dictionary = StoryData.quest_def(story_id)
			var need := int(quest.get("collect_count", 0))
			if run_state.get_collect_count(story_id) >= need:
				out["text"] = StoryData.prompt_return(story_id)
				out["disembark"] = StoryData.prompt_disembark(story_id)
				out["show_disembark"] = true
				return out
			out["text"] = str(quest.get("hint", "E 进入完成委托"))
			out["disembark"] = "进入 (E)"
			out["show_disembark"] = true
			return out
		out["text"] = "%s · E 进入" % StoryData.title_of(story_id)
		out["disembark"] = StoryData.prompt_disembark(story_id)
		out["show_disembark"] = true
		return out
	if is_instance_valid(gate_dialogue) and gate_dialogue.is_active():
		match gate_dialogue.phase:
			StoryGateDialogue.Phase.INTRO:
				out["text"] = "E 继续"
			StoryGateDialogue.Phase.INTRO_CHOICE:
				out["text"] = StoryData.gate_field(story_id, "choice_npc", "能帮我吗？")
				out["disembark"] = "帮忙"
				out["decline"] = "算了"
				out["show_story_choice"] = true
			StoryGateDialogue.Phase.REWARD_CHOICE:
				out["text"] = StoryData.reward_gate_npc(story_id)
				out["show_reward_choice"] = true
		return out
	if not run_state.is_quest_active(story_id) and not run_state.is_reward_pending(story_id):
		out["text"] = "%s · E 交谈（同意前无法入内）" % StoryData.title_of(story_id)
		out["disembark"] = StoryData.prompt_disembark(story_id)
		out["show_disembark"] = true
		return out
	if _uses_dialogue_file(story_id) and run_state.is_quest_active(story_id):
		var quest: Dictionary = StoryData.quest_def(story_id)
		var need := int(quest.get("collect_count", 0))
		if run_state.get_collect_count(story_id) >= need:
			out["text"] = StoryData.prompt_return(story_id)
			return out
		out["text"] = str(quest.get("hint", "E 进入完成委托"))
		out["disembark"] = "进入 (E)"
		out["show_disembark"] = true
		return out
	if run_state.is_reward_pending(story_id):
		out["text"] = StoryData.prompt_reward(story_id)
		return out
	var quest: Dictionary = StoryData.quest_def(story_id)
	out["text"] = str(quest.get("hint", "E 进入完成委托"))
	out["disembark"] = "进入 (E)"
	out["show_disembark"] = true
	return out


func foot_door_hint(district_index: int) -> String:
	var story_id := _story_id_of_district(district_index)
	if story_id != "" and blocks_foot_exit(district_index):
		return "先完成抉择"
	if story_id != "" and _uses_dialogue_file(story_id):
		var quest: Dictionary = StoryData.quest_def(story_id)
		var need := int(quest.get("collect_count", 0))
		if run_state.is_quest_active(story_id) and run_state.get_collect_count(story_id) >= need:
			return StoryData.prompt_return(story_id)
	if story_id != "" and run_state.is_reward_pending(story_id):
		return StoryData.prompt_reward(story_id)
	return "E 返回车辆"


func get_foot_loot_nodes() -> Array[Area2D]:
	var out: Array[Area2D] = []
	for node in _quest_nodes:
		if is_instance_valid(node):
			out.append(node)
	for node in _unlocked_loot_nodes:
		if is_instance_valid(node):
			out.append(node)
	return out


func get_foot_loot_local(node: Area2D, district_index: int) -> Vector2:
	return _foot_local_of_pickup(node, district_index)


func restore_after_load() -> void:
	for story_id in StoryData.all_story_ids():
		if run_state.is_quest_active(story_id):
			var district := run_state.get_district(story_id)
			if district >= 0:
				_sync_ambient_loot(story_id, district)
				_sync_quest_pickups(story_id, district)
				fix_foot_loot_positions(district)
	_try_reveal_tactical_sites_from_inventory()


func _reveal_tactical_hidden_sites(source_id: String = "") -> void:
	var map: WorldMapData = _map()
	if map == null:
		return
	if not map.reveal_tactical_hidden_sites(source_id):
		return
	if _host != null and _host.has_method("_on_tactical_sites_revealed"):
		_host.call("_on_tactical_sites_revealed", source_id)


func _try_reveal_tactical_sites_from_inventory() -> void:
	var backpack: InventoryData = _backpack()
	if backpack == null:
		return
	if backpack.has("data_chip_tactical_map", 1):
		_reveal_tactical_hidden_sites("staff_officer_07")
	if backpack.has("data_chip_radar_coords", 1):
		_reveal_tactical_hidden_sites("ad_1_radar")


func to_save_dict() -> Dictionary:
	return run_state.to_dictionary()


func load_save_dict(raw: Variant) -> void:
	run_state.load_from_dictionary(raw)


func _begin_gate_talk(story_id: String, district_index: int) -> void:
	if run_state.is_completed(story_id):
		return
	if run_state.is_quest_active(story_id) and not _uses_dialogue_file(story_id):
		return
	if _uses_dialogue_file(story_id):
		start_story_talk(story_id, district_index)
		return
	if run_state.is_quest_active(story_id):
		return
	_active_story_id = story_id
	run_state.set_district(story_id, district_index)
	_cache_gate_entrance(district_index)
	_ui_locked = true
	gate_dialogue.start_intro(story_id)


func _begin_reward_talk(story_id: String) -> void:
	if run_state.is_completed(story_id):
		return
	_active_story_id = story_id
	var district := run_state.get_district(story_id)
	if district < 0:
		district = district_for_story_at_node(_current_node_index(), story_id)
	if district >= 0:
		_cache_gate_entrance(district)
	_ui_locked = true
	gate_dialogue.start_reward(story_id)


func _on_quest_accepted(story_id: String) -> void:
	run_state.set_phase(story_id, StoryRunState.PHASE_QUEST)
	run_state.set_collect_count(story_id, 0)
	run_state.clear_dialogue_node(story_id)
	var district := run_state.get_district(story_id)
	if district < 0:
		district = district_for_story_at_node(_current_node_index(), story_id)
		if district >= 0:
			run_state.set_district(story_id, district)
	if district >= 0:
		_sync_quest_pickups(story_id, district)
		fix_foot_loot_positions(district)
	if _host != null:
		_host.queue_redraw()
	_ui_locked = false
	ui_refresh_requested.emit()


func _on_quest_declined(story_id: String) -> void:
	_ui_locked = false
	ui_refresh_requested.emit()


func _on_reward_chosen(story_id: String, choice: Dictionary) -> void:
	var encounter_id := str(choice.get("encounter_id", ""))
	var layer := int(_host.get("_current_layer")) if _host else 1
	var day_index := 1
	if _host and _host.get("time_system"):
		var ts = _host.time_system
		if is_instance_valid(ts):
			day_index = ts.day_index
	var journal: RunJournal = _journal()
	if journal != null and encounter_id != "":
		if journal.add_story_outcome(encounter_id, int(layer), day_index):
			print("[Journal] 记录：%s" % JournalData.title_of(encounter_id))
			_notify_journal_added(encounter_id)
	var district := run_state.get_district(story_id)
	var effects: Variant = choice.get("effects", [])
	if typeof(effects) == TYPE_ARRAY:
		apply_effects(district, effects)
	run_state.mark_done(story_id)
	_ui_locked = false
	ui_refresh_requested.emit()


func _on_npc_story_completed(story_id: String, result: Dictionary) -> void:
	if story_id == THUNDER_LEITING_STORY_ID:
		_ui_locked = false
		ui_refresh_requested.emit()
		return
	run_state.clear_dialogue_node(story_id)
	var encounter_id := str(result.get("encounter_id", ""))
	var layer := int(_host.get("_current_layer")) if _host else 1
	var day_index := 1
	if _host and _host.get("time_system"):
		var ts = _host.time_system
		if is_instance_valid(ts):
			day_index = ts.day_index
	var journal: RunJournal = _journal()
	if journal != null and encounter_id != "":
		if journal.add_story_outcome(encounter_id, int(layer), day_index):
			print("[Journal] 记录：%s" % JournalData.title_of(encounter_id))
			_notify_journal_added(encounter_id)
		else:
			push_warning("[Story] 日记未写入: %s (body=%s)" % [encounter_id, JournalData.body_of(encounter_id)])
	var loot_key := str(result.get("reward_loot_key", ""))
	if loot_key == "tactical_map" or encounter_id == "staff_officer_07_calibrate":
		_reveal_tactical_hidden_sites("staff_officer_07")
	if encounter_id == "ad_1_radar_coords":
		_reveal_tactical_hidden_sites("ad_1_radar")
	if loot_key != "":
		var district := run_state.get_district(story_id)
		var loot_def: Dictionary = StoryData.reward_loot_def(story_id, loot_key)
		var pickups: Variant = loot_def.get("pickups", [])
		if typeof(pickups) == TYPE_ARRAY:
			_spawn_unlocked_loot(district, pickups)
			fix_foot_loot_positions(district)
	run_state.mark_done(story_id)
	_ui_locked = false
	ui_refresh_requested.emit()


func _on_npc_dialogue_updated() -> void:
	if is_instance_valid(npc_dialogue) and not npc_dialogue.is_active():
		_ui_locked = false
	ui_refresh_requested.emit()


func _notify_journal_added(encounter_id: String) -> void:
	if _host != null and _host.has_method("_on_journal_entry_added"):
		_host.call("_on_journal_entry_added", encounter_id)


func _normalize_dialogue_entry(story_id: String, entry: String) -> String:
	if entry != "":
		return entry
	var saved := run_state.get_dialogue_node(story_id)
	if saved == "":
		return entry
	var post_quest_nodes := [
		"return_start",
		"give_two",
		"give_one_a",
		"give_one_b",
		"reward_choice",
		"repair_01",
		"repair_02",
	]
	if saved in post_quest_nodes:
		if not run_state.is_quest_active(story_id):
			run_state.clear_dialogue_node(story_id)
			return ""
		var need := int(StoryData.quest_def(story_id).get("collect_count", 0))
		if need > 0 and run_state.get_collect_count(story_id) < need and saved == "return_start":
			return "quest_remind"
	return entry


func _dialogue_context(story_id: String) -> Dictionary:
	return {
		"backpack": _backpack(),
		"get_variable": func(key: String) -> Variant: return run_state.get_variable(story_id, key),
		"set_variable": func(key: String, value: Variant) -> void: run_state.set_variable(story_id, key, value),
		"get_checkpoint": func() -> String: return run_state.get_dialogue_node(story_id),
		"set_checkpoint": func(node_id: String) -> void: run_state.set_dialogue_node(story_id, node_id),
		"clear_checkpoint": func() -> void: run_state.clear_dialogue_node(story_id),
		"get_quest_collect_count": func() -> int: return run_state.get_collect_count(story_id),
		"trigger_clone_restart": func() -> void:
			if _host != null and _host.has_method("_trigger_clone_restart"):
				_host.call("_trigger_clone_restart"),
	}


func apply_effects(district_index: int, effects: Array) -> void:
	for effect_var in effects:
		if typeof(effect_var) == TYPE_DICTIONARY:
			_story_apply_effect(district_index, effect_var)


func _story_apply_effect(district_index: int, effect: Dictionary) -> void:
	match str(effect.get("type", "")):
		"inventory_add":
			var items: Variant = effect.get("items", {})
			if typeof(items) != TYPE_DICTIONARY:
				return
			var backpack: InventoryData = _backpack()
			if backpack == null:
				return
			for item_id in items.keys():
				backpack.add(str(item_id), int(items[item_id]))
		"spawn_district_loot":
			var pickups: Variant = effect.get("pickups", [])
			if typeof(pickups) != TYPE_ARRAY or district_index < 0:
				return
			_spawn_unlocked_loot(district_index, pickups)


func _sync_ambient_loot(story_id: String, district_index: int) -> void:
	if story_id == "" or district_index < 0:
		return
	for node in _unlocked_loot_nodes:
		if not is_instance_valid(node):
			continue
		if int(node.get_meta("district_index", -1)) != district_index:
			continue
		if str(node.get_meta("ambient_story_id", "")) == story_id:
			return
	var pickups := StoryData.interior_ambient_loot_pickups(story_id)
	if pickups.is_empty():
		return
	_spawn_ambient_loot(story_id, district_index, pickups)
	fix_foot_loot_positions(district_index)


func _spawn_ambient_loot(story_id: String, district_index: int, pickups: Array) -> void:
	var map: WorldMapData = _map()
	if map == null:
		return
	map.ensure_foot_layout(district_index)
	var foot_origin := map.get_foot_origin(district_index)
	for pickup_var in pickups:
		if typeof(pickup_var) != TYPE_DICTIONARY:
			continue
		var pickup: Dictionary = pickup_var
		var item_id := str(pickup.get("item_id", "scrap"))
		var offset_arr: Variant = pickup.get("offset", [64, 64])
		var offset := Vector2(64, 64)
		if typeof(offset_arr) == TYPE_ARRAY and (offset_arr as Array).size() >= 2:
			offset = Vector2(float(offset_arr[0]), float(offset_arr[1]))
		var node := _create_pickup(district_index, item_id, foot_origin + offset, "", false)
		node.set_meta("ambient_story_id", story_id)
		_unlocked_loot_nodes.append(node)


func _sync_quest_pickups(story_id: String, district_index: int) -> void:
	_clear_quest_nodes()
	if story_id == "" or district_index < 0 or not run_state.is_quest_active(story_id):
		return
	var map: WorldMapData = _map()
	if map == null:
		return
	map.ensure_foot_layout(district_index)
	var quest: Dictionary = StoryData.quest_def(story_id)
	var item_id := str(quest.get("collect_item_id", ""))
	if item_id == "":
		return
	if bool(quest.get("interact_to_collect", false)):
		return
	var need := int(quest.get("collect_count", 1))
	var collected := run_state.get_collect_count(story_id)
	var remaining := need - collected
	if remaining <= 0:
		return
	var offsets: Variant = quest.get("interior_offsets", [])
	if typeof(offsets) != TYPE_ARRAY:
		return
	var foot_origin := map.get_foot_origin(district_index)
	var offset_arr: Array = offsets
	for i in range(collected, mini(need, offset_arr.size())):
		if remaining <= 0:
			break
		var offset_var: Variant = offset_arr[i]
		if typeof(offset_var) != TYPE_ARRAY:
			continue
		var arr: Array = offset_var
		if arr.size() < 2:
			continue
		var offset := Vector2(float(arr[0]), float(arr[1]))
		var node := _create_pickup(district_index, item_id, foot_origin + offset, story_id, true)
		node.set_meta("foot_local", offset)
		_quest_nodes.append(node)
		remaining -= 1


func _spawn_unlocked_loot(district_index: int, pickups: Array) -> void:
	var map: WorldMapData = _map()
	if map == null:
		return
	map.ensure_foot_layout(district_index)
	var foot_origin := map.get_foot_origin(district_index)
	for pickup_var in pickups:
		if typeof(pickup_var) != TYPE_DICTIONARY:
			continue
		var pickup: Dictionary = pickup_var
		var item_id := str(pickup.get("item_id", "scrap"))
		var offset_arr: Variant = pickup.get("offset", [64, 64])
		var offset := Vector2(64, 64)
		if typeof(offset_arr) == TYPE_ARRAY and (offset_arr as Array).size() >= 2:
			offset = Vector2(float(offset_arr[0]), float(offset_arr[1]))
		var node := _create_pickup(district_index, item_id, foot_origin + offset, "", false)
		_unlocked_loot_nodes.append(node)


func _create_pickup(district_index: int, item_id: String, world_pos: Vector2, story_id: String, is_quest: bool) -> Area2D:
	var scene: PackedScene = _host.get("resource_scene") if _host else null
	if scene == null:
		scene = load("res://scenes/resource_pickup.tscn")
	var pickup: Area2D = scene.instantiate()
	_host.add_child(pickup)
	pickup.visible = false
	pickup.monitorable = false
	pickup.monitoring = false
	var collision := pickup.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if is_instance_valid(collision):
		collision.disabled = true
	var sprite := pickup.get_node_or_null("Sprite2D") as Sprite2D
	if is_instance_valid(sprite):
		sprite.visible = false
	var label := pickup.get_node_or_null("Label") as Label
	if is_instance_valid(label):
		label.visible = false
	pickup.position = world_pos
	var map: WorldMapData = _map()
	if map != null:
		_set_pickup_foot_local(pickup, district_index, map.get_foot_origin(district_index))
	pickup.set_meta("district_index", district_index)
	pickup.set_meta("item_id", item_id)
	pickup.set_meta("skip_map_resource", true)
	if story_id != "":
		pickup.set_meta("story_id", story_id)
	if is_quest:
		pickup.set_meta("story_quest", true)
		var quest := StoryData.quest_def(story_id)
		if bool(quest.get("interact_to_collect", false)):
			pickup.set_meta("interact_only", true)
			var prop_id := str(quest.get("pickup_prop", ""))
			if prop_id != "":
				pickup.set_meta("pickup_prop", prop_id)
	if pickup.has_method("setup_loot"):
		pickup.setup_loot(item_id)
	if pickup.has_signal("collected") and _host.has_method("_on_resource_collected"):
		pickup.collected.connect(_host._on_resource_collected.bind(district_index))
	return pickup


func _cache_gate_entrance(district_index: int) -> void:
	var map: WorldMapData = _map()
	var node_index := _current_node_index()
	if map != null and map.is_valid_index(node_index):
		var road_rect := map.cell_rect(node_index)
		var side := (map.cell_center(district_index) - map.cell_center(node_index))
		if side.length_squared() > 1.0:
			_gate_entrance_world = DayTopdownRender.roadside_facade_entrance(road_rect, side.normalized())
			return
	if map != null:
		_gate_entrance_world = map.get_building_entrance_world_pos(district_index)


func _story_id_of_district(district_index: int) -> String:
	var map: WorldMapData = _map()
	if map == null or not map.is_district(district_index):
		return ""
	var cell := map.get_cell(district_index)
	var sid := str(cell.get("story_id", ""))
	if sid != "":
		return sid
	var tag := str(cell.get("special_encounter", ""))
	if tag != "":
		return StoryData.story_id_for_district_tag(tag)
	return ""


func _current_node_index() -> int:
	if _host == null:
		return -1
	return int(_host.get("_current_node_index"))


func _map() -> WorldMapData:
	if _host == null:
		return null
	return _host.get("_map") as WorldMapData


func _backpack() -> InventoryData:
	if _host == null:
		return null
	return _host.get("_backpack") as InventoryData


func _journal() -> RunJournal:
	if _host == null:
		return null
	return _host.get("_run_journal") as RunJournal


func _clear_quest_nodes() -> void:
	for node in _quest_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_quest_nodes.clear()


func _clear_unlocked_loot_nodes() -> void:
	for node in _unlocked_loot_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_unlocked_loot_nodes.clear()


func _prune_invalid_quest_nodes() -> void:
	for i in range(_quest_nodes.size() - 1, -1, -1):
		if not is_instance_valid(_quest_nodes[i]):
			_quest_nodes.remove_at(i)


func _prune_invalid_unlocked_loot_nodes() -> void:
	for i in range(_unlocked_loot_nodes.size() - 1, -1, -1):
		if not is_instance_valid(_unlocked_loot_nodes[i]):
			_unlocked_loot_nodes.remove_at(i)
