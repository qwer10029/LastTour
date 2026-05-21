class_name WorldMapData
extends RefCounted

const DIRECTIONS := {
	"up": Vector2i(0, -1),
	"down": Vector2i(0, 1),
	"left": Vector2i(-1, 0),
	"right": Vector2i(1, 0),
}

var columns: int = 0
var rows: int = 0
var cell_size: Vector2i = Vector2i(240, 240)
var cells: Array[Dictionary] = []
var district_indices: Array[int] = []
var hub_indices: Array[int] = []
var start_node_index: int = -1

func generate(new_columns: int, new_rows: int, new_cell_size: Vector2i, rng_seed: int = 0) -> void:
	columns = new_columns
	rows = new_rows
	cell_size = new_cell_size
	cells.clear()
	district_indices.clear()
	hub_indices.clear()
	start_node_index = -1

	var rng := RandomNumberGenerator.new()
	if rng_seed == 0:
		rng.randomize()
	else:
		rng.seed = rng_seed

	for row in range(rows):
		for column in range(columns):
			cells.append(_create_empty_cell(Vector2i(column, row)))

	var hub_coords: Array[Vector2i] = _pick_cells(rng, max(2, min(4, (columns + rows) / 4)))
	for coord in hub_coords:
		var index := index_from_coord(coord)
		cells[index]["kind"] = "hub"
		cells[index]["building_type"] = "hub"
		hub_indices.append(index)

	var district_coords: Array[Vector2i] = _pick_cells(rng, max(5, min(8, columns)))
	for coord in district_coords:
		var index := index_from_coord(coord)
		if index in hub_indices:
			continue
		cells[index]["kind"] = "district"
		cells[index]["building_type"] = _pick_building_type(rng)
		cells[index]["has_elevator"] = cells[index]["building_type"] == "elevator"
		cells[index]["resource_total"] = rng.randi_range(1, 4)
		cells[index]["resource_remaining"] = cells[index]["resource_total"]
		cells[index]["resource_spawns"] = _generate_resource_spawns(rng, int(cells[index]["resource_total"]))
		district_indices.append(index)

	_ensure_elevator_district()

	if district_indices.is_empty():
		return
	for district_index in district_indices:
		var district_coord := coord_from_index(district_index)
		var closest_hub := _closest_coord(district_coord, hub_coords)
		if closest_hub != Vector2i(-1, -1):
			_carve_l_path(district_coord, closest_hub, rng)

	for i in range(max(0, hub_coords.size() - 1)):
		_carve_l_path(hub_coords[i], hub_coords[i + 1], rng)

	# Build a simple full grid road network so every adjacent cell is connected.
	for y in range(rows):
		for x in range(columns):
			var c := Vector2i(x, y)
			# link right neighbor
			if x < columns - 1:
				_link_coords(c, Vector2i(x + 1, y))
			# link down neighbor
			if y < rows - 1:
				_link_coords(c, Vector2i(x, y + 1))

	_finalize_cell_kinds()
	_mark_start_node()

func get_world_size() -> Vector2:
	return Vector2(columns * cell_size.x, rows * cell_size.y)

func is_valid_index(index: int) -> bool:
	return index >= 0 and index < cells.size()

func coord_from_index(index: int) -> Vector2i:
	if not is_valid_index(index):
		return Vector2i(-1, -1)
	return Vector2i(index % columns, index / columns)

func index_from_coord(coord: Vector2i) -> int:
	if coord.x < 0 or coord.y < 0 or coord.x >= columns or coord.y >= rows:
		return -1
	return coord.y * columns + coord.x

func index_from_position(position: Vector2) -> int:
	if columns <= 0 or rows <= 0:
		return -1
	var coord := Vector2i(clampi(int(position.x / float(cell_size.x)), 0, columns - 1), clampi(int(position.y / float(cell_size.y)), 0, rows - 1))
	return index_from_coord(coord)

func cell_rect(index: int) -> Rect2:
	if not is_valid_index(index):
		return Rect2()
	var coord := coord_from_index(index)
	return Rect2(Vector2(coord.x * cell_size.x, coord.y * cell_size.y), Vector2(float(cell_size.x), float(cell_size.y)))

func cell_center(index: int) -> Vector2:
	return cell_rect(index).position + cell_rect(index).size * 0.5

func get_cell(index: int) -> Dictionary:
	if not is_valid_index(index):
		return {}
	return cells[index]

