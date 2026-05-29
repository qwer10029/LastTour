extends Control
class_name MinimapView

var world_map: WorldMapData
var focus_position: Vector2 = Vector2.ZERO
var focus_node_index: int = -1
var exit_hint_directions: Array[String] = []
var active_segment_axis: String = ""
var war_fog_enabled: bool = true

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

func _world_to_minimap(position: Vector2) -> Vector2:
	if world_map == null or world_map.columns <= 0 or world_map.rows <= 0:
		return Vector2.ZERO
	var world_size := world_map.get_world_size()
	if world_size.x <= 0.0 or world_size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(
		clampf(position.x / world_size.x, 0.0, 1.0) * size.x,
		clampf(position.y / world_size.y, 0.0, 1.0) * size.y
	)

func _node_center_minimap(index: int) -> Vector2:
	var coord := world_map.coord_from_index(index)
	var cell_width := size.x / float(world_map.columns)
	var cell_height := size.y / float(world_map.rows)
	return Vector2(
		(float(coord.x) + 0.5) * cell_width,
		(float(coord.y) + 0.5) * cell_height
	)

func _draw_compass() -> void:
	var north := Vector2(size.x * 0.5, 10.0)
	draw_line(north, north + Vector2(0.0, 10.0), Color("#9ec9ff"), 2.0)
	draw_string(ThemeDB.fallback_font, north + Vector2(-4.0, -4.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#9ec9ff"))

func _draw_exit_hint_arrows(node_index: int) -> void:
	if not world_map.is_valid_index(node_index):
		return
	var center := _node_center_minimap(node_index)
	var cell_width := size.x / float(world_map.columns)
	var cell_height := size.y / float(world_map.rows)
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
		draw_line(tail, tip, Color("#7dffb2"), 3.0)
		draw_circle(tip, 2.5, Color("#ffffff"))

func _cell_visible(index: int) -> bool:
	if not war_fog_enabled:
		return true
	if world_map == null or not world_map.is_valid_index(index):
		return false
	return bool(world_map.get_cell(index)["explored"])

func _draw() -> void:
	if world_map == null or world_map.columns <= 0 or world_map.rows <= 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#090d12"), true)
		return

	var cell_width := size.x / float(world_map.columns)
	var cell_height := size.y / float(world_map.rows)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#060a10"), true)
	_draw_compass()

	for index in range(world_map.cells.size()):
		var cell := world_map.get_cell(index)
		var coord := world_map.coord_from_index(index)
		var cell_rect := Rect2(Vector2(coord.x * cell_width, coord.y * cell_height), Vector2(cell_width, cell_height))
		if cell.is_empty():
			continue
		if not _cell_visible(index):
			draw_rect(cell_rect, Color("#000000"), true)
			continue
		var explored := bool(cell["explored"])
		var kind := str(cell["kind"])
		var fill := Color("#121820")
		if explored or not war_fog_enabled:
			match kind:
				"district":
					fill = Color("#647b50")
				"hub":
					fill = Color("#596874")
				"junction":
					fill = Color("#51697d")
				_:
					fill = Color("#36424d")
		else:
			fill = Color("#151b24")
		draw_rect(cell_rect, fill, true)
		var border_bright := explored or not war_fog_enabled
		draw_rect(cell_rect, Color("#243040") if border_bright else Color("#141a22"), false, 1.0)

		for direction in world_map.get_available_directions(index):
			var other := world_map.get_neighbor_index(index, direction)
			if other < 0 or other < index:
				continue
			if not _cell_visible(other):
				continue
			var other_coord := world_map.coord_from_index(other)
			var other_center := Vector2(
				(float(other_coord.x) + 0.5) * cell_width,
				(float(other_coord.y) + 0.5) * cell_height
			)
			var center := Vector2(
				(float(coord.x) + 0.5) * cell_width,
				(float(coord.y) + 0.5) * cell_height
			)
			var is_ns := direction == "up" or direction == "down"
			var road_color := Color("#6eb5e8") if is_ns else Color("#e8c66e")
			if not war_fog_enabled and not explored:
				road_color = road_color.darkened(0.55)
			draw_line(center, other_center, road_color, 3.0 if is_ns else 2.0)

		if (explored or not war_fog_enabled) and int(cell["resource_remaining"]) > 0:
			draw_circle(cell_rect.position + cell_rect.size * 0.5, 3.0, Color("#f3d34a"))

		if kind == "district":
			var building_rect := cell_rect.grow(-cell_width * 0.22)
			var building_bright := explored or not war_fog_enabled
			draw_rect(building_rect, Color("#9e8564") if building_bright else Color("#2a2f36"), true)
			if bool(cell["has_elevator"]):
				draw_rect(building_rect.grow(-cell_width * 0.18), Color("#6ed08b") if building_bright else Color("#1a2a22"), false, 2.0)

	if world_map.is_valid_index(focus_node_index):
		var focus_rect := Rect2(
			Vector2(world_map.coord_from_index(focus_node_index)) * Vector2(cell_width, cell_height),
			Vector2(cell_width, cell_height)
		)
		draw_rect(focus_rect, Color("#ff5f57", 0.18), true)
		draw_rect(focus_rect, Color("#ff8b7a"), false, 2.0)
		_draw_exit_hint_arrows(focus_node_index)

	var marker_pos := _world_to_minimap(focus_position)
	draw_circle(marker_pos, 5.0, Color(1.0, 0.35, 0.35, 0.35))
	draw_circle(marker_pos, 3.0, Color("#ff2d2d"))
	draw_circle(marker_pos, 1.5, Color("#ffffff"))

	if active_segment_axis == "ns":
		draw_string(ThemeDB.fallback_font, Vector2(8.0, size.y - 8.0), "路段: 南北 (↑↓)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#9ec9ff"))
	elif active_segment_axis == "ew":
		draw_string(ThemeDB.fallback_font, Vector2(8.0, size.y - 8.0), "路段: 东西 (←→)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#f0d080"))
