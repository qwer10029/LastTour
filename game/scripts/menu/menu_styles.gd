class_name MenuStyles
extends RefCounted

const BG_COLOR := Color("#0b1018")
const PANEL_COLOR := Color("#141c28")
const PANEL_BORDER := Color("#2a3a4f")
const TITLE_COLOR := Color("#d8e4f0")
const SUBTITLE_COLOR := Color("#8fa3b8")
const ACCENT_COLOR := Color("#6ed08b")
const DISABLED_COLOR := Color("#4a5568")
const BUTTON_NORMAL := Color("#1a2533")
const BUTTON_HOVER := Color("#243447")
const BUTTON_SELECTED := Color("#2d4a3a")

const MENU_BUTTON_SIZE := Vector2(380, 58)


## 从磁盘直接读取 PNG，绕过损坏的 .import 缓存。
static func load_menu_texture(resource_path: String) -> Texture2D:
	if resource_path.is_empty():
		return null
	var abs_path := ProjectSettings.globalize_path(resource_path)
	if not abs_path.is_empty():
		var image := Image.new()
		if image.load(abs_path) == OK and not image.is_empty():
			return ImageTexture.create_from_image(image)
	if ResourceLoader.exists(resource_path):
		var resource: Resource = ResourceLoader.load(
			resource_path, "", ResourceLoader.CACHE_MODE_IGNORE
		)
		if resource is Texture2D:
			var tex := resource as Texture2D
			if tex.get_width() > 16:
				return tex
	return null


static func style_panel(panel: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)


static func style_title(label: Label, size: int = 42) -> void:
	label.add_theme_color_override("font_color", TITLE_COLOR)
	label.add_theme_font_size_override("font_size", size)


static func style_subtitle(label: Label) -> void:
	label.add_theme_color_override("font_color", Color("#d8e8f4"))
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_constant_override("line_spacing", 4)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)


static func _apply_button_base(button: Button, font_size: int = 19) -> void:
	button.custom_minimum_size = MENU_BUTTON_SIZE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.45))


static func _set_button_styles(
	button: Button,
	normal: StyleBoxFlat,
	hover: StyleBoxFlat,
	pressed: StyleBoxFlat,
	disabled: StyleBoxFlat,
	font: Color,
	font_hover: Color,
	font_disabled: Color,
) -> void:
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", font)
	button.add_theme_color_override("font_hover_color", font_hover)
	button.add_theme_color_override("font_pressed_color", font_hover)
	button.add_theme_color_override("font_disabled_color", font_disabled)


static func _glow_button_style(
	bg: Color,
	border: Color,
	shadow: Color,
	radius: int = 10,
	border_width: int = 2,
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = shadow
	style.shadow_size = 5
	return style


static func style_new_game_button(button: Button) -> void:
	_apply_button_base(button)
	var accent := Color("#e87840")
	var normal := _glow_button_style(Color(0.10, 0.12, 0.16, 0.94), accent, Color(accent.r, accent.g, accent.b, 0.32))
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.14, 0.16, 0.22, 0.98)
	hover.border_color = Color("#ff9058")
	hover.shadow_size = 8
	hover.shadow_color = Color("#ff7840", 0.42)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.08, 0.10, 0.14, 1.0)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.08, 0.10, 0.13, 0.82)
	disabled.border_color = Color("#6a4a38", 0.55)
	disabled.shadow_size = 0
	_set_button_styles(button, normal, hover, pressed, disabled, Color("#f4f0e8"), Color("#ffffff"), Color("#6a7080"))


static func style_continue_button(button: Button, enabled: bool = true) -> void:
	_apply_button_base(button)
	if enabled:
		style_new_game_button(button)
		return
	var normal := _glow_button_style(Color(0.07, 0.09, 0.12, 0.82), Color("#3a424c", 0.65), Color(0.0, 0.0, 0.0, 0.0), 10, 1)
	normal.shadow_size = 0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.09, 0.11, 0.14, 0.88)
	var pressed := normal.duplicate() as StyleBoxFlat
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.06, 0.08, 0.10, 0.72)
	_set_button_styles(button, normal, hover, pressed, disabled, Color("#6a7480"), Color("#8a94a0"), Color("#4e5660"))


static func style_message_button(button: Button) -> void:
	_apply_button_base(button, 18)
	var border := Color("#8a6840")
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#c4a574")
	normal.border_color = border
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	normal.shadow_size = 3
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#d4b584")
	hover.border_color = Color("#9a7850")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#b49564")
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("#8a7a64", 0.72)
	_set_button_styles(button, normal, hover, pressed, disabled, Color("#3a2818"), Color("#2a1810"), Color("#5a4a38"))


static func style_settings_button(button: Button) -> void:
	_apply_button_base(button)
	var accent := Color("#5ec8ff")
	var normal := _glow_button_style(Color(0.06, 0.10, 0.15, 0.94), accent, Color(accent.r, accent.g, accent.b, 0.28), 10, 2)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.10, 0.16, 0.24, 0.98)
	hover.border_color = Color("#7ed8ff")
	hover.shadow_size = 8
	hover.shadow_color = Color("#5ec8ff", 0.38)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.05, 0.08, 0.12, 1.0)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.06, 0.08, 0.11, 0.72)
	disabled.border_color = Color("#3a4a58", 0.45)
	disabled.shadow_size = 0
	_set_button_styles(button, normal, hover, pressed, disabled, Color("#e8f4ff"), Color("#ffffff"), Color("#5a6878"))


static func style_menu_button(button: Button) -> void:
	style_new_game_button(button)
