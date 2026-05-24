extends Node2D
class_name NightTdController

signal session_finished(result: Dictionary)

enum Phase { PLACE, COMBAT, RESULT }

@export var placement_time_sec: float = 180.0
@export var base_max_hp: float = 100.0
@export var spawn_interval_sec: float = 1.2
@export var use_wave_plan: bool = true
@export_file("*.json") var wave_plan_path: String = "res://data/night_td/waves/night_wave_demo.json"
@export var debug_draw_routes: bool = true
@export var td_base_deploy: int = 14

@onready var field: NightTdField = $Field
@onready var hud: CanvasLayer = $Hud

var phase: int = Phase.PLACE
var show_route_overlay: bool = false
var _allow_placement := true
var _starting_inventory: int = 0
var _exploration_inventory: int = 0
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
var wave_plan: NightTdWavePlan
var _wave_scheduler: NightTdWaveScheduler
var _spawn_timer: float = 0.0
var _enemies_spawned: int = 0
var _enemies_killed: int = 0
var _enemies_reached: int = 0
var _combat_done := false
var _last_result: Dictionary = {}
var _projectiles: Array[Dictionary] = []


func _ready() -> void:
	visible = false
	if is_instance_valid(field):
		field.bind_controller(self)
		field.cell_clicked.connect(_on_cell_clicked)
		field.cell_right_clicked.connect(_on_cell_right_clicked)
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
		Phase.RESULT:
			pass
	if is_instance_valid(field):
		field.queue_redraw()
	queue_redraw()


func start_session(
	inventory: int,
	diff: int,
	day: int,
	allow_placement: bool = true,
	vehicle_hp: float = -1.0,
	vehicle_hp_max: float = -1.0,
) -> void:
	_allow_placement = allow_placement
	_exploration_inventory = maxi(inventory, 0)
	_starting_inventory = _exploration_inventory
	backpack_remaining = _compute_deploy_budget()
	resources_spent = 0
	difficulty = diff
	day_index = day
	if vehicle_hp_max > 0.0:
		base_max_hp = vehicle_hp_max
	if vehicle_hp >= 0.0:
		base_hp = clampf(vehicle_hp, 0.0, base_max_hp)
	else:
		base_hp = base_max_hp
	placement_remaining = placement_time_sec if allow_placement else 0.0
	_selected_tower = "jammer"
	_towers.clear()
	_enemies.clear()
	_projectiles.clear()
	_wave_queue = _build_wave_queue()
	_wave_scheduler = NightTdWaveScheduler.new()
	wave_plan = null
	if use_wave_plan:
		wave_plan = NightTdWavePlan.load_from_json(wave_plan_path)
		_wave_scheduler.build_from_plan(wave_plan, difficulty, day_index)
	else:
		_wave_scheduler.build_legacy_queue(_wave_queue)
	_spawn_timer = 0.0
	_enemies_spawned = 0
	_enemies_killed = 0
	_enemies_reached = 0
	_combat_done = false
	_last_result = {}
	phase = Phase.PLACE if allow_placement and placement_time_sec > 0.0 else Phase.COMBAT
	show_route_overlay = phase == Phase.PLACE
	visible = true
	if is_instance_valid(hud):
		hud.show_session_ui()
		hud.set_resources(backpack_remaining, resources_spent)
		if phase == Phase.PLACE:
			hud.set_place_mode(true)
			hud.set_phase_text("夜晚塔防 · 布防阶段")
			hud.set_placement_timer(placement_remaining)
			hud.set_hint(
				"俯视图：红线为敌人路线（接敌后隐藏）。左键放置设施、右键撤销。\n"
				+ "右侧列出每种设施消耗的部署点与效果，选中后点地图格子放置。"
			)
		else:
			hud.set_place_mode(false)
			hud.set_combat_mode()
			hud.set_phase_text("夜晚塔防 · 接敌中")
			hud.set_hint("没有进入布防模式，敌人将直接来袭。")
		hud.clear_log()
	_update_hud_tools()


func _compute_deploy_budget() -> int:
	var pts := td_base_deploy + day_index * 3
	match difficulty:
		0:
			pts += 2
		2:
			pts -= 2
	return maxi(pts, 10)


