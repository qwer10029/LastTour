class_name WorldMapData
extends RefCounted

const FOOT_TILE_SIZE := 28
const INTERIOR_COLS := 14
const INTERIOR_ROWS := 10
## 各资源区固定障碍格（网格坐标，通常为正中格）
const FOOT_ANCHOR_OBSTACLE := Vector2i(6, 4)
const FOOT_DOOR_TILE := Vector2i(6, 9)

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
		var building_type := str(cells[index]["building_type"])
		cells[index]["seed"] = rng.randi()
		var foot_layout := _build_foot_layout(rng, cell_size)
		cells[index]["foot_grid_cols"] = foot_layout["cols"]
		cells[index]["foot_grid_rows"] = foot_layout["rows"]
		cells[index]["foot_blocked"] = foot_layout["blocked"]
		var foot_area := Vector2(
			float(int(foot_layout["cols"]) * FOOT_TILE_SIZE),
			float(int(foot_layout["rows"]) * FOOT_TILE_SIZE),
		)
		var foot_origin_offset := (Vector2(cell_size) - foot_area) * 0.5
		cells[index]["resource_total"] = rng.randi_range(2, 6)
		cells[index]["resource_remaining"] = cells[index]["resource_total"]
		cells[index]["resource_spawns"] = _generate_resource_spawns_on_walkable(
			rng, int(cells[index]["resource_total"]), building_type, foot_layout, foot_origin_offset
		)
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
	_setup_district_roadside(rng)
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


func is_drive_node(index: int) -> bool:
	return is_valid_index(index) and not is_district(index)


func get_roadside_districts(road_index: int) -> Array[int]:
	var result: Array[int] = []
	if not is_valid_index(road_index) or is_district(road_index):
		return result
	for neighbor in get_connected_indices(road_index):
		if is_district(neighbor):
			result.append(neighbor)
	return result


func get_building_entrance_world_pos(district_index: int) -> Vector2:
	if not is_valid_index(district_index) or not is_district(district_index):
		return Vector2.ZERO
	var approach := int(cells[district_index].get("approach_road_index", -1))
	if not is_valid_index(approach):
		return cell_center(district_index)
	var road_rect := cell_rect(approach)
	var road_center := cell_center(approach)
	var district_center := cell_center(district_index)
	var side := district_center - road_center
	if side.length_squared() < 0.001:
		return road_center
	var unit := minf(road_rect.size.x, road_rect.size.y)
	var side_dir := side.normalized()
	var facade_depth := unit * 0.14
	var edge := road_center + side_dir * (unit * 0.32)
	return edge + side_dir * (facade_depth * 0.42)


func get_roadside_parking_world_pos(road_index: int, district_index: int) -> Vector2:
	if not is_valid_index(road_index) or not is_district(district_index):
		return cell_center(road_index)
	var road_center := cell_center(road_index)
	var district_center := cell_center(district_index)
	var offset := district_center - road_center
	if offset.length_squared() < 0.001:
		return road_center
	var inset := minf(cell_rect(road_index).size.x, cell_rect(road_index).size.y) * 0.34
	return road_center + offset.normalized() * inset

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


## 仅统计通向其它路网格的方向（不含建筑 district），用于路口贴图与路段。
func get_road_directions(index: int) -> Array[String]:
	var result: Array[String] = []
	if not is_valid_index(index):
		return result
	for direction in get_available_directions(index):
		var other := get_neighbor_index(index, direction)
		if other < 0 or not is_road_link(index, other):
			continue
		result.append(direction)
	return result


func is_road_link(from_index: int, to_index: int) -> bool:
	if not is_valid_index(from_index) or not is_valid_index(to_index):
		return false
	if is_district(from_index) or is_district(to_index):
		return false
	if direction_between(from_index, to_index) == "":
		return false
	var from_kind := get_kind(from_index)
	var to_kind := get_kind(to_index)
	if not _is_road_surface_kind(from_kind) or not _is_road_surface_kind(to_kind):
		return false
	return true


