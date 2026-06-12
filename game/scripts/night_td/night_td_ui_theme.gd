class_name NightTdUiTheme
extends RefCounted

## 夜战全息 UI 资产路径（将切图放入 res://assets/ui/night_td/）
const UI_DIR := "res://assets/ui/night_td/"

const FRAME_INTERFACE := UI_DIR + "frame_interface_full.png"
const PANEL_SIDEBAR := UI_DIR + "panel_sidebar.png"
const PANEL_TOP_STATUS := UI_DIR + "panel_top_status.png"
const PANEL_DIALOG_LOG := UI_DIR + "panel_dialog_log.png"
const SWITCH_HEATMAP_ON := UI_DIR + "switch_heatmap_on.png"
const BAR_DURABILITY_SEGMENTS := UI_DIR + "bar_durability_segments.png"
const UNIT_DEFENCE_CORE := UI_DIR + "unit_defence_core.png"
const EFFECT_ENERGY_SHIELD := UI_DIR + "effect_energy_shield.png"

const COLOR_CHARGE_DARK := Color("#1a2438")
const COLOR_CHARGE_GLOW := Color("#4a8ec8")
const COLOR_HOLO_TEXT := Color("#d8e8f8")
const COLOR_HOLO_SUB := Color("#8fa8c8")
const COLOR_HOLO_ACCENT := Color("#6ed0ff")

const PANEL_MARGINS := {
	PANEL_SIDEBAR: 18,
	PANEL_TOP_STATUS: 14,
	PANEL_DIALOG_LOG: 16,
}


static func load_texture(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	return tex


static func panel_style(texture_path: String, margin: int = 16) -> StyleBox:
	var tex := load_texture(texture_path)
	if tex != null:
		var box := StyleBoxTexture.new()
		box.texture = tex
		box.texture_margin_left = margin
		box.texture_margin_top = margin
		box.texture_margin_right = margin
		box.texture_margin_bottom = margin
		box.set_content_margin_all(maxi(margin / 2, 8))
		return box
	return _fallback_panel_style()


static func _fallback_panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.09, 0.14, 0.88)
	box.border_color = Color("#3a5a78")
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(10)
	return box


static func apply_holo_label(label: Label, accent: bool = false) -> void:
	if not is_instance_valid(label):
		return
	label.add_theme_color_override("font_color", COLOR_HOLO_ACCENT if accent else COLOR_HOLO_TEXT)
	label.add_theme_font_size_override("font_size", 13 if accent else 12)


static func sci_bar_styles(accent: Color, height: int = 10) -> Dictionary:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.06, 0.10, 0.94)
	bg.border_color = Color(accent.r, accent.g, accent.b, 0.42)
	bg.border_width_left = 1
	bg.border_width_top = 1
	bg.border_width_right = 1
	bg.border_width_bottom = 2
	bg.corner_radius_top_left = 2
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 2
	bg.shadow_color = Color(accent.r, accent.g, accent.b, 0.12)
	bg.shadow_size = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(accent.r, accent.g, accent.b, 0.92)
	fill.corner_radius_top_left = 1
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 1
	fill.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
	fill.shadow_size = 4
	return {"background": bg, "fill": fill, "height": height}


static func card_style(selected: bool, accent: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if selected:
		s.bg_color = Color(0.10, 0.18, 0.14, 0.96)
		s.border_color = Color(accent.r, accent.g, accent.b, 0.95)
		s.set_border_width_all(2)
		s.shadow_color = Color(accent.r, accent.g, accent.b, 0.38)
		s.shadow_size = 8
	else:
		s.bg_color = Color(0.06, 0.10, 0.15, 0.94)
		s.border_color = Color("#2a4058")
		s.border_width_left = 1
		s.border_width_top = 1
		s.border_width_right = 2
		s.border_width_bottom = 2
	s.corner_radius_top_left = 2
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_left = 6
	s.corner_radius_bottom_right = 2
	return s


static func toggle_terminal_style(accent: Color, active: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.09, 0.14, 0.96 if active else 0.88)
	s.border_color = Color(accent.r, accent.g, accent.b, 0.95 if active else 0.38)
	s.border_width_left = 2
	s.border_width_top = 1
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.corner_radius_top_left = 2
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 6
	s.corner_radius_bottom_right = 6
	s.shadow_color = Color(accent.r, accent.g, accent.b, 0.32 if active else 0.08)
	s.shadow_size = 6 if active else 2
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func cta_button_styles(accent: Color) -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent.r * 0.55, accent.g * 0.45, accent.b * 0.25, 0.98)
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.95)
	normal.set_border_width_all(2)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 4
	normal.shadow_color = Color(accent.r, accent.g, accent.b, 0.42)
	normal.shadow_size = 10
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(accent.r * 0.68, accent.g * 0.58, accent.b * 0.35, 1.0)
	hover.shadow_size = 14
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(accent.r * 0.42, accent.g * 0.32, accent.b * 0.18, 1.0)
	pressed.shadow_size = 6
	return {"normal": normal, "hover": hover, "pressed": pressed, "focus": normal}
