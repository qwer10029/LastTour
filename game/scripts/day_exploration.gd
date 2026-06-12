extends "res://scripts/main.gd"

## DayExploration — 白天探索场景的根节点脚本。
## 继承 main.gd 的全部探索逻辑，但重写日夜切换为场景级别的切换：
## 不再使用内嵌的 NightTd 子节点，而是通过 GameManager 切换到独立的 night_td.tscn。
##
## 与 main.gd 的关键区别：
## - 没有 NightTd 子节点（night_td 始终为 null）
## - 傍晚/夜晚时通过 GameManager 切换到 night_td.tscn
## - 初始化时从 GameManager.run_state 恢复状态

var _handling_night_transition := false


func _ready() -> void:
	night_td = null
	var overlay_flags := {
		"enter": GameManager.should_dismiss_enter_overlay(),
		"transition": GameManager.should_dismiss_transition_overlay(),
	}
	call_deferred("_boot_exploration_scene", overlay_flags)


func _boot_exploration_scene(overlay_flags: Dictionary) -> void:
	# 初始化基础配置
	_base_fuel_max = fuel_max
	_base_elevator_repair_cost = base_elevator_repair_cost
	_apply_run_config_from_manager()
	if road_render_settings == null:
		road_render_settings = RoadRenderSettings.new()
	DayTopdownRender.apply_settings(road_render_settings)
	# 幂等预热：贴图已缓存则秒回，避免每次昼夜场景切换都重新解码+抠图导致的卡顿。
	# 生物群系变化时 set_overworld_biome() 会自行 reload，故此处不再无条件失效缓存。
	DayTopdownRender.preload_road_textures()
	DayTopdownRender.preload_prop_textures()
	if enable_road_tuning_panel:
		_setup_road_tuning_panel()
	_ensure_input_actions()
	_connect_buttons()
	_setup_pause_ui()
	_setup_backpack_ui()
	_setup_fuel_empty_dialog()
	_setup_story_controller()
	_setup_run_end_ui()
	_setup_stat_bars()
	_setup_world_camera()
	_setup_minimap_hud()
	_setup_world_map_overlay()
	_setup_hud_theme()
	_setup_repair_choice_popup()
	_spawn_vehicle()
	_spawn_player()
	# 用自己的日夜系统（场景切换模式）
	_setup_day_night_scene_switch()

	# 从 GameManager 的 RunState 恢复（场景切换后）、读档或开始新游戏
	if GameManager.consume_load_save_request():
		var save_data: Dictionary = SaveManager.load_game()
		if save_data.is_empty():
			_start_new_run()
		else:
			_apply_save_data(save_data)
	elif GameManager.run_state != null and not GameManager.run_state.to_full_dict().is_empty():
		init_from_run_state(GameManager.run_state)
	else:
		_start_new_run()
	_sync_view_cameras()
	_sync_day_entity_visibility()
	_refresh_ui()
	queue_redraw()
	await _release_pending_overlays(overlay_flags)


func _release_pending_overlays(overlay_flags: Dictionary) -> void:
	if overlay_flags.get("enter", false) or GameManager.should_dismiss_enter_overlay():
		await GameManager.dismiss_enter_overlay()
	if overlay_flags.get("transition", false) or GameManager.should_dismiss_transition_overlay():
		await GameManager.dismiss_transition_overlay()


## 重写：使用场景切换模式的日夜系统。
func _setup_day_night_scene_switch() -> void:
	if is_instance_valid(time_hud) and time_hud.has_method("bind_time_system"):
		time_hud.bind_time_system(time_system)
	# night_defense 不绑定 NightTd（不存在），只用于信号
	if is_instance_valid(time_system):
		time_system.evening_warning_triggered.connect(_on_evening_warning)
		time_system.night_setup_started.connect(_on_night_setup_scene_switch)
		time_system.day_started.connect(_on_day_started)
		time_system.phase_changed.connect(_on_time_phase_changed)
	if is_instance_valid(evening_notice):
		evening_notice.hide_notice()


## 夜晚开始 → 冻结状态，导出 RunState，切换到 night_td.tscn。
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

	# 导出当前状态
	var rs = export_run_state()
	# 确保 RunState 中包含了夜间 TD 需要的额外数据
	if is_instance_valid(_backpack) and _backpack.has_method("to_dictionary"):
		rs.backpack_dict = _backpack.to_dictionary().duplicate()

	GameManager.go_to_night_with_loading(rs)
	# GameManager.change_scene_to_file() 会销毁当前场景，无需额外清理


## 手动进入布防（傍晚按 F）。
func _try_enter_defense_mode() -> bool:
	if not is_instance_valid(time_system):
		return false
	if not time_system.can_manual_enter_defense():
		return false
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

## scene_switch 模式下，不应该调用父类的 _setup_day_night（它会绑定 night_td）。
## 在 _ready() 中已用自己的 _setup_day_night_scene_switch 替代。
