class_name WorldMapData
extends RefCounted

const FOOT_TILE_SIZE := 28
const INTERIOR_COLS := 14
const INTERIOR_ROWS := 10
## 各资源区固定障碍格（网格坐标，通常为正中格）
const FOOT_ANCHOR_OBSTACLE := Vector2i(6, 4)
const FOOT_ELEVATOR_CONSOLE_TILE := FOOT_ANCHOR_OBSTACLE
const FOOT_DOOR_TILE := Vector2i(6, 9)

const DIRECTIONS := {
	"up": Vector2i(0, -1),
	"down": Vector2i(0, 1),
	"left": Vector2i(-1, 0),
	"right": Vector2i(1, 0),
}

const TERRAIN_PROP_TYPES := [
	"grass_clump",
	"rock_small",
	"rock_large",
	"dead_tree",
	"rubble_pile",
]
const ROAD_BLOCKAGE_TYPES := ["crater", "wreck_tank", "wreck_truck", "rubble_barricade"]
## 预览干净焦土地表时关闭路边杂物与路障装饰
const OVERWORLD_DECOR_ENABLED := false

var columns: int = 0
var rows: int = 0
var cell_size: Vector2i = Vector2i(240, 240)
var cells: Array[Dictionary] = []
var district_indices: Array[int] = []
var hub_indices: Array[int] = []
var start_node_index: int = -1

func generate(
	new_columns: int,
	new_rows: int,
	new_cell_size: Vector2i,
	rng_seed: int = 0,
	is_final_layer: bool = false,
	debug_near_spawn: bool = false,
) -> void:
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

	var district_coords: Array[Vector2i] = _pick_district_coords(
		rng, max(8, min(16, (columns + rows) / 3)), hub_coords
	)
	for coord in district_coords:
		var index := index_from_coord(coord)
		if index in hub_indices:
			continue
		cells[index]["kind"] = "district"
		cells[index]["building_type"] = _pick_building_type(rng, is_final_layer)
		cells[index]["has_elevator"] = not is_final_layer and cells[index]["building_type"] == "elevator"
		cells[index]["has_kunlun_control"] = is_final_layer and cells[index]["building_type"] == "kunlun_control"
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

	if is_final_layer:
		_ensure_kunlun_control_district()
	else:
		_ensure_elevator_district()

	if district_indices.is_empty():
		return
	# 路在格与格之间的边沿：所有非建筑格（空地/hub）四向连通，建筑格本身不可通行
	_link_traversable_grid()
	_finalize_cell_kinds()
	_setup_district_roadside(rng)
	_finalize_cell_kinds()
	_mark_start_node()
	if debug_near_spawn:
		_place_special_building_near_start(is_final_layer)
	_place_terrain_scatter(rng)
	_place_road_blockages(rng)

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
	for district_index in district_indices:
		if int(cells[district_index].get("approach_road_index", -1)) == road_index:
			result.append(district_index)
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


func is_direction_blocked(index: int, direction: String) -> bool:
	if not OVERWORLD_DECOR_ENABLED:
		return false
	if not is_valid_index(index):
		return true
	var blocks: Dictionary = cells[index].get("road_blockages", {})
	return blocks.has(direction)


func is_node_enterable(index: int) -> bool:
	return is_drive_node(index)


func is_direction_passable(from_index: int, direction: String) -> bool:
	return not is_direction_blocked(from_index, direction)


func get_passable_directions(index: int) -> Array[String]:
	var result: Array[String] = []
	for direction in get_available_directions(index):
		if is_direction_passable(index, direction):
			result.append(direction)
	return result


func get_passable_indices(index: int) -> Array[int]:
	var result: Array[int] = []
	for direction in get_passable_directions(index):
		var other := get_neighbor_index(index, direction)
		if other >= 0:
			result.append(other)
	return result


func should_draw_blockage_overlay(index: int) -> bool:
	if not OVERWORLD_DECOR_ENABLED:
		return false
	if not is_valid_index(index):
		return false
	var blockages: Dictionary = get_road_blockages(index)
	if blockages.is_empty():
		return false
	var road_dirs := get_road_directions(index)
	if road_dirs.size() >= 3:
		return true
	for direction in blockages.keys():
		var other := get_neighbor_index(index, str(direction))
		if other >= 0 and is_junction(other):
			return false
		if other >= 0 and other > index:
			return true
	return false


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
		"kunlun_control":
			return "昆仑控制中心"
		"garage":
			return "车库"
		"barracks":
			var story_id := str(cells[index].get("story_id", ""))
			if story_id != "" and StoryData.has_story(story_id):
				var custom := str(StoryData.get_story(story_id).get("building_label", ""))
				if custom != "":
					return custom
			return "荒废军营"
		"archive":
			var archive_story := str(cells[index].get("story_id", ""))
			if archive_story != "" and StoryData.has_story(archive_story):
				var archive_label := str(StoryData.get_story(archive_story).get("building_label", ""))
				if archive_label != "":
					return archive_label
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

