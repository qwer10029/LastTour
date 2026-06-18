extends Node

const RunStateClass = preload("res://scripts/run_state.gd")
const DifficultySelectScript := preload("res://scripts/menu/difficulty_select.gd")
const RunLoadingScene := preload("res://scenes/menu/run_loading.tscn")
const DayNightLoadingScene := preload("res://scenes/menu/day_night_loading.tscn")

enum Difficulty { EASY, NORMAL, HARD }
const RUN_CONFIG_PATH := "res://data/run_config.json"

const SCENE_MAIN_MENU := "res://scenes/menu/main_menu.tscn"
const SCENE_OPENING_PROLOGUE := "res://scenes/menu/opening_prologue.tscn"
const SCENE_DIFFICULTY := "res://scenes/menu/difficulty_select.tscn"
const SCENE_SQUAD := "res://scenes/menu/squad_select.tscn"
const SCENE_RUN_LOADING := "res://scenes/menu/run_loading.tscn"
const SCENE_GAME := "res://scenes/day_exploration.tscn"
const SCENE_DAY := "res://scenes/day_exploration.tscn"
const SCENE_TUTORIAL_DAY := "res://scenes/tutorial/tutorial_day.tscn"
const SCENE_TUTORIAL_COMPLETE := "res://scenes/tutorial/tutorial_complete.tscn"
const SCENE_NIGHT_TD := "res://scenes/night_td/night_td_standalone.tscn"

var is_tutorial_run := false

var _difficulty_names := {
	Difficulty.EASY: "简单",
	Difficulty.NORMAL: "普通",
	Difficulty.HARD: "困难",
}

var _squad_defs := {
	"scavenger": {
		"name": "拾荒者",
		"description": "建筑物室内可拾取资源数量为其他分队的 2 倍。",
		"repair_discount": 0,
		"fuel_multiplier": 1.0,
		"building_resource_multiplier": 2.0,
	},
	"logistics": {
		"name": "后勤型",
		"description": "修复电梯时材料消耗 ×0.75（向下取整）。",
		"repair_discount": 0,
		"fuel_multiplier": 1.0,
	},
}

var difficulty: int = Difficulty.NORMAL
var squad_id: String = "scavenger"
var _run_config: Dictionary = {}

var _pending_new_game := false
var _pending_load_save := false
var _run_bootstrap: Dictionary = {}
var _preloaded_game_scene: PackedScene = null
var _await_enter_overlay_dismiss := false
var _preloaded_transition_scene: PackedScene = null
var _await_transition_overlay_dismiss := false
var _transition_direction := 0
var _transition_target_scene := ""
const OVERLAY_SAFETY_DISMISS_SEC := 12.0
const BOOT_HANDOFF_RATIO := 0.98

# -- 场景切换模式（方案四）：Day/Night 独立场景之间的状态传递 --
var run_state = null   # RunState — 跨场景共享状态（类型在 preload 中解析）
var _game_paused := false           # 暂停状态（NightTdRoot 需要查询）

## 启动昼夜切换加载页，进入夜间塔防场景（有加载画面）。
func go_to_night_with_loading(rs) -> void:
	if rs != null:
		if rs.night_session_options.is_empty():
			rs.night_session_options = {}
			rs.night_context = "normal"
		else:
			rs.night_context = str(rs.night_session_options.get("kind", "normal"))
		rs.pending_open_terminal = false
	run_state = rs
	_preloaded_transition_scene = null
	_await_transition_overlay_dismiss = true
	_transition_direction = 0   # DAY_TO_NIGHT
	_transition_target_scene = SCENE_NIGHT_TD
	_play_music_cue("night_setup", 1.0)
	var transition := _run_transition()
	if transition != null:
		if transition.has_method("preload_background"):
			transition.preload_background()
		if transition.has_method("show_cover"):
			transition.show_cover(BOOT_HANDOFF_RATIO, "正在准备夜间布防…", "夜幕降临")
	get_tree().change_scene_to_packed(DayNightLoadingScene)


## 请求切换到夜间塔防场景（无加载画面，直接切换，保留兼容）。
func request_night_defense(rs, session_options: Dictionary = {}) -> void:
	if rs != null:
		rs.night_session_options = session_options.duplicate(true)
		rs.night_context = str(session_options.get("kind", "normal"))
		rs.pending_open_terminal = false
	run_state = rs
	_play_music_cue("night_setup", 1.0)
	get_tree().change_scene_to_file(SCENE_NIGHT_TD)


