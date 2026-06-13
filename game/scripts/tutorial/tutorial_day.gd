extends "res://scripts/day_exploration.gd"

const TutorialMapBuilderScript := preload("res://scripts/tutorial/tutorial_map_builder.gd")
const TutorialDirectorScript := preload("res://scripts/tutorial/tutorial_director.gd")

var _tutorial_director: TutorialDirector
var _warehouse_node_index: int = -1
var _elevator_node_index: int = -1
var _tutorial_crafted_parts := false


func _is_tutorial_run() -> bool:
	return true


func _boot_exploration_scene(overlay_flags: Dictionary) -> void:
	enable_road_tuning_panel = false
	war_fog_enabled = false
	base_elevator_repair_cost = 1
	fuel_max = 999.0
	if is_instance_valid(time_system):
		time_system.day_duration_sec = 99999.0
		time_system.evening_warning_sec = 0.0
	await super._boot_exploration_scene(overlay_flags)
	_setup_tutorial_director()
	_ensure_tutorial_daylight()


func _start_new_run() -> void:
	_run_ended = false
	_run_end_reason = ""
	_final_choice_id = ""
	_final_defense_cleared = false
	_thunder_leiting_defeated = false
	_tower_upgrades = NightTdUpgrades.default_state()
	_blueprint_state = BlueprintCatalog.default_run_state()
	_pending_thunder_district = -1
	_run_journal = RunJournal.new()
	_story_controller.reset_for_new_run()
	_init_tutorial_loadout()
	if GameManager.has_run_bootstrap():
		_apply_pregenerated_map(GameManager.consume_run_bootstrap())
	else:
		_map = TutorialMapBuilderScript.build_tutorial_map()
	_clear_story_from_tutorial_map()
	_warehouse_node_index = TutorialMapBuilderScript.warehouse_node_index(_map)
	_elevator_node_index = TutorialMapBuilderScript.elevator_node_index(_map)
	_tutorial_crafted_parts = false
	_current_layer = 1
	_elevator_repair_progress = 0
	_current_district_index = -1
	_apply_overworld_biome_for_layer()
	_fuel = fuel_max
	_reset_vehicle_hp_for_new_run()
	_spawn_resources()
	if is_instance_valid(minimap_view):
		minimap_view.set_world_map(_map)
		minimap_view.set_war_fog_enabled(false)
	if _map.start_node_index >= 0:
		_enter_node(_map.start_node_index, true)
	if is_instance_valid(time_system):
		time_system.day_duration_sec = 99999.0
		time_system.evening_warning_sec = 0.0
		time_system.start_day(1)
	_ensure_tutorial_daylight()
	_play_music_cue("day_exploration", 1.0)
	if is_instance_valid(_tutorial_director):
		_tutorial_director.set_phase("day", "drive")


func _init_tutorial_loadout() -> void:
	_survival.reset_for_new_run()
	_backpack.clear()
	_backpack.apply_starting_items(GameManager.get_tutorial_starting_items())


func _setup_tutorial_director() -> void:
	if is_instance_valid(_tutorial_director):
		return
	_tutorial_director = TutorialDirectorScript.new()
	_tutorial_director.name = "TutorialDirector"
	add_child(_tutorial_director)
	var rs = GameManager.run_state
	if rs != null and str(rs.tutorial_phase) == "elevator":
		_tutorial_director.set_phase("elevator", str(rs.tutorial_step if rs.tutorial_step != "" else "go_elevator"))
	else:
		_tutorial_director.set_phase("day", "drive")


func _apply_save_data(data: Dictionary) -> void:
	super._apply_save_data(data)
	_clear_story_from_tutorial_map()
	_warehouse_node_index = TutorialMapBuilderScript.warehouse_node_index(_map)
	_elevator_node_index = TutorialMapBuilderScript.elevator_node_index(_map)


func init_from_run_state(rs) -> void:
	super.init_from_run_state(rs)
	_clear_story_from_tutorial_map()
	_warehouse_node_index = TutorialMapBuilderScript.warehouse_node_index(_map)
	_elevator_node_index = TutorialMapBuilderScript.elevator_node_index(_map)
	_ensure_tutorial_daylight()
	if rs != null and str(rs.tutorial_phase) == "elevator":
		call_deferred("_restore_after_tutorial_night")


