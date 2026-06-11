class_name DialogueUiTheme
extends RefCounted

const BORDER_COLD := Color("#507896")
const BORDER_HOVER := Color("#ff6b00")
const BG_DIALOG := Color(0.11, 0.12, 0.14, 180.0 / 255.0)
const BG_NAME_TAG := Color(0.08, 0.10, 0.13, 0.92)
const BG_CHOICE := Color(0.0, 0.0, 0.0, 0.55)


static func _sci_fi_flat(
	bg: Color,
	border: Color,
	border_w: int = 1,
	corner_tl: int = 0,
	corner_tr: int = 0,
	corner_br: int = 0,
	corner_bl: int = 0,
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_w)
	box.corner_radius_top_left = corner_tl
	box.corner_radius_top_right = corner_tr
	box.corner_radius_bottom_right = corner_br
	box.corner_radius_bottom_left = corner_bl
	box.anti_aliasing = true
	box.anti_aliasing_size = 1.0
	return box


static func dialog_panel_style() -> StyleBoxFlat:
	return _sci_fi_flat(BG_DIALOG, BORDER_COLD, 1)


static func name_tag_style() -> StyleBoxFlat:
	var box := _sci_fi_flat(BG_NAME_TAG, BORDER_COLD, 1, 2, 2, 0, 2)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


static func choice_button_normal_style() -> StyleBoxFlat:
	var box := _sci_fi_flat(
		BG_CHOICE,
		Color(BORDER_COLD.r, BORDER_COLD.g, BORDER_COLD.b, 0.65),
		1,
		2,
		0,
		2,
		0,
	)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box
