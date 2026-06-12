extends Control
class_name DayNightLoading
## 昼夜切换加载页：与 RunLoading 同一背景风格，淡入标题 + 进度条，预加载目标场景。

enum TransitionDirection { DAY_TO_NIGHT, NIGHT_TO_DAY }

const BACKGROUND_PATH := "res://assets/menu/difficulty/background.png"
const BACKGROUND_BRIGHTNESS := Color(1.18, 1.18, 1.14, 1.0)
const COLOR_MASK := Color(0.102, 0.118, 0.149, 120.0 / 255.0)
const INTRO_FADE_SEC := 0.85
const INTRO_SWEEP_SEC := 0.72
const MIN_DISPLAY_SEC := 1.35
const BOOT_HANDOFF_RATIO := 0.98

const DAY_TO_NIGHT_STATUS := [
	"加载场景资源…",
	"正在准备夜间布防…",
]
const NIGHT_TO_DAY_STATUS := [
	"加载场景资源…",
	"正在加载探索区域…",
]

@onready var background_texture: TextureRect = %BackgroundTexture
@onready var color_mask: ColorRect = %ColorMask
@onready var intro_overlay: ColorRect = %IntroOverlay
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var sweep_glare: ColorRect = %SweepGlare
@onready var progress_panel: PanelContainer = %ProgressPanel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var status_label: Label = %StatusLabel

var _direction: int = TransitionDirection.DAY_TO_NIGHT
var _target_scene_path: String = ""
var _preload_started := false
var _shown_at_msec := 0
var _threaded_load_started := false


func _ready() -> void:
	_shown_at_msec = Time.get_ticks_msec()
	_read_transition_params()
	_setup_background()
	call_deferred("_release_transition_cover")
	_setup_labels()
	_setup_progress_ui()
	_prepare_intro_state()
	_begin_threaded_scene_load()
	_play_entrance_animation()
	await get_tree().create_timer(INTRO_FADE_SEC).timeout
	_ensure_header_visible()
	await _preload_and_enter()


func _read_transition_params() -> void:
	var manager := _game_manager()
	if manager != null and manager.has_method("get_day_night_loading_params"):
		var params: Dictionary = manager.get_day_night_loading_params()
		_direction = int(params.get("direction", TransitionDirection.DAY_TO_NIGHT))
		_target_scene_path = str(params.get("target_scene", ""))


func _release_transition_cover() -> void:
	var transition := _run_transition()
	if (
		transition != null
		and transition.has_method("is_covering")
		and transition.has_method("hide_cover")
		and bool(transition.is_covering())
	):
		transition.hide_cover()


func _setup_background() -> void:
	if is_instance_valid(background_texture):
		background_texture.modulate = BACKGROUND_BRIGHTNESS
		background_texture.texture = MenuStyles.load_menu_texture(BACKGROUND_PATH)
	if is_instance_valid(color_mask):
		color_mask.color = COLOR_MASK


func _setup_labels() -> void:
	MenuStyles.style_title(title_label, 38)
	MenuStyles.style_subtitle(subtitle_label)
	match _direction:
		TransitionDirection.DAY_TO_NIGHT:
			title_label.text = "夜幕降临"
			subtitle_label.text = "夜间布防 · 守住车辆与物资"
		TransitionDirection.NIGHT_TO_DAY:
			title_label.text = "黎明将至"
			subtitle_label.text = "重返废墟 · 继续探索"


func _setup_progress_ui() -> void:
	if is_instance_valid(progress_panel):
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.05, 0.08, 0.12, 0.72)
		panel_style.border_color = Color(0.35, 0.48, 0.62, 0.45)
		panel_style.set_border_width_all(1)
		panel_style.set_corner_radius_all(10)
		panel_style.content_margin_left = 18
		panel_style.content_margin_right = 18
		panel_style.content_margin_top = 12
		panel_style.content_margin_bottom = 12
		progress_panel.add_theme_stylebox_override("panel", panel_style)
	if is_instance_valid(progress_bar):
		progress_bar.min_value = 0.0
		progress_bar.max_value = 1.0
		progress_bar.value = 0.0
		progress_bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.35, 0.78, 0.95, 0.95)
		fill.set_corner_radius_all(4)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.10, 0.14, 0.20, 0.85)
		bg.set_corner_radius_all(4)
		progress_bar.add_theme_stylebox_override("fill", fill)
		progress_bar.add_theme_stylebox_override("background", bg)
	if is_instance_valid(status_label):
		status_label.add_theme_font_size_override("font_size", 13)
		status_label.add_theme_color_override("font_color", Color("#b8c8d8"))
		status_label.text = "准备加载…"


func _prepare_intro_state() -> void:
	if is_instance_valid(intro_overlay):
		intro_overlay.color = Color(0.02, 0.04, 0.07, 1.0)
	_ensure_header_visible()
	if is_instance_valid(progress_panel):
		progress_panel.modulate.a = 0.0
	if is_instance_valid(sweep_glare):
		sweep_glare.color = Color(0.72, 0.95, 1.0, 0.0)


func _ensure_header_visible() -> void:
	if is_instance_valid(title_label):
		title_label.modulate = Color.WHITE
	if is_instance_valid(subtitle_label):
		subtitle_label.modulate = Color.WHITE