## 夜间结束后切回白天场景。
func apply_night_result_and_continue(result: Dictionary) -> void:
	if run_state == null:
		push_error("GameManager: run_state is null when applying night result.")
		start_day_exploration(null)
		return
	var context := str(result.get("kind", run_state.night_context))
	var no_day_advance := bool(result.get("no_day_advance", false))
	run_state.apply_night_result(result)
	if not run_state.run_ended:
		if context == "tutorial" or run_state.run_context == "tutorial":
			return_to_tutorial_hub_after_night()
			return
		if context == "thunder_leiting_boss" and str(result.get("outcome", "")) == "success":
			run_state.thunder_leiting_defeated = true
			run_state.final_defense_cleared = true
			run_state.thunder_terminal_sequence_active = true
		elif not no_day_advance:
			run_state.advance_after_normal_night()
	start_day_via_loading(run_state)


## 返回当前 RunState。夜战结束前不能清空，否则结果无法回写。
func consume_run_state():
	return run_state


## 启动白天探索场景（方案四入口，无加载画面，保留兼容）。
func start_day_exploration(rs = null) -> void:
	run_state = rs
	_pending_new_game = false
	_pending_load_save = false
	if rs != null and bool(rs.pending_open_terminal):
		_play_music_cue("terminal", 0.9)
	else:
		_play_music_cue("day_exploration", 1.2)
	var scene_path := _day_scene_path()
	get_tree().change_scene_to_file(scene_path)


## 启动白天探索场景（通过加载页）。
func start_day_via_loading(rs = null) -> void:
	run_state = rs
	_pending_new_game = false
	_pending_load_save = false
	_preloaded_transition_scene = null
	_await_transition_overlay_dismiss = true
	_transition_direction = 1   # NIGHT_TO_DAY
	_transition_target_scene = _day_scene_path()
	if rs != null and bool(rs.pending_open_terminal):
		_play_music_cue("terminal", 0.9)
	else:
		_play_music_cue("day_exploration", 1.2)
	var transition := _run_transition()
	if transition != null:
		if transition.has_method("preload_background"):
			transition.preload_background()
		if transition.has_method("show_cover"):
			transition.show_cover(BOOT_HANDOFF_RATIO, "正在加载探索区域…", "黎明将至")
	get_tree().change_scene_to_packed(DayNightLoadingScene)


## 加载页预加载完成后，进入夜间塔防场景。
func enter_night_td_after_loading() -> void:
	_await_transition_overlay_dismiss = true
	var transition := _run_transition()
	if transition != null and transition.has_method("show_cover"):
		transition.show_cover(BOOT_HANDOFF_RATIO, "正在准备夜间布防…", "夜幕降临")
	if _preloaded_transition_scene != null:
		get_tree().change_scene_to_packed(_preloaded_transition_scene)
		_preloaded_transition_scene = null
	else:
		get_tree().change_scene_to_file(SCENE_NIGHT_TD)
	_schedule_overlay_safety_dismiss()


## 加载页预加载完成后，进入白天探索场景。
func enter_day_after_loading() -> void:
	_await_transition_overlay_dismiss = true
	var transition := _run_transition()
	if transition != null and transition.has_method("show_cover"):
		transition.show_cover(BOOT_HANDOFF_RATIO, "正在加载探索区域…", "黎明将至")
	if _preloaded_transition_scene != null:
		get_tree().change_scene_to_packed(_preloaded_transition_scene)
		_preloaded_transition_scene = null
	else:
		get_tree().change_scene_to_file(_day_scene_path())
	_schedule_overlay_safety_dismiss()


## 供 DayNightLoading 存储预加载完成的 PackedScene。
func set_preloaded_scene_for_transition(scene: PackedScene) -> void:
	_preloaded_transition_scene = scene


## 供 DayNightLoading 读取过渡方向与目标场景路径。
func get_day_night_loading_params() -> Dictionary:
	return {
		"direction": _transition_direction,
		"target_scene": _transition_target_scene,
	}


## 目标场景 _ready() 中检查是否需要关闭过渡遮罩。
func should_dismiss_transition_overlay() -> bool:
	return _await_transition_overlay_dismiss


