class_name HudTheme
extends RefCounted

## 全局 HUD 安全区与可读性规范

const SAFE_MARGIN := 28.0
const TOP_HUD_Y := 10.0
const INNER_MARGIN := 14.0
const TOP_BAR_HEIGHT := 72.0
const TIME_PANEL_HEIGHT := 72.0
const TOP_BAR_CONTENT_HEIGHT := 40.0
const TOP_BAR_INNER := 8.0
const INFO_PANEL_WIDTH := 284.0
const TIME_PANEL_WIDTH := 192.0
const TOP_HUD_GAP := 10.0


static func evening_panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.12, 0.08, 0.05, 0.92)
	box.border_color = Color("#e87840")
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	box.shadow_size = 4
	box.content_margin_left = INNER_MARGIN
	box.content_margin_top = INNER_MARGIN
	box.content_margin_right = INNER_MARGIN
	box.content_margin_bottom = INNER_MARGIN
	return box


static func panel_style(bg_alpha: float = 0.52) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.08, 0.12, bg_alpha)
	box.border_color = Color(0.30, 0.42, 0.52, 0.5)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	box.shadow_size = 3
	box.content_margin_left = INNER_MARGIN
	box.content_margin_top = INNER_MARGIN
	box.content_margin_right = INNER_MARGIN
	box.content_margin_bottom = INNER_MARGIN
	return box


static func top_bar_panel_style(bg_alpha: float = 0.44) -> StyleBoxFlat:
	var box := panel_style(bg_alpha)
	box.content_margin_left = TOP_BAR_INNER
	box.content_margin_top = TOP_BAR_INNER
	box.content_margin_right = TOP_BAR_INNER
	box.content_margin_bottom = TOP_BAR_INNER
	box.shadow_size = 2
	return box


static func inventory_panel_style() -> StyleBoxFlat:
	var box := top_bar_panel_style(0.94)
	box.bg_color = Color(0.04, 0.07, 0.11, 0.96)
	box.border_color = Color(0.28, 0.40, 0.52, 0.72)
	box.shadow_size = 0
	return box


static func inventory_hud_screen_rect(padding: float = 8.0) -> Rect2:
	return Rect2(
		SAFE_MARGIN - padding,
		TOP_HUD_Y - padding,
		INFO_PANEL_WIDTH + padding * 2.0,
		TOP_BAR_HEIGHT + padding * 2.0,
	)


static func time_panel_style() -> StyleBoxFlat:
	var box := top_bar_panel_style(0.36)
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	box.shadow_size = 0
	return box


static func apply_time_panel_margin(container: MarginContainer) -> void:
	if container == null:
		return
	container.add_theme_constant_override("margin_left", int(TOP_BAR_INNER))
	container.add_theme_constant_override("margin_top", 4)
	container.add_theme_constant_override("margin_right", int(TOP_BAR_INNER))
	container.add_theme_constant_override("margin_bottom", 4)


static func apply_inventory_panel(panel: Panel) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", inventory_panel_style())
	panel.clip_contents = true


static func apply_label(label: Label) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.78))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
	label.add_theme_constant_override("outline_size", 1)


static func apply_glyph_label(label: Label) -> void:
	if label == null:
		return
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)


static func apply_compact_label(label: Label) -> void:
	if label == null:
		return
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))


static func apply_button(button: BaseButton) -> void:
	if button == null:
		return
	button.add_theme_color_override("font_color", Color("#e6eef6"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#c8d4e0"))
	button.add_theme_color_override("font_focus_color", Color("#ffffff"))
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
	button.add_theme_constant_override("outline_size", 1)


static func apply_choice_button(button: Button, accent: Color = Color("#8ec8e8")) -> void:
	if button == null:
		return
	apply_button(button)
	# 与分队选择一致：仅鼠标悬停高亮，不用键盘焦点描边
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.11, 0.16, 0.88)
	normal.border_color = Color(0.26, 0.34, 0.44, 0.55)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.14, 0.20, 0.28, 0.96)
	hover.border_color = Color(accent.r, accent.g, accent.b, 0.92)
	hover.set_border_width_all(2)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", normal)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.10, 0.14, 0.20, 0.98)
	pressed.border_color = Color(accent.r, accent.g, accent.b, 0.75)
	button.add_theme_stylebox_override("pressed", pressed)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.05, 0.07, 0.10, 0.72)
	disabled.border_color = Color(0.18, 0.22, 0.28, 0.35)
	button.add_theme_stylebox_override("disabled", disabled)


static func apply_panel(panel: Panel) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", top_bar_panel_style(0.42))
	panel.clip_contents = true


static func apply_panel_container(container: PanelContainer) -> void:
	if container == null:
		return
	container.add_theme_stylebox_override("panel", panel_style(0.58))


static func apply_margin(container: MarginContainer) -> void:
	if container == null:
		return
	container.add_theme_constant_override("margin_left", int(INNER_MARGIN))
	container.add_theme_constant_override("margin_top", int(INNER_MARGIN))
	container.add_theme_constant_override("margin_right", int(INNER_MARGIN))
	container.add_theme_constant_override("margin_bottom", int(INNER_MARGIN))


