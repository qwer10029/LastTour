extends Control
class_name MinimapView

var world_map: WorldMapData
var focus_position: Vector2 = Vector2.ZERO
var focus_node_index: int = -1
var exit_hint_directions: Array[String] = []
var active_segment_axis: String = ""
var war_fog_enabled: bool = true

const RIM_PADDING := 5.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(168, 168)
	set_process(true)


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func set_world_map(map_data: WorldMapData) -> void:
	world_map = map_data
	queue_redraw()


func set_war_fog_enabled(enabled: bool) -> void:
	war_fog_enabled = enabled
	queue_redraw()


func set_focus_position(position: Vector2) -> void:
	focus_position = position
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
	var center := _radar_center()
	var half := _radar_radius() * 0.72
	return Rect2(center - Vector2(half, half), Vector2(half * 2.0, half * 2.0))


func _inside_disc(point: Vector2) -> bool:
	var radius := _radar_radius()
	return point.distance_squared_to(_radar_center()) <= radius * radius


func _world_to_minimap(position: Vector2, map_rect: Rect2) -> Vector2:
	if world_map == null or world_map.columns <= 0 or world_map.rows <= 0:
		return map_rect.get_center()
	var world_size := world_map.get_world_size()
	if world_size.x <= 0.0 or world_size.y <= 0.0:
		return map_rect.get_center()
	return Vector2(
		map_rect.position.x + clampf(position.x / world_size.x, 0.0, 1.0) * map_rect.size.x,
		map_rect.position.y + clampf(position.y / world_size.y, 0.0, 1.0) * map_rect.size.y,
	)


func _node_center_minimap(index: int, map_rect: Rect2) -> Vector2:
	var coord := world_map.coord_from_index(index)
	var cell_width := map_rect.size.x / float(world_map.columns)
	var cell_height := map_rect.size.y / float(world_map.rows)
	return Vector2(
		map_rect.position.x + (float(coord.x) + 0.5) * cell_width,
		map_rect.position.y + (float(coord.y) + 0.5) * cell_height,
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


func _draw_exit_hint_arrows(node_index: int, map_rect: Rect2) -> void:
	if not world_map.is_valid_index(node_index):
		return
	var center := _node_center_minimap(node_index, map_rect)
	if not _inside_disc(center):
		return
	var cell_width := map_rect.size.x / float(world_map.columns)
	var cell_height := map_rect.size.y / float(world_map.rows)
	var arm := minf(cell_width, cell_height) * 0.28
	for direction in exit_hint_directions:
		var tip := center
		var tail := center
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
		if not _inside_disc(tip):
			continue
		draw_line(tail, tip, Color("#7dffb2", 0.9), 2.5)
		draw_circle(tip, 2.0, Color("#ffffff", 0.95))


func _cell_visible(index: int) -> bool:
	if not war_fog_enabled:
		return true
	if world_map == null or not world_map.is_valid_index(index):
		return false
	return bool(world_map.get_cell(index)["explored"])


func _draw() -> void:
	_draw_radar_chrome()
	if world_map == null or world_map.columns <= 0 or world_map.rows <= 0:
		return

	var map_rect := _map_draw_rect()
	var cell_width := map_rect.size.x / float(world_map.columns)
	var cell_height := map_rect.size.y / float(world_map.rows)

	for index in range(world_map.cells.size()):
		var cell := world_map.get_cell(index)
		var coord := world_map.coord_from_index(index)
		var cell_rect := Rect2(
			map_rect.position + Vector2(coord.x * cell_width, coord.y * cell_height),
			Vector2(cell_width, cell_height),
		)
		var cell_center := cell_rect.position + cell_rect.size * 0.5
		if not _inside_disc(cell_center):
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
			var other_center := _node_center_minimap(other, map_rect)
			if not _inside_disc(other_center):
				continue
			var center := _node_center_minimap(index, map_rect)
			var road_color := Color("#a89472", 0.85) if explored or not war_fog_enabled else Color("#5c5448", 0.55)
			draw_line(center, other_center, road_color, 1.8)

		if (explored or not war_fog_enabled) and int(cell["resource_remaining"]) > 0:
			draw_circle(cell_center, 2.5, Color("#f3d34a", 0.95))

		if kind == "district":
			var building_rect := cell_rect.grow(-cell_width * 0.22)
			var building_bright := explored or not war_fog_enabled
			draw_rect(building_rect, Color("#9e8564", 0.9) if building_bright else Color("#2a2f36", 0.5), true)
			if bool(cell["has_elevator"]):
				draw_rect(
					building_rect.grow(-cell_width * 0.18),
					Color("#6ed08b", 0.9) if building_bright else Color("#1a2a22", 0.45),
					false,
					1.5,
				)

	if world_map.is_valid_index(focus_node_index):
		var focus_rect := Rect2(
			map_rect.position
				+ Vector2(world_map.coord_from_index(focus_node_index)) * Vector2(cell_width, cell_height),
			Vector2(cell_width, cell_height),
		)
		if _inside_disc(focus_rect.get_center()):
			draw_rect(focus_rect, Color("#ff5f57", 0.16), true)
			draw_rect(focus_rect, Color("#ff8b7a", 0.75), false, 1.5)
		_draw_exit_hint_arrows(focus_node_index, map_rect)

	var marker_pos := _world_to_minimap(focus_position, map_rect)
	if _inside_disc(marker_pos):
		draw_circle(marker_pos, 5.0, Color(1.0, 0.35, 0.35, 0.28))
		draw_circle(marker_pos, 3.0, Color("#ff2d2d", 0.95))
		draw_circle(marker_pos, 1.5, Color("#ffffff", 0.95))

	# 外圈描边压在最上层，遮住方形地图角
	var center := _radar_center()
	var radius := _radar_radius()
	draw_arc(center, radius, 0.0, TAU, 96, Color(0.62, 0.8, 0.88, 0.72), 2.0)
