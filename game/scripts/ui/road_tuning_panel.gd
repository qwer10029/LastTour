class_name RoadTuningPanel
extends CanvasLayer

const DayTopdownRender = preload("res://scripts/day_topdown_render.gd")

var _settings: RoadRenderSettings
var _redraw_target: Node
var _panel: PanelContainer
var _rows: Dictionary = {}


func setup(settings: RoadRenderSettings, redraw_target: Node) -> void:
	_settings = settings
	_redraw_target = redraw_target
	layer = 90
	_build_ui()
	visible = false


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_panel.offset_left = 16.0
	_panel.offset_top = -720.0
	_panel.offset_right = 400.0
	_panel.offset_bottom = -16.0
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	var title := Label.new()
	title.text = "道路贴图调节（F9 开关）"
	title.add_theme_font_size_override("font_size", 14)
	root.add_child(title)

	var hint := Label.new()
	hint.text = "每种拐角朝向单独调位置，互不影响。先对准一种，再调另外三种。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 340.0
	hint.add_theme_color_override("font_color", Color("#b8c8d8"))
	hint.add_theme_font_size_override("font_size", 11)
	root.add_child(hint)

	root.add_child(HSeparator.new())
	_add_slider(root, "junction_scale_inset", "路口整体缩放", 0.75, 1.1, 0.01)
	_add_slider(root, "cross_arm_tex_width", "路口路面宽度(像素)", 150.0, 280.0, 1.0)
	_add_slider(root, "cross_arm_tex_half_length", "路段让出长度(像素)", 60.0, 220.0, 1.0)
	_add_slider(root, "cross_trim_inset", "路段 trim 比例", 0.75, 1.45, 0.01)
	_add_slider(root, "segment_trim_max_frac", "路段最大 trim 比例", 0.35, 0.55, 0.01)
	_add_slider(root, "corner_trim_extra", "拐角直路让出(倍率)", 0.90, 1.50, 0.01)
	_add_slider(root, "t_junction_trim_extra", "三岔直路让出(倍率)", 0.90, 1.50, 0.01)
	_add_slider(root, "corner_scale_inset", "拐角额外缩放", 0.75, 1.15, 0.01)
	_add_slider(root, "corner_offset_rd_x", "拐角(右+下) X", -180.0, 180.0, 1.0)
	_add_slider(root, "corner_offset_rd_y", "拐角(右+下) Y", -180.0, 180.0, 1.0)
	_add_slider(root, "corner_offset_dl_x", "拐角(下+左) X", -180.0, 180.0, 1.0)
	_add_slider(root, "corner_offset_dl_y", "拐角(下+左) Y", -180.0, 180.0, 1.0)
	_add_slider(root, "corner_offset_lu_x", "拐角(左+上) X", -180.0, 180.0, 1.0)
	_add_slider(root, "corner_offset_lu_y", "拐角(左+上) Y", -180.0, 180.0, 1.0)
	_add_slider(root, "corner_offset_ur_x", "拐角(上+右) X", -180.0, 180.0, 1.0)
	_add_slider(root, "corner_offset_ur_y", "拐角(上+右) Y", -180.0, 180.0, 1.0)
	_add_slider(root, "t_junction_scale_inset", "三岔额外缩放", 0.75, 1.35, 0.01)
	_add_slider(root, "t_junction_offset_x", "三岔位置 X", -180.0, 180.0, 1.0)
	_add_slider(root, "t_junction_offset_y", "三岔位置 Y", -180.0, 180.0, 1.0)

	var reset_btn := Button.new()
	reset_btn.text = "恢复默认"
	reset_btn.pressed.connect(_on_reset_pressed)
	root.add_child(reset_btn)


func _add_slider(parent: Control, prop: String, label_text: String, min_v: float, max_v: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 150.0
	label.add_theme_font_size_override("font_size", 11)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value = _settings.get(prop)
	slider.value_changed.connect(func(value: float) -> void:
		_settings.set(prop, value)
		_value_label(prop).text = _format_value(prop, value)
		DayTopdownRender.apply_settings(_settings)
		if is_instance_valid(_redraw_target):
			_redraw_target.queue_redraw()
	)
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = 52.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = _format_value(prop, slider.value)
	value_label.add_theme_font_size_override("font_size", 11)
	row.add_child(value_label)

	_rows[prop] = {"slider": slider, "value": value_label}


func _value_label(prop: String) -> Label:
	return _rows[prop]["value"]


func _format_value(prop: String, value: float) -> String:
	if prop in ["cross_arm_tex_width", "cross_arm_tex_half_length"]:
		return str(int(round(value)))
	if prop.ends_with("_x") or prop.ends_with("_y"):
		return str(int(round(value)))
	return "%.2f" % value


func _on_reset_pressed() -> void:
	_settings.junction_scale_inset = 0.94
	_settings.cross_arm_tex_width = 213.0
	_settings.cross_arm_tex_half_length = 113.0
	_settings.cross_trim_inset = 1.05
	_settings.segment_trim_max_frac = 0.50
	_settings.corner_trim_extra = 1.22
	_settings.t_junction_trim_extra = 1.10
	_settings.corner_scale_inset = 0.75
	_settings.corner_offset_rd_x = 27.0
	_settings.corner_offset_rd_y = 29.0
	_settings.corner_offset_dl_x = -27.0
	_settings.corner_offset_dl_y = 25.0
	_settings.corner_offset_lu_x = -29.0
	_settings.corner_offset_lu_y = -30.0
	_settings.corner_offset_ur_x = 30.0
	_settings.corner_offset_ur_y = -29.0
	_settings.t_junction_scale_inset = 0.75
	_settings.t_junction_offset_x = 0.0
	_settings.t_junction_offset_y = 0.0
	_settings.cross_offset_x = 0.0
	_settings.cross_offset_y = 0.0
	_settings.junction_ref_tex_size = 512.0
	_sync_sliders_from_settings()
	DayTopdownRender.apply_settings(_settings)
	if is_instance_valid(_redraw_target):
		_redraw_target.queue_redraw()


func _sync_sliders_from_settings() -> void:
	for prop in _rows.keys():
		var slider: HSlider = _rows[prop]["slider"]
		slider.set_value_no_signal(_settings.get(prop))
		_value_label(prop).text = _format_value(prop, slider.value)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		if _night_td_blocks_f9():
			return
		visible = not visible
		get_viewport().set_input_as_handled()


func _night_td_blocks_f9() -> bool:
	var root := get_tree().current_scene
	if root == null:
		return false
	var td := root.get_node_or_null("NightTd")
	return td != null and td.visible