static func apply_top_bar_margin(container: MarginContainer) -> void:
	if container == null:
		return
	container.add_theme_constant_override("margin_left", int(TOP_BAR_INNER))
	container.add_theme_constant_override("margin_top", int(TOP_BAR_INNER))
	container.add_theme_constant_override("margin_right", int(TOP_BAR_INNER))
	container.add_theme_constant_override("margin_bottom", int(TOP_BAR_INNER))


static func apply_progress_bar(bar: ProgressBar, fill: Color) -> void:
	if bar == null:
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.1, 0.14, 0.88)
	bg.set_corner_radius_all(4)
	var fill_box := StyleBoxFlat.new()
	fill_box.bg_color = fill
	fill_box.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill_box)


static func apply_slim_progress_bar(bar: ProgressBar, fill: Color) -> void:
	if bar == null:
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.09, 0.12, 0.55)
	bg.set_corner_radius_all(2)
	var fill_box := StyleBoxFlat.new()
	fill_box.bg_color = fill
	fill_box.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill_box)
	bar.custom_minimum_size = Vector2(0, 4)


static func apply_tree(root: Node) -> void:
	if root is Label:
		var label := root as Label
		if label.has_meta("hud_glyph"):
			apply_glyph_label(label)
		elif label.has_meta("hud_compact"):
			apply_compact_label(label)
		else:
			apply_label(label)
	elif root is Button:
		apply_button(root as Button)
	for child in root.get_children():
		apply_tree(child)


static func layout_hud(hud: CanvasLayer) -> void:
	if hud == null:
		return

	var info := hud.get_node_or_null("InfoPanel") as Panel
	if info != null:
		apply_inventory_panel(info)
		info.offset_left = SAFE_MARGIN
		info.offset_top = TOP_HUD_Y
		info.offset_right = SAFE_MARGIN + INFO_PANEL_WIDTH
		info.offset_bottom = TOP_HUD_Y + TOP_BAR_HEIGHT
		var info_margin := info.get_node_or_null("MarginContainer") as MarginContainer
		apply_top_bar_margin(info_margin)

	var time_panel := hud.get_node_or_null("TimePanel") as Panel
	if time_panel != null:
		time_panel.add_theme_stylebox_override("panel", time_panel_style())
		time_panel.clip_contents = true
		time_panel.offset_left = -SAFE_MARGIN - TIME_PANEL_WIDTH
		time_panel.offset_top = TOP_HUD_Y
		time_panel.offset_right = -SAFE_MARGIN
		time_panel.offset_bottom = TOP_HUD_Y + TIME_PANEL_HEIGHT
		var time_margin := time_panel.get_node_or_null("MarginContainer") as MarginContainer
		apply_time_panel_margin(time_margin)
		var day_bar := time_panel.get_node_or_null(
			"MarginContainer/TimeHud/VBox/DayProgressBar"
		) as ProgressBar
		if day_bar != null:
			apply_slim_progress_bar(day_bar, Color("#52a872"))

	var action := hud.get_node_or_null("ActionPanel") as Panel
	if action != null:
		action.add_theme_stylebox_override("panel", panel_style(0.42))
		action.offset_left = -300.0
		action.offset_top = -280.0
		action.offset_right = 300.0
		action.offset_bottom = -SAFE_MARGIN
		var action_margin := action.get_node_or_null("MarginContainer") as MarginContainer
		apply_margin(action_margin)

	var evening := hud.get_node_or_null("EveningNotice") as PanelContainer
	if evening != null:
		evening.add_theme_stylebox_override("panel", evening_panel_style())
		evening.offset_top = TOP_HUD_Y + TOP_BAR_HEIGHT + 8.0
		var evening_margin := evening.get_node_or_null("MarginContainer") as MarginContainer
		apply_margin(evening_margin)

	apply_tree(hud)


static func apply_vitals_bar(bar: PanelContainer) -> void:
	if bar == null:
		return
	bar.add_theme_stylebox_override("panel", top_bar_panel_style(0.50))
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = SAFE_MARGIN + INFO_PANEL_WIDTH + TOP_HUD_GAP
	bar.offset_right = -(SAFE_MARGIN + TIME_PANEL_WIDTH + TOP_HUD_GAP)
	bar.offset_top = TOP_HUD_Y
	bar.offset_bottom = TOP_HUD_Y + TOP_BAR_HEIGHT


static func desaturate(color: Color, amount: float = 0.18) -> Color:
	return Color(
		lerpf(color.r, color.r * 0.82, amount),
		lerpf(color.g, color.g * 0.82, amount),
		lerpf(color.b, color.b * 0.82, amount),
		color.a,
	)


static func draw_string(
	canvas: CanvasItem,
	pos: Vector2,
	text: String,
	font_size: int,
	color: Color,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
	width: int = -1,
) -> void:
	var font := ThemeDB.fallback_font
	canvas.draw_string(
		font,
		pos + Vector2(1.0, 2.0),
		text,
		alignment,
		width,
		font_size,
		Color(0.0, 0.0, 0.0, 0.74),
	)
	canvas.draw_string(font, pos, text, alignment, width, font_size, color)
