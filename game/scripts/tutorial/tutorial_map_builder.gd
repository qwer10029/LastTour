class_name TutorialMapBuilder
extends RefCounted

## 教学关卡迷你地图：十字路口起点 — 北仓库 — 东电梯枢纽。

const CELL_SIZE := Vector2i(720, 720)
const MAP_COLUMNS := 5
const MAP_ROWS := 3

const JUNCTION_COORD := Vector2i(2, 1)
const CAMP_HUB_COORD := Vector2i(0, 1)
const WAREHOUSE_COORD := Vector2i(2, 0)
const ELEVATOR_COORD := Vector2i(4, 1)

const WAREHOUSE_LOOT := [
	{"item_id": "scrap", "tile": Vector2i(2, 3)},
	{"item_id": "scrap", "tile": Vector2i(4, 3)},
	{"item_id": "scrap", "tile": Vector2i(8, 3)},
	{"item_id": "fuel", "tile": Vector2i(6, 5)},
]

const ELEVATOR_LOOT := [
	{"item_id": "parts", "tile": Vector2i(3, 3)},
	{"item_id": "parts", "tile": Vector2i(8, 4)},
]


static func build_tutorial_map() -> WorldMapData:
	var map := WorldMapData.new()
	map.columns = MAP_COLUMNS
	map.rows = MAP_ROWS
	map.cell_size = CELL_SIZE
	map.cells.clear()
	map.district_indices.clear()
	map.hub_indices.clear()
	map.start_node_index = -1

	for row in range(MAP_ROWS):
		for column in range(MAP_COLUMNS):
			map.cells.append(map._create_empty_cell(Vector2i(column, row)))

	_setup_start_hub(map, CAMP_HUB_COORD)
	_setup_warehouse(map, WAREHOUSE_COORD)
	_setup_elevator_hub(map, ELEVATOR_COORD)

	map._link_traversable_grid()
	map._finalize_cell_kinds()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	map._setup_district_roadside(rng)
	map._finalize_cell_kinds()

	var junction_index := map.index_from_coord(JUNCTION_COORD)
	if map.is_valid_index(junction_index) and map.is_drive_node(junction_index):
		map.start_node_index = junction_index
	else:
		map._mark_start_node()
	return map


static func warehouse_node_index(map: WorldMapData) -> int:
	return map.index_from_coord(WAREHOUSE_COORD)


static func elevator_node_index(map: WorldMapData) -> int:
	return map.index_from_coord(ELEVATOR_COORD)


static func junction_node_index(map: WorldMapData) -> int:
	return map.index_from_coord(JUNCTION_COORD)


static func _setup_start_hub(map: WorldMapData, coord: Vector2i) -> void:
	var index := map.index_from_coord(coord)
	if not map.is_valid_index(index):
		return
	var cell: Dictionary = map.cells[index]
	cell["kind"] = "hub"
	cell["building_type"] = "hub"
	cell["seed"] = 100
	map.hub_indices.append(index)


static func _setup_warehouse(map: WorldMapData, coord: Vector2i) -> void:
	var index := map.index_from_coord(coord)
	if not map.is_valid_index(index):
		return
	var cell: Dictionary = map.cells[index]
	cell["kind"] = "district"
	cell["building_type"] = "warehouse"
	cell["has_elevator"] = false
	cell["has_kunlun_control"] = false
	cell["seed"] = 201

	var rng := RandomNumberGenerator.new()
	rng.seed = 201
	var foot_layout: Dictionary = map._build_foot_layout(rng, map.cell_size)
	cell["foot_grid_cols"] = foot_layout["cols"]
	cell["foot_grid_rows"] = foot_layout["rows"]
	cell["foot_blocked"] = foot_layout["blocked"]

	var foot_area := Vector2(
		float(int(foot_layout["cols"]) * WorldMapData.FOOT_TILE_SIZE),
		float(int(foot_layout["rows"]) * WorldMapData.FOOT_TILE_SIZE),
	)
	var foot_origin_offset := (Vector2(map.cell_size) - foot_area) * 0.5
	cell["resource_total"] = WAREHOUSE_LOOT.size()
	cell["resource_remaining"] = WAREHOUSE_LOOT.size()
	cell["resource_spawns"] = _build_fixed_loot_spawns(WAREHOUSE_LOOT, foot_layout, foot_origin_offset)
	map.district_indices.append(index)


static func _setup_elevator_hub(map: WorldMapData, coord: Vector2i) -> void:
	var index := map.index_from_coord(coord)
	if not map.is_valid_index(index):
		return
	var cell: Dictionary = map.cells[index]
	cell["kind"] = "district"
	cell["building_type"] = "elevator"
	cell["has_elevator"] = true
	cell["has_kunlun_control"] = false
	cell["seed"] = 302

	var rng := RandomNumberGenerator.new()
	rng.seed = 302
	var foot_layout: Dictionary = map._build_foot_layout(rng, map.cell_size)
	cell["foot_grid_cols"] = foot_layout["cols"]
	cell["foot_grid_rows"] = foot_layout["rows"]
	cell["foot_blocked"] = foot_layout["blocked"]

	var foot_area := Vector2(
		float(int(foot_layout["cols"]) * WorldMapData.FOOT_TILE_SIZE),
		float(int(foot_layout["rows"]) * WorldMapData.FOOT_TILE_SIZE),
	)
	var foot_origin_offset := (Vector2(map.cell_size) - foot_area) * 0.5
	cell["resource_total"] = ELEVATOR_LOOT.size()
	cell["resource_remaining"] = ELEVATOR_LOOT.size()
	cell["resource_spawns"] = _build_fixed_loot_spawns(ELEVATOR_LOOT, foot_layout, foot_origin_offset)
	map.district_indices.append(index)


static func _build_fixed_loot_spawns(
	loot_table: Array,
	foot_layout: Dictionary,
	foot_origin_offset: Vector2,
) -> Array:
	var result: Array = []
	for entry in loot_table:
		var tile: Vector2i = entry["tile"]
		var center := Vector2(
			float(tile.x) * WorldMapData.FOOT_TILE_SIZE + WorldMapData.FOOT_TILE_SIZE * 0.5,
			float(tile.y) * WorldMapData.FOOT_TILE_SIZE + WorldMapData.FOOT_TILE_SIZE * 0.5,
		)
		result.append({
			"x": foot_origin_offset.x + center.x,
			"y": foot_origin_offset.y + center.y,
			"item_id": str(entry["item_id"]),
		})
	return result
