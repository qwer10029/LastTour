extends Control
class_name WorldMapOverlay

signal closed

var _map_view: MinimapView
var _hint_label: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 40

	var dim := ColorRect.new()
	dim.name = "Dimmer"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.07, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var frame := PanelContainer.new()
	frame.name = "MapFrame"
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -520.0
	frame.offset_top = -360.0
	frame.offset_right = 520.0
	frame.offset_bottom = 360.0
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.06, 0.1, 0.14, 0.96)
	frame_style.border_color = Color(0.45, 0.68, 0.78, 0.85)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(10)
	frame_style.set_content_margin_all(14)
	frame.add_theme_stylebox_override("panel", frame_style)
	add_child(frame)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	frame.add_child(vbox)

	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	var title := Label.new()
	title.text = "区域地图"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#b8d8ec"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	_hint_label = Label.new()
	_hint_label.text = "M / Esc 关闭"
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.add_theme_color_override("font_color", Color("#7a9aaa"))
	title_row.add_child(_hint_label)

	_map_view = MinimapView.new()
	_map_view.name = "FullMapView"
	_map_view.local_radar_mode = false
	_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_view.custom_minimum_size = Vector2(960, 620)
	vbox.add_child(_map_view)


func is_open() -> bool:
	return visible


func open(
	map_data: WorldMapData,
	war_fog: bool,
	focus_pos: Vector2,
	node_index: int,
	exit_directions: Array[String],
	segment_axis: String,
) -> void:
	_map_view.set_world_map(map_data)
	_map_view.set_war_fog_enabled(war_fog)
	_map_view.set_focus_position(focus_pos)
	_map_view.set_navigation_hints(node_index, exit_directions, segment_axis)
	_resize_map_panel()
	visible = true
	_map_view.queue_redraw()


func refresh(
	focus_pos: Vector2,
	node_index: int,
	exit_directions: Array[String],
	segment_axis: String,
) -> void:
	if not visible:
		return
	_map_view.set_focus_position(focus_pos)
	_map_view.set_navigation_hints(node_index, exit_directions, segment_axis)


func close_overlay() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_resize_map_panel()


func _resize_map_panel() -> void:
	if not is_instance_valid(_map_view):
		return
	var vp := get_viewport_rect().size
	if vp == Vector2.ZERO:
		vp = Vector2(1280.0, 720.0)
	var panel_w := clampf(vp.x * 0.82, 720.0, 1040.0)
	var panel_h := clampf(vp.y * 0.78, 480.0, 700.0)
	var frame := get_node_or_null("MapFrame") as Control
	if frame != null:
		frame.offset_left = -panel_w * 0.5
		frame.offset_right = panel_w * 0.5
		frame.offset_top = -panel_h * 0.5
		frame.offset_bottom = panel_h * 0.5
	_map_view.custom_minimum_size = Vector2(panel_w - 40.0, panel_h - 72.0)

