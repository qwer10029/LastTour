extends Node2D
class_name NightTdField

signal cell_clicked(cell: Vector2i)

@export var grid_cols: int = 14
@export var grid_rows: int = 10
@export var tile_size: int = 48
@export var field_origin: Vector2 = Vector2(120, 70)

var vehicle_cells: Array[Vector2i] = [Vector2i(6, 7), Vector2i(7, 7), Vector2i(6, 8), Vector2i(7, 8)]
var base_local_pos: Vector2 = Vector2.ZERO
var _controller: NightTdController


func _ready() -> void:
	_controller = get_parent() as NightTdController
	base_local_pos = _cell_to_local(Vector2i(6, 8))


func bind_controller(controller: NightTdController) -> void:
	_controller = controller


func _process(_delta: float) -> void:
	if get_parent() != null and get_parent().visible:
		queue_redraw()


func _cell_to_local(cell: Vector2i) -> Vector2:
	return field_origin + Vector2((cell.x + 0.5) * tile_size, (cell.y + 0.5) * tile_size)


func cell_to_world(cell: Vector2i) -> Vector2:
	return to_global(_cell_to_local(cell))


func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local := to_local(world_pos) - field_origin
	return Vector2i(
		clampi(int(local.x / tile_size), 0, grid_cols - 1),
		clampi(int(local.y / tile_size), 0, grid_rows - 1)
	)


func get_field_rect_local() -> Rect2:
	return Rect2(field_origin, Vector2(grid_cols * tile_size, grid_rows * tile_size))


func is_inside_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_cols and cell.y < grid_rows


func is_vehicle_cell(cell: Vector2i) -> bool:
	return cell in vehicle_cells


func is_spawn_lane(cell: Vector2i) -> bool:
	return cell.y <= 1


func can_place_tower(cell: Vector2i, occupied: Dictionary) -> bool:
	if not is_inside_grid(cell):
		return false
	if is_vehicle_cell(cell):
		return false
	if occupied.has(cell):
		return false
	return true


func _input(event: InputEvent) -> void:
	if _controller != null and _controller.phase != NightTdController.Phase.PLACE:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := world_to_cell(get_global_mouse_position())
		if is_inside_grid(cell):
			cell_clicked.emit(cell)


func _draw() -> void:
	var grid_color := Color("#0f1a28")
	var line_color := Color("#2a4560")
	var spawn_color := Color(0.55, 0.22, 0.22, 0.35)
	var field_rect := get_field_rect_local()
	draw_rect(field_rect, grid_color, true)
	draw_rect(field_rect, Color("#3d5a73"), false, 2.0)

	for x in range(grid_cols + 1):
		var px := field_origin.x + x * tile_size
		draw_line(Vector2(px, field_origin.y), Vector2(px, field_origin.y + grid_rows * tile_size), line_color, 1.0)
	for y in range(grid_rows + 1):
		var py := field_origin.y + y * tile_size
		draw_line(Vector2(field_origin.x, py), Vector2(field_origin.x + grid_cols * tile_size, py), line_color, 1.0)

	for x in range(grid_cols):
		for y in range(2):
			var r := Rect2(field_origin + Vector2(x * tile_size, y * tile_size), Vector2(tile_size, tile_size))
			draw_rect(r, spawn_color, true)
			draw_string(ThemeDB.fallback_font, r.position + Vector2(8, 20), "敌", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.5, 0.5, 0.6))

	for cell in vehicle_cells:
		var rect := Rect2(field_origin + Vector2(cell.x * tile_size, cell.y * tile_size), Vector2(tile_size, tile_size))
		draw_rect(rect, Color("#1a2533"), true)
		draw_rect(rect, Color("#d89246"), false, 2.0)

	var veh_center := _cell_to_local(Vector2i(7, 7))
	draw_rect(Rect2(veh_center.x - 30, veh_center.y - 20, 60, 36), Color("#d89246"), true)
	draw_rect(Rect2(veh_center.x - 34, veh_center.y + 10, 68, 16), Color("#6b3f17"), true)
	draw_string(ThemeDB.fallback_font, veh_center + Vector2(-18, -4), "车", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#fff3d6"))
	draw_circle(base_local_pos, 9.0, Color("#ff5f57"))
	draw_string(ThemeDB.fallback_font, base_local_pos + Vector2(-10, -28), "据点", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ff5f57"))

	if _controller != null:
		_draw_placed_towers()


func _draw_placed_towers() -> void:
	for tower in _controller._towers:
		if tower.get("removed", false):
			continue
		var cell: Vector2i = tower["cell"]
		var local_pos := _cell_to_local(cell)
		var tdef: Dictionary = NightTdDefs.get_tower_def(str(tower["type"]))
		var radius: float = float(tdef.get("radius", 12))
		draw_circle(local_pos, radius, tdef.get("color", Color.WHITE))
		if tower["type"] == "jammer":
			draw_arc(local_pos, float(tdef.get("range", 100)), 0.0, TAU, 48, Color(0.43, 0.82, 0.55, 0.22), 2.0)
		draw_rect(Rect2(local_pos.x - 14, local_pos.y - 22, 28, 4), Color("#6ed08b"), true)
