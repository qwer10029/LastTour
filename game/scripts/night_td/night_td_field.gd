extends Node2D
class_name NightTdField

signal cell_clicked(cell: Vector2i)
signal cell_right_clicked(cell: Vector2i)

@export var grid_cols: int = 14
@export var grid_rows: int = 10
@export var tile_size: int = 48
@export var field_origin: Vector2 = Vector2(120, 70)
@export var top_reserved_px: float = 112.0
@export var right_reserved_px: float = 176.0
@export var outer_margin_px: float = 24.0

var vehicle_cells: Array[Vector2i] = [Vector2i(6, 7), Vector2i(7, 7), Vector2i(6, 8), Vector2i(7, 8)]
var base_local_pos: Vector2 = Vector2.ZERO
var _layout_tile_size: float = 48.0
var _controller: NightTdController
var _last_view_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	_controller = get_parent() as NightTdController
	set_process_unhandled_input(true)
	z_index = 1
	_reflow_layout()
	base_local_pos = get_vehicle_center_local()


func bind_controller(controller: NightTdController) -> void:
	_controller = controller


func _process(_delta: float) -> void:
	var view_size := get_viewport_rect().size
	if view_size != _last_view_size:
		_reflow_layout()
	if get_parent() != null and get_parent().visible:
		queue_redraw()


func _reflow_layout() -> void:
	var view_size := get_viewport_rect().size
	if view_size == Vector2.ZERO:
		view_size = Vector2(1280.0, 720.0)
	_last_view_size = view_size
	var play_rect := _play_area_rect(view_size)
	var fitted_tile := floorf(minf(
		(play_rect.size.x - outer_margin_px * 2.0) / float(grid_cols),
		(play_rect.size.y - outer_margin_px * 2.0) / float(grid_rows)
	))
	_layout_tile_size = clampf(fitted_tile, 44.0, 56.0)
	var vehicle_offset := _vehicle_center_offset()
	var target_center := view_size * Vector2(0.5, 0.54)
	field_origin = target_center - vehicle_offset * _layout_tile_size


func _play_area_rect(view_size: Vector2) -> Rect2:
	var left := outer_margin_px * 2.0
	var top := top_reserved_px + outer_margin_px * 0.5
	var right := right_reserved_px + outer_margin_px * 0.5
	var bottom := outer_margin_px * 1.5
	return Rect2(
		Vector2(left, top),
		Vector2(maxf(view_size.x - left - right, 1.0), maxf(view_size.y - top - bottom, 1.0))
	)


func _vehicle_center_offset() -> Vector2:
	var offset := Vector2.ZERO
	for cell in vehicle_cells:
		offset += Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5)
	return offset / float(vehicle_cells.size())


func _cell_to_local(cell: Vector2i) -> Vector2:
	return field_origin + Vector2((cell.x + 0.5) * _layout_tile_size, (cell.y + 0.5) * _layout_tile_size)


func get_vehicle_center_local() -> Vector2:
	var center := Vector2.ZERO
	for cell in vehicle_cells:
		center += _cell_to_local(cell)
	return center / float(vehicle_cells.size())


func get_vehicle_center_world() -> Vector2:
	return to_global(get_vehicle_center_local())


func cell_to_world(cell: Vector2i) -> Vector2:
	return to_global(_cell_to_local(cell))


func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local := to_local(world_pos) - field_origin
	return Vector2i(
		clampi(int(local.x / _layout_tile_size), 0, grid_cols - 1),
		clampi(int(local.y / _layout_tile_size), 0, grid_rows - 1)
	)


func get_field_rect_local() -> Rect2:
	return Rect2(field_origin, Vector2(grid_cols * _layout_tile_size, grid_rows * _layout_tile_size))


func get_layout_tile_size() -> float:
	return _layout_tile_size


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


func _unhandled_input(event: InputEvent) -> void:
	if _controller == null or _controller.phase != NightTdController.Phase.PLACE:
		return
	if _is_pointer_over_ui():
		return
	if event is InputEventMouseButton and event.pressed:
		var cell := world_to_cell(get_global_mouse_position())
		if not is_inside_grid(cell):
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			cell_clicked.emit(cell)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cell_right_clicked.emit(cell)
			get_viewport().set_input_as_handled()


