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
	label.add_theme_color_override("font_color", SUBTITLE_COLOR)
	label.add_theme_font_size_override("font_size", 16)


static func style_menu_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = BUTTON_NORMAL
	normal.border_color = PANEL_BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12

	var hover := normal.duplicate()
	hover.bg_color = BUTTON_HOVER

	var pressed := normal.duplicate()
	pressed.bg_color = BUTTON_SELECTED

	var disabled := normal.duplicate()
	disabled.bg_color = Color("#121820")
	disabled.border_color = Color("#1e2835")

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", TITLE_COLOR)
	button.add_theme_color_override("font_hover_color", TITLE_COLOR)
	button.add_theme_color_override("font_pressed_color", TITLE_COLOR)
	button.add_theme_color_override("font_disabled_color", DISABLED_COLOR)
	button.add_theme_font_size_override("font_size", 20)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