func _update_hud_tools() -> void:
	if is_instance_valid(hud):
		hud.refresh_tool_buttons()


func hide_session() -> void:
	phase = Phase.PLACE
	show_route_overlay = false
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
	if _wave_scheduler != null:
		for spec in _wave_scheduler.tick(delta):
			_spawn_from_spec(spec)
	else:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0 and _wave_queue.size() > 0:
			_spawn_next_enemy()
			_spawn_timer = spawn_interval_sec
	_update_enemies(delta)
	_update_towers(delta)
	if base_hp <= 0.0:
		_end_combat_vehicle_destroyed()
		return
	if is_instance_valid(hud) and int(Engine.get_frames_drawn()) % 15 == 0:
		var total := _wave_scheduler.total_spawn_events if _wave_scheduler != null else _enemies_spawned + _wave_queue.size()
		var remain := _wave_scheduler.remaining_count() if _wave_scheduler != null else _wave_queue.size()
		hud.set_combat_status("波次 %d/%d · 待刷 %d · 场上 %d 敌 · 车辆 HP %.0f" % [
			_enemies_spawned, total, remain, _enemies.size(), base_hp
		])
	var waves_done := false
	if _wave_scheduler != null:
		waves_done = _wave_scheduler.is_finished(_enemies.size())
	else:
		waves_done = _wave_queue.is_empty()
	if waves_done and _enemies.is_empty() and _enemies_spawned > 0:
		_end_combat()


func _spawn_next_enemy() -> void:
	if _wave_queue.is_empty():
		return
	var type_id: String = _wave_queue.pop_front()
	_spawn_from_spec({"enemy": type_id, "move_speed": -1.0, "route_id": "", "spawn_point": ""})


func _spawn_from_spec(spec: Dictionary) -> void:
	var type_id: String = str(spec.get("enemy", "drone"))
	var def: Dictionary = NightTdDefs.get_enemy_def(type_id)
	if def.is_empty():
		return
	var move_speed := float(spec.get("move_speed", -1.0))
	if move_speed <= 0.0:
		move_speed = float(def.get("speed", 50))
	# Speed jitter ±15% so enemies in the same wave spread out
	move_speed *= randf_range(0.85, 1.15)
	var route_id := str(spec.get("route_id", ""))
	# Randomly pick from main route + alternates for variety
	var alt_routes: Array = spec.get("alternate_routes", [])
	if alt_routes is Array and not alt_routes.is_empty():
		var candidates: Array = [route_id]
		for alt in alt_routes:
			if alt is String and alt != "":
				candidates.append(alt)
		route_id = str(candidates[randi_range(0, candidates.size() - 1)])
	var spawn_point := str(spec.get("spawn_point", ""))
	var spawn_cell := _resolve_spawn_cell(route_id, spawn_point)
	var path_runtime := _build_runtime_path(route_id, spawn_cell)
	var path_index := 0
	if path_runtime.size() > 1 and path_runtime[0]["cell"] == spawn_cell:
		path_index = 1
	var pos: Vector2 = field.cell_to_world(spawn_cell)
	_enemies.append({
		"type": type_id,
		"pos": pos,
		"hp": float(def.get("hp", 20)),
		"max_hp": float(def.get("hp", 20)),
		"speed": move_speed,
		"base_damage": float(def.get("base_damage", 5)),
		"color": def.get("color", Color.WHITE),
		"radius": float(def.get("radius", 10)),
		"path_waypoints": path_runtime,
		"path_index": path_index,
		"wait_remaining": 0.0,
		"route_finished": path_runtime.is_empty(),
		"move_dir": Vector2.LEFT,
	})
	_enemies_spawned += 1
	if is_instance_valid(hud):
		var route_hint := (" · 路线 %s" % route_id) if route_id != "" else ""
		hud.append_log("敌袭：%s 自 %s 出现%s" % [
			def.get("name", type_id),
			NightTdWavePlan.cell_label(spawn_cell),
			route_hint,
		])