func _is_road_surface_kind(kind: String) -> bool:
	return kind == "road" or kind == "junction" or kind == "hub"

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
		"foot_grid_cols": 0,
		"foot_grid_rows": 0,
		"foot_blocked": [],
		"connections": {
			"up": -1,
			"down": -1,
			"left": -1,
			"right": -1,
		},
		"seed": 0,
		"approach_road_index": -1,
		"entry_from_road": "",
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

func _build_foot_layout(rng: RandomNumberGenerator, _district_size: Vector2i) -> Dictionary:
	var cols := INTERIOR_COLS
	var rows := INTERIOR_ROWS
	var center := Vector2i(cols / 2, rows / 2)
	var blocked: Array[Vector2i] = []
	# 固定障碍：正中格 (2,2)，各区块一致
	if FOOT_ANCHOR_OBSTACLE.x < cols and FOOT_ANCHOR_OBSTACLE.y < rows:
		blocked.append(FOOT_ANCHOR_OBSTACLE)
	var spawn_tile := _pick_foot_spawn_tile(cols, rows, center, blocked)
	var target_blocked := maxi(int(float(cols * rows) * 0.14), 2)
	var attempts := 0
	while blocked.size() < target_blocked and attempts < 200:
		attempts += 1
		var tile := Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
		if maxi(absi(tile.x - center.x), absi(tile.y - center.y)) <= 1:
			continue
		if tile in blocked:
			continue
		blocked.append(tile)
	# 保证从出生点能走到所有可走格子（优先保留固定障碍）
	spawn_tile = _pick_foot_spawn_tile(cols, rows, center, blocked)
	while not _foot_tiles_connected(cols, rows, spawn_tile, blocked):
		var removed := false
		for i in range(blocked.size() - 1, -1, -1):
			if blocked[i] == FOOT_ANCHOR_OBSTACLE:
				continue
			blocked.remove_at(i)
			removed = true
			break
		if not removed:
			break
		spawn_tile = _pick_foot_spawn_tile(cols, rows, center, blocked)
	return {"cols": cols, "rows": rows, "blocked": blocked, "center": center, "spawn": spawn_tile}


func _pick_foot_spawn_tile(cols: int, rows: int, center: Vector2i, blocked: Array) -> Vector2i:
	var blocked_set: Dictionary = {}
	for raw in blocked:
		var tile := Vector2i.ZERO
		if raw is Vector2i:
			tile = raw
		elif raw is Dictionary:
			tile = Vector2i(int(raw.get("x", 0)), int(raw.get("y", 0)))
		blocked_set[tile] = true
	if not blocked_set.has(center):
		return center
	var candidates: Array[Vector2i] = [
		center + Vector2i(0, 1),
		center + Vector2i(0, -1),
		center + Vector2i(1, 0),
		center + Vector2i(-1, 0),
	]
	for tile in candidates:
		if tile.x >= 0 and tile.y >= 0 and tile.x < cols and tile.y < rows and not blocked_set.has(tile):
			return tile
	for y in range(rows):
		for x in range(cols):
			var fallback := Vector2i(x, y)
			if not blocked_set.has(fallback):
				return fallback
	return center


func _foot_tiles_connected(cols: int, rows: int, start: Vector2i, blocked: Array[Vector2i]) -> bool:
	var blocked_set: Dictionary = {}
	for tile in blocked:
		blocked_set[tile] = true
	var total_walkable := 0
	for x in range(cols):
		for y in range(rows):
			if not blocked_set.has(Vector2i(x, y)):
				total_walkable += 1
	if total_walkable <= 0:
		return false
	var queue: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var seen := 1
	var neighbors: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for offset in neighbors:
			var next: Vector2i = current + offset
			if next.x < 0 or next.y < 0 or next.x >= cols or next.y >= rows:
				continue
			if blocked_set.has(next) or visited.has(next):
				continue
			visited[next] = true
			seen += 1
			queue.append(next)
	return seen >= total_walkable


