extends Control

const NARRATION_WIDTH_RATIO := 0.55
const NARRATION_TOP_RATIO := 0.62
const NARRATION_BOTTOM_RATIO := 0.88
const BOTTOM_FADE_HEIGHT_RATIO := 0.38
const BOTTOM_FADE_ALPHA := 0.76

@onready var _texture_rect: TextureRect = %BackgroundImage
@onready var _bottom_fade: ColorRect = %BottomFade
@onready var _narration_anchor: Control = %NarrationAnchor
@onready var _narration_label: Label = %NarrationLabel
@onready var _page_label: Label = %PageLabel
@onready var _next_button: Button = %NextButton
@onready var _skip_button: Button = %SkipButton

var _slide_index := 0


func _ready() -> void:
	_play_music_cue("day_exploration", 1.0)
	_setup_bottom_fade_shader()
	_apply_narration_style(_narration_label)
	_apply_page_style(_page_label)
	_style_next_button(_next_button)
	_style_skip_button(_skip_button)
	_next_button.pressed.connect(_on_next_pressed)
	_skip_button.pressed.connect(_on_skip_pressed)
	resized.connect(_on_viewport_layout_changed)
	call_deferred("_on_viewport_layout_changed")
	_show_slide(0)


func _play_music_cue(cue_id: String, fade_sec: float = -1.0) -> void:
	var music := get_tree().root.get_node_or_null("MusicManager") if get_tree() != null else null
	if music != null and music.has_method("play_cue"):
		music.play_cue(cue_id, fade_sec)


func _on_viewport_layout_changed() -> void:
	_layout_bottom_fade()
	_layout_narration_area()


func _setup_bottom_fade_shader() -> void:
	if not is_instance_valid(_bottom_fade):
		return
	var shader := load("res://shaders/bottom_fade.gdshader") as Shader
	if shader == null:
		return
	var fade_material := ShaderMaterial.new()
	fade_material.shader = shader
	fade_material.set_shader_parameter("max_alpha", BOTTOM_FADE_ALPHA)
	_bottom_fade.material = fade_material


func _layout_bottom_fade() -> void:
	if not is_instance_valid(_bottom_fade):
		return
	var view := get_viewport_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var fade_h := floorf(view.y * BOTTOM_FADE_HEIGHT_RATIO)
	_bottom_fade.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_bottom_fade.position = Vector2(0.0, view.y - fade_h)
	_bottom_fade.size = Vector2(view.x, fade_h)


func _layout_narration_area() -> void:
	if not is_instance_valid(_narration_anchor):
		return
	var view := get_viewport_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var width := view.x * NARRATION_WIDTH_RATIO
	var left := (view.x - width) * 0.5
	var top := view.y * NARRATION_TOP_RATIO
	var height := view.y * (NARRATION_BOTTOM_RATIO - NARRATION_TOP_RATIO)
	_narration_anchor.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_narration_anchor.position = Vector2(left, top)
	_narration_anchor.size = Vector2(width, height)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()


func _font_with_glyph_spacing(glyph_spacing: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.spacing_glyph = glyph_spacing
	return font


func _apply_narration_style(label: Label) -> void:
	var settings := LabelSettings.new()
	settings.font = _font_with_glyph_spacing(2)
	settings.font_size = 19
	settings.font_color = Color("#e8eef4")
	settings.outline_size = 2
	settings.outline_color = Color(0.02, 0.04, 0.08, 0.85)
	settings.shadow_size = 2
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	settings.shadow_offset = Vector2(1.0, 2.0)
	settings.line_spacing = 10.0
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.text_direction = Control.TEXT_DIRECTION_AUTO


func _apply_page_style(label: Label) -> void:
	var settings := LabelSettings.new()
	settings.font = _font_with_glyph_spacing(1)
	settings.font_size = 13
	settings.font_color = Color("#5e8aac")
	label.label_settings = settings


func _style_next_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(148, 36)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 15)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.12, 0.18, 0.88)
	normal.border_color = Color("#7ec8e8", 0.85)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	normal.shadow_color = Color("#5ec8ff", 0.22)
	normal.shadow_size = 4
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.12, 0.18, 0.26, 0.95)
	hover.border_color = Color("#9ed8ff")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_color_override("font_color", Color("#f0f8ff"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))


func _style_skip_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(72, 34)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.flat = true
	button.add_theme_font_size_override("font_size", 14)
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.add_theme_color_override("font_color", Color("#6a7a88", 0.88))
	button.add_theme_color_override("font_hover_color", Color("#9aa8b4"))
	button.add_theme_color_override("font_pressed_color", Color("#5a6878"))


func _load_slide_texture(image_path: String) -> Texture2D:
	if image_path.is_empty() or not ResourceLoader.exists(image_path):
		return null
	var tex := load(image_path) as Texture2D
	if tex != null:
		return tex
	var image := Image.new()
	if image.load(image_path) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _show_slide(index: int) -> void:
	_slide_index = clampi(index, 0, OpeningPrologueDefs.slide_count() - 1)
	var data := OpeningPrologueDefs.slide(_slide_index)
	var image_path := str(data.get("image", ""))
	var tex := _load_slide_texture(image_path)
	if tex != null:
		_texture_rect.texture = tex
	# 直接显示当前页的全部文字
	var all_text := ""
	for raw in data.get("lines", []):
		if not all_text.is_empty():
			all_text += "\n"
		all_text += str(raw)
	_narration_label.text = all_text
	_update_page_label()
	_update_next_button_text()


func _update_page_label() -> void:
	var total := OpeningPrologueDefs.slide_count()
	_page_label.text = "[ SYSTEM_LOG: %02d/%02d ]" % [_slide_index + 1, total]


func _update_next_button_text() -> void:
	var is_last_slide := _slide_index >= OpeningPrologueDefs.slide_count() - 1
	if is_last_slide:
		_next_button.text = "开始游戏  ▶"
	else:
		_next_button.text = "下一页  ▶"


func _advance() -> void:
	if _slide_index >= OpeningPrologueDefs.slide_count() - 1:
		_finish()
	else:
		_show_slide(_slide_index + 1)


func _on_next_pressed() -> void:
	_advance()


func _on_skip_pressed() -> void:
	_finish()


func _finish() -> void:
	GameManager.go_to_difficulty_select()
