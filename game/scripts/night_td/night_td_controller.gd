extends Node2D
class_name NightTdController

signal session_finished(result: Dictionary)

enum Phase { PLACE, COMBAT, RESULT }

@export var placement_time_sec: float = 180.0
@export var base_max_hp: float = 100.0
@export var spawn_interval_sec: float = 1.2

@onready var field: NightTdField = $Field
@onready var hud: CanvasLayer = $Hud

var phase: int = Phase.PLACE
var backpack_remaining: int = 0
var resources_spent: int = 0
var difficulty: int = 1
var day_index: int = 1
var placement_remaining: float = 0.0
var base_hp: float = 100.0
var _selected_tower := "jammer"
var _towers: Array[Dictionary] = []
var _enemies: Array[Dictionary] = []
var _wave_queue: Array[String] = []
var _spawn_timer: float = 0.0
var _enemies_spawned: int = 0
var _enemies_killed: int = 0
var _enemies_reached: int = 0
var _combat_done := false
var _last_result: Dictionary = {}


func _ready() -> void:
	visible = false
	if is_instance_valid(field):
		field.bind_controller(self)
		field.cell_clicked.connect(_on_cell_clicked)
	if is_instance_valid(hud):
		hud.tower_selected.connect(_on_tower_selected)
		hud.start_wave_pressed.connect(_begin_combat)
		hud.continue_pressed.connect(_finish_session)


func _process(delta: float) -> void:
	var root := get_parent()
	if root != null and root.has_method("is_user_paused") and root.is_user_paused():
		return
	if not visible:
		return
	match phase:
		Phase.PLACE:
			_process_place(delta)
		Phase.COMBAT:
			_process_combat(delta)
	if is_instance_valid(field):
		field.queue_redraw()
	queue_redraw()


func start_session(inventory: int, diff: int, day: int) -> void:
	backpack_remaining = maxi(inventory, 0)
	resources_spent = 0
	difficulty = diff
	day_index = day
	base_hp = base_max_hp
	placement_remaining = placement_time_sec
	_selected_tower = "jammer"
	_towers.clear()
	_enemies.clear()
	_wave_queue = _build_wave_queue()
	_spawn_timer = 0.0
	_enemies_spawned = 0
	_enemies_killed = 0
	_enemies_reached = 0
	_combat_done = false
	_last_result = {}
	phase = Phase.PLACE
	visible = true
	if is_instance_valid(hud):
		hud.show_session_ui()
		hud.set_place_mode(true)
		hud.set_phase_text("夜晚塔防 · 布防阶段")
		hud.set_resources(backpack_remaining, resources_spent)
		hud.set_placement_timer(placement_remaining)
		hud.set_hint("俯视图：点击地图格子放置防御。选中背包中的设施后，消耗对应资源部署。")
		hud.clear_log()
	_update_hud_tools()


func _update_hud_tools() -> void:
	if is_instance_valid(hud):
		hud.refresh_tool_buttons()


func hide_session() -> void:
	phase = Phase.PLACE
	_combat_done = false
	visible = false
	_towers.clear()
	_enemies.clear()
	if is_instance_valid(hud):
		hud.hide_session_ui()


func _process_place(delta: float) -> void:
	placement_remaining = maxf(placement_remaining - delta, 0.0)
	if is_instance_valid(hud):
		hud.set_placement_timer(placement_remaining)
	if placement_remaining <= 0.0:
		_begin_combat()


func _process_combat(delta: float) -> void:
	if _combat_done:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _wave_queue.size() > 0:
		_spawn_next_enemy()
		_spawn_timer = spawn_interval_sec
	_update_enemies(delta)
	_update_towers(delta)
	if is_instance_valid(hud) and int(Engine.get_frames_drawn()) % 15 == 0:
		hud.set_combat_status("波次 %d/%d · 场上 %d 敌 · 车辆 HP %.0f" % [
			_enemies_spawned, _enemies_spawned + _wave_queue.size(), _enemies.size(), base_hp
		])
	if _wave_queue.is_empty() and _enemies.is_empty() and _enemies_spawned > 0:
		_end_combat()


func _spawn_next_enemy() -> void:
	if _wave_queue.is_empty():
		return
	var type_id: String = _wave_queue.pop_front()
	var def: Dictionary = NightTdDefs.get_enemy_def(type_id)
	if def.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spawn_cell: Vector2i = Vector2i(rng.randi_range(1, field.grid_cols - 2), 0)
	var pos: Vector2 = field.cell_to_world(spawn_cell)
	_enemies.append({
		"type": type_id,
		"pos": pos,
		"hp": float(def.get("hp", 20)),
		"max_hp": float(def.get("hp", 20)),
		"speed": float(def.get("speed", 50)),
		"base_damage": float(def.get("base_damage", 5)),
		"color": def.get("color", Color.WHITE),
		"radius": float(def.get("radius", 10)),
	})
	_enemies_spawned += 1
	if is_instance_valid(hud):
		hud.append_log("敌袭：%s 接近防线" % def.get("name", type_id))