func _get_walkable_tiles(foot_layout: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var cols: int = int(foot_layout.get("cols", 0))
	var rows: int = int(foot_layout.get("rows", 0))
	var blocked_set: Dictionary = {}
	for raw in foot_layout.get("blocked", []):
		if raw is Vector2i:
			blocked_set[raw] = true
		elif raw is Dictionary:
			blocked_set[Vector2i(int(raw.get("x", 0)), int(raw.get("y", 0)))] = true
	for x in range(cols):
		for y in range(rows):
			var tile := Vector2i(x, y)
			if not blocked_set.has(tile):
				result.append(tile)
	return result


func _generate_resource_spawns_on_walkable(
	rng: RandomNumberGenerator,
	amount: int,
	building_type: String,
	foot_layout: Dictionary,
	foot_origin_offset: Vector2 = Vector2.ZERO,
) -> Array:
	var walkable := _get_walkable_tiles(foot_layout)
	if walkable.is_empty():
		return []
	var pool := walkable.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var result: Array = []
	var spawn_count := mini(amount, pool.size())
	for i in range(spawn_count):
		var tile: Vector2i = pool[i]
		var center := Vector2(
			float(tile.x) * FOOT_TILE_SIZE + FOOT_TILE_SIZE * 0.5,
			float(tile.y) * FOOT_TILE_SIZE + FOOT_TILE_SIZE * 0.5
		)
		result.append({
			"x": foot_origin_offset.x + center.x + rng.randf_range(-4.0, 4.0),
			"y": foot_origin_offset.y + center.y + rng.randf_range(-4.0, 4.0),
			"item_id": ItemDefs.pick_loot_for_building(building_type, rng),
		})
	return result


func get_foot_origin(index: int) -> Vector2:
	ensure_foot_layout(index)
	if not is_valid_index(index):
		return Vector2.ZERO
	var district_rect := cell_rect(index)
	var cell := cells[index]
	var cols: int = maxi(int(cell.get("foot_grid_cols", 1)), 1)
	var rows: int = maxi(int(cell.get("foot_grid_rows", 1)), 1)
	var area_size := Vector2(float(cols * FOOT_TILE_SIZE), float(rows * FOOT_TILE_SIZE))
	return district_rect.position + (district_rect.size - area_size) * 0.5


func get_foot_area_rect(index: int) -> Rect2:
	var origin := get_foot_origin(index)
	if origin == Vector2.ZERO and not is_valid_index(index):
		return Rect2()
	var cell := get_cell(index)
	var cols: int = maxi(int(cell.get("foot_grid_cols", 1)), 1)
	var rows: int = maxi(int(cell.get("foot_grid_rows", 1)), 1)
	return Rect2(origin, Vector2(float(cols * FOOT_TILE_SIZE), float(rows * FOOT_TILE_SIZE)))


func get_foot_play_rect(index: int, margin: float = 12.0) -> Rect2:
	var area := get_foot_area_rect(index)
	if area.size == Vector2.ZERO:
		return area
	var inset := Vector2(margin, margin) * 2.0
	return Rect2(area.position + Vector2(margin, margin), area.size - inset)


func is_foot_tile_blocked(cell: Dictionary, foot_origin: Vector2, world_pos: Vector2) -> bool:
	var local := world_pos - foot_origin
	var cols: int = maxi(int(cell.get("foot_grid_cols", 1)), 1)
	var rows: int = maxi(int(cell.get("foot_grid_rows", 1)), 1)
	var area := Vector2(cols * FOOT_TILE_SIZE, rows * FOOT_TILE_SIZE)
	if local.x < 0.0 or local.y < 0.0 or local.x >= area.x or local.y >= area.y:
		return true
	var tile := Vector2i(
		clampi(int(local.x / FOOT_TILE_SIZE), 0, cols - 1),
		clampi(int(local.y / FOOT_TILE_SIZE), 0, rows - 1),
	)
	for raw in cell.get("foot_blocked", []):
		var blocked_tile := Vector2i.ZERO
		if raw is Vector2i:
			blocked_tile = raw
		elif raw is Dictionary:
			blocked_tile = Vector2i(int(raw.get("x", 0)), int(raw.get("y", 0)))
		if blocked_tile == tile:
			return true
	return false


func ensure_foot_layout(index: int) -> void:
	if not is_valid_index(index) or not is_district(index):
		return
	var cell := cells[index]
	if cell.get("foot_blocked", []) is Array and not cell["foot_blocked"].is_empty():
		_ensure_anchor_obstacle(cell)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cell.get("seed", index + 1))
	var layout := _build_foot_layout(rng, cell_size)
	cell["foot_grid_cols"] = layout["cols"]
	cell["foot_grid_rows"] = layout["rows"]
	cell["foot_blocked"] = layout["blocked"]