func _play_entrance_animation() -> void:
	if is_instance_valid(intro_overlay):
		var fade := create_tween()
		fade.tween_property(intro_overlay, "color:a", 0.0, INTRO_FADE_SEC)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_instance_valid(progress_panel):
		var t := create_tween()
		t.tween_property(progress_panel, "modulate:a", 1.0, 0.35)\
			.set_delay(INTRO_FADE_SEC * 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_play_screen_sweep()


func _play_screen_sweep() -> void:
	if not is_instance_valid(sweep_glare):
		return
	var view_w := maxf(get_viewport_rect().size.x, 960.0)
	var band_w := view_w * 0.22
	sweep_glare.size = Vector2(band_w, get_viewport_rect().size.y)
	sweep_glare.position = Vector2(-band_w, 0.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sweep_glare, "position:x", view_w + band_w * 0.2, INTRO_SWEEP_SEC)\
		.set_delay(0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		func(alpha: float) -> void:
			var c := sweep_glare.color
			c.a = alpha
			sweep_glare.color = c,
		0.0,
		0.55,
		INTRO_SWEEP_SEC * 0.42,
	).set_delay(0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_method(
		func(alpha: float) -> void:
			var c := sweep_glare.color
			c.a = alpha
			sweep_glare.color = c,
		0.55,
		0.0,
		INTRO_SWEEP_SEC * 0.35,
	)


func _begin_threaded_scene_load() -> void:
	if _target_scene_path.is_empty() or _threaded_load_started:
		return
	var status := ResourceLoader.load_threaded_request(_target_scene_path)
	if status == OK or status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_threaded_load_started = true


func _preload_and_enter() -> void:
	if _preload_started:
		return
	_preload_started = true
	_ensure_header_visible()
	_set_progress(0.08, "准备加载…")
	await get_tree().process_frame

	if _target_scene_path.is_empty():
		await _finish_loading_and_enter()
		return

	if not _threaded_load_started:
		_begin_threaded_scene_load()

	while true:
		var progress: Array = []
		var load_status := ResourceLoader.load_threaded_get_status(_target_scene_path, progress)
		if load_status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(_target_scene_path)
			if packed is PackedScene:
				_store_preloaded_scene(packed)
			await _finish_loading_and_enter()
			return
		if load_status == ResourceLoader.THREAD_LOAD_FAILED:
			_set_progress(1.0, "加载失败，尝试直接进入…")
			await _wait_min_display()
			call_deferred("_enter_target_scene")
			return
		if not progress.is_empty():
			var load_ratio := float(progress[0])
			_set_progress(0.12 + load_ratio * (BOOT_HANDOFF_RATIO - 0.12), _status_for_load_ratio(load_ratio))
		await get_tree().process_frame


func _status_for_load_ratio(ratio: float) -> String:
	var lines := DAY_TO_NIGHT_STATUS if _direction == TransitionDirection.DAY_TO_NIGHT else NIGHT_TO_DAY_STATUS
	if lines.is_empty():
		return "加载场景资源…"
	var index := clampi(int(ratio * float(lines.size())), 0, lines.size() - 1)
	return lines[index]


func _finish_loading_and_enter() -> void:
	var handoff_label := "正在初始化…"
	if _direction == TransitionDirection.DAY_TO_NIGHT:
		handoff_label = "正在准备夜间布防…"
	elif _direction == TransitionDirection.NIGHT_TO_DAY:
		handoff_label = "正在加载探索区域…"
	_set_progress(BOOT_HANDOFF_RATIO, handoff_label)
	await _wait_min_display()
	call_deferred("_enter_target_scene")


func _store_preloaded_scene(packed: PackedScene) -> void:
	var manager := _game_manager()
	if manager != null and manager.has_method("set_preloaded_scene_for_transition"):
		manager.set_preloaded_scene_for_transition(packed)


func _enter_target_scene() -> void:
	var manager := _game_manager()
	match _direction:
		TransitionDirection.DAY_TO_NIGHT:
			if manager != null and manager.has_method("enter_night_td_after_loading"):
				manager.enter_night_td_after_loading()
				return
		TransitionDirection.NIGHT_TO_DAY:
			if manager != null and manager.has_method("enter_day_after_loading"):
				manager.enter_day_after_loading()
				return
	if not _target_scene_path.is_empty():
		get_tree().change_scene_to_file(_target_scene_path)


func _wait_min_display() -> void:
	var elapsed := (Time.get_ticks_msec() - _shown_at_msec) / 1000.0
	var remaining := MIN_DISPLAY_SEC - elapsed
	if remaining > 0.0:
		await get_tree().create_timer(remaining).timeout


func _set_progress(ratio: float, label: String) -> void:
	_ensure_header_visible()
	if is_instance_valid(progress_bar):
		progress_bar.value = clampf(ratio, 0.0, 1.0)
	if is_instance_valid(status_label) and not label.is_empty():
		status_label.text = label


func _run_transition() -> Node:
	if get_tree() == null or get_tree().root == null:
		return null
	return get_tree().root.get_node_or_null("RunTransition")


func _game_manager() -> Node:
	if get_tree() == null or get_tree().root == null:
		return null
	return get_tree().root.get_node_or_null("GameManager")