func _update_enemies(delta: float) -> void:
	var base_pos: Vector2 = field.cell_to_world(Vector2i(6, 8))
	var to_remove: Array[int] = []
	for i in range(_enemies.size()):
		var enemy: Dictionary = _enemies[i]
		var pos: Vector2 = enemy["pos"]
		var cell: Vector2i = field.world_to_cell(pos)
		var slow: float = 1.0
		for tower in _towers:
			if tower.get("removed", false):
				continue
			if tower["cell"] == cell and tower["type"] == "barrier":
				var bdef: Dictionary = NightTdDefs.get_tower_def("barrier")
				slow = minf(slow, float(bdef.get("slow_factor", 0.25)))
				_damage_tower(tower, float(bdef.get("damage", 6)) * delta)
		var dir: Vector2 = (base_pos - pos).normalized()
		pos += dir * float(enemy["speed"]) * slow * delta
		enemy["pos"] = pos
		for tower in _towers:
			if tower.get("removed", false):
				continue
			if tower["type"] == "trap" and tower["cell"] == field.world_to_cell(pos):
				_trigger_trap(tower, enemy)
		if pos.distance_to(base_pos) < 28.0:
			base_hp = maxf(base_hp - float(enemy["base_damage"]), 0.0)
			_enemies_reached += 1
			to_remove.append(i)
			if is_instance_valid(hud):
				hud.append_log("警告：敌人突破防线，车辆受损！")
		elif float(enemy["hp"]) <= 0.0:
			_enemies_killed += 1
			to_remove.append(i)
	for idx in range(to_remove.size() - 1, -1, -1):
		_enemies.remove_at(to_remove[idx])


func _update_towers(delta: float) -> void:
	for tower in _towers:
		if tower.get("removed", false):
			continue
		var tdef: Dictionary = NightTdDefs.get_tower_def(str(tower["type"]))
		if tower["type"] == "jammer":
			tower["cooldown"] = maxf(float(tower["cooldown"]) - delta, 0.0)
			if float(tower["cooldown"]) > 0.0:
				continue
			var target: int = _find_enemy_in_range(tower["world_pos"], float(tdef.get("range", 100)))
			if target >= 0:
				var enemy: Dictionary = _enemies[target]
				enemy["hp"] = float(enemy["hp"]) - float(tdef.get("damage", 10))
				tower["cooldown"] = float(tdef.get("fire_interval", 0.8))
				if is_instance_valid(hud) and randf() < 0.15:
					hud.append_log("信标命中 %s" % NightTdDefs.get_enemy_def(enemy["type"]).get("name", ""))


func _find_enemy_in_range(origin: Vector2, range_px: float) -> int:
	var best: int = -1
	var best_dist: float = range_px
	for i in range(_enemies.size()):
		var dist: float = origin.distance_to(_enemies[i]["pos"])
		if dist <= best_dist:
			best_dist = dist
			best = i
	return best


func _trigger_trap(tower: Dictionary, enemy: Dictionary) -> void:
	var tdef: Dictionary = NightTdDefs.get_tower_def("trap")
	enemy["hp"] = float(enemy["hp"]) - float(tdef.get("damage", 40))
	tower["removed"] = true
	if is_instance_valid(hud):
		hud.append_log("陷阱触发！")


func _damage_tower(tower: Dictionary, amount: float) -> void:
	tower["hp"] = float(tower["hp"]) - amount
	if float(tower["hp"]) <= 0.0:
		tower["removed"] = true


func _on_cell_clicked(cell: Vector2i) -> void:
	if phase != Phase.PLACE:
		return
	var tdef: Dictionary = NightTdDefs.get_tower_def(_selected_tower)
	if tdef.is_empty():
		return
	var cost: int = int(tdef.get("cost", 1))
	if backpack_remaining < cost:
		if is_instance_valid(hud):
			hud.append_log("资源不足，无法部署 %s" % tdef.get("name", ""))
		return
	var occupied: Dictionary = {}
	for tower in _towers:
		if not tower.get("removed", false):
			occupied[tower["cell"]] = true
	if not field.can_place_tower(cell, occupied):
		if is_instance_valid(hud):
			hud.append_log("该格无法部署（车辆/占用/越界）")
		return
	backpack_remaining -= cost
	resources_spent += cost
	_towers.append({
		"type": _selected_tower,
		"cell": cell,
		"world_pos": field.cell_to_world(cell),
		"cooldown": 0.0,
		"hp": float(tdef.get("hp", 30)),
		"removed": false,
	})
	if is_instance_valid(hud):
		hud.set_resources(backpack_remaining, resources_spent)
		hud.append_log("已部署 %s" % tdef.get("name", ""))


func _on_tower_selected(type_id: String) -> void:
	_selected_tower = type_id