func _ensure_anchor_obstacle(cell: Dictionary) -> void:
	var cols: int = maxi(int(cell.get("foot_grid_cols", 1)), 1)
	var rows: int = maxi(int(cell.get("foot_grid_rows", 1)), 1)
	var anchor := FOOT_ANCHOR_OBSTACLE
	if anchor.x >= cols or anchor.y >= rows:
		return
	var blocked: Array = cell.get("foot_blocked", [])
	var cleaned: Array = []
	var has_anchor := false
	for raw in blocked:
		var tile := Vector2i.ZERO
		if raw is Vector2i:
			tile = raw
		elif raw is Dictionary:
			tile = Vector2i(int(raw.get("x", 0)), int(raw.get("y", 0)))
		if tile == Vector2i(1, 2):
			continue
		cleaned.append(raw)
		if tile == anchor:
			has_anchor = true
	if not has_anchor:
		cleaned.append(anchor)
	cell["foot_blocked"] = cleaned


func get_walkable_world_positions(index: int) -> Array[Vector2]:
	ensure_foot_layout(index)
	if not is_valid_index(index):
		return []
	var cell := cells[index]
	var district_rect := cell_rect(index)
	var layout := {
		"cols": int(cell.get("foot_grid_cols", 0)),
		"rows": int(cell.get("foot_grid_rows", 0)),
		"blocked": cell.get("foot_blocked", []),
	}
	var positions: Array[Vector2] = []
	for tile in _get_walkable_tiles(layout):
		var foot_origin := get_foot_origin(index)
		positions.append(
			foot_origin
			+ Vector2(
				float(tile.x) * FOOT_TILE_SIZE + FOOT_TILE_SIZE * 0.5,
				float(tile.y) * FOOT_TILE_SIZE + FOOT_TILE_SIZE * 0.5,
			)
		)
	return positions


func get_foot_door_tile(index: int) -> Vector2i:
	ensure_foot_layout(index)
	if not is_valid_index(index):
		return Vector2i.ZERO
	var cell := cells[index]
	var cols: int = maxi(int(cell.get("foot_grid_cols", 1)), 1)
	var rows: int = maxi(int(cell.get("foot_grid_rows", 1)), 1)
	var blocked: Array = cell.get("foot_blocked", [])
	var door_tile := Vector2i(
		clampi(FOOT_DOOR_TILE.x, 0, cols - 1),
		clampi(FOOT_DOOR_TILE.y, 0, rows - 1),
	)
	if _tile_blocked(door_tile, blocked):
		door_tile = _pick_foot_spawn_tile(cols, rows, door_tile, blocked)
	for row in range(door_tile.y, maxi(door_tile.y - 3, -1), -1):
		var candidate := Vector2i(door_tile.x, row)
		if not _tile_blocked(candidate, blocked):
			door_tile = candidate
			break
	return door_tile


func get_foot_door_world_pos(index: int) -> Vector2:
	if not is_valid_index(index):
		return Vector2.ZERO
	var foot_origin := get_foot_origin(index)
	var door_tile := get_foot_door_tile(index)
	return foot_origin + Vector2(
		float(door_tile.x) * FOOT_TILE_SIZE + FOOT_TILE_SIZE * 0.5,
		float(door_tile.y) * FOOT_TILE_SIZE + FOOT_TILE_SIZE * 0.5,
	)


func _tile_blocked(tile: Vector2i, blocked: Array) -> bool:
	for raw in blocked:
		var blocked_tile := Vector2i.ZERO
		if raw is Vector2i:
			blocked_tile = raw
		elif raw is Dictionary:
			blocked_tile = Vector2i(int(raw.get("x", 0)), int(raw.get("y", 0)))
		if blocked_tile == tile:
			return true
	return false


func get_foot_spawn_world_pos(cell: Dictionary, district_rect: Rect2) -> Vector2:
	return get_foot_door_world_pos(index_from_position(district_rect.position + district_rect.size * 0.5))

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

