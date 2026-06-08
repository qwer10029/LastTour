extends Node2D
class_name NightTdField

const DayTopdownRender = preload("res://scripts/day_topdown_render.gd")

signal cell_clicked(cell: Vector2i)
signal cell_right_clicked(cell: Vector2i)
signal cell_combat_clicked(cell: Vector2i)

@export var grid_cols: int = 28
@export var grid_rows: int = 18
@export var tile_size: int = 48
@export var field_origin: Vector2 = Vector2(120, 70)
@export var top_reserved_px: float = 80.0
@export var right_reserved_px: float = 216.0
@export var outer_margin_px: float = 24.0

# 基地居中（敌人从四面边缘涌入）。
var vehicle_cells: Array[Vector2i] = [Vector2i(13, 8), Vector2i(14, 8), Vector2i(13, 9), Vector2i(14, 9)]
var base_local_pos: Vector2 = Vector2.ZERO
var _layout_tile_size: float = 48.0
var _controller: NightTdController
var _last_view_size: Vector2 = Vector2.ZERO

# Tower selection (P5): multiple towers selectable via click or box-drag
var _selected_tower_ids: Array[int] = []
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_end_pos: Vector2 = Vector2.ZERO
var _is_dragging := false
# Breach flash effects
var _breach_flashes: Array[Dictionary] = []  # {pos, timer, max_timer}
# 缓存字体引用，避免每帧在 draw_string 中查 ThemeDB
var _font: Font = null


func _ready() -> void:
	_controller = get_parent() as NightTdController
	set_process_unhandled_input(true)
	z_index = 1
	_font = ThemeDB.fallback_font
	_reflow_layout()
	base_local_pos = get_vehicle_center_local()


func bind_controller(controller: NightTdController) -> void:
	_controller = controller


func _process(delta: float) -> void:
	var view_size := get_viewport_rect().size
	if view_size != _last_view_size:
		_reflow_layout()
	_process_breach_flashes(delta)
	if view_size != _last_view_size:
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
	_layout_tile_size = clampf(fitted_tile, 22.0, 56.0)
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
	# 四面边缘的最外两格为敌人涌入带。
	return cell.x <= 1 or cell.y <= 1 or cell.x >= grid_cols - 2 or cell.y >= grid_rows - 2


func can_place_tower(cell: Vector2i, occupied: Dictionary) -> bool:
	if not is_inside_grid(cell):
		return false
	if is_vehicle_cell(cell):
		return false
	if occupied.has(cell):
		return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if _controller == null:
		return
	if _is_pointer_over_ui():
		return

	if _controller.phase == NightTdController.Phase.COMBAT:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					_drag_start_pos = get_global_mouse_position()
					_drag_end_pos = _drag_start_pos
					_is_dragging = true
				else:
					var dist := _drag_end_pos.distance_to(_drag_start_pos)
					if dist < 8.0:
						var cell := world_to_cell(get_global_mouse_position())
						if is_inside_grid(cell):
							var hit_tower := false
							for tower in _controller._towers:
								if tower.get("removed", false): continue
								if tower["cell"] == cell:
									hit_tower = true
									break
							if not hit_tower:
								clear_tower_selection()
							cell_combat_clicked.emit(cell)
							get_viewport().set_input_as_handled()
					else:
						_select_towers_in_rect(_drag_start_pos, _drag_end_pos)
						get_viewport().set_input_as_handled()
						_controller.sync_selection_to_hud()
					_is_dragging = false
					queue_redraw()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				if event.pressed:
					_selected_tower_ids.clear()
					queue_redraw()
		elif event is InputEventMouseMotion and _is_dragging:
			_drag_end_pos = get_global_mouse_position()
			queue_redraw()
		return

	if not (event is InputEventMouseButton and event.pressed):
		return
	var cell := world_to_cell(get_global_mouse_position())
	if not is_inside_grid(cell):
		return
	if _controller.phase == NightTdController.Phase.PLACE:
		if event.button_index == MOUSE_BUTTON_LEFT:
			cell_clicked.emit(cell)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cell_right_clicked.emit(cell)
			get_viewport().set_input_as_handled()


func _select_towers_in_rect(from: Vector2, to: Vector2) -> void:
	_selected_tower_ids.clear()
	var r := Rect2(from.min(to), (to - from).abs())
	for tower in _controller._towers:
		if tower.get("removed", false): continue
		var wp: Vector2 = tower["world_pos"]
		if r.has_point(wp):
			_selected_tower_ids.append(int(tower.get("id", -1)))