func _begin_combat() -> void:
	if phase == Phase.COMBAT:
		return
	phase = Phase.COMBAT
	_spawn_timer = 0.0
	if is_instance_valid(hud):
		hud.set_combat_mode()
		hud.set_phase_text("夜晚塔防 · 接敌中")
		hud.set_hint("敌人正从上方逼近车辆，设施会自动开火/阻挡。")
		hud.set_combat_status("波次 %d/%d · 场上 %d 敌" % [_enemies_spawned, _enemies_spawned + _wave_queue.size(), _enemies.size()])
		hud.append_log("—— 夜间威胁来袭 ——")


func _end_combat() -> void:
	_combat_done = true
	_last_result = _build_result()
	phase = Phase.RESULT
	if is_instance_valid(hud):
		hud.show_result(str(_last_result.get("message", "")))
		hud.set_phase_text("夜晚塔防 · 结算")
		hud.set_combat_status("交互结束，请确认结算")


func _finish_session() -> void:
	if _last_result.is_empty():
		return
	var result := _last_result.duplicate()
	_last_result = {}
	hide_session()
	session_finished.emit(result)


func _build_result() -> Dictionary:
	var outcome: String = "success"
	var inv_loss: int = 0
	var fuel_loss: float = 0.0
	var msg: String = ""
	if base_hp >= 70.0:
		outcome = "success"
		inv_loss = 0
		msg = "防线稳固！车辆完好，今夜安全度过。"
	elif base_hp >= 35.0:
		outcome = "partial"
		inv_loss = 1
		fuel_loss = 8.0
		msg = "部分敌人突破防线，损失少量物资（车辆 HP %.0f/%.0f）。" % [base_hp, base_max_hp]
	else:
		outcome = "fail"
		inv_loss = 2
		fuel_loss = 18.0
		msg = "防线失守！车辆严重受损（HP %.0f/%.0f）。" % [base_hp, base_max_hp]
	return {
		"outcome": outcome,
		"message": msg,
		"inventory_remaining": backpack_remaining,
		"inventory_loss": inv_loss,
		"fuel_loss": fuel_loss,
		"base_hp": base_hp,
		"base_hp_max": base_max_hp,
		"enemies_killed": _enemies_killed,
		"enemies_reached": _enemies_reached,
		"towers_placed": _count_active_towers(),
		"resources_spent": resources_spent,
		"defense_power": _count_active_towers() * 2 + _enemies_killed,
		"threat_power": _enemies_spawned,
	}


func _count_active_towers() -> int:
	var n: int = 0
	for tower in _towers:
		if not tower.get("removed", false):
			n += 1
	return n


func _build_wave_queue() -> Array[String]:
	var queue: Array[String] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = day_index * 997 + difficulty * 131
	var drone_count: int = 5
	var scout_count: int = 2
	match difficulty:
		0:
			drone_count = 4
			scout_count = 1
		2:
			drone_count = 6
			scout_count = 4
	for _i in range(drone_count):
		queue.append("drone")
	for _i in range(scout_count):
		queue.append("scout")
	for i in range(queue.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: String = queue[i]
		queue[i] = queue[j]
		queue[j] = tmp
	return queue


func _draw() -> void:
	if not visible:
		return
	var view_size := get_viewport_rect().size
	if view_size == Vector2.ZERO:
		view_size = Vector2(1280.0, 720.0)
	draw_rect(Rect2(Vector2.ZERO, view_size), Color("#060a10"), true)

	for enemy in _enemies:
		var pos: Vector2 = to_local(enemy["pos"])
		var radius: float = float(enemy["radius"])
		draw_circle(pos, radius, enemy.get("color", Color.WHITE))
		var hp_ratio: float = clampf(float(enemy["hp"]) / maxf(float(enemy["max_hp"]), 1.0), 0.0, 1.0)
		draw_rect(Rect2(pos.x - 14, pos.y - 20, 28 * hp_ratio, 3), Color("#ff5f57"), true)

	if phase == Phase.PLACE and is_instance_valid(field):
		var hover: Vector2i = field.world_to_cell(get_global_mouse_position())
		if field.is_inside_grid(hover) and not field.is_vehicle_cell(hover):
			var local_origin := field.field_origin + Vector2(hover.x * field.tile_size, hover.y * field.tile_size)
			var rect := Rect2(local_origin, Vector2(field.tile_size, field.tile_size))
			draw_rect(rect, Color(0.43, 0.82, 0.55, 0.3), true)
			draw_rect(rect, Color("#6ed08b"), false, 2.0)

	if is_instance_valid(field):
		var bar_rect := field.get_field_rect_local()
		var bar_w: float = bar_rect.size.x
		var bar_x: float = bar_rect.position.x
		var bar_y: float = bar_rect.end.y + 12.0
		draw_rect(Rect2(bar_x, bar_y, bar_w, 12), Color("#1a2533"), true)
		draw_rect(Rect2(bar_x, bar_y, bar_w * (base_hp / base_max_hp), 12), Color("#d89246"), true)
		draw_string(ThemeDB.fallback_font, Vector2(bar_x, bar_y - 18), "车辆耐久", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#d8e4f0"))