func _restore_after_tutorial_night() -> void:
	_handling_night_transition = false
	_clear_story_from_tutorial_map()
	if is_instance_valid(_story_controller):
		_story_controller.reset_for_new_run()
	_ensure_tutorial_daylight()
	if is_instance_valid(_tutorial_director):
		_tutorial_director.set_phase("elevator", "go_elevator")
	_mark_overworld_dirty()
	_sync_day_entity_visibility()
	_refresh_ui()
	queue_redraw()


func _clear_story_from_tutorial_map() -> void:
	for cell in _map.cells:
		cell["story_id"] = ""
		cell["district_tag"] = ""
		cell["special_encounter"] = ""
	_restore_tutorial_district_types()
	if is_instance_valid(_story_controller):
		_story_controller.reset_for_new_run()


func _restore_tutorial_district_types() -> void:
	var warehouse_index := TutorialMapBuilderScript.warehouse_node_index(_map)
	if _map.is_valid_index(warehouse_index):
		var warehouse_cell: Dictionary = _map.cells[warehouse_index]
		warehouse_cell["building_type"] = "warehouse"
		warehouse_cell["has_elevator"] = false
		warehouse_cell["has_kunlun_control"] = false
	var elevator_index := TutorialMapBuilderScript.elevator_node_index(_map)
	if _map.is_valid_index(elevator_index):
		var elevator_cell: Dictionary = _map.cells[elevator_index]
		elevator_cell["building_type"] = "elevator"
		elevator_cell["has_elevator"] = true
		elevator_cell["has_kunlun_control"] = false


func _ensure_tutorial_daylight() -> void:
	var keep_evening := (
		is_instance_valid(_tutorial_director)
		and _tutorial_director.phase == "day"
		and _tutorial_director.current_step == "evening"
	)
	if not keep_evening:
		_evening_tint = 0.0
	if is_instance_valid(evening_notice) and evening_notice.has_method("hide_notice") and not keep_evening:
		evening_notice.hide_notice()
	if not is_instance_valid(time_system):
		return
	if not keep_evening and time_system.phase != TimeSystem.Phase.DAY:
		time_system.start_day(maxi(time_system.day_index, 1))
	time_system.resume()


func _on_evening_warning(_remaining_sec: float) -> void:
	if not is_instance_valid(_tutorial_director):
		return
	if _tutorial_director.phase != "day" or _tutorial_director.current_step != "evening":
		return
	_show_tutorial_defense_reminder()


func _update_evening_tint(delta: float) -> void:
	if is_instance_valid(_tutorial_director):
		var allow_dim := (
			_tutorial_director.phase == "day"
			and _tutorial_director.current_step == "evening"
		)
		if not allow_dim:
			_evening_tint = move_toward(_evening_tint, 0.0, delta * 3.0)
			return
	super._update_evening_tint(delta)


func _can_enter_district(district_index: int) -> bool:
	return _map.is_valid_index(district_index) and _map.is_district(district_index)


func _on_disembark_pressed() -> void:
	if _mode == TravelMode.DRIVE and _segment_target_index < 0:
		var buildings := _get_enterable_buildings()
		if not buildings.is_empty():
			var district_index := _selected_enterable_district()
			if district_index >= 0:
				_begin_foot_mode(district_index)
				_refresh_ui()
				return
	super._on_disembark_pressed()


func _begin_foot_mode(district_index: int = -1) -> void:
	if district_index < 0:
		district_index = _current_district_index
	if district_index < 0 or not _map.is_district(district_index):
		return
	_current_district_index = district_index
	_map.ensure_foot_layout(_current_district_index)
	_mode = TravelMode.FOOT
	_segment_target_index = -1
	if is_instance_valid(_vehicle):
		_vehicle.set_active(false)
	if is_instance_valid(_player):
		_player.set_active(true)
		_player.set_physics_process(false)
	var foot_origin := _map.get_foot_origin(_current_district_index)
	var door_world := _map.get_foot_door_world_pos(_current_district_index)
	_foot_local_pos = door_world - foot_origin
	_apply_foot_world_position()
	_sync_day_entity_visibility()
	_refresh_resource_pickups()
	_mark_overworld_dirty()
	queue_redraw()
	_sync_tutorial_objective_override()


func _show_tutorial_defense_reminder() -> void:
	if is_instance_valid(evening_notice) and evening_notice.has_method("show_evening_warning"):
		var remaining := 600.0
		if is_instance_valid(time_system):
			remaining = maxf(time_system.get_day_remaining_sec(), 60.0)
		evening_notice.show_evening_warning(remaining)