func _resolve_spawn_cell(route_id: String, spawn_point: String) -> Vector2i:
	if wave_plan != null:
		return wave_plan.pick_spawn_cell(route_id, spawn_point, field.grid_cols, field.grid_rows)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	match rng.randi_range(0, 3):
		0:
			return Vector2i(rng.randi_range(0, field.grid_cols - 1), 0)
		1:
			return Vector2i(rng.randi_range(0, field.grid_cols - 1), field.grid_rows - 1)
		2:
			return Vector2i(0, rng.randi_range(0, field.grid_rows - 1))
		_:
			return Vector2i(field.grid_cols - 1, rng.randi_range(0, field.grid_rows - 1))


func _build_runtime_path(route_id: String, spawn_cell: Vector2i) -> Array:
	var runtime: Array = []
	if wave_plan == null or route_id == "":
		return runtime
	var tile_size := field.get_layout_tile_size()
	var jitter_range := tile_size * 0.22
	for wp in wave_plan.get_route_waypoints(route_id):
		var cell: Vector2i = wp["cell"]
		var world_pos := field.cell_to_world(cell)
		# Add small random jitter so enemies on the same route don't visually overlap
		world_pos += Vector2(randf_range(-jitter_range, jitter_range), randf_range(-jitter_range, jitter_range))
		runtime.append({
			"cell": cell,
			"world": world_pos,
			"standby_sec": float(wp.get("standby_sec", 0.0)),
		})
	if runtime.is_empty():
		runtime.append({
			"cell": spawn_cell,
			"world": field.cell_to_world(spawn_cell),
			"standby_sec": 0.0,
		})
	return runtime


func _update_enemies(delta: float) -> void:
	var base_pos: Vector2 = field.get_vehicle_center_world()
	var arrive_radius := maxf(field.get_layout_tile_size() * 0.38, 16.0)
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
		var move_dir := Vector2.ZERO
		if not bool(enemy.get("route_finished", true)):
			var wait_left := float(enemy.get("wait_remaining", 0.0))
			if wait_left > 0.0:
				enemy["wait_remaining"] = maxf(wait_left - delta, 0.0)
			else:
				var waypoints: Array = enemy.get("path_waypoints", [])
				var path_index: int = int(enemy.get("path_index", 0))
				if path_index >= waypoints.size():
					enemy["route_finished"] = true
				else:
					var wp: Dictionary = waypoints[path_index]
					var target: Vector2 = wp["world"]
					if pos.distance_to(target) <= arrive_radius:
						var standby := float(wp.get("standby_sec", 0.0))
						if standby > 0.0:
							enemy["wait_remaining"] = standby
						enemy["path_index"] = path_index + 1
					else:
						move_dir = target - pos
						if move_dir.length_squared() > 0.0001:
							move_dir = move_dir.normalized()
							pos += move_dir * float(enemy["speed"]) * slow * delta
							enemy["pos"] = pos
		if not bool(enemy.get("route_finished", true)):
			pos = enemy["pos"]
			cell = field.world_to_cell(pos)
		else:
			move_dir = base_pos - pos
			if move_dir.length_squared() > 0.0001:
				move_dir = move_dir.normalized()
				pos += move_dir * float(enemy["speed"]) * slow * delta
			enemy["pos"] = pos
			cell = field.world_to_cell(pos)
		if move_dir.length_squared() > 0.0001:
			enemy["move_dir"] = move_dir
		for tower in _towers:
			if tower.get("removed", false):
				continue
			if tower["type"] == "trap" and tower["cell"] == field.world_to_cell(pos):
				_trigger_trap(tower, enemy)
		if pos.distance_to(base_pos) < 28.0:
			var loss := maxi(int(round(float(enemy["base_damage"]) * 0.5)), 1)
			backpack_remaining = maxi(backpack_remaining - loss, 0)
			base_hp = maxf(base_hp - float(enemy["base_damage"]), 0.0)
			_enemies_reached += 1
			to_remove.append(i)
			if is_instance_valid(hud):
				hud.set_resources(backpack_remaining, resources_spent)
				hud.append_log("警告：敌人突破防线，物资损耗 %d！" % loss)
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
				_projectiles.append({
					"from": tower["world_pos"],
					"to": enemy["pos"],
					"life": 0.16,
					"color": tdef.get("color", Color.WHITE),
				})
				tower["cooldown"] = float(tdef.get("fire_interval", 0.8))
				if is_instance_valid(hud) and randf() < 0.15:
					hud.append_log("信标命中 %s" % NightTdDefs.get_enemy_def(enemy["type"]).get("name", ""))

	for i in range(_projectiles.size() - 1, -1, -1):
		_projectiles[i]["life"] = float(_projectiles[i]["life"]) - delta
		if float(_projectiles[i]["life"]) <= 0.0:
			_projectiles.remove_at(i)


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