func _is_pointer_over_ui() -> bool:
	var control: Control = get_viewport().gui_get_hovered_control()
	while control != null:
		if control is BaseButton:
			return true
		if control.name in ["SidePanel", "TopBar", "ResultOverlay", "Hud", "ResultPanel", "ContinueBtn"]:
			return true
		control = control.get_parent() as Control
	return false


func _draw() -> void:
	var grid_color := Color("#05080c")
	var line_color := Color("#8ec7ff")
	var spawn_color := Color(0.95, 0.2, 0.2, 0.55)
	var buildable_color := Color(0.12, 0.45, 0.24, 0.18)
	var buildable_border := Color(0.55, 0.95, 0.66, 0.34)
	var field_rect := get_field_rect_local()
	draw_rect(field_rect, grid_color, true)
	draw_rect(field_rect, Color("#d7f1ff"), false, 4.0)
	draw_rect(field_rect.grow(-5.0), Color(0.0, 0.0, 0.0, 0.10), false, 1.0)
	draw_string(ThemeDB.fallback_font, field_origin + Vector2(8, -10), "布防区", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#eef8ff"))

	for x in range(grid_cols + 1):
		var px := field_origin.x + x * _layout_tile_size
		draw_line(Vector2(px, field_origin.y), Vector2(px, field_origin.y + grid_rows * _layout_tile_size), line_color, 1.5)
	for y in range(grid_rows + 1):
		var py := field_origin.y + y * _layout_tile_size
		draw_line(Vector2(field_origin.x, py), Vector2(field_origin.x + grid_cols * _layout_tile_size, py), line_color, 1.5)

	for x in range(grid_cols):
		for y in range(2):
			var r := Rect2(field_origin + Vector2(x * _layout_tile_size, y * _layout_tile_size), Vector2(_layout_tile_size, _layout_tile_size))
			draw_rect(r, spawn_color, true)
			draw_rect(r.grow(-4.0), Color(1.0, 0.9, 0.9, 0.35), false, 1.0)
			draw_string(ThemeDB.fallback_font, r.position + Vector2(8, 20), "敌", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#fff4f4"))

	for x in range(grid_cols):
		for y in range(grid_rows):
			if is_vehicle_cell(Vector2i(x, y)):
				continue
			var build_rect := Rect2(field_origin + Vector2(x * _layout_tile_size, y * _layout_tile_size), Vector2(_layout_tile_size, _layout_tile_size))
			var checker := 0.10 if (x + y) % 2 == 0 else 0.18
			draw_rect(build_rect, Color(0.14, 0.52, 0.28, checker), true)
			draw_rect(build_rect, buildable_border, false, 1.0)
			if y == 0 or y == 1:
				draw_rect(build_rect, Color(0.82, 0.26, 0.26, 0.08), true)

	for cell in vehicle_cells:
		var rect := Rect2(field_origin + Vector2(cell.x * _layout_tile_size, cell.y * _layout_tile_size), Vector2(_layout_tile_size, _layout_tile_size))
		draw_rect(rect, Color("#203144"), true)
		draw_rect(rect, Color("#ffcc6f"), false, 3.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(6, 18), "车", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#fff8e6"))

	var veh_center := get_vehicle_center_local()
	draw_circle(veh_center, 30.0, Color(0.95, 0.74, 0.22, 0.22))
	draw_circle(veh_center, 20.0, Color("#ffd66d"))
	draw_circle(veh_center, 10.0, Color("#ff6b63"))
	draw_string(ThemeDB.fallback_font, veh_center + Vector2(-18, -4), "车辆", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#fff8e6"))
	draw_string(ThemeDB.fallback_font, veh_center + Vector2(-18, -28), "防守核心", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffb1a8"))

	if _controller != null:
		if (
			_controller.show_route_overlay
			and _controller.debug_draw_routes
			and _controller.wave_plan != null
		):
			_draw_wave_design_overlay()
		_draw_placed_towers()
		_draw_combat_entities()
		_draw_placement_preview()
		_draw_vehicle_hp_bar()


func _draw_arrow_head(tip: Vector2, direction: Vector2, size: float, color: Color) -> void:
	if direction.length_squared() < 0.0001:
		return
	var dir := direction.normalized()
	var wing := dir.orthogonal() * size * 0.45
	var base := tip - dir * size
	draw_colored_polygon(PackedVector2Array([tip, base + wing, base - wing]), color)


func _draw_wave_design_overlay() -> void:
	var plan: NightTdWavePlan = _controller.wave_plan
	if plan == null:
		return
	var route_color := Color(0.95, 0.28, 0.28, 0.75)
	var arrow_color := Color(1.0, 0.55, 0.35, 0.95)
	var spawn_color := Color(0.95, 0.2, 0.2, 0.9)
	var standby_color := Color(1.0, 0.55, 0.2, 0.85)
	draw_string(
		ThemeDB.fallback_font,
		field_origin + Vector2(8, -28),
		"敌人行进方向 →",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color("#ffc9a8"),
	)
	for route_id in plan.routes.keys():
		var waypoints := plan.get_route_waypoints(str(route_id))
		var prev: Vector2 = Vector2.ZERO
		var has_prev := false
		for idx in range(waypoints.size()):
			var wp: Dictionary = waypoints[idx]
			var cell: Vector2i = wp["cell"]
			if not is_inside_grid(cell):
				continue
			var local_pos := _cell_to_local(cell)
			var standby := float(wp.get("standby_sec", 0.0))
			if has_prev:
				draw_line(prev, local_pos, route_color, 3.0)
				var seg := local_pos - prev
				if seg.length_squared() > 4.0:
					var mid := prev + seg * 0.55
					_draw_arrow_head(mid + seg.normalized() * 10.0, seg, 14.0, arrow_color)
			prev = local_pos
			has_prev = true
			if standby > 0.0:
				draw_circle(local_pos, 10.0, standby_color)
				draw_string(
					ThemeDB.fallback_font,
					local_pos + Vector2(-16, -14),
					"%.0fs" % standby,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					10,
					Color("#ffe8c8"),
				)
			draw_string(
				ThemeDB.fallback_font,
				local_pos + Vector2(-10, 6),
				NightTdWavePlan.cell_label(cell),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				9,
				Color("#ffd0d0"),
			)
	for sp_id in plan.spawn_points.keys():
		for label in plan.spawn_points[sp_id]:
			var cell := NightTdWavePlan.parse_cell_label(str(label))
			if not is_inside_grid(cell):
				continue
			var local_pos := _cell_to_local(cell)
			draw_rect(
				Rect2(local_pos.x - 12, local_pos.y - 12, 24, 24),
				spawn_color,
				false,
				2.5,
			)
			draw_string(
				ThemeDB.fallback_font,
				local_pos + Vector2(-14, -18),
				str(label),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				10,
				Color("#ffcccc"),
			)


func _draw_combat_entities() -> void:
	if _controller == null:
		return
	for enemy in _controller._enemies:
		var local_pos := to_local(enemy["pos"])
		var radius: float = maxf(float(enemy.get("radius", 10.0)), 12.0)
		var color: Color = enemy.get("color", Color.WHITE)
		var edef: Dictionary = NightTdDefs.get_enemy_def(str(enemy.get("type", "")))
		var label: String = str(edef.get("name", "敌")).left(2)
		draw_circle(local_pos, radius + 6.0, Color(1.0, 0.35, 0.35, 0.35))
		draw_circle(local_pos, radius + 3.0, Color("#ffffff"))
		draw_circle(local_pos, radius, color)
		draw_arc(local_pos, radius + 5.0, 0.0, TAU, 32, Color("#ff8b7a"), 2.5)
		draw_string(ThemeDB.fallback_font, local_pos + Vector2(-14, -20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#fff8f8"))
		if _controller.phase == NightTdController.Phase.COMBAT:
			var move_dir: Vector2 = enemy.get("move_dir", Vector2.ZERO)
			if move_dir.length_squared() > 0.0001:
				var arrow_tip := local_pos + move_dir * (radius + 14.0)
				_draw_arrow_head(arrow_tip, move_dir, 11.0, Color(1.0, 0.45, 0.35, 0.95))
		if float(enemy.get("wait_remaining", 0.0)) > 0.0:
			draw_string(
				ThemeDB.fallback_font,
				local_pos + Vector2(-10, 8),
				"停",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				10,
				Color("#ffe0a0"),
			)
		var hp_ratio: float = clampf(float(enemy["hp"]) / maxf(float(enemy["max_hp"]), 1.0), 0.0, 1.0)
		draw_rect(Rect2(local_pos.x - 18, local_pos.y - 28, 36, 5), Color(0.05, 0.05, 0.05, 0.95), true)
		draw_rect(Rect2(local_pos.x - 18, local_pos.y - 28, 36 * hp_ratio, 5), Color("#ff5f57"), true)

	for projectile in _controller._projectiles:
		var from_pos := to_local(projectile["from"])
		var to_pos := to_local(projectile["to"])
		draw_line(from_pos, to_pos, projectile.get("color", Color.WHITE), 3.0)
		draw_circle(to_pos, 4.0, projectile.get("color", Color.WHITE))


func _draw_placement_preview() -> void:
	if _controller == null or _controller.phase != NightTdController.Phase.PLACE:
		return
	if _is_pointer_over_ui():
		return
	var hover: Vector2i = world_to_cell(get_global_mouse_position())
	if not is_inside_grid(hover):
		return
	var occupied: Dictionary = {}
	for tower in _controller._towers:
		if not tower.get("removed", false):
			occupied[tower["cell"]] = true
	var build_rect := Rect2(field_origin + Vector2(hover.x * _layout_tile_size, hover.y * _layout_tile_size), Vector2(_layout_tile_size, _layout_tile_size))
	if can_place_tower(hover, occupied):
		draw_rect(build_rect, Color(0.43, 0.82, 0.55, 0.42), true)
		draw_rect(build_rect, Color("#ffffff"), false, 2.5)
		draw_string(ThemeDB.fallback_font, build_rect.position + Vector2(6, 18), "可放置", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#f1fff3"))
	else:
		draw_rect(build_rect, Color(0.95, 0.35, 0.35, 0.28), true)
		draw_rect(build_rect, Color(1.0, 0.8, 0.8, 0.8), false, 2.0)


func _draw_vehicle_hp_bar() -> void:
	if _controller == null:
		return
	var bar_rect := get_field_rect_local()
	var bar_w: float = bar_rect.size.x
	var bar_x: float = bar_rect.position.x
	var bar_y: float = bar_rect.end.y + 12.0
	var ratio: float = clampf(_controller.base_hp / _controller.base_max_hp, 0.0, 1.0)
	draw_rect(Rect2(bar_x, bar_y, bar_w, 12), Color("#1a2533"), true)
	draw_rect(Rect2(bar_x, bar_y, bar_w * ratio, 12), Color("#d89246"), true)
	draw_string(ThemeDB.fallback_font, Vector2(bar_x, bar_y - 18), "车辆耐久", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#d8e4f0"))


func _draw_placed_towers() -> void:
	for tower in _controller._towers:
		if tower.get("removed", false):
			continue
		var cell: Vector2i = tower["cell"]
		var local_pos := _cell_to_local(cell)
		var tdef: Dictionary = NightTdDefs.get_tower_def(str(tower["type"]))
		var radius: float = float(tdef.get("radius", 12))
		match str(tower["type"]):
			"jammer":
				draw_circle(local_pos, radius, tdef.get("color", Color.WHITE))
				draw_arc(local_pos, float(tdef.get("range", 100)), 0.0, TAU, 48, Color(0.43, 0.82, 0.55, 0.22), 2.0)
				draw_rect(Rect2(local_pos.x - 14, local_pos.y - 22, 28, 4), Color("#6ed08b"), true)
			"barrier":
				var barrier_rect := Rect2(local_pos.x - 16, local_pos.y - 14, 32, 28)
				draw_rect(barrier_rect, tdef.get("color", Color.WHITE), true)
				draw_rect(barrier_rect, Color("#f2e2c8"), false, 2.0)
			"trap":
				var points := PackedVector2Array([
					local_pos + Vector2(0, -15),
					local_pos + Vector2(14, 12),
					local_pos + Vector2(-14, 12),
				])
				draw_colored_polygon(points, tdef.get("color", Color.WHITE))
			_:
				draw_circle(local_pos, radius, tdef.get("color", Color.WHITE))


func get_buildable_hint_cell(world_pos: Vector2) -> Vector2i:
	return world_to_cell(world_pos)
