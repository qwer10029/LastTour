extends Control
class_name RunLoading
## 分队选择后的入场加载页：难度同款背景 + 扫光动画 + 地图初始化进度条。

const RunBootstrapScript := preload("res://scripts/menu/run_bootstrap.gd")
const BACKGROUND_PATH := "res://assets/menu/difficulty/background.png"
const BACKGROUND_BRIGHTNESS := Color(1.18, 1.18, 1.14, 1.0)
const COLOR_MASK := Color(0.102, 0.118, 0.149, 120.0 / 255.0)
const INTRO_FADE_SEC := 0.85
const INTRO_SWEEP_SEC := 0.72
@onready var background_texture: TextureRect = %BackgroundTexture
@onready var color_mask: ColorRect = %ColorMask
@onready var intro_overlay: ColorRect = %IntroOverlay
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var sweep_glare: ColorRect = %SweepGlare
@onready var progress_panel: PanelContainer = %ProgressPanel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var status_label: Label = %StatusLabel

var _bootstrap_started := false


func _ready() -> void:
	_setup_background()
	call_deferred("_release_transition_cover")
	_play_music_cue("menu_select", 0.6)
	_setup_labels()
	_setup_progress_ui()
	_prepare_intro_state()
	_play_entrance_animation()
	await get_tree().create_timer(0.18).timeout
	await _run_bootstrap_pipeline()
	_enter_game_scene()


func _release_transition_cover() -> void:
	if RunTransition.is_covering():
		RunTransition.hide_cover()


func _play_music_cue(cue_id: String, fade_sec: float = -1.0) -> void:
	var music := get_tree().root.get_node_or_null("MusicManager") if get_tree() != null else null
	if music != null and music.has_method("play_cue"):
		music.play_cue(cue_id, fade_sec)


func _setup_background() -> void:
	if is_instance_valid(background_texture):
		background_texture.modulate = BACKGROUND_BRIGHTNESS
		background_texture.texture = MenuStyles.load_menu_texture(BACKGROUND_PATH)
	if is_instance_valid(color_mask):
		color_mask.color = COLOR_MASK


func _setup_labels() -> void:
	MenuStyles.style_title(title_label, 38)
	MenuStyles.style_subtitle(subtitle_label)
	title_label.text = "正在进入废墟"
	subtitle_label.text = "%s · %s" % [
		GameManager.get_difficulty_name(),
		GameManager.get_squad_name(),
	]


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
		status_label.text = "准备勘探数据…"


func _prepare_intro_state() -> void:
	if is_instance_valid(intro_overlay):
		intro_overlay.color = Color(0.02, 0.04, 0.07, 1.0)
	if is_instance_valid(title_label):
		title_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if is_instance_valid(subtitle_label):
		subtitle_label.modulate.a = 0.0
	if is_instance_valid(progress_panel):
		progress_panel.modulate.a = 0.0
	if is_instance_valid(sweep_glare):
		sweep_glare.color = Color(0.72, 0.95, 1.0, 0.0)


func _play_entrance_animation() -> void:
	if is_instance_valid(intro_overlay):
		var fade := create_tween()
		fade.tween_property(intro_overlay, "color:a", 0.0, INTRO_FADE_SEC)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_instance_valid(title_label):
		var title_tween := create_tween()
		title_tween.tween_property(title_label, "modulate:a", 1.0, INTRO_FADE_SEC * 0.7)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_instance_valid(subtitle_label):
		var sub_tween := create_tween()
		sub_tween.tween_property(subtitle_label, "modulate:a", 1.0, INTRO_FADE_SEC * 0.75)\
			.set_delay(0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
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


func _run_bootstrap_pipeline() -> void:
	if _bootstrap_started:
		return
	_bootstrap_started = true
	if is_instance_valid(progress_panel):
		var panel_tween := create_tween()
		panel_tween.tween_property(progress_panel, "modulate:a", 1.0, 0.35)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var progress_cb := func(ratio: float, label: String) -> void:
		_set_progress(ratio, label)

	await get_tree().process_frame
	RunBootstrapScript.preload_render_assets(progress_cb)
	await get_tree().process_frame

	var map: WorldMapData = RunBootstrapScript.build_new_run_map(progress_cb)
	await get_tree().process_frame

	GameManager.store_run_bootstrap(RunBootstrapScript.pack_bootstrap(map))
	_set_progress(0.94, "加载游戏场景…")
	await _preload_game_scene()
	_set_progress(1.0, "准备就绪")


func _preload_game_scene() -> void:
	var scene_path := GameManager.SCENE_GAME
	var status := ResourceLoader.load_threaded_request(scene_path)
	if status != OK:
		return
	while true:
		var progress: Array = []
		var load_status := ResourceLoader.load_threaded_get_status(scene_path, progress)
		if load_status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(scene_path)
			if packed is PackedScene:
				GameManager.set_preloaded_game_scene(packed)
			_set_progress(0.98, "场景资源就绪")
			return
		if load_status == ResourceLoader.THREAD_LOAD_FAILED:
			return
		if not progress.is_empty():
			var local := 0.94 + float(progress[0]) * 0.05
			_set_progress(local, "加载游戏场景…")
		await get_tree().process_frame


func _set_progress(ratio: float, label: String) -> void:
	if is_instance_valid(progress_bar):
		progress_bar.value = clampf(ratio, 0.0, 1.0)
	if is_instance_valid(status_label) and not label.is_empty():
		status_label.text = label


func _enter_game_scene() -> void:
	GameManager.enter_game_after_bootstrap()