func _on_cell_right_clicked(cell: Vector2i) -> void:
	if phase != Phase.PLACE:
		return
	var removed := _remove_tower_at_cell(cell)
	if removed and is_instance_valid(hud):
		hud.set_resources(backpack_remaining, resources_spent)
		hud.append_log("已撤销 %s" % removed)
	elif is_instance_valid(hud):
		hud.append_log("该格没有可撤销的防御")


func _remove_tower_at_cell(cell: Vector2i) -> String:
	for tower in _towers:
		if tower.get("removed", false):
			continue
		if tower["cell"] != cell:
			continue
		var tdef: Dictionary = NightTdDefs.get_tower_def(str(tower["type"]))
		var refund: int = int(tdef.get("cost", 1))
		backpack_remaining += refund
		resources_spent = maxi(resources_spent - refund, 0)
		tower["removed"] = true
		return str(tdef.get("name", tower["type"]))
	return ""


func _on_tower_selected(type_id: String) -> void:
	_selected_tower = type_id


func _begin_combat() -> void:
	if phase == Phase.COMBAT:
		return
	phase = Phase.COMBAT
	show_route_overlay = false
	_spawn_timer = 0.0
	if is_instance_valid(field):
		field.queue_redraw()
	if is_instance_valid(hud):
		hud.set_combat_mode()
		hud.set_phase_text("夜晚塔防 · 接敌中")
		hud.set_hint("接敌中：敌人头顶箭头为当前前进方向，设施自动开火/阻挡。")
		var total := _wave_scheduler.total_spawn_events if _wave_scheduler != null else _enemies_spawned + _wave_queue.size()
		hud.set_combat_status("波次 %d/%d · 场上 %d 敌" % [_enemies_spawned, total, _enemies.size()])
		hud.append_log("—— 夜间威胁来袭 ——")


func _end_combat_vehicle_destroyed() -> void:
	if _combat_done:
		return
	_combat_done = true
	_last_result = _build_result()
	_last_result["outcome"] = "vehicle_destroyed"
	_last_result["message"] = "车辆防线被突破，乘员失联。本局勘探终止。"
	base_hp = 0.0
	phase = Phase.RESULT
	if is_instance_valid(hud):
		hud.show_result(str(_last_result.get("message", "")))
		hud.set_phase_text("夜晚塔防 · 车辆损毁")
		hud.set_combat_status("车辆 HP 归零")


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
	var loss_severity: String = "none"
	var fuel_loss: float = 0.0
	var msg: String = ""
	if base_hp >= 70.0:
		outcome = "success"
		loss_severity = "none"
		msg = "防线稳固！车辆完好，今夜安全度过。"
	elif base_hp >= 35.0:
		outcome = "partial"
		loss_severity = "partial"
		fuel_loss = 8.0
		msg = "部分敌人突破防线，损失少量物资（车辆 HP %.0f/%.0f）。" % [base_hp, base_max_hp]
	else:
		outcome = "fail"
		loss_severity = "severe"
		fuel_loss = 18.0
		msg = "防线失守！车辆严重受损（HP %.0f/%.0f）。" % [base_hp, base_max_hp]
	var inv_loss: int = resources_spent
	if inv_loss > 0:
		msg += " 物资损耗 %d 件。" % inv_loss
	return {
		"outcome": outcome,
		"message": msg,
		"inventory_remaining": maxi(_exploration_inventory - inv_loss, 0),
		"inventory_loss": inv_loss,
		"loss_severity": loss_severity,
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
