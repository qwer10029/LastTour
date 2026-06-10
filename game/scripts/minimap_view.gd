extends Control
class_name MinimapView

## true=右下角圆形局部雷达；false=矩形全图（供 M 键大地图面板使用）
@export var local_radar_mode: bool = true

var world_map: WorldMapData
var focus_position: Vector2 = Vector2.ZERO
var focus_node_index: int = -1
var exit_hint_directions: Array[String] = []
var active_segment_axis: String = ""
var war_fog_enabled: bool = true

const RIM_PADDING := 5.0
const REFERENCE_GRID := Vector2(8.0, 6.0)
const RADAR_ANIM_INTERVAL := 0.09

var _anim_accum := 0.0
var _last_focus_redraw_pos := Vector2(-99999.0, -99999.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if local_radar_mode:
		custom_minimum_size = Vector2(168, 168)
		set_process(true)
	else:
		set_process(false)


func _process(delta: float) -> void:
	if not local_radar_mode or not is_visible_in_tree():
		return
	_anim_accum += delta
	if _anim_accum >= RADAR_ANIM_INTERVAL:
		_anim_accum = 0.0
		queue_redraw()


func set_world_map(map_data: WorldMapData) -> void:
	world_map = map_data
	queue_redraw()


func set_war_fog_enabled(enabled: bool) -> void:
	war_fog_enabled = enabled
	queue_redraw()


func set_focus_position(world_pos: Vector2) -> void:
	focus_position = world_pos
	if not local_radar_mode:
		queue_redraw()
		return
	if world_pos.distance_squared_to(_last_focus_redraw_pos) >= 144.0:
		_last_focus_redraw_pos = world_pos
		queue_redraw()


func set_navigation_hints(node_index: int, exit_directions: Array[String], segment_axis: String) -> void:
	focus_node_index = node_index
	exit_hint_directions = exit_directions
	active_segment_axis = segment_axis
	queue_redraw()


func _radar_center() -> Vector2:
	return size * 0.5


func _radar_radius() -> float:
	return minf(size.x, size.y) * 0.5 - RIM_PADDING


func _map_draw_rect() -> Rect2:
	if not local_radar_mode:
		var pad := 8.0
		return Rect2(
			Vector2(pad, pad),
			Vector2(maxf(size.x - pad * 2.0, 1.0), maxf(size.y - pad * 2.0, 1.0)),
		)
	var center := _radar_center()
	var half := _radar_radius() * 0.72
	return Rect2(center - Vector2(half, half), Vector2(half * 2.0, half * 2.0))


func _inside_clip(point: Vector2, map_rect: Rect2) -> bool:
	if not local_radar_mode:
		return map_rect.grow(1.0).has_point(point)
	var radius := _radar_radius()
	return point.distance_squared_to(_radar_center()) <= radius * radius


func _focus_cell_coord() -> Vector2i:
	if world_map == null:
		return Vector2i.ZERO
	if world_map.is_valid_index(focus_node_index):
		return world_map.coord_from_index(focus_node_index)
	var index := world_map.index_from_position(focus_position)
	if world_map.is_valid_index(index):
		return world_map.coord_from_index(index)
	var world_size := world_map.get_world_size()
	if world_size.x <= 0.0 or world_size.y <= 0.0:
		return Vector2i.ZERO
	return Vector2i(
		clampi(int(focus_position.x / world_size.x * world_map.columns), 0, world_map.columns - 1),
		clampi(int(focus_position.y / world_size.y * world_map.rows), 0, world_map.rows - 1),
	)


func _view_span() -> Vector2:
	if world_map == null or world_map.columns <= 0 or world_map.rows <= 0:
		return REFERENCE_GRID
	if not local_radar_mode:
		return Vector2(float(world_map.columns), float(world_map.rows))
	var cols := float(world_map.columns)
	var rows := float(world_map.rows)
	var zoom := maxf(cols / REFERENCE_GRID.x, rows / REFERENCE_GRID.y)
	if zoom <= 1.0:
		return Vector2(cols, rows)
	return Vector2(cols / zoom, rows / zoom)


func _view_origin(span: Vector2) -> Vector2:
	if not local_radar_mode:
		return Vector2.ZERO
	var focus_cell := _focus_cell_coord()
	var max_origin_x := maxf(0.0, float(world_map.columns) - span.x)
	var max_origin_y := maxf(0.0, float(world_map.rows) - span.y)
	return Vector2(
		clampf(float(focus_cell.x) + 0.5 - span.x * 0.5, 0.0, max_origin_x),
		clampf(float(focus_cell.y) + 0.5 - span.y * 0.5, 0.0, max_origin_y),
	)


func _map_cell_size(map_rect: Rect2, span: Vector2) -> Vector2:
	return Vector2(map_rect.size.x / span.x, map_rect.size.y / span.y)


func _coord_in_view(coord: Vector2i, origin: Vector2, span: Vector2) -> bool:
	return (
		float(coord.x) >= origin.x
		and float(coord.y) >= origin.y
		and float(coord.x) < origin.x + span.x
		and float(coord.y) < origin.y + span.y
	)


func _world_to_map(world_pos: Vector2, map_rect: Rect2, origin: Vector2, span: Vector2) -> Vector2:
	if world_map == null or world_map.columns <= 0 or world_map.rows <= 0:
		return map_rect.get_center()
	var world_size := world_map.get_world_size()
	if world_size.x <= 0.0 or world_size.y <= 0.0:
		return map_rect.get_center()
	var cell_x := world_pos.x / world_size.x * float(world_map.columns) - origin.x
	var cell_y := world_pos.y / world_size.y * float(world_map.rows) - origin.y
	return Vector2(
		map_rect.position.x + cell_x / span.x * map_rect.size.x,
		map_rect.position.y + cell_y / span.y * map_rect.size.y,
	)


func _node_center(index: int, map_rect: Rect2, origin: Vector2, span: Vector2) -> Vector2:
	var coord := world_map.coord_from_index(index)
	var cell_size_mm := _map_cell_size(map_rect, span)
	return Vector2(
		map_rect.position.x + (float(coord.x) - origin.x + 0.5) * cell_size_mm.x,
		map_rect.position.y + (float(coord.y) - origin.y + 0.5) * cell_size_mm.y,
	)


func _draw_radar_chrome() -> void:
	var center := _radar_center()
	var radius := _radar_radius()
	draw_circle(center, radius + 2.0, Color(0.08, 0.12, 0.16, 0.16))
	draw_circle(center, radius, Color(0.05, 0.09, 0.13, 0.42))
	for ring_scale in [0.34, 0.66, 1.0]:
		draw_arc(center, radius * ring_scale, 0.0, TAU, 72, Color(0.42, 0.62, 0.72, 0.07), 1.0)
	for i in range(-2, 3):
		var t := float(i) / 2.0
		var x := center.x + radius * t
		var y := center.y + radius * t
		draw_line(Vector2(x, center.y - radius), Vector2(x, center.y + radius), Color(0.38, 0.58, 0.66, 0.055), 1.0)
		draw_line(Vector2(center.x - radius, y), Vector2(center.x + radius, y), Color(0.38, 0.58, 0.66, 0.055), 1.0)
	var scan_angle := fmod(float(Time.get_ticks_msec()) * 0.0018, TAU)
	var scan_tip := center + Vector2(cos(scan_angle), sin(scan_angle)) * radius
	draw_line(center, scan_tip, Color(0.42, 0.82, 0.68, 0.12), 1.5)
	var rim_pulse := 0.42 + 0.08 * sin(float(Time.get_ticks_msec()) * 0.003)
	draw_arc(center, radius, 0.0, TAU, 96, Color(0.62, 0.8, 0.88, rim_pulse), 1.0)
	draw_arc(center, radius + 1.5, 0.0, TAU, 96, Color(0.52, 0.82, 0.92, 0.12), 0.8)
	var north := center + Vector2(0.0, -radius + 10.0)
	draw_line(north, north + Vector2(0.0, 7.0), Color("#9ec9ff", 0.85), 1.5)
	HudTheme.draw_string(self, north + Vector2(-4.0, -6.0), "N", 11, Color("#9ec9ff", 0.9))


func _draw_full_map_frame(map_rect: Rect2) -> void:
	draw_rect(map_rect.grow(2.0), Color(0.08, 0.12, 0.16, 0.55), true)
	draw_rect(map_rect, Color(0.12, 0.18, 0.24, 0.35), false, 1.0)
	var north := map_rect.position + Vector2(map_rect.size.x * 0.5, 10.0)
	HudTheme.draw_string(self, north + Vector2(-4.0, -2.0), "N", 12, Color("#9ec9ff", 0.9))


func _draw_exit_hint_arrows(node_index: int, map_rect: Rect2, origin: Vector2, span: Vector2) -> void:
	if not world_map.is_valid_index(node_index):
		return
	var node_center := _node_center(node_index, map_rect, origin, span)
	if not _inside_clip(node_center, map_rect):
		return
	var cell_size_mm := _map_cell_size(map_rect, span)
	var arm := minf(cell_size_mm.x, cell_size_mm.y) * (0.28 if local_radar_mode else 0.22)
	for direction in exit_hint_directions:
		var tip := node_center
		var tail := node_center
		match direction:
			"up":
				tip += Vector2(0.0, -arm)
				tail += Vector2(0.0, -arm * 0.45)
			"down":
				tip += Vector2(0.0, arm)
				tail += Vector2(0.0, arm * 0.45)
			"left":
				tip += Vector2(-arm, 0.0)
				tail += Vector2(-arm * 0.45, 0.0)
			"right":
				tip += Vector2(arm, 0.0)
				tail += Vector2(arm * 0.45, 0.0)
		if not _inside_clip(tip, map_rect):
			continue
		draw_line(tail, tip, Color("#7dffb2", 0.9), 2.5 if local_radar_mode else 3.0)
		draw_circle(tip, 2.0, Color("#ffffff", 0.95))


func _cell_visible(index: int) -> bool:
	if not war_fog_enabled:
		return true
	if world_map == null or not world_map.is_valid_index(index):
		return false
	if world_map.is_tactical_revealed(index):
		return true
	return bool(world_map.get_cell(index)["explored"])


func _draw_map_content(map_rect: Rect2, origin: Vector2, span: Vector2) -> void:
	var cell_size_mm := _map_cell_size(map_rect, span)
	var marker_radius := 5.0 if local_radar_mode else 7.0

	for index in range(world_map.cells.size()):
		var cell := world_map.get_cell(index)
		var coord := world_map.coord_from_index(index)
		if not _coord_in_view(coord, origin, span):
			continue
		var cell_rect := Rect2(
			map_rect.position
				+ Vector2(
					(float(coord.x) - origin.x) * cell_size_mm.x,
					(float(coord.y) - origin.y) * cell_size_mm.y,
				),
			cell_size_mm,
		)
		var cell_center := cell_rect.position + cell_rect.size * 0.5
		if not _inside_clip(cell_center, map_rect):
			continue
		if cell.is_empty():
			continue
		if not _cell_visible(index):
			draw_rect(cell_rect, Color(0.02, 0.03, 0.05, 0.35), true)
			continue
		var explored := bool(cell["explored"])
		var kind := str(cell["kind"])
		var fill := Color("#121820", 0.82)
		if explored or not war_fog_enabled:
			match kind:
				"district":
					fill = Color("#647b50", 0.88)
				"hub":
					fill = Color("#596874", 0.88)
				"junction":
					fill = Color("#51697d", 0.88)
				_:
					fill = Color("#36424d", 0.86)
		else:
			fill = Color("#151b24", 0.55)
		draw_rect(cell_rect, fill, true)
		var border_bright := explored or not war_fog_enabled
		draw_rect(cell_rect, Color("#243040", 0.75) if border_bright else Color("#141a22", 0.45), false, 1.0)

		for direction in world_map.get_available_directions(index):
			var other := world_map.get_neighbor_index(index, direction)
			if other < 0 or other < index:
				continue
			if not _cell_visible(other):
				continue
			var other_coord := world_map.coord_from_index(other)
			if not _coord_in_view(other_coord, origin, span):
				continue
			var other_center := _node_center(other, map_rect, origin, span)
			if not _inside_clip(other_center, map_rect):
				continue
			var line_center := _node_center(index, map_rect, origin, span)
			var road_color := Color("#a89472", 0.85) if explored or not war_fog_enabled else Color("#5c5448", 0.55)
			draw_line(line_center, other_center, road_color, 1.8 if local_radar_mode else 2.2)

		if (explored or not war_fog_enabled or world_map.is_tactical_revealed(index)) and int(cell["resource_remaining"]) > 0:
			var dot_r := 2.5 if local_radar_mode else maxf(3.0, cell_size_mm.x * 0.12)
			draw_circle(cell_center, dot_r, Color("#f3d34a", 0.95))

		if kind == "district":
			if world_map.is_tactical_dormant(index):
				continue
			var building_rect := cell_rect.grow(-cell_size_mm.x * 0.22)
			var building_bright := explored or not war_fog_enabled or world_map.is_tactical_revealed(index)
			draw_rect(building_rect, Color("#9e8564", 0.9) if building_bright else Color("#2a2f36", 0.5), true)
			if world_map.is_tactical_revealed(index):
				draw_rect(building_rect.grow(2.0), Color("#68b0ff", 0.85), false, 1.5)
			if bool(cell.get("has_elevator", false)):
				draw_rect(
					building_rect.grow(-cell_size_mm.x * 0.18),
					Color("#6ed08b", 0.9) if building_bright else Color("#1a2a22", 0.45),
					false,
					1.5,
				)
			elif bool(cell.get("has_kunlun_control", false)):
				draw_rect(
					building_rect.grow(-cell_size_mm.x * 0.18),
					Color("#6eb8ff", 0.9) if building_bright else Color("#1a2838", 0.45),
					false,
					1.5,
				)
			if not local_radar_mode and building_bright and cell_size_mm.x >= 18.0:
				var label := world_map.building_label(index)
				if label != "":
					HudTheme.draw_string(
						self,
						building_rect.position + Vector2(2.0, 2.0),
						label,
						maxi(9, int(cell_size_mm.y * 0.28)),
						Color("#a8d8ff" if world_map.is_tactical_revealed(index) else Color("#e8dcc8", 0.92)),
					)

	if world_map.is_valid_index(focus_node_index):
		var focus_coord := world_map.coord_from_index(focus_node_index)
		if _coord_in_view(focus_coord, origin, span):
			var focus_rect := Rect2(
				map_rect.position
					+ Vector2(
						(float(focus_coord.x) - origin.x) * cell_size_mm.x,
						(float(focus_coord.y) - origin.y) * cell_size_mm.y,
					),
				cell_size_mm,
			)
			if _inside_clip(focus_rect.get_center(), map_rect):
				draw_rect(focus_rect, Color("#ff5f57", 0.16), true)
				draw_rect(focus_rect, Color("#ff8b7a", 0.75), false, 1.5)
			_draw_exit_hint_arrows(focus_node_index, map_rect, origin, span)

	var marker_pos := _world_to_map(focus_position, map_rect, origin, span)
	if _inside_clip(marker_pos, map_rect):
		draw_circle(marker_pos, marker_radius, Color(1.0, 0.35, 0.35, 0.28))
		draw_circle(marker_pos, marker_radius - 2.0, Color("#ff2d2d", 0.95))
		draw_circle(marker_pos, marker_radius - 3.5, Color("#ffffff", 0.95))


func _draw() -> void:
	if local_radar_mode:
		_draw_radar_chrome()
	else:
		var map_rect_preview := _map_draw_rect()
		_draw_full_map_frame(map_rect_preview)

	if world_map == null or world_map.columns <= 0 or world_map.rows <= 0:
		return

	var map_rect := _map_draw_rect()
	var span := _view_span()
	var origin := _view_origin(span)
	_draw_map_content(map_rect, origin, span)

	if local_radar_mode:
		var center := _radar_center()
		var radius := _radar_radius()
		draw_arc(center, radius, 0.0, TAU, 96, Color(0.62, 0.8, 0.88, 0.72), 2.0)