func _setup_district_roadside(rng: RandomNumberGenerator) -> void:
	for district_index in district_indices:
		var road_neighbors: Array[int] = []
		for neighbor in get_connected_indices(district_index):
			if not is_district(neighbor):
				road_neighbors.append(neighbor)
		if road_neighbors.is_empty():
			continue
		var approach_index: int = road_neighbors[rng.randi_range(0, road_neighbors.size() - 1)]
		for neighbor in get_connected_indices(district_index).duplicate():
			if neighbor != approach_index:
				_disconnect_cells(district_index, neighbor)
		cells[district_index]["approach_road_index"] = approach_index
		cells[district_index]["entry_from_road"] = direction_between(approach_index, district_index)


func _disconnect_cells(from_index: int, to_index: int) -> void:
	var dir := direction_between(from_index, to_index)
	if dir == "":
		return
	var rev := opposite_direction(dir)
	cells[from_index]["connections"][dir] = -1
	cells[to_index]["connections"][rev] = -1


func _mark_start_node() -> void:
	if district_indices.is_empty():
		return
	var first_district: int = district_indices[0]
	var approach := int(cells[first_district].get("approach_road_index", -1))
	if is_valid_index(approach) and is_drive_node(approach):
		start_node_index = approach
		return
	for index in range(cells.size()):
		if is_drive_node(index) and connected_count(index) > 0:
			start_node_index = index
			return
	start_node_index = first_district

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
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(columns * 9176 + rows * 131)
	_setup_district_roadside(rng)
	if not is_valid_index(start_node_index) or not is_drive_node(start_node_index):
		_mark_start_node()


func _serialize_cell(cell: Dictionary) -> Dictionary:
	var coord: Vector2i = cell.get("coord", Vector2i.ZERO)
	var spawns: Array = []
	for spawn in cell.get("resource_spawns", []):
		if spawn is Vector2:
			spawns.append({"x": spawn.x, "y": spawn.y, "item_id": "scrap"})
		elif spawn is Dictionary:
			spawns.append({
				"x": float(spawn.get("x", 0.0)),
				"y": float(spawn.get("y", 0.0)),
				"item_id": str(spawn.get("item_id", "scrap")),
			})
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
		"foot_grid_cols": int(cell.get("foot_grid_cols", 0)),
		"foot_grid_rows": int(cell.get("foot_grid_rows", 0)),
		"foot_blocked": _serialize_foot_blocked(cell.get("foot_blocked", [])),
		"connections": connections,
		"seed": int(cell.get("seed", 0)),
		"approach_road_index": int(cell.get("approach_road_index", -1)),
		"entry_from_road": str(cell.get("entry_from_road", "")),
	}


func _deserialize_cell(data: Dictionary) -> Dictionary:
	var coord_dict: Dictionary = data.get("coord", {})
	var coord := Vector2i(int(coord_dict.get("x", 0)), int(coord_dict.get("y", 0)))
	var spawns: Array = []
	for spawn_data in data.get("resource_spawns", []):
		if spawn_data is Dictionary:
			spawns.append({
				"x": float(spawn_data.get("x", 0.0)),
				"y": float(spawn_data.get("y", 0.0)),
				"item_id": str(spawn_data.get("item_id", "scrap")),
			})
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
		"foot_grid_cols": int(data.get("foot_grid_cols", 0)),
		"foot_grid_rows": int(data.get("foot_grid_rows", 0)),
		"foot_blocked": _deserialize_foot_blocked(data.get("foot_blocked", [])),
		"connections": connections,
		"seed": int(data.get("seed", 0)),
		"approach_road_index": int(data.get("approach_road_index", -1)),
		"entry_from_road": str(data.get("entry_from_road", "")),
	}


func _serialize_foot_blocked(blocked: Array) -> Array:
	var result: Array = []
	for raw in blocked:
		if raw is Vector2i:
			result.append({"x": raw.x, "y": raw.y})
		elif raw is Dictionary:
			result.append({"x": int(raw.get("x", 0)), "y": int(raw.get("y", 0))})
	return result


func _deserialize_foot_blocked(raw_list: Array) -> Array:
	var result: Array = []
	for raw in raw_list:
		if raw is Dictionary:
			result.append(Vector2i(int(raw.get("x", 0)), int(raw.get("y", 0))))
	return result