func _begin_tutorial_evening_phase() -> void:
	if not is_instance_valid(time_system):
		return
	time_system.evening_warning_sec = 600.0
	if time_system.phase != TimeSystem.Phase.EVENING:
		time_system.begin_evening_phase()
	time_system.resume()


func _open_backpack(open_journal_tab: bool = false) -> void:
	super._open_backpack(open_journal_tab)
	_sync_tutorial_craft_highlight()
	_sync_tutorial_objective_override()


func _refresh_backpack_if_open() -> void:
	super._refresh_backpack_if_open()
	_sync_tutorial_craft_highlight()


func _sync_tutorial_craft_highlight() -> void:
	if not is_instance_valid(_backpack_ui) or not is_instance_valid(_tutorial_director):
		return
	if _backpack_ui.has_method("set_craft_highlight"):
		_backpack_ui.set_craft_highlight(_tutorial_director.should_highlight_craft())


func capture_save_data() -> Dictionary:
	var data := super.capture_save_data()
	data["run_context"] = "tutorial"
	if is_instance_valid(_tutorial_director):
		data["tutorial_phase"] = _tutorial_director.phase
		data["tutorial_step"] = _tutorial_director.current_step
	return data


func export_run_state():
	var rs = super.export_run_state()
	rs.run_context = "tutorial"
	if is_instance_valid(_tutorial_director):
		rs.tutorial_phase = _tutorial_director.phase
		rs.tutorial_step = _tutorial_director.current_step
	return rs


func _on_night_setup_scene_switch(day_index: int, _manual_setup: bool) -> void:
	if _handling_night_transition:
		return
	_handling_night_transition = true
	_night_result_applied = false
	_force_return_to_vehicle_for_night()
	if is_instance_valid(time_system):
		time_system.pause()
	if is_instance_valid(evening_notice) and evening_notice.has_method("hide_notice"):
		evening_notice.hide_notice()

	if is_instance_valid(_tutorial_director):
		_tutorial_director.set_phase("night", "place_tower")
	var rs = export_run_state()
	if is_instance_valid(_backpack) and _backpack.has_method("to_dictionary"):
		rs.backpack_dict = _backpack.to_dictionary().duplicate()
	rs.night_session_options = _build_tutorial_night_options()
	rs.night_context = "tutorial"
	GameManager.go_to_night_with_loading(rs)


func _build_tutorial_night_options() -> Dictionary:
	return {
		"kind": "tutorial",
		"wave_plan_path": "res://data/night_td/waves/tutorial_wave.json",
		"phase_title": "教学 · 守夜",
		"no_day_advance": true,
		"tutorial_flags": {
			"hide_power_panel": true,
			"hide_emergency_fuel": true,
			"hide_heatmap_until_place": true,
			"gradual_features": true,
			"setup_time_sec": 120.0,
		},
	}


func _close_backpack() -> void:
	super._close_backpack()
	_sync_tutorial_objective_override()


func _on_backpack_closed() -> void:
	super._on_backpack_closed()
	_sync_tutorial_objective_override()


func _sync_tutorial_objective_override() -> void:
	if not is_instance_valid(_tutorial_director):
		return
	if _backpack_open and _tutorial_director.current_step in ["return", "evening"]:
		_tutorial_director.set_objective_override(_tutorial_director.override_hint("close_backpack"))
		return
	if _backpack_open and _tutorial_director.current_step == "craft":
		_tutorial_director.set_objective_override("")
		return
	if _tutorial_director.current_step == "craft" and not _backpack_open:
		_tutorial_director.set_objective_override(_tutorial_director.override_hint("open_backpack"))
		return
	if _mode == TravelMode.FOOT and _tutorial_director.phase == "day":
		match _tutorial_director.current_step:
			"enter":
				_tutorial_director.set_objective_override(_tutorial_director.override_hint("foot_move"))
				return
			"loot":
				_tutorial_director.set_objective_override(_tutorial_director.override_hint("foot_loot"))
				return
			"return":
				if _is_near_foot_door():
					_tutorial_director.set_objective_override(_tutorial_director.override_hint("foot_return_near_door"))
				else:
					_tutorial_director.set_objective_override(_tutorial_director.override_hint("foot_return_go_door"))
				return
	_tutorial_director.set_objective_override("")


func _try_enter_defense_mode() -> bool:
	if is_instance_valid(_tutorial_director) and not _tutorial_director.is_action_allowed("enter_defense"):
		return false
	if (
		is_instance_valid(_tutorial_director)
		and _tutorial_director.current_step == "evening"
		and is_instance_valid(time_system)
	):
		if _game_paused or _backpack_open:
			return false
		if _segment_target_index >= 0:
			_cancel_drive_segment_for_night()
		if _segment_target_index >= 0:
			return false
		_ensure_vehicle_ready_for_night()
		if _mode != TravelMode.DRIVE:
			return false
		time_system.enter_night_setup(true)
		return true
	return super._try_enter_defense_mode()


