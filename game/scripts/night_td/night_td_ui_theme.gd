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