func get_kind(index: int) -> String:
	if not is_valid_index(index):
		return "empty"
	return str(cells[index]["kind"])

func is_district(index: int) -> bool:
	return get_kind(index) == "district"

func is_hub(index: int) -> bool:
	return get_kind(index) == "hub"

func is_road(index: int) -> bool:
	return get_kind(index) == "road"

func is_junction(index: int) -> bool:
	return get_kind(index) == "junction"

func mark_explored(index: int) -> void:
	if not is_valid_index(index):
		return
	cells[index]["explored"] = true

func mark_position_explored(position: Vector2) -> int:
	var index := index_from_position(position)
	mark_explored(index)
	return index

func get_connected_indices(index: int) -> Array[int]:
	var result: Array[int] = []
	if not is_valid_index(index):
		return result
	var connections: Dictionary = cells[index]["connections"]
	for direction in connections.keys():
		var other := int(connections[direction])
		if other >= 0:
			result.append(other)
	return result

func get_available_directions(index: int) -> Array[String]:
	var result: Array[String] = []
	if not is_valid_index(index):
		return result
	var connections: Dictionary = cells[index]["connections"]
	for direction in connections.keys():
		if int(connections[direction]) >= 0:
			result.append(str(direction))
	return result

func get_neighbor_index(index: int, direction: String) -> int:
	if not is_valid_index(index):
		return -1
	var connections: Dictionary = cells[index]["connections"]
	if connections.has(direction):
		return int(connections[direction])
	return -1

func direction_between(from_index: int, to_index: int) -> String:
	if not is_valid_index(from_index) or not is_valid_index(to_index):
		return ""
	var delta := coord_from_index(to_index) - coord_from_index(from_index)
	if delta == Vector2i(0, -1):
		return "up"
	if delta == Vector2i(0, 1):
		return "down"
	if delta == Vector2i(-1, 0):
		return "left"
	if delta == Vector2i(1, 0):
		return "right"
	return ""

func opposite_direction(direction: String) -> String:
	match direction:
		"up":
			return "down"
		"down":
			return "up"
		"left":
			return "right"
		"right":
			return "left"
		_:
			return ""

func get_segment_axis(from_index: int, to_index: int) -> String:
	if not is_valid_index(from_index) or not is_valid_index(to_index):
		return ""
	var delta := coord_from_index(to_index) - coord_from_index(from_index)
	if delta.x == 0 and delta.y != 0:
		return "ns"
	if delta.y == 0 and delta.x != 0:
		return "ew"
	return ""

func allowed_input_directions_for_segment(from_index: int, to_index: int) -> Array[String]:
	var axis := get_segment_axis(from_index, to_index)
	if axis == "ns":
		return ["up", "down"]
	if axis == "ew":
		return ["left", "right"]
	return []

func connected_count(index: int) -> int:
	return get_connected_indices(index).size()

func total_resources_remaining() -> int:
	var total := 0
	for cell in cells:
		total += int(cell["resource_remaining"])
	return total

func explored_count() -> int:
	var total := 0
	for cell in cells:
		if bool(cell["explored"]):
			total += 1
	return total

func collect_resource(index: int) -> bool:
	if not is_valid_index(index):
		return false
	if int(cells[index]["resource_remaining"]) <= 0:
		return false
	cells[index]["resource_remaining"] = int(cells[index]["resource_remaining"]) - 1
	return true

func building_label(index: int) -> String:
	if not is_valid_index(index):
		return "未知建筑"
	var building_type := str(cells[index]["building_type"])
	match building_type:
		"warehouse":
			return "仓库"
		"elevator":
			return "电梯楼"
		"garage":
			return "车库"
		"archive":
			return "档案站"
		"hub":
			return "枢纽"
		_:
			return "建筑群"

func road_path_between(a: int, b: int) -> Array[int]:
	var result: Array[int] = []
	if not is_valid_index(a) or not is_valid_index(b):
		return result
	var start := coord_from_index(a)
	var target := coord_from_index(b)
	var current := start
	result.append(index_from_coord(current))
	while current.x != target.x:
		current.x += signi(target.x - current.x)
		result.append(index_from_coord(current))
	while current.y != target.y:
		current.y += signi(target.y - current.y)
		result.append(index_from_coord(current))
	return result

func sector_resource_remaining(index: int) -> int:
	if not is_valid_index(index):
		return 0
	return int(cells[index]["resource_remaining"])