func _on_backpack_craft_parts() -> void:
	var parts_before := _backpack.count("parts")
	super._on_backpack_craft_parts()
	if _backpack.count("parts") <= parts_before:
		return
	_tutorial_crafted_parts = true
	if is_instance_valid(_tutorial_director):
		_tutorial_director.advance_to("return")
	_sync_tutorial_craft_highlight()
	_sync_tutorial_objective_override()


func _physics_process(delta: float) -> void:
	if not _run_ended and not _game_paused and not _backpack_open:
		if Input.is_action_just_pressed("interact"):
			if _mode == TravelMode.FOOT:
				if not _try_foot_return_to_vehicle():
					_handle_foot_interact()
				return
			if _mode == TravelMode.DRIVE and _segment_target_index < 0:
				if _tutorial_try_drive_enter_building():
					return
				return
	super._physics_process(delta)


func _tutorial_try_drive_enter_building() -> bool:
	if _mode != TravelMode.DRIVE or _segment_target_index >= 0:
		return false
	var buildings := _get_enterable_buildings()
	if buildings.is_empty():
		return false
	var district_index := _selected_enterable_district()
	if district_index < 0:
		return false
	_begin_foot_mode(district_index)
	_refresh_ui()
	return true


func _try_foot_return_to_vehicle() -> bool:
	if _mode != TravelMode.FOOT:
		return false
	if not _is_near_foot_door():
		return false
	_return_to_vehicle()
	return true


func _handle_foot_interact() -> void:
	if is_instance_valid(_story_controller):
		if _story_controller.try_interact_foot_loot(_current_district_index, _foot_local_pos):
			queue_redraw()
			return
	if _try_foot_console_interact():
		return


func _restore_foot_mode_from_save(foot: Dictionary) -> void:
	if _current_district_index < 0:
		_mode = TravelMode.DRIVE
		_restore_drive_state_after_load()
		return
	if is_instance_valid(_vehicle):
		_vehicle.set_active(false)
	if is_instance_valid(_player):
		_player.set_active(true)
		_player.set_physics_process(false)
	_map.ensure_foot_layout(_current_district_index)
	var foot_origin := _map.get_foot_origin(_current_district_index)
	_foot_local_pos = Vector2(float(foot.get("player_x", 0.0)), float(foot.get("player_y", 0.0))) - foot_origin
	if foot.has("player_x"):
		_apply_foot_world_position()
	else:
		var door_world := _map.get_foot_door_world_pos(_current_district_index)
		_foot_local_pos = door_world - foot_origin
		_apply_foot_world_position()
	for node in _resource_nodes:
		if is_instance_valid(node):
			node.visible = int(node.get_meta("district_index", -1)) == _current_district_index
	_sync_day_entity_visibility()
	_refresh_ui()


func _process(delta: float) -> void:
	super._process(delta)
	_poll_tutorial_director()
	if _mode == TravelMode.FOOT:
		_sync_tutorial_objective_override()


func _poll_tutorial_director() -> void:
	if not is_instance_valid(_tutorial_director) or _run_ended:
		return
	if _tutorial_director.phase == "elevator":
		if _tutorial_director.current_step == "go_elevator":
			if _mode == TravelMode.FOOT and _current_district_index == _elevator_node_index:
				_tutorial_director.advance_to("repair_elevator")
		return
	if _tutorial_director.phase != "day":
		return
	match _tutorial_director.current_step:
		"drive":
			if _is_near_warehouse_for_tutorial():
				_tutorial_director.advance_to("enter")
		"enter":
			if _mode == TravelMode.FOOT and _current_district_index == _warehouse_node_index:
				_tutorial_director.advance_to("loot")
		"loot":
			if _warehouse_loot_complete():
				_tutorial_director.advance_to("craft")
				_sync_tutorial_craft_highlight()
				_sync_tutorial_objective_override()
		"craft":
			if _tutorial_crafted_parts:
				_tutorial_director.advance_to("return")
				_sync_tutorial_craft_highlight()
			else:
				_sync_tutorial_craft_highlight()
		"return":
			if _mode == TravelMode.DRIVE:
				_tutorial_director.advance_to("evening")
				_begin_tutorial_evening_phase()
				_show_tutorial_defense_reminder()
				_sync_tutorial_objective_override()