func _is_pointer_over_ui() -> bool:
	var control: Control = get_viewport().gui_get_hovered_control()
	while control != null:
		if control is BaseButton:
			return true
		if str(control.name) in ["SidePanel", "Sidebar", "TopBar", "ResultOverlay", "Hud", "ResultPanel", "ContinueBtn", "OverlayBtn"]:
			return true
		control = control.get_parent() as Control
	return false


func _draw() -> void:
	var grid_color := Color("#05080c")
	var line_color := Color("#8ec7ff")
	var spawn_color := Color(0.95, 0.2, 0.2, 0.55)
	var field_rect := get_field_rect_local()
	draw_rect(field_rect, grid_color, true)
	draw_rect(field_rect, Color("#d7f1ff"), false, 4.0)
	draw_rect(field_rect.grow(-5.0), Color(0.0, 0.0, 0.0, 0.10), false, 1.0)
	draw_string(_font, field_origin + Vector2(8, -10), "布防区", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#eef8ff"))

	for x in range(grid_cols + 1):
		var px := field_origin.x + x * _layout_tile_size
		draw_line(Vector2(px, field_origin.y), Vector2(px, field_origin.y + grid_rows * _layout_tile_size), line_color, 1.5)
	for y in range(grid_rows + 1):
		var py := field_origin.y + y * _layout_tile_size
		draw_line(Vector2(field_origin.x, py), Vector2(field_origin.x + grid_cols * _layout_tile_size, py), line_color, 1.5)

	# 可建造区域：整块填充 + 逐行棋盘格（18 行 vs 504 格，draw_rect 从 1200 降到 ~25）
	var buildable_rect := get_field_rect_local()
	draw_rect(buildable_rect, Color(0.14, 0.52, 0.28, 0.14), true)
	for y in range(grid_rows):
		if y % 2 == 0:
			var row_rect := Rect2(
				field_origin + Vector2(0, y * _layout_tile_size),
				Vector2(grid_cols * _layout_tile_size, _layout_tile_size)
			)
			draw_rect(row_rect, Color(0.14, 0.52, 0.28, 0.08), true)

	# 出生带：4 个矩形替代 ~60 个格子绘制
	var ts := _layout_tile_size
	draw_rect(Rect2(field_origin, Vector2(2 * ts, grid_rows * ts)), spawn_color, true)
	draw_rect(Rect2(field_origin + Vector2((grid_cols - 2) * ts, 0), Vector2(2 * ts, grid_rows * ts)), spawn_color, true)
	draw_rect(Rect2(field_origin, Vector2(grid_cols * ts, 2 * ts)), spawn_color, true)
	draw_rect(Rect2(field_origin + Vector2(0, (grid_rows - 2) * ts), Vector2(grid_cols * ts, 2 * ts)), spawn_color, true)

	for cell in vehicle_cells:
		var rect := Rect2(field_origin + Vector2(cell.x * _layout_tile_size, cell.y * _layout_tile_size), Vector2(_layout_tile_size, _layout_tile_size))
		draw_rect(rect, Color("#203144", 0.35), true)
		draw_rect(rect, Color("#ffcc6f", 0.55), false, 2.0)

	var veh_center := get_vehicle_center_local()
	var veh_scale := (_layout_tile_size * 2.28) / maxf(DayTopdownRender.vehicle_display_width(), 1.0)
	DayTopdownRender.draw_vehicle_marker(self, veh_center, veh_scale, "", Vector2.UP)
	draw_string(_font, veh_center + Vector2(-22, -36), "防守核心", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffb1a8", 0.9))

	if _controller != null:
		if _controller.show_overlay:
			_draw_influence_heatmap()
			_draw_commander_overlay()
		if (
			_controller.show_route_overlay
			and _controller.debug_draw_routes
			and _controller._flow != null
			and _controller._flow.cols > 0
		):
			_draw_flow_overlay()
		_draw_placed_towers()
		_draw_combat_entities()
		_draw_placement_preview()
		_draw_vehicle_hp_bar()
		_draw_breach_flashes()
		if _is_dragging:
			_draw_selection_rect()


func _draw_arrow_head(tip: Vector2, direction: Vector2, size: float, color: Color) -> void:
	if direction.length_squared() < 0.0001:
		return
	var dir := direction.normalized()
	var wing := dir.orthogonal() * size * 0.45
	var base := tip - dir * size
	draw_colored_polygon(PackedVector2Array([tip, base + wing, base - wing]), color)


## 威胁热力图：用颜色覆盖层展示每格的威胁值（火力覆盖密度）。
func _draw_influence_heatmap() -> void:
	if _controller == null:
		return
	var data: Dictionary = _controller.get_influence_display_data()
	if data.is_empty():
		return
	var threat: PackedFloat32Array = data.get("threat", PackedFloat32Array())
	var max_t: float = float(data.get("max_threat", 0.0))
	var cols: int = int(data.get("cols", 0))
	var rows: int = int(data.get("rows", 0))
	if threat.size() == 0 or cols == 0 or max_t <= 0.0:
		var field_rect := get_field_rect_local()
		draw_rect(field_rect, Color(0.1, 0.12, 0.2, 0.12), true)
		draw_string(_font, field_origin + Vector2(8, -28),
			"威胁热力图  (无火力覆盖)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(0.4, 0.5, 0.7, 0.8))
		return
	draw_string(_font, field_origin + Vector2(8, -28),
		"威胁热力图  (%.0f DPS 峰值)" % max_t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(0.95, 0.4, 0.3, 0.85))
	var tile := _layout_tile_size
	for y in range(rows):
		for x in range(cols):
			var idx := y * cols + x
			if idx >= threat.size():
				continue
			var v := threat[idx]
			if v <= 0.0:
				continue
			var t := clampf(v / max_t, 0.0, 1.0)
			draw_rect(Rect2(
				field_origin + Vector2(x * tile, y * tile),
				Vector2(tile, tile)
			), _heat_color(t), true)


## 归一化威胁值 → 热力图颜色
func _heat_color(t: float) -> Color:
	if t < 0.25:
		var s := t / 0.25
		return Color(0.08, 0.18 + s * 0.5, 0.35 + s * 0.5, 0.32)
	elif t < 0.5:
		var s := (t - 0.25) / 0.25
		return Color(0.08 + s * 0.15, 0.68 + s * 0.3, 0.85 - s * 0.55, 0.32)
	elif t < 0.75:
		var s := (t - 0.5) / 0.25
		return Color(0.23 + s * 0.72, 0.98 - s * 0.1, 0.3 - s * 0.2, 0.32)
	else:
		var s := (t - 0.75) / 0.25
		return Color(0.95 - s * 0.05, 0.88 - s * 0.65, 0.1 - s * 0.05, 0.32)


## 指挥官覆盖层：画出集结区域、攻坚目标、佯攻方向。
func _draw_commander_overlay() -> void:
	if _controller == null:
		return
	var cd: Dictionary = _controller.get_commander_display_data()
	if cd.is_empty():
		return
	if bool(cd.get("suppressed", false)):
		draw_string(_font, field_origin + Vector2(8, -44),
			"指挥官: 失能中", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(0.8, 0.4, 0.3, 0.9))
		return

	var missions: Array = cd.get("missions", [])
	var pressure_active: bool = bool(cd.get("pressure_active", false))

	var label_text := "指挥官: 活跃"
	if missions.is_empty():
		label_text += " (暂无攻坚任务)"
	draw_string(_font, field_origin + Vector2(8, -44),
		label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(1.0, 0.82, 0.29, 0.9))

	for m in missions:
		var target_cell: Vector2i = m["target_cell"]
		var staging_cell: Vector2i = m["staging_cell"]
		var state: String = str(m["state"])

		# 集结区域：黄色虚线圆
		var staging_pos := _cell_to_local(staging_cell)
		var r := _layout_tile_size * 1.2
		var segments := 16
		for i in range(segments):
			var a0 := TAU * i / segments
			var a1 := TAU * (i + 0.5) / segments
			draw_line(
				staging_pos + Vector2(cos(a0) * r, sin(a0) * r),
				staging_pos + Vector2(cos(a1) * r, sin(a1) * r),
				Color(1.0, 0.85, 0.2, 0.55), 2.0
			)

		draw_string(_font, staging_pos + Vector2(-14, -r - 10),
			"集结", HORIZONTAL_ALIGNMENT_CENTER, -1, 9,
			Color(1.0, 0.85, 0.2, 0.8))

		# 突击目标：红色十字
		var target_pos := _cell_to_local(target_cell)
		var cross := _layout_tile_size * 0.55
		var line_color: Color
		if state == "push":
			line_color = Color(1.0, 0.2, 0.2, 0.85)
		else:
			line_color = Color(0.8, 0.5, 0.3, 0.5)
		draw_line(target_pos + Vector2(-cross, -cross), target_pos + Vector2(cross, cross), line_color, 2.5)
		draw_line(target_pos + Vector2(cross, -cross), target_pos + Vector2(-cross, cross), line_color, 2.5)

		# 从集结到目标的连线（虚线）
		var sx := staging_pos.x
		var sy := staging_pos.y
		var tx := target_pos.x
		var ty := target_pos.y
		var steps := 8
		for i in range(steps):
			var f0 := float(i) / steps
			var f1 := float(i + 0.5) / steps
			draw_line(
				Vector2(lerpf(sx, tx, f0), lerpf(sy, ty, f0)),
				Vector2(lerpf(sx, tx, f1), lerpf(sy, ty, f1)),
				Color(1.0, 0.6, 0.15, 0.4), 1.5
			)

		if state == "push":
			draw_string(_font, target_pos + Vector2(-16, -22),
				"突击!", HORIZONTAL_ALIGNMENT_CENTER, -1, 10,
				Color(1.0, 0.25, 0.2, 0.9))

	# 佯攻指示
	if pressure_active:
		var p_pos := get_vehicle_center_local()
		draw_string(_font, p_pos + Vector2(-30, -48),
			"佯攻", HORIZONTAL_ALIGNMENT_CENTER, -1, 9,
			Color(0.7, 0.55, 0.9, 0.75))


func _draw_flow_overlay() -> void:
	var ff: NightTdFlowField = _controller._flow
	if ff == null or ff.cols == 0:
		return
	draw_string(_font, field_origin + Vector2(8, -58), "流场方向 →",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.85, 0.95, 0.75))
	var arrow_len := _layout_tile_size * 0.3
	var int_max := maxf(
		ff.integration_at(Vector2i(0, 0)),
		maxf(
			ff.integration_at(Vector2i(ff.cols - 1, 0)),
			maxf(
				ff.integration_at(Vector2i(0, ff.rows - 1)),
				ff.integration_at(Vector2i(ff.cols - 1, ff.rows - 1))
			)
		)
	)
	if int_max >= NightTdFlowField.INF:
		int_max = float(ff.cols + ff.rows)
	int_max = maxf(int_max, 1.0)
	for y in range(ff.rows):
		for x in range(ff.cols):
			var cell := Vector2i(x, y)
			if is_vehicle_cell(cell):
				continue
			if not ff.is_reachable(cell):
				continue
			var dir := ff.sample_dir(cell)
			if dir.length_squared() < 0.0001:
				continue
			var center := _cell_to_local(cell)
			var t := clampf(ff.integration_at(cell) / int_max, 0.0, 1.0)
			var alpha := lerpf(0.72, 0.32, t)
			var color := Color(0.55, 0.85, 0.95, alpha)
			var tip := center + dir * arrow_len
			draw_line(center - dir * arrow_len * 0.4, tip, color, 1.5)
			_draw_arrow_head(tip, dir, arrow_len * 0.55, color)


func _draw_combat_entities() -> void:
	if _controller == null:
		return
	for enemy in _controller._enemies:
		var local_pos := to_local(enemy["pos"])
		var radius: float = maxf(float(enemy.get("radius", 10.0)), 12.0)
		var color: Color = enemy.get("color", Color.WHITE)
		var edef: Dictionary = NightTdDefs.get_enemy_def(str(enemy.get("type", "")))
		var label: String = str(edef.get("name", "敌")).left(2)
		var is_ally := str(enemy.get("faction", "enemy")) == "ally"
		var is_hacked := int(enemy.get("hacked_by", -1)) >= 0
		var halo := Color(0.35, 0.95, 0.7, 0.35) if is_ally else Color(1.0, 0.35, 0.35, 0.35)
		var ring := Color("#5ce0a8") if is_ally else Color("#ff8b7a")
		if is_hacked and not is_ally:
			ring = Color("#5ac8e0")
		draw_circle(local_pos, radius + 6.0, halo)
		draw_circle(local_pos, radius + 3.0, Color("#ffffff"))
		draw_circle(local_pos, radius, color)
		draw_arc(local_pos, radius + 5.0, 0.0, TAU, 32, ring, 2.5)
		if is_ally:
			label = "友" + label.left(1)
		draw_string(_font, local_pos + Vector2(-14, -20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#fff8f8"))
		# 牧羊者：金色指挥光环
		if bool(enemy.get("is_shepherd", false)) and not is_ally:
			draw_arc(local_pos, radius + 10.0, 0.0, TAU, 40, Color(1.0, 0.82, 0.29, 0.7), 2.0)
		# 战斗中显示指挥官分配的组标签
		if _controller.phase == NightTdController.Phase.COMBAT:
			var goal_key: String = str(enemy.get("goal_key", ""))
			if goal_key.begins_with("m:"):
				draw_string(_font, local_pos + Vector2(-10, -32),
					"突击", HORIZONTAL_ALIGNMENT_CENTER, -1, 8,
					Color(1.0, 0.5, 0.2, 0.8))
			elif goal_key == "pressure":
				draw_string(_font, local_pos + Vector2(-10, -32),
					"佯攻", HORIZONTAL_ALIGNMENT_CENTER, -1, 8,
					Color(0.6, 0.5, 0.9, 0.8))
		if _controller.phase == NightTdController.Phase.COMBAT:
			var move_dir: Vector2 = enemy.get("move_dir", Vector2.ZERO)
			if move_dir.length_squared() > 0.0001:
				var arrow_tip := local_pos + move_dir * (radius + 14.0)
				_draw_arrow_head(arrow_tip, move_dir, 11.0, Color(1.0, 0.45, 0.35, 0.95))
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
		draw_string(_font, build_rect.position + Vector2(6, 18), "可放置", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#f1fff3"))
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
	draw_string(_font, Vector2(bar_x, bar_y - 18), "车辆耐久", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#d8e4f0"))


func play_breach_flash(world_pos: Vector2) -> void:
	var local := to_local(world_pos)
	_breach_flashes.append({"pos": local, "timer": 0.0, "max_timer": 0.5})


func set_highlighted_tower(tower_id: int) -> void:
	_selected_tower_ids.clear()
	if tower_id >= 0:
		_selected_tower_ids.append(tower_id)
	queue_redraw()


func get_selected_tower_ids() -> Array[int]:
	return _selected_tower_ids


func clear_tower_selection() -> void:
	_selected_tower_ids.clear()
	queue_redraw()
	if _controller != null and is_instance_valid(_controller.hud):
		_controller.hud.clear_power_highlight()


func _process_breach_flashes(delta: float) -> void:
	for i in range(_breach_flashes.size() - 1, -1, -1):
		_breach_flashes[i]["timer"] += delta
		if _breach_flashes[i]["timer"] >= _breach_flashes[i]["max_timer"]:
			_breach_flashes.remove_at(i)
	if not _breach_flashes.is_empty():
		queue_redraw()


func _draw_breach_flashes() -> void:
	for flash in _breach_flashes:
		var t: float = flash["timer"]
		var max_t: float = flash["max_timer"]
		var progress: float = clampf(t / max_t, 0.0, 1.0)
		var r: float = lerpf(0.0, 48.0, progress)
		var a: float = lerpf(0.9, 0.0, progress)
		draw_circle(flash["pos"], r, Color(0.91, 0.47, 0.25, a))


func _draw_selection_rect() -> void:
	var r := Rect2(_drag_start_pos.min(_drag_end_pos), (_drag_end_pos - _drag_start_pos).abs())
	draw_rect(r, Color("#ffcc6f", 0.3), true)
	draw_rect(r, Color("#ffcc6f", 0.8), false, 2.0)


func _draw_placed_towers() -> void:
	for tower in _controller._towers:
		if tower.get("removed", false):
			continue
		var cell: Vector2i = tower["cell"]
		var local_pos := _cell_to_local(cell)
		var tdef: Dictionary = NightTdDefs.get_tower_def(str(tower["type"]))
		var radius: float = float(tdef.get("radius", 12))
		# 功率指示：超频塔外圈发光
		var power_scale := float(tower.get("power_scale", 1.0))
		if power_scale > 1.05:
			draw_circle(local_pos, radius + 6.0, Color(1.0, 0.7, 0.2, 0.25 * (power_scale - 1.0)))
		elif power_scale < 0.95 and float(tdef.get("upkeep", 0.0)) > 0.0:
			draw_circle(local_pos, radius + 4.0, Color(0.3, 0.3, 0.3, 0.4))
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
			"hacker":
				var hk_color: Color = tdef.get("color", Color("#5ac8e0"))
				draw_arc(local_pos, float(tdef.get("range", 150)), 0.0, TAU, 48, Color(0.35, 0.78, 0.88, 0.18), 2.0)
				draw_circle(local_pos, radius, hk_color)
				draw_circle(local_pos, radius * 0.5, Color("#0a2030"))
				if _controller.phase == NightTdController.Phase.COMBAT and int(tower.get("id", -1)) == _controller._selected_hacker_id:
					draw_arc(local_pos, radius + 6.0, 0.0, TAU, 40, Color("#9af0ff"), 2.5)
				var prog := float(tower.get("hack_progress", 0.0))
				if prog > 0.0:
					var ratio := clampf(prog / 100.0, 0.0, 1.0)
					draw_rect(Rect2(local_pos.x - 16, local_pos.y - 24, 32, 4), Color(0.05, 0.1, 0.12, 0.9), true)
					draw_rect(Rect2(local_pos.x - 16, local_pos.y - 24, 32 * ratio, 4), Color("#5ac8e0"), true)
				var teid := int(tower.get("target_eid", -1))
				if teid >= 0:
					for e in _controller._enemies:
						if int(e.get("eid", -1)) == teid:
							draw_line(local_pos, to_local(e["pos"]), Color(0.35, 0.82, 0.95, 0.6), 2.0)
							break
			"sniper":
				var sn_color: Color = tdef.get("color", Color("#7aa6ff"))
				draw_arc(local_pos, float(tdef.get("range", 220)), 0.0, TAU, 64, Color(0.48, 0.65, 1.0, 0.18), 1.5)
				draw_circle(local_pos, radius, sn_color)
				draw_circle(local_pos, radius * 0.35, Color("#0a1830"))
			"splash":
				var sp_color: Color = tdef.get("color", Color("#e0a23a"))
				var splash_r := float(tdef.get("splash_radius", 56.0))
				draw_circle(local_pos, splash_r, Color(0.88, 0.64, 0.23, 0.10))
				draw_arc(local_pos, splash_r, 0.0, TAU, 48, Color(0.88, 0.64, 0.23, 0.28), 1.5)
				draw_arc(local_pos, float(tdef.get("range", 120)), 0.0, TAU, 48, Color(0.88, 0.64, 0.23, 0.22), 2.0)
				draw_circle(local_pos, radius, sp_color)
				draw_circle(local_pos, radius * 0.45, Color("#1a0e00"))
			_:
				draw_circle(local_pos, radius, tdef.get("color", Color.WHITE))

		# Tower HP bar + selection highlight
		var tid := int(tower.get("id", -1))
		var tmax_hp := float(tdef.get("hp", 30))
		var tcurrent_hp := float(tower.get("hp", tmax_hp))
		var is_powered := float(tdef.get("upkeep", 0.0)) > 0.0
		var is_selected := tid in _selected_tower_ids and is_powered
		var is_damaged := tcurrent_hp < tmax_hp
		if is_damaged or is_selected:
			var bar_w: float = 30.0
			var bar_h: float = 4.0
			var bar_y := local_pos.y - radius - 10.0
			var ratio := clampf(tcurrent_hp / tmax_hp, 0.0, 1.0)
			draw_rect(Rect2(local_pos.x - bar_w * 0.5, bar_y, bar_w, bar_h), Color("#1a2533"), true)
			if is_selected:
				draw_rect(Rect2(local_pos.x - bar_w * 0.5, bar_y, bar_w * ratio, bar_h), Color("#ffcc6f"), true)
			else:
				draw_rect(Rect2(local_pos.x - bar_w * 0.5, bar_y, bar_w * ratio, bar_h), Color("#6ed08b"), true)
		if is_selected:
			var pulse := (sin(Time.get_ticks_msec() * 0.006) + 1.0) * 0.5
			draw_circle(local_pos, radius + 8.0, Color("#ffcc6f", 0.22 + pulse * 0.18))
			draw_arc(local_pos, radius + 8.0, 0.0, TAU, 48, Color("#ffcc6f", 0.7 + pulse * 0.3), 3.0)
			var bar_y := local_pos.y - radius - 10.0
			draw_rect(Rect2(local_pos.x - 17.0, bar_y - 2.0, 34.0, 8.0), Color("#ffcc6f", 0.8), false, 2.5)


func get_buildable_hint_cell(world_pos: Vector2) -> Vector2i:
	return world_to_cell(world_pos)