func district_has_elevator(index: int) -> bool:
	if not is_valid_index(index):
		return false
	return bool(cells[index]["has_elevator"])

func sector_has_elevator(index: int) -> bool:
	return district_has_elevator(index)

func _create_empty_cell(coord: Vector2i) -> Dictionary:
	return {
		"coord": coord,
		"kind": "empty",
		"explored": false,
		"building_type": "",
		"has_elevator": false,
		"resource_total": 0,
		"resource_remaining": 0,
		"resource_spawns": [],
		"connections": {
			"up": -1,
			"down": -1,
			"left": -1,
			"right": -1,
		},
		"seed": 0,
	}

func _pick_cells(rng: RandomNumberGenerator, count: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var attempts := 0
	while result.size() < count and attempts < 200:
		attempts += 1
		var coord := Vector2i(rng.randi_range(0, columns - 1), rng.randi_range(0, rows - 1))
		if coord in result:
			continue
		var too_close := false
		for existing in result:
			if abs(existing.x - coord.x) + abs(existing.y - coord.y) < 2:
				too_close = true
				break
		if too_close:
			continue
		result.append(coord)
	return result

func _closest_coord(source: Vector2i, candidates: Array[Vector2i]) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_distance := 999999
	for candidate in candidates:
		var distance: int = abs(candidate.x - source.x) + abs(candidate.y - source.y)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

func _carve_l_path(a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> void:
	if rng.randi_range(0, 1) == 0:
		_current_step_x_then_y(a, b)
	else:
		_current_step_y_then_x(a, b)

func _carve_grid_roads() -> void:
	for row in range(rows):
		for column in range(columns):
			var coord := Vector2i(column, row)
			if column + 1 < columns:
				_link_coords(coord, Vector2i(column + 1, row))
			if row + 1 < rows:
				_link_coords(coord, Vector2i(column, row + 1))

func _current_step_x_then_y(current: Vector2i, target: Vector2i) -> void:
	while current.x != target.x:
		var next := Vector2i(current.x + signi(target.x - current.x), current.y)
		_link_coords(current, next)
		current = next
	while current.y != target.y:
		var next := Vector2i(current.x, current.y + signi(target.y - current.y))
		_link_coords(current, next)
		current = next

func _current_step_y_then_x(current: Vector2i, target: Vector2i) -> void:
	while current.y != target.y:
		var next := Vector2i(current.x, current.y + signi(target.y - current.y))
		_link_coords(current, next)
		current = next
	while current.x != target.x:
		var next := Vector2i(current.x + signi(target.x - current.x), current.y)
		_link_coords(current, next)
		current = next

func _link_coords(a: Vector2i, b: Vector2i) -> void:
	var a_index := index_from_coord(a)
	var b_index := index_from_coord(b)
	if a_index < 0 or b_index < 0:
		return
	var direction := _direction_between(a, b)
	var reverse := _opposite_direction(direction)
	cells[a_index]["connections"][direction] = b_index
	cells[b_index]["connections"][reverse] = a_index
	if cells[a_index]["kind"] == "empty":
		cells[a_index]["kind"] = "road"
	if cells[b_index]["kind"] == "empty":
		cells[b_index]["kind"] = "road"

func _direction_between(a: Vector2i, b: Vector2i) -> String:
	if b.x > a.x:
		return "right"
	if b.x < a.x:
		return "left"
	if b.y > a.y:
		return "down"
	return "up"

func _opposite_direction(direction: String) -> String:
	match direction:
		"up":
			return "down"
		"down":
			return "up"
		"left":
			return "right"
		"right":
			return "left"
		_:
			return ""

func _pick_building_type(rng: RandomNumberGenerator) -> String:
	var options := ["warehouse", "elevator", "garage", "archive", "warehouse", "market"]
	return options[rng.randi_range(0, options.size() - 1)]

func _generate_resource_spawns(rng: RandomNumberGenerator, amount: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for _i in range(amount):
		result.append(Vector2(rng.randf_range(36.0, float(cell_size.x) - 36.0), rng.randf_range(36.0, float(cell_size.y) - 36.0)))
	return result

func _finalize_cell_kinds() -> void:
	for index in range(cells.size()):
		if cells[index]["kind"] == "district" or cells[index]["kind"] == "hub":
			continue
		var connection_count := 0
		for direction in DIRECTIONS.keys():
			if int(cells[index]["connections"][direction]) >= 0:
				connection_count += 1
		if connection_count >= 3:
			cells[index]["kind"] = "junction"
		elif connection_count >= 1:
			cells[index]["kind"] = "road"

func _mark_start_node() -> void:
	if district_indices.is_empty():
		return
	var first_district := district_indices[0]
	var connected := get_connected_indices(first_district)
	if connected.is_empty():
		start_node_index = first_district
		return
	# 优先从连接数最多的邻格出发，便于开局即进入路口选择
	var best_index := connected[0]
	var best_degree := -1
	for neighbor in connected:
		var degree := connected_count(neighbor)
		if degree > best_degree:
			best_degree = degree
			best_index = neighbor
	start_node_index = best_index

func _ensure_elevator_district() -> void:
	if district_indices.is_empty():
		return
	for district_index in district_indices:
		if bool(cells[district_index]["has_elevator"]):
			return
	var fallback_index := district_indices[0]
	cells[fallback_index]["building_type"] = "elevator"
	cells[fallback_index]["has_elevator"] = true


func to_dictionary() -> Dictionary:
	var serialized_cells: Array = []
	for cell in cells:
		serialized_cells.append(_serialize_cell(cell))
	return {
		"columns": columns,
		"rows": rows,
		"cell_size": {"x": cell_size.x, "y": cell_size.y},
		"cells": serialized_cells,
		"district_indices": district_indices.duplicate(),
		"hub_indices": hub_indices.duplicate(),
		"start_node_index": start_node_index,
	}


func load_from_dictionary(data: Dictionary) -> void:
	columns = int(data.get("columns", 0))
	rows = int(data.get("rows", 0))
	var size_dict: Dictionary = data.get("cell_size", {})
	cell_size = Vector2i(int(size_dict.get("x", 240)), int(size_dict.get("y", 240)))
	cells.clear()
	district_indices.clear()
	hub_indices.clear()
	for raw_cell in data.get("cells", []):
		if raw_cell is Dictionary:
			cells.append(_deserialize_cell(raw_cell))
	for raw_index in data.get("district_indices", []):
		district_indices.append(int(raw_index))
	for raw_index in data.get("hub_indices", []):
		hub_indices.append(int(raw_index))
	start_node_index = int(data.get("start_node_index", -1))


func _serialize_cell(cell: Dictionary) -> Dictionary:
	var coord: Vector2i = cell.get("coord", Vector2i.ZERO)
	var spawns: Array = []
	for spawn in cell.get("resource_spawns", []):
		if spawn is Vector2:
			spawns.append({"x": spawn.x, "y": spawn.y})
	var connections: Dictionary = {}
	for direction in cell.get("connections", {}).keys():
		connections[direction] = int(cell["connections"][direction])
	return {
		"coord": {"x": coord.x, "y": coord.y},
		"kind": str(cell.get("kind", "empty")),
		"explored": bool(cell.get("explored", false)),
		"building_type": str(cell.get("building_type", "")),
		"has_elevator": bool(cell.get("has_elevator", false)),
		"resource_total": int(cell.get("resource_total", 0)),
		"resource_remaining": int(cell.get("resource_remaining", 0)),
		"resource_spawns": spawns,
		"connections": connections,
		"seed": int(cell.get("seed", 0)),
	}


func _deserialize_cell(data: Dictionary) -> Dictionary:
	var coord_dict: Dictionary = data.get("coord", {})
	var coord := Vector2i(int(coord_dict.get("x", 0)), int(coord_dict.get("y", 0)))
	var spawns: Array[Vector2] = []
	for spawn_data in data.get("resource_spawns", []):
		if spawn_data is Dictionary:
			spawns.append(Vector2(float(spawn_data.get("x", 0.0)), float(spawn_data.get("y", 0.0))))
	var connections := {
		"up": -1,
		"down": -1,
		"left": -1,
		"right": -1,
	}
	for direction in data.get("connections", {}).keys():
		connections[direction] = int(data["connections"][direction])
	return {
		"coord": coord,
		"kind": str(data.get("kind", "empty")),
		"explored": bool(data.get("explored", false)),
		"building_type": str(data.get("building_type", "")),
		"has_elevator": bool(data.get("has_elevator", false)),
		"resource_total": int(data.get("resource_total", 0)),
		"resource_remaining": int(data.get("resource_remaining", 0)),
		"resource_spawns": spawns,
		"connections": connections,
		"seed": int(data.get("seed", 0)),
	}