func district_has_kunlun_control(index: int) -> bool:
	if not is_valid_index(index):
		return false
	return bool(cells[index].get("has_kunlun_control", false))

func sector_has_elevator(index: int) -> bool:
	return district_has_elevator(index)

func _create_empty_cell(coord: Vector2i) -> Dictionary:
	return {
		"coord": coord,
		"kind": "empty",
		"explored": false,
		"building_type": "",
		"has_elevator": false,
		"has_kunlun_control": false,
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
		"special_encounter": "",
		"terrain_props": [],
		"road_blockages": {},
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


func _pick_district_coords(
	rng: RandomNumberGenerator,
	count: int,
	hub_coords: Array[Vector2i],
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var attempts := 0
	var max_attempts := maxi(count * 80, 320)
	while result.size() < count and attempts < max_attempts:
		attempts += 1
		var coord := Vector2i(rng.randi_range(0, columns - 1), rng.randi_range(0, rows - 1))
		if _can_place_district_at(coord, result, hub_coords):
			result.append(coord)
	return result


func _can_place_district_at(
	coord: Vector2i,
	placed: Array[Vector2i],
	hub_coords: Array[Vector2i],
) -> bool:
	if coord in placed:
		return false
	for existing in placed:
		if abs(existing.x - coord.x) + abs(existing.y - coord.y) < 2:
			return false
	for hub in hub_coords:
		if hub == coord:
			return false
		if abs(hub.x - coord.x) + abs(hub.y - coord.y) < 2:
			return false
	for delta: Vector2i in DIRECTIONS.values():
		var neighbor := coord + delta
		if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= columns or neighbor.y >= rows:
			continue
		if neighbor in placed:
			return false
		if neighbor in hub_coords:
			return false
	return true

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
	_link_traversable_grid()


## 空地与 hub 格之间四向连边（路在格边沿）；建筑格不参与，形成绕建筑通行的网格。
func _link_traversable_grid() -> void:
	for row in range(rows):
		for column in range(columns):
			var coord := Vector2i(column, row)
			var index := index_from_coord(coord)
			if is_district(index):
				continue
			if column + 1 < columns:
				var right_coord := Vector2i(column + 1, row)
				var right_index := index_from_coord(right_coord)
				if not is_district(right_index):
					_link_coords(coord, right_coord)
			if row + 1 < rows:
				var down_coord := Vector2i(column, row + 1)
				var down_index := index_from_coord(down_coord)
				if not is_district(down_index):
					_link_coords(coord, down_coord)

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

func _pick_building_type(rng: RandomNumberGenerator, is_final_layer: bool = false) -> String:
	var options: Array[String]
	if is_final_layer:
		options = ["warehouse", "garage", "archive", "warehouse", "market"]
	else:
		options = ["warehouse", "elevator", "garage", "archive", "warehouse", "market"]
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


func get_foot_console_tile(_index: int) -> Vector2i:
	return FOOT_ELEVATOR_CONSOLE_TILE


func get_foot_console_world_pos(index: int) -> Vector2:
	if not is_valid_index(index):
		return Vector2.ZERO
	var foot_origin := get_foot_origin(index)
	var console_tile := get_foot_console_tile(index)
	return foot_origin + Vector2(
		float(console_tile.x) * FOOT_TILE_SIZE + FOOT_TILE_SIZE * 0.5,
		float(console_tile.y) * FOOT_TILE_SIZE + FOOT_TILE_SIZE * 0.5,
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
		for neighbor in get_connected_indices(district_index).duplicate():
			if is_district(neighbor):
				_disconnect_cells(district_index, neighbor)
		for direction in DIRECTIONS.keys():
			var linked := int(cells[district_index]["connections"][direction])
			if linked >= 0:
				_disconnect_cells(district_index, linked)
		var door_candidates: Array[int] = _district_door_candidates(district_index)
		if door_candidates.is_empty():
			continue
		var approach_index: int = _pick_district_door(door_candidates, rng)
		var door_dir := direction_between(district_index, approach_index)
		if door_dir == "":
			continue
		cells[district_index]["connections"][door_dir] = approach_index
		cells[approach_index]["connections"][opposite_direction(door_dir)] = district_index
		cells[district_index]["approach_road_index"] = approach_index
		cells[district_index]["entry_from_road"] = direction_between(approach_index, district_index)


func _district_door_candidates(district_index: int) -> Array[int]:
	var result: Array[int] = []
	if not is_valid_index(district_index) or not is_district(district_index):
		return result
	var coord := coord_from_index(district_index)
	for dir_key in DIRECTIONS.keys():
		var delta: Vector2i = DIRECTIONS[dir_key]
		var neighbor_coord := coord + delta
		if neighbor_coord.x < 0 or neighbor_coord.y < 0 or neighbor_coord.x >= columns or neighbor_coord.y >= rows:
			continue
		var neighbor_index := index_from_coord(neighbor_coord)
		if is_valid_index(neighbor_index) and is_drive_node(neighbor_index):
			result.append(neighbor_index)
	return result


func _pick_district_door(candidates: Array[int], rng: RandomNumberGenerator) -> int:
	var best: Array[int] = []
	var best_count := -1
	for index in candidates:
		var road_count := 0
		for neighbor in get_connected_indices(index):
			if is_road_link(index, neighbor):
				road_count += 1
		if road_count > best_count:
			best_count = road_count
			best = [index]
		elif road_count == best_count:
			best.append(index)
	return best[rng.randi_range(0, best.size() - 1)]


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
	if is_valid_index(approach) and is_drive_node(approach) and is_node_enterable(approach):
		start_node_index = approach
		return
	for index in range(cells.size()):
		if is_drive_node(index) and connected_count(index) > 0 and is_node_enterable(index):
			start_node_index = index
			return
	start_node_index = first_district


func find_nearest_enterable_drive_node(from_index: int) -> int:
	if not is_valid_index(from_index):
		return -1
	if is_node_enterable(from_index):
		return from_index
	var visited: Dictionary = {from_index: true}
	var queue: Array[int] = [from_index]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for neighbor in get_connected_indices(current):
			if visited.has(neighbor) or not is_drive_node(neighbor):
				continue
			visited[neighbor] = true
			if is_node_enterable(neighbor):
				return neighbor
			queue.append(neighbor)
	return from_index


func get_terrain_props(index: int) -> Array:
	if not OVERWORLD_DECOR_ENABLED:
		return []
	if not is_valid_index(index):
		return []
	var raw: Array = cells[index].get("terrain_props", [])
	return raw if raw is Array else []


func get_road_blockages(index: int) -> Dictionary:
	if not OVERWORLD_DECOR_ENABLED:
		return {}
	if not is_valid_index(index):
		return {}
	var raw: Variant = cells[index].get("road_blockages", {})
	return raw if raw is Dictionary else {}


func _place_terrain_scatter(rng: RandomNumberGenerator) -> void:
	if not OVERWORLD_DECOR_ENABLED:
		for index in range(cells.size()):
			cells[index]["terrain_props"] = []
		return
	for index in range(cells.size()):
		if is_district(index):
			cells[index]["terrain_props"] = []
			continue
		var kind := get_kind(index)
		if kind != "road" and kind != "junction" and kind != "hub" and kind != "empty":
			continue
		cells[index]["terrain_props"] = _generate_cell_terrain_props(rng, index, kind)


func _terrain_prop_position(
	local_rng: RandomNumberGenerator,
	kind: String,
	center_x: float = -1.0,
	center_y: float = -1.0,
	spread: float = 0.0,
) -> Vector2:
	var nx := center_x
	var ny := center_y
	if nx < 0.0:
		nx = local_rng.randf_range(0.1, 0.9)
	if ny < 0.0:
		ny = local_rng.randf_range(0.1, 0.9)
	if spread > 0.0:
		nx = clampf(nx + local_rng.randf_range(-spread, spread), 0.06, 0.94)
		ny = clampf(ny + local_rng.randf_range(-spread, spread), 0.06, 0.94)
	if kind == "road" or kind == "junction" or kind == "hub":
		var dist := Vector2(nx - 0.5, ny - 0.5).length()
		var attempts := 0
		while dist < 0.34 and attempts < 14:
			nx = local_rng.randf_range(0.08, 0.92)
			ny = local_rng.randf_range(0.08, 0.92)
			dist = Vector2(nx - 0.5, ny - 0.5).length()
			attempts += 1
	return Vector2(nx, ny)


func _append_terrain_prop(
	result: Array,
	prop_type: String,
	pos: Vector2,
	local_rng: RandomNumberGenerator,
	scale_min: float,
	scale_max: float,
) -> void:
	result.append({
		"type": prop_type,
		"nx": pos.x,
		"ny": pos.y,
		"rot": local_rng.randf_range(-PI, PI),
		"scale": local_rng.randf_range(scale_min, scale_max),
	})


func _generate_cell_terrain_props(_rng: RandomNumberGenerator, index: int, kind: String) -> Array:
	var result: Array = []
	var base_seed := int(cells[index].get("seed", index + 1))
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = hash(base_seed * 7919 + index * 104729)

	if local_rng.randf() < 0.22:
		var big_roll := local_rng.randf()
		var big_type := "dead_tree"
		if big_roll > 0.58:
			big_type = "rock_large"
		elif big_roll > 0.36:
			big_type = "rubble_pile"
		var big_pos := _terrain_prop_position(local_rng, kind)
		_append_terrain_prop(result, big_type, big_pos, local_rng, 0.92, 1.12)

	var patch_count := local_rng.randi_range(2, 4) if kind != "junction" else local_rng.randi_range(1, 3)
	for _patch in range(patch_count):
		var patch_center := _terrain_prop_position(local_rng, kind)
		var clump_count := local_rng.randi_range(4, 7)
		var spread := local_rng.randf_range(0.04, 0.075)
		for _clump in range(clump_count):
			var clump_pos := _terrain_prop_position(
				local_rng, kind, patch_center.x, patch_center.y, spread
			)
			_append_terrain_prop(result, "grass_clump", clump_pos, local_rng, 0.88, 1.15)

	var small_rocks := local_rng.randi_range(0, 2)
	for _rock in range(small_rocks):
		var rock_pos := _terrain_prop_position(local_rng, kind)
		_append_terrain_prop(result, "rock_small", rock_pos, local_rng, 0.85, 1.1)

	return result


func _place_road_blockages(rng: RandomNumberGenerator) -> void:
	if not OVERWORLD_DECOR_ENABLED:
		for index in range(cells.size()):
			cells[index]["road_blockages"] = {}
		return
	var target := rng.randi_range(2, mini(5, maxi(2, (columns + rows) / 3)))
	var candidates := _collect_blockable_road_edges(rng)
	var placed := 0
	for edge in candidates:
		if placed >= target:
			break
		var from_index: int = int(edge.get("from", -1))
		var to_index: int = int(edge.get("to", -1))
		if not is_valid_index(from_index) or not is_valid_index(to_index):
			continue
		if not _try_add_road_blockage(rng, from_index, to_index):
			continue
		placed += 1


func _collect_blockable_road_edges(rng: RandomNumberGenerator) -> Array:
	var edges: Array = []
	for index in range(cells.size()):
		if not is_drive_node(index):
			continue
		for direction in get_available_directions(index):
			if is_direction_blocked(index, direction):
				continue
			var other := get_neighbor_index(index, direction)
			if other < 0 or other <= index:
				continue
			if not is_road_link(index, other):
				continue
			if _is_district_approach_edge(index, other):
				continue
			var priority := 0
			if is_junction(index) or is_junction(other):
				priority += 2
			if connected_count(index) >= 3 or connected_count(other) >= 3:
				priority += 1
			edges.append({
				"from": index,
				"to": other,
				"priority": priority,
			})
	edges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("priority", 0)) != int(b.get("priority", 0)):
			return int(a.get("priority", 0)) > int(b.get("priority", 0))
		return rng.randf() < 0.5
	)
	return edges


func _is_district_approach_edge(a: int, b: int) -> bool:
	for district_index in district_indices:
		var approach := int(cells[district_index].get("approach_road_index", -1))
		if approach == a or approach == b:
			return true
	return false


func _try_add_road_blockage(rng: RandomNumberGenerator, from_index: int, to_index: int) -> bool:
	var from_dir := direction_between(from_index, to_index)
	var to_dir := direction_between(to_index, from_index)
	if from_dir == "" or to_dir == "":
		return false
	if is_direction_blocked(from_index, from_dir):
		return false
	var blockage_type: String = str(ROAD_BLOCKAGE_TYPES[rng.randi_range(0, ROAD_BLOCKAGE_TYPES.size() - 1)])
	_set_direction_blockage(from_index, from_dir, blockage_type)
	_set_direction_blockage(to_index, to_dir, blockage_type)
	if not _passable_graph_fully_connected():
		_clear_direction_blockage(from_index, from_dir)
		_clear_direction_blockage(to_index, to_dir)
		return false
	return true


func _set_direction_blockage(index: int, direction: String, blockage_type: String) -> void:
	var blocks: Dictionary = cells[index].get("road_blockages", {})
	blocks[direction] = blockage_type
	cells[index]["road_blockages"] = blocks


func _clear_direction_blockage(index: int, direction: String) -> void:
	var blocks: Dictionary = cells[index].get("road_blockages", {})
	blocks.erase(direction)
	cells[index]["road_blockages"] = blocks


func _passable_graph_fully_connected() -> bool:
	if not is_valid_index(start_node_index) or not is_drive_node(start_node_index):
		return false
	var visited: Dictionary = {}
	var queue: Array[int] = [start_node_index]
	visited[start_node_index] = true
	var seen := 1
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for neighbor in get_passable_indices(current):
			if not is_drive_node(neighbor) or visited.has(neighbor):
				continue
			visited[neighbor] = true
			seen += 1
			queue.append(neighbor)
	var total := 0
	for index in range(cells.size()):
		if is_drive_node(index):
			total += 1
	return seen >= total


func _ensure_elevator_district() -> void:
	_ensure_special_building_district(false)


func _ensure_kunlun_control_district() -> void:
	_ensure_special_building_district(true)


func _ensure_special_building_district(is_final_layer: bool) -> void:
	if district_indices.is_empty():
		return
	var target_index := -1
	for district_index in district_indices:
		if is_final_layer and bool(cells[district_index].get("has_kunlun_control", false)):
			target_index = district_index
			break
		if not is_final_layer and bool(cells[district_index]["has_elevator"]):
			target_index = district_index
			break
	if target_index < 0:
		target_index = district_indices[0]
	_assign_special_building(target_index, is_final_layer)


func _assign_special_building(district_index: int, is_final_layer: bool) -> void:
	if not is_valid_index(district_index) or not is_district(district_index):
		return
	for index in district_indices:
		if index == district_index:
			continue
		_clear_special_building_from(index)
	if is_final_layer:
		cells[district_index]["building_type"] = "kunlun_control"
		cells[district_index]["has_kunlun_control"] = true
		cells[district_index]["has_elevator"] = false
	else:
		cells[district_index]["building_type"] = "elevator"
		cells[district_index]["has_elevator"] = true
		cells[district_index]["has_kunlun_control"] = false


func _clear_special_building_from(district_index: int) -> void:
	if not is_valid_index(district_index):
		return
	var building_type := str(cells[district_index].get("building_type", ""))
	if building_type == "elevator":
		cells[district_index]["building_type"] = "warehouse"
	elif building_type == "kunlun_control":
		cells[district_index]["building_type"] = "archive"
	cells[district_index]["has_elevator"] = false
	cells[district_index]["has_kunlun_control"] = false


func relocate_special_building_from(district_index: int) -> void:
	if not is_valid_index(district_index) or not is_district(district_index):
		return
	var is_final_layer := bool(cells[district_index].get("has_kunlun_control", false))
	var had_special := (
		bool(cells[district_index].get("has_elevator", false))
		or is_final_layer
	)
	if not had_special:
		return
	_clear_special_building_from(district_index)
	for index in district_indices:
		if index == district_index:
			continue
		if str(cells[index].get("story_id", "")) != "":
			continue
		if str(cells[index].get("special_encounter", "")) != "":
			continue
		_assign_special_building(index, is_final_layer)
		return


func _place_special_building_near_start(is_final_layer: bool) -> void:
	if district_indices.is_empty():
		return
	var anchor_index := start_node_index
	if not is_valid_index(anchor_index):
		anchor_index = district_indices[0]
	var anchor_coord := coord_from_index(anchor_index)
	var best_index := -1
	var best_distance := 1_000_000
	for district_index in district_indices:
		if str(cells[district_index].get("story_id", "")) != "":
			continue
		var district_coord := coord_from_index(district_index)
		var distance := absi(district_coord.x - anchor_coord.x) + absi(district_coord.y - anchor_coord.y)
		if distance < best_distance:
			best_distance = distance
			best_index = district_index
	if best_index < 0:
		best_index = district_indices[0]
	_assign_special_building(best_index, is_final_layer)
	_mark_start_at_special_building(is_final_layer)


func set_start_near_special_building(is_final_layer: bool) -> void:
	_mark_start_at_special_building(is_final_layer)


func _mark_start_at_special_building(is_final_layer: bool) -> void:
	for district_index in district_indices:
		var is_special := (
			bool(cells[district_index].get("has_kunlun_control", false))
			if is_final_layer
			else bool(cells[district_index].get("has_elevator", false))
		)
		if not is_special:
			continue
		var approach := int(cells[district_index].get("approach_road_index", -1))
		if is_valid_index(approach) and is_drive_node(approach) and is_node_enterable(approach):
			start_node_index = approach
			return


func ensure_story_districts_from_data() -> void:
	StoryData.ensure_story_districts(self)


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
	_link_traversable_grid()
	_finalize_cell_kinds()
	_setup_district_roadside(rng)
	_finalize_cell_kinds()
	if not is_valid_index(start_node_index) or not is_drive_node(start_node_index):
		_mark_start_node()
	_sanitize_district_terrain_props()
	if not _has_terrain_scatter():
		_place_terrain_scatter(rng)
	if _count_road_blockages() <= 0:
		_place_road_blockages(rng)


func _sanitize_district_terrain_props() -> void:
	for index in district_indices:
		if is_valid_index(index):
			cells[index]["terrain_props"] = []


func _has_terrain_scatter() -> bool:
	for cell in cells:
		var props: Array = cell.get("terrain_props", [])
		if props is Array and not props.is_empty():
			return true
	return false


func _count_road_blockages() -> int:
	var total := 0
	for cell in cells:
		var blocks: Dictionary = cell.get("road_blockages", {})
		total += blocks.size()
	return total


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
		"has_kunlun_control": bool(cell.get("has_kunlun_control", false)),
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
		"special_encounter": str(cell.get("special_encounter", "")),
		"story_id": str(cell.get("story_id", "")),
		"district_tag": str(cell.get("district_tag", "")),
		"terrain_props": _serialize_terrain_props(cell.get("terrain_props", [])),
		"road_blockages": _serialize_road_blockages(cell.get("road_blockages", {})),
	}


