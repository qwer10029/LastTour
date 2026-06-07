extends Node
class_name StoryController

signal ui_refresh_requested

var run_state := StoryRunState.new()
var gate_dialogue: StoryGateDialogue
var _host: Node
var _quest_nodes: Array[Area2D] = []
var _unlocked_loot_nodes: Array[Area2D] = []
var _gate_entrance_world: Vector2 = Vector2.ZERO
var _active_story_id: String = ""
var _ui_locked := false


func setup(host: Node) -> void:
	_host = host
	gate_dialogue = StoryGateDialogue.new()
	gate_dialogue.name = "StoryGateDialogue"
	add_child(gate_dialogue)
	gate_dialogue.quest_accepted.connect(_on_quest_accepted)
	gate_dialogue.quest_declined.connect(_on_quest_declined)
	gate_dialogue.reward_chosen.connect(_on_reward_chosen)
	gate_dialogue.dialogue_updated.connect(func(): ui_refresh_requested.emit())


func reset_for_new_run() -> void:
	run_state.clear()
	_clear_quest_nodes()
	_clear_unlocked_loot_nodes()
	_gate_entrance_world = Vector2.ZERO
	_active_story_id = ""
	_ui_locked = false
	if is_instance_valid(gate_dialogue):
		gate_dialogue.phase = StoryGateDialogue.Phase.IDLE


func is_ui_locked() -> bool:
	return _ui_locked or (is_instance_valid(gate_dialogue) and gate_dialogue.is_active())


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
	if run_state.is_completed(story_id):
		return false
	if run_state.is_reward_pending(story_id):
		return false
	if not run_state.is_quest_active(story_id):
		return false
	var quest: Dictionary = StoryData.quest_def(story_id)
	var need := int(quest.get("collect_count", 0))
	return run_state.get_collect_count(story_id) < need


func handle_drive_interact(node_index: int) -> bool:
	var story_id := story_id_at_node(node_index)
	if story_id == "" or run_state.is_completed(story_id):
		return false
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


func try_enter_district(district_index: int) -> bool:
	if not can_enter_district(district_index):
		var story_id := _story_id_of_district(district_index)
		if story_id != "":
			_begin_gate_talk(story_id, district_index)
		return false
	return true


func on_entered_district_foot(district_index: int) -> void:
	var story_id := _story_id_of_district(district_index)
	if story_id == "" or not run_state.is_quest_active(story_id):
		return
	run_state.set_district(story_id, district_index)
	_sync_quest_pickups(story_id, district_index)
	fix_foot_loot_positions(district_index)


func on_exited_district_to_drive(district_index: int) -> bool:
	var story_id := _story_id_of_district(district_index)
	if story_id == "":
		return false
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


func try_collect_foot_loot(district_index: int, player_local: Vector2, radius: float = 80.0) -> void:
	_prune_invalid_quest_nodes()
	_prune_invalid_unlocked_loot_nodes()
	for node in _quest_nodes.duplicate():
		_try_collect_node(node, district_index, player_local, radius)
	for node in _unlocked_loot_nodes.duplicate():
		_try_collect_node(node, district_index, player_local, radius)


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
	if count >= need:
		run_state.set_phase(story_id, StoryRunState.PHASE_REWARD)
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


func draw_gate_bubbles(canvas: CanvasItem, vehicle_pos: Vector2, draw_bubble: Callable) -> void:
	if not is_instance_valid(gate_dialogue) or not gate_dialogue.is_active():
		return
	var gate := _gate_entrance_world
	if gate == Vector2.ZERO:
		var district := run_state.get_district(_active_story_id)
		if district >= 0 and _map() != null:
			gate = _map().get_building_entrance_world_pos(district)
	canvas.draw_circle(gate, 14.0, Color("#6a8ca8", 0.35))
	canvas.draw_circle(gate, 14.0, Color("#9ef0ff", 0.55), false, 2.0)
	if gate_dialogue.npc_bubble != "":
		draw_bubble.call(gate + Vector2(0.0, -38.0), gate_dialogue.npc_bubble, Color("#dce8f4"), Color("#5a7a98"))
	if gate_dialogue.player_bubble != "":
		draw_bubble.call(vehicle_pos + Vector2(0.0, -42.0), gate_dialogue.player_bubble, Color("#f0e8d0"), Color("#c8a060"))


func should_hide_map_loot(district_index: int) -> bool:
	var story_id := _story_id_of_district(district_index)
	if story_id == "":
		return false
	if run_state.is_completed(story_id):
		return false
	return run_state.is_quest_active(story_id) or run_state.is_reward_pending(story_id)


func build_prompt(story_id: String) -> Dictionary:
	var out := {
		"text": "",
		"disembark": "",
		"decline": "",
		"show_disembark": false,
		"show_decline": false,
		"show_story_choice": false,
		"show_reward_choice": false,
	}
	if story_id == "" or run_state.is_completed(story_id):
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
		out["text"] = "%s · E 与 NPC 交谈（同意前无法入内）" % StoryData.title_of(story_id)
		return out
	if run_state.is_reward_pending(story_id):
		out["text"] = "E 与哨兵交谈领取报酬"
		return out
	var quest: Dictionary = StoryData.quest_def(story_id)
	out["text"] = str(quest.get("hint", "E 进入完成委托"))
	out["disembark"] = "进入 (E)"
	out["show_disembark"] = true
	return out


func foot_door_hint(district_index: int) -> String:
	var story_id := _story_id_of_district(district_index)
	if story_id != "" and run_state.is_reward_pending(story_id):
		return "E 回营门口"
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
				_sync_quest_pickups(story_id, district)
				fix_foot_loot_positions(district)


func to_save_dict() -> Dictionary:
	return run_state.to_dictionary()


func load_save_dict(raw: Variant) -> void:
	run_state.load_from_dictionary(raw)


func _begin_gate_talk(story_id: String, district_index: int) -> void:
	if run_state.is_completed(story_id) or run_state.is_quest_active(story_id):
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
	var district := run_state.get_district(story_id)
	if district < 0:
		district = district_for_story_at_node(_current_node_index(), story_id)
		if district >= 0:
			run_state.set_district(story_id, district)
	if district >= 0:
		_sync_quest_pickups(story_id, district)
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
	var district := run_state.get_district(story_id)
	var effects: Variant = choice.get("effects", [])
	if typeof(effects) == TYPE_ARRAY:
		apply_effects(district, effects)
	run_state.mark_done(story_id)
	_ui_locked = false
	ui_refresh_requested.emit()


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
