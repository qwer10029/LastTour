extends CanvasLayer
## 跨场景持久入场遮罩：在场景切换与主场景初始化期间盖住视口，避免露出灰色空帧。
## 遮罩上可显示进度条，承接加载页未完成的最后一段（boot 阶段）。

const BACKGROUND_PATH := "res://assets/menu/difficulty/background.png"
const BACKGROUND_BRIGHTNESS := Color(1.18, 1.18, 1.14, 1.0)
const COLOR_MASK := Color(0.102, 0.118, 0.149, 120.0 / 255.0)
const FALLBACK_FILL := Color(0.043, 0.063, 0.094, 1.0)

var _root: Control
var _fallback: ColorRect
var _background: TextureRect
var _mask: ColorRect
var _progress_panel: PanelContainer
var _progress_bar: ProgressBar
var _status_label: Label
var _header_layer: VBoxContainer
var _header_title: Label
var _covering := false
var _cached_texture: Texture2D


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_nodes()
	hide_cover()


func preload_background() -> void:
	_ensure_texture()


func show_cover(initial_progress: float = -1.0, status: String = "", header_title: String = "") -> void:
	_ensure_texture()
	_covering = true
	visible = true
	if is_instance_valid(_root):
		_root.visible = true
		_root.modulate = Color.WHITE
	_set_header_title(header_title)
	if initial_progress >= 0.0:
		_show_progress_ui()
		set_cover_progress(initial_progress, status)
	else:
		_hide_progress_ui()


func is_covering() -> bool:
	return _covering and visible


func set_cover_progress(ratio: float, status: String = "") -> void:
	if not is_instance_valid(_progress_bar):
		return
	_show_progress_ui()
	_progress_bar.value = clampf(ratio, 0.0, 1.0)
	if is_instance_valid(_status_label) and not status.is_empty():
		_status_label.text = status


func finish_cover_progress(status: String = "准备就绪") -> void:
	if not is_instance_valid(_progress_bar):
		await get_tree().create_timer(0.12).timeout
		return
	_show_progress_ui()
	if is_instance_valid(_status_label):
		_status_label.text = status
	var start_value := _progress_bar.value
	if start_value >= 1.0:
		await get_tree().create_timer(0.12).timeout
		return
	var tween := create_tween()
	tween.tween_method(
		func(value: float) -> void:
			if is_instance_valid(_progress_bar):
				_progress_bar.value = value,
		start_value,
		1.0,
		0.35,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	await get_tree().create_timer(0.12).timeout


func fade_out_cover(duration: float = 0.45) -> void:
	if not _covering:
		return
	if not is_instance_valid(_root):
		hide_cover()
		return
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	hide_cover()


func hide_cover() -> void:
	_covering = false
	visible = false
	_hide_progress_ui()
	_hide_header_ui()
	if is_instance_valid(_root):
		_root.modulate = Color.WHITE


func _build_nodes() -> void:
	_root = Control.new()
	_root.name = "CoverRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_fallback = ColorRect.new()
	_fallback.name = "FallbackFill"
	_fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fallback.color = FALLBACK_FILL
	_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fallback)

	_background = TextureRect.new()
	_background.name = "BackgroundTexture"
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.modulate = BACKGROUND_BRIGHTNESS
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_background)

	_mask = ColorRect.new()
	_mask.name = "ColorMask"
	_mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mask.color = COLOR_MASK
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_mask)

	_build_header_ui()
	_build_progress_ui()


func _build_header_ui() -> void:
	_header_layer = VBoxContainer.new()
	_header_layer.name = "HeaderLayer"
	_header_layer.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_header_layer.offset_left = -320.0
	_header_layer.offset_top = 120.0
	_header_layer.offset_right = 320.0
	_header_layer.offset_bottom = 200.0
	_header_layer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_header_layer.alignment = BoxContainer.ALIGNMENT_CENTER
	_header_layer.add_theme_constant_override("separation", 10)
	_header_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_layer.visible = false
	_root.add_child(_header_layer)
	_header_title = Label.new()
	_header_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MenuStyles.style_title(_header_title, 38)
	_header_layer.add_child(_header_title)


func _set_header_title(text: String) -> void:
	if not is_instance_valid(_header_layer) or not is_instance_valid(_header_title):
		return
	if text.strip_edges().is_empty():
		_hide_header_ui()
		return
	_header_title.text = text
	_header_title.modulate = Color.WHITE
	_header_layer.visible = true


func _hide_header_ui() -> void:
	if is_instance_valid(_header_layer):
		_header_layer.visible = false


func _build_progress_ui() -> void:
	var bottom := MarginContainer.new()
	bottom.name = "ProgressBottom"
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -108.0
	bottom.add_theme_constant_override("margin_left", 72)
	bottom.add_theme_constant_override("margin_right", 72)
	bottom.add_theme_constant_override("margin_bottom", 36)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom)

	_progress_panel = PanelContainer.new()
	_progress_panel.name = "ProgressPanel"
	_progress_panel.visible = false
	bottom.add_child(_progress_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.08, 0.12, 0.72)
	panel_style.border_color = Color(0.35, 0.48, 0.62, 0.45)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 18
	panel_style.content_margin_right = 18
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	_progress_panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_progress_panel.add_child(vbox)

	_status_label = Label.new()
	_status_label.text = "正在初始化…"
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color("#b8c8d8"))
	vbox.add_child(_status_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 14)
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.78, 0.95, 0.95)
	fill.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.14, 0.20, 0.85)
	bg.set_corner_radius_all(4)
	_progress_bar.add_theme_stylebox_override("fill", fill)
	_progress_bar.add_theme_stylebox_override("background", bg)
	vbox.add_child(_progress_bar)


func _show_progress_ui() -> void:
	if is_instance_valid(_progress_panel):
		_progress_panel.visible = true


func _hide_progress_ui() -> void:
	if is_instance_valid(_progress_panel):
		_progress_panel.visible = false


func _ensure_texture() -> void:
	if _cached_texture != null:
		_background.texture = _cached_texture
		return
	_cached_texture = MenuStyles.load_menu_texture(BACKGROUND_PATH)
	if _cached_texture == null:
		_cached_texture = ArtAssetLoader.load_texture_from_disk(BACKGROUND_PATH)
	if _cached_texture != null:
		_background.texture = _cached_texture
