extends Control

const TYPEWRITER_CHAR_SEC := 0.038
const NARRATION_WIDTH_RATIO := 0.55
const NARRATION_TOP_RATIO := 0.66
const NARRATION_BOTTOM_RATIO := 0.80
const MAX_VISIBLE_LINES := 2
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
var _line_index := 0
var _lines: PackedStringArray = []
var _prefix_text := ""
var _is_typing := false


func _ready() -> void:
	_play_music_cue("opening_prologue", 1.0)
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


func _exit_tree() -> void:
	_stop_typewriter()


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
	label.max_lines_visible = MAX_VISIBLE_LINES
	label.clip_text = true
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


func _show_slide(index: int) -> void:
	_stop_typewriter()
	_slide_index = clampi(index, 0, OpeningPrologueDefs.slide_count() - 1)
	var data := OpeningPrologueDefs.slide(_slide_index)
	var image_path := str(data.get("image", ""))
	if image_path != "" and ResourceLoader.exists(image_path):
		var tex := load(image_path) as Texture2D
		_texture_rect.texture = tex
	_lines = PackedStringArray()
	for raw in data.get("lines", []):
		_lines.append(str(raw))
	_line_index = 0
	_prefix_text = ""
	_set_narration_text("")
	_update_page_label()
	_update_next_button_text()
	_begin_current_line_typewriter()


func _update_page_label() -> void:
	var total := OpeningPrologueDefs.slide_count()
	_page_label.text = "[ SYSTEM_LOG: %02d/%02d ]" % [_slide_index + 1, total]


func _update_next_button_text() -> void:
	var is_last_slide := _slide_index >= OpeningPrologueDefs.slide_count() - 1
	var is_last_line := _line_index >= _lines.size() - 1
	if is_last_slide and is_last_line and not _is_typing:
		_next_button.text = "开始游戏  ▶"
	elif _is_typing:
		_next_button.text = "下一段  ▶"
	else:
		_next_button.text = "下一段  ▶"


func _begin_current_line_typewriter() -> void:
	if _line_index >= _lines.size():
		return
	_is_typing = true
	_update_next_button_text()
	_play_typewriter()


func _play_typewriter() -> void:
	var prefix := _prefix_text
	var line := _lines[_line_index]
	if not prefix.is_empty():
		prefix += "\n"
	for i in range(line.length()):
		if not _is_typing:
			return
		_set_narration_text(prefix + line.substr(0, i + 1))
		await get_tree().create_timer(TYPEWRITER_CHAR_SEC).timeout
	if not _is_typing:
		return
	_prefix_text = _joined_lines_through(_line_index)
	_set_narration_text(_prefix_text)
	_is_typing = false
	_update_next_button_text()


func _stop_typewriter() -> void:
	_is_typing = false


func _complete_current_line() -> void:
	if not _is_typing:
		return
	_is_typing = false
	if _line_index < _lines.size():
		_prefix_text = _joined_lines_through(_line_index)
		_set_narration_text(_prefix_text)
	_update_next_button_text()


func _set_narration_text(raw: String) -> void:
	_narration_label.text = _window_narration_text(raw)


func _window_narration_text(raw: String) -> String:
	if raw.is_empty():
		return ""
	var logical_lines := raw.split("\n", false)
	if logical_lines.size() <= MAX_VISIBLE_LINES:
		return "\n".join(logical_lines)
	var start := logical_lines.size() - MAX_VISIBLE_LINES
	var windowed: PackedStringArray = []
	for i in range(start, logical_lines.size()):
		windowed.append(logical_lines[i])
	return "\n".join(windowed)


func _joined_lines_through(index: int) -> String:
	if index < 0 or _lines.is_empty():
		return ""
	var parts: PackedStringArray = []
	for i in range(index + 1):
		parts.append(_lines[i])
	return "\n".join(parts)


func _advance() -> void:
	if _is_typing:
		_complete_current_line()
		return
	if _line_index < _lines.size() - 1:
		_line_index += 1
		_begin_current_line_typewriter()
		return
	if _slide_index >= OpeningPrologueDefs.slide_count() - 1:
		_finish()
	else:
		_show_slide(_slide_index + 1)


func _on_next_pressed() -> void:
	_advance()


func _on_skip_pressed() -> void:
	_stop_typewriter()
	_finish()


func _finish() -> void:
	_stop_typewriter()
	GameManager.go_to_difficulty_select()