## 目标场景 _ready() 中调用，淡出过渡遮罩。
func dismiss_transition_overlay() -> void:
	if not _await_transition_overlay_dismiss:
		return
	_await_transition_overlay_dismiss = false
	await _finish_overlay_progress("就绪")
	await _fade_out_or_hide_overlay()


## 检查游戏是否暂停（供 NightTdController 查询）。
func is_game_paused() -> bool:
	return _game_paused


func _ready() -> void:
	_load_run_config()


func _music_manager() -> Node:
	return get_tree().root.get_node_or_null("MusicManager") if get_tree() != null else null


func _play_music_cue(cue_id: String, fade_sec: float = -1.0, restart: bool = false) -> void:
	var music := _music_manager()
	if music != null and music.has_method("play_cue"):
		music.play_cue(cue_id, fade_sec, restart)


func _load_run_config() -> void:
	var file := FileAccess.open(RUN_CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_warning("无法打开运行配置文件：%s，将使用默认配置。" % RUN_CONFIG_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("运行配置 JSON 无效：%s，将使用默认配置。" % RUN_CONFIG_PATH)
		return
	var cfg: Dictionary = parsed
	_run_config = cfg
	var names: Dictionary = cfg.get("difficulty_names", {})
	if not names.is_empty():
		_difficulty_names = {
			Difficulty.EASY: str(names.get("easy", _difficulty_names[Difficulty.EASY])),
			Difficulty.NORMAL: str(names.get("normal", _difficulty_names[Difficulty.NORMAL])),
			Difficulty.HARD: str(names.get("hard", _difficulty_names[Difficulty.HARD])),
		}
	var squads: Dictionary = cfg.get("squads", {})
	if not squads.is_empty():
		_squad_defs = squads.duplicate(true)


func begin_tutorial_flow() -> void:
	is_tutorial_run = true
	_pending_new_game = false
	_pending_load_save = false
	difficulty = Difficulty.EASY
	squad_id = "scavenger"
	_run_bootstrap = {}
	run_state = null
	_preloaded_game_scene = null
	_await_enter_overlay_dismiss = true
	_play_music_cue("menu_select", 0.6)
	var transition := _run_transition()
	if transition != null:
		if transition.has_method("preload_background"):
			transition.preload_background()
		if transition.has_method("show_cover"):
			transition.show_cover()
	get_tree().change_scene_to_packed(RunLoadingScene)


func get_exploration_scene_path() -> String:
	return _day_scene_path()


func finish_tutorial_run() -> void:
	is_tutorial_run = false
	get_tree().change_scene_to_file(SCENE_TUTORIAL_COMPLETE)


func finish_tutorial_and_return_menu() -> void:
	is_tutorial_run = false
	go_to_main_menu()


func return_to_tutorial_hub_after_night() -> void:
	if run_state == null:
		push_error("GameManager: run_state is null when returning to tutorial hub.")
		go_to_main_menu()
		return
	is_tutorial_run = true
	run_state.run_context = "tutorial"
	run_state.tutorial_phase = "elevator"
	run_state.tutorial_step = "go_elevator"
	# 夜战在独立场景完成，回到白天前必须把阶段从 NIGHT_SETUP 重置为 DAY，
	# 否则 scene_switch 模式会因 night_td 为空而只绘制黑夜背景（黑屏）。
	var day_idx := maxi(run_state.day_index, 1)
	run_state.time_dict = {
		"phase": 0,
		"day_index": day_idx,
		"elapsed_in_phase": 0.0,
		"evening_warning_sent": false,
	}
	run_state.travel_dict["mode"] = 0
	run_state.travel_dict["current_district_index"] = -1
	run_state.travel_dict["segment_target_index"] = -1
	start_day_via_loading(run_state)


func _day_scene_path() -> String:
	return SCENE_TUTORIAL_DAY if is_tutorial_run else SCENE_DAY


func go_to_main_menu() -> void:
	is_tutorial_run = false
	_pending_new_game = false
	_pending_load_save = false
	_run_bootstrap = {}
	_preloaded_game_scene = null
	_await_enter_overlay_dismiss = false
	_await_transition_overlay_dismiss = false
	_preloaded_transition_scene = null
	var transition := _run_transition()
	if transition != null and transition.has_method("hide_cover"):
		transition.hide_cover()
	run_state = null
	_play_music_cue("day_exploration", 1.0)
	get_tree().change_scene_to_file(SCENE_MAIN_MENU)


func continue_from_save() -> void:
	var save_manager := _save_manager()
	if save_manager == null or not save_manager.has_save():
		return
	_pending_new_game = false
	_pending_load_save = true
	run_state = null
	_play_music_cue("day_exploration", 1.0)
	get_tree().change_scene_to_file(SCENE_GAME)


func consume_load_save_request() -> bool:
	var should_load := _pending_load_save
	_pending_load_save = false
	return should_load


func begin_new_game_flow() -> void:
	_pending_new_game = true
	difficulty = Difficulty.NORMAL
	squad_id = "scavenger"
	_run_bootstrap = {}
	run_state = null
	_play_music_cue("day_exploration", 1.0)
	get_tree().change_scene_to_file(SCENE_OPENING_PROLOGUE)


func go_to_difficulty_select() -> void:
	DifficultySelectScript.preload_assets()
	_play_music_cue("day_exploration", 0.8)
	get_tree().change_scene_to_file(SCENE_DIFFICULTY)


func go_to_squad_select() -> void:
	_play_music_cue("day_exploration", 0.8)
	get_tree().change_scene_to_file(SCENE_SQUAD)


func start_run() -> void:
	_pending_new_game = false
	run_state = null
	_run_bootstrap = {}
	_preloaded_game_scene = null
	_await_enter_overlay_dismiss = true
	var transition := _run_transition()
	if transition != null:
		if transition.has_method("preload_background"):
			transition.preload_background()
		if transition.has_method("show_cover"):
			transition.show_cover()
	get_tree().change_scene_to_packed(RunLoadingScene)


func store_run_bootstrap(data: Dictionary) -> void:
	_run_bootstrap = data


func has_run_bootstrap() -> bool:
	return _run_bootstrap.has("map")


func run_bootstrap_textures_preloaded() -> bool:
	return has_run_bootstrap() and bool(_run_bootstrap.get("textures_preloaded", false))


func consume_run_bootstrap() -> Dictionary:
	var data := _run_bootstrap
	_run_bootstrap = {}
	return data


func set_preloaded_game_scene(scene: PackedScene) -> void:
	_preloaded_game_scene = scene


func should_dismiss_enter_overlay() -> bool:
	return _await_enter_overlay_dismiss


func dismiss_enter_overlay() -> void:
	if not _await_enter_overlay_dismiss:
		return
	_await_enter_overlay_dismiss = false
	await _finish_overlay_progress("准备就绪")
	await _fade_out_or_hide_overlay()


func report_overlay_boot_progress(ratio: float, label: String) -> void:
	var transition := _run_transition()
	if transition != null and transition.has_method("set_cover_progress"):
		transition.set_cover_progress(ratio, label)


func enter_game_after_bootstrap() -> void:
	_await_enter_overlay_dismiss = true
	_play_music_cue("day_exploration", 1.0)
	var transition := _run_transition()
	if transition != null and transition.has_method("show_cover"):
		transition.show_cover(BOOT_HANDOFF_RATIO, "正在初始化世界…")
	if _preloaded_game_scene != null:
		get_tree().change_scene_to_packed(_preloaded_game_scene)
		_preloaded_game_scene = null
	else:
		get_tree().change_scene_to_file(_day_scene_path())
	_schedule_overlay_safety_dismiss()


func _fade_out_or_hide_overlay() -> void:
	var transition := _run_transition()
	if transition == null:
		return
	if (
		transition.has_method("is_covering")
		and transition.has_method("fade_out_cover")
		and bool(transition.is_covering())
	):
		await transition.fade_out_cover()
		return
	if transition.has_method("hide_cover"):
		transition.hide_cover()


func _finish_overlay_progress(done_label: String) -> void:
	var transition := _run_transition()
	if transition != null and transition.has_method("finish_cover_progress"):
		await transition.finish_cover_progress(done_label)


func _schedule_overlay_safety_dismiss() -> void:
	call_deferred("_overlay_safety_dismiss_job")


func _overlay_safety_dismiss_job() -> void:
	var waited := 0.0
	while waited < OVERLAY_SAFETY_DISMISS_SEC:
		if not _await_enter_overlay_dismiss and not _await_transition_overlay_dismiss:
			return
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	if _await_enter_overlay_dismiss:
		push_warning("GameManager: 入场遮罩超时，强制淡出。")
		await dismiss_enter_overlay()
	if _await_transition_overlay_dismiss:
		push_warning("GameManager: 过渡遮罩超时，强制淡出。")
		await dismiss_transition_overlay()


func _run_transition() -> Node:
	if get_tree() == null or get_tree().root == null:
		return null
	return get_tree().root.get_node_or_null("RunTransition")


func get_difficulty_name(value: int = -1) -> String:
	if value < 0:
		value = difficulty
	return _difficulty_names.get(value, "未知")


func get_squad_name(id: String = "") -> String:
	var key := id if id != "" else squad_id
	var def: Dictionary = _squad_defs.get(key, {})
	return str(def.get("name", "未知分队"))


func get_squad_description(id: String = "") -> String:
	var key := id if id != "" else squad_id
	var def: Dictionary = _squad_defs.get(key, {})
	return str(def.get("description", ""))


func get_building_resource_multiplier() -> float:
	var def: Dictionary = _squad_defs.get(squad_id, {})
	return maxf(float(def.get("building_resource_multiplier", 1.0)), 1.0)


func apply_run_config_to_game(game: Node) -> void:
	if not game.has_method("apply_run_config"):
		return
	game.apply_run_config(self)


func _save_manager() -> Node:
	return get_tree().root.get_node_or_null("SaveManager") if get_tree() != null else null


func get_fuel_max(base: float) -> float:
	match difficulty:
		Difficulty.EASY:
			return base * 1.25
		Difficulty.HARD:
			return base * 0.75
		_:
			return base


func get_elevator_repair_cost(base: int) -> int:
	var cost := base
	match difficulty:
		Difficulty.EASY:
			cost = maxi(cost - 1, 1)
		Difficulty.HARD:
			cost += 1
	return cost


func scale_elevator_repair_material_cost(base: int) -> int:
	var amount := float(base)
	match difficulty:
		Difficulty.NORMAL:
			amount = float(ceili(base * 1.5))
		Difficulty.HARD:
			amount = float(ceili(base * 2.0))
		_:
			pass
	if squad_id == "logistics":
		amount = float(floori(amount * 0.75))
	return maxi(int(amount), 1)


func get_repair_parts_cost() -> int:
	return scale_elevator_repair_material_cost(ItemDefs.REPAIR_PARTS_EACH)


func get_repair_scrap_cost() -> int:
	return scale_elevator_repair_material_cost(ItemDefs.REPAIR_SCRAP_EACH)


func get_repair_wood_cost() -> int:
	return scale_elevator_repair_material_cost(ItemDefs.REPAIR_WOOD_EACH)


func get_repair_scrap_alt_cost() -> int:
	return scale_elevator_repair_material_cost(ItemDefs.REPAIR_SCRAP_ALT_EACH)


func get_tutorial_starting_items() -> Dictionary:
	return {
		"supplies": 2,
		"parts": get_repair_parts_cost(),
		"scrap": get_repair_scrap_cost(),
	}


func get_starting_items() -> Dictionary:
	var items := {
		"supplies": 4,
		"wood": 1,
		"parts": 1,
		"scrap": 40,
	}
	var start_cfg: Dictionary = _run_config.get("starting_items", {})
	var default_items: Dictionary = start_cfg.get("default", {})
	if not default_items.is_empty():
		items = default_items.duplicate(true)
	var squad_overrides: Dictionary = start_cfg.get("squad_overrides", {})
	if squad_overrides.has(squad_id):
		var override_data: Variant = squad_overrides[squad_id]
		if typeof(override_data) == TYPE_DICTIONARY:
			var override_items: Dictionary = override_data
			for key in override_items.keys():
				items[str(key)] = int(override_items[key])
	var diff_adjustments: Dictionary = start_cfg.get("difficulty_adjustments", {})
	match difficulty:
		Difficulty.EASY:
			var easy_add: Dictionary = diff_adjustments.get("easy_add", {})
			for key in easy_add.keys():
				items[str(key)] = int(items.get(key, 0)) + int(easy_add[key])
		Difficulty.HARD:
			var hard_reduce: Dictionary = diff_adjustments.get("hard_reduce", {})
			for key in hard_reduce.keys():
				items[str(key)] = maxi(int(items.get(key, 0)) - int(hard_reduce[key]), 0)
	return items
