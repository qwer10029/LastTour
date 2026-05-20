extends Control
class_name MinimapView

var world_map: WorldMapData
var focus_position: Vector2 = Vector2.ZERO

func set_world_map(map_data: WorldMapData) -> void:
	world_map = map_data
	queue_redraw()

func set_focus_position(position: Vector2) -> void:
	focus_position = position
	queue_redraw()

func _draw() -> void:
	if world_map == null or world_map.columns <= 0 or world_map.rows <= 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#090d12"), true)
		return

	var cell_width := size.x / float(world_map.columns)
	var cell_height := size.y / float(world_map.rows)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#090d12"), true)

	for index in range(world_map.cells.size()):
		var cell := world_map.get_cell(index)
		var coord := world_map.coord_from_index(index)
		var cell_rect := Rect2(Vector2(coord.x * cell_width, coord.y * cell_height), Vector2(cell_width, cell_height))
		if cell.is_empty():
			continue
		var explored := bool(cell["explored"])
		var kind := str(cell["kind"])
		var fill := Color("#0a0b0d")
		if explored:
			match kind:
				"district":
					fill = Color("#647b50")
				"hub":
					fill = Color("#596874")
				"junction":
					fill = Color("#51697d")
				_:
					fill = Color("#36424d")
		draw_rect(cell_rect, fill, true)
		draw_rect(cell_rect, Color("#1c2730"), false, 1.0)

		for direction in world_map.get_available_directions(index):
			var other := world_map.get_neighbor_index(index, direction)
			if other < 0 or other < index:
				continue
			var other_coord := world_map.coord_from_index(other)
			var other_center := Vector2(other_coord.x * cell_width + cell_width * 0.5, other_coord.y * cell_height + cell_height * 0.5)
			var center := Vector2(coord.x * cell_width + cell_width * 0.5, coord.y * cell_height + cell_height * 0.5)
			draw_line(center, other_center, Color("#7da0be") if explored else Color("#20262b"), 2.0)

		if explored and int(cell["resource_remaining"]) > 0:
			draw_circle(cell_rect.position + cell_rect.size * 0.5, 3.0, Color("#f3d34a"))

		if kind == "district":
			var building_rect := cell_rect.grow(-cell_width * 0.22)
			draw_rect(building_rect, Color("#9e8564") if explored else Color("#111111"), true)
			if bool(cell["has_elevator"]):
				draw_rect(building_rect.grow(-cell_width * 0.18), Color("#6ed08b") if explored else Color("#111111"), false, 2.0)

	var focus_index := world_map.index_from_position(focus_position)
	if world_map.is_valid_index(focus_index):
		var focus_coord := world_map.coord_from_index(focus_index)
		var focus_rect := Rect2(Vector2(focus_coord.x * cell_width, focus_coord.y * cell_height), Vector2(cell_width, cell_height))
		draw_rect(focus_rect.grow(-1.5), Color("#ff5f57"), false, 2.0)
		draw_rect(Rect2(focus_rect.position + focus_rect.size * 0.4, focus_rect.size * 0.2), Color("#ff5f57"), true)