func _is_near_warehouse_for_tutorial() -> bool:
	if _warehouse_node_index < 0:
		return false
	if _current_node_index == _warehouse_node_index:
		return true
	var approach := int(_map.cells[_warehouse_node_index].get("approach_road_index", -1))
	return _current_node_index == approach


func _warehouse_loot_complete() -> bool:
	if _warehouse_node_index < 0 or not _map.is_valid_index(_warehouse_node_index):
		return false
	return int(_map.cells[_warehouse_node_index].get("resource_remaining", 0)) <= 0


func _repair_with_material(material: String) -> void:
	if is_instance_valid(_tutorial_director) and _tutorial_director.phase == "elevator":
		_repair_tutorial_elevator(material)
		return
	super._repair_with_material(material)


func _show_repair_choices() -> void:
	super._show_repair_choices()
	if is_instance_valid(_tutorial_director) and _tutorial_director.phase == "elevator":
		_show_repair_choicf_hint("三种材料任选其一，均可推进 1 步修复进度", false)


func _elevator_consolf_hint_text() -> String:
	if is_instance_valid(_tutorial_director) and _tutorial_director.phase == "elevator":
		return "F 修复电梯（零件/废料/木材+废料 三选一均可）· %d/%d" % [
			_elevator_repair_progress,
			_current_repair_cost(),
		]
	return super._elevator_consolf_hint_text()


func _repair_tutorial_elevator(material: String) -> void:
	if not _has_repair_material(material):
		_refresh_repair_choice_popup("资源不足", true)
		return
	var consumed := false
	match material:
		"parts":
			consumed = _backpack.remove("parts", _elevator_repair_parts_cost())
		"scrap":
			consumed = _backpack.remove("scrap", _elevator_repair_scrap_cost())
		"wood_scrap":
			consumed = (
				_backpack.remove("wood", _elevator_repair_wood_cost())
				and _backpack.remove("scrap", _elevator_repair_scrap_alt_cost())
			)
	if not consumed:
		_refresh_repair_choice_popup("资源不足", true)
		return
	_elevator_repair_progress += 1
	_refresh_ui()
	_close_repair_choice_popup()
	GameManager.finish_tutorial_run()


func get_warehouse_node_index() -> int:
	return _warehouse_node_index


func get_elevator_node_index() -> int:
	return _elevator_node_index


func _draw_door_exit_hint(door_rect: Rect2) -> void:
	if _should_show_tutorial_backpack_close_hint():
		var close_hint := _tutorial_director.override_hint("foot_close_backpack")
		_draw_tutorial_foot_hint_bubble(door_rect, close_hint, Color("#6ec8e8", 0.52), Color("#b8e8ff"))
		return
	if is_instance_valid(_tutorial_director) and _tutorial_director.current_step == "return":
		var door_text := _tutorial_director.override_hint("foot_door_go")
		if _is_near_foot_door():
			door_text = _tutorial_director.override_hint("foot_door_enter")
		_draw_tutorial_foot_hint_bubble(door_rect, door_text, Color("#c8a060", 0.42), Color("#f0d8a0"))
		return
	super._draw_door_exit_hint(door_rect)


func _should_show_tutorial_backpack_close_hint() -> bool:
	if not _backpack_open or not is_instance_valid(_tutorial_director):
		return false
	return _tutorial_director.current_step in ["return", "evening"]


func _draw_tutorial_foot_hint_bubble(
	door_rect: Rect2,
	text: String,
	border: Color,
	fill: Color,
) -> void:
	if _current_district_index < 0 or _mode != TravelMode.FOOT:
		return
	if door_rect.size.x <= 0.0 or door_rect.size.y <= 0.0:
		return
	var bubble_w := clampf(float(text.length()) * 10.0 + 24.0, 72.0, 200.0)
	var bubble_h := 16.0
	var door_center_x := door_rect.position.x + door_rect.size.x * 0.5
	var bubble_pos := Vector2(door_center_x - bubble_w * 0.5, door_rect.position.y - bubble_h - 10.0)
	draw_rect(Rect2(bubble_pos, Vector2(bubble_w, bubble_h)), Color(0.05, 0.09, 0.13, 0.74), true)
	draw_rect(Rect2(bubble_pos, Vector2(bubble_w, bubble_h)), border, false, 1.0)
	HudTheme.draw_string(self, bubble_pos + Vector2(10.0, 12.0), text, 10, fill)