func _serialize_terrain_props(raw_list: Array) -> Array:
	var result: Array = []
	for raw in raw_list:
		if raw is Dictionary:
			result.append({
				"type": str(raw.get("type", "grass_clump")),
				"nx": float(raw.get("nx", 0.5)),
				"ny": float(raw.get("ny", 0.5)),
				"rot": float(raw.get("rot", 0.0)),
				"scale": float(raw.get("scale", 1.0)),
			})
	return result


func _serialize_road_blockages(raw: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for direction in raw.keys():
		result[str(direction)] = str(raw[direction])
	return result


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
	var building_type := str(data.get("building_type", ""))
	var has_kunlun := bool(data.get("has_kunlun_control", building_type == "kunlun_control"))
	return {
		"coord": coord,
		"kind": str(data.get("kind", "empty")),
		"explored": bool(data.get("explored", false)),
		"building_type": building_type,
		"has_elevator": bool(data.get("has_elevator", false)),
		"has_kunlun_control": has_kunlun,
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
		"special_encounter": str(data.get("special_encounter", "")),
		"story_id": str(data.get("story_id", "")),
		"district_tag": str(data.get("district_tag", "")),
		"terrain_props": _deserialize_terrain_props(data.get("terrain_props", [])),
		"road_blockages": _deserialize_road_blockages(data.get("road_blockages", {})),
	}


func _deserialize_terrain_props(raw_list: Array) -> Array:
	var result: Array = []
	for raw in raw_list:
		if raw is Dictionary:
			result.append({
				"type": str(raw.get("type", "grass_clump")),
				"nx": float(raw.get("nx", 0.5)),
				"ny": float(raw.get("ny", 0.5)),
				"rot": float(raw.get("rot", 0.0)),
				"scale": float(raw.get("scale", 1.0)),
			})
	return result


func _deserialize_road_blockages(raw: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if raw is Dictionary:
		for direction in raw.keys():
			result[str(direction)] = str(raw[direction])
	return result


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
