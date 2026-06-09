extends Node2D
class_name NightTdController

signal session_finished(result: Dictionary)
signal enemy_breached(enemy_type: String, pos: Vector2)

# -- 事件日志（每步资源变动，用于结算明细）--
var _event_log: Array[Dictionary] = []       # {time, type, detail, resource_change}
var _converted_survivors: Array[Dictionary] = []  # {enemy_type, parts_value}

enum Phase { PLACE, COMBAT, RESULT }

@export var placement_time_sec: float = 180.0
@export var base_max_hp: float = 100.0
@export var spawn_interval_sec: float = 1.2
@export var use_wave_plan: bool = true
@export_file("*.json") var wave_plan_path: String = "res://data/night_td/waves/night_wave_demo.json"
@export var debug_draw_routes: bool = false   # 默认关闭流场箭头，仅在调试时开启（极耗性能）
@export var td_base_deploy: int = 14

@onready var field: NightTdField = $Field
@onready var hud: CanvasLayer = $Hud

var phase: int = Phase.PLACE
var show_route_overlay: bool = false
var show_overlay: bool = false   # 热力图/指挥官覆盖层开关（按钮切换）
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

# --- 流场寻路（P1）---
const SEPARATION_WEIGHT := 0.6   # 分离转向权重：防止同场单位排成一条龙
const BARRIER_FLOW_COST := 6.0   # 路障作为软性高代价格：流场优先绕行，被逼到墙角才硬挤
var _flow: NightTdFlowField = null
var _flow_dirty := true
var _flow_rebuild_cooldown := 0.0    # 流场重建最小间隔（秒），防止 brownout 振荡导致每帧 Dijkstra
const FLOW_REBUILD_INTERVAL := 0.25

# --- 威胁影响图（P2）---
const ENERGY_CONFIG_PATH := "res://data/night_td/energy.json"
var _influence: NightTdInfluence = null
var _display_influence: NightTdInfluence = null   # 独立的热力图缓存（布防/战斗两阶段均可查询）
var _display_influence_dirty := true
var _danger_weight := 0.0   # 由难度决定：0=无视火力（简单），高=主动绕开杀伤区（困难）

# --- 指挥官 / 牧羊人 AI（P3）---
const TOWER_MELEE_DPS := 26.0   # 攻坚组贴脸时对塔的近战 DPS
const BASE_DAMAGE_FACTOR := 0.12   # 突破时对车辆的伤害系数（敌人重在抢物资，不在拆车）
var _commander: NightTdCommander = null

# --- 能源系统（P4）---
var _energy: NightTdEnergy = null
var _next_tower_id := 1   # 每座塔分配稳定 id，用于能源/UI 索引

# --- 黑入系统（P5）---
const SHEPHERD_DEGRADE_SEC := 8.0   # 牧羊者被策反/击杀后，敌方 AI 退化时长
var _next_enemy_id := 1
var _selected_hacker_id := -1       # 已点选、等待指派目标的入侵天线
var _shepherd_degrade_until := 0.0  # 此刻之前指挥官退化为 base-rush
var _combat_time := 0.0

# --- 资源经济（P6）---
# _local_backpack 是白天背包的快照副本（非 live 引用），TD 期间所有建造/回收/偷窃
# 都只操作这份副本；夜末通过 result["final_backpack_dict"] 把最终状态返回给白天。
var _local_backpack: InventoryData = null
var _salvage_pending: Dictionary = {}   # 夜末待结算的废料掉落 item_id -> count
var _session_paused := false             # 由 GameManager / 父场景控制暂停
var _breach_losses: Dictionary = {}      # 突破被拖走的物资 item_id -> count（夜末汇报）
var _combat_tower_ids: Array[int] = []   # 进入战斗时的塔 id 快照（排除布防阶段已撤销的塔）
var _redraw_frame := 0                   # 帧计数器，用于节流 queue_redraw
var _session_options: Dictionary = {}
var _session_kind: String = "normal"
var _phase_title_override: String = ""
var _no_day_advance := false


func _ready() -> void:
	visible = false
	if is_instance_valid(field):
		field.bind_controller(self)
		field.cell_clicked.connect(_on_cell_clicked)
		field.cell_right_clicked.connect(_on_cell_right_clicked)
		field.cell_combat_clicked.connect(_on_cell_combat_clicked)
	if is_instance_valid(hud):
		hud.tower_selected.connect(_on_tower_selected)
		hud.start_wave_pressed.connect(_begin_combat)
		hud.continue_pressed.connect(_finish_session)
		hud.tower_power_step.connect(_on_tower_power_step)
		hud.power_tower_selected.connect(_on_power_tower_selected)
		hud.overlay_toggled.connect(_on_overlay_toggled)


func set_session_paused(paused: bool) -> void:
	_session_paused = paused

func _process(delta: float) -> void:
	if _session_paused:
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
	# 节流重绘：每 3 帧 (~20fps) 才触发一次 _draw，避免 60fps 下 GPU 被 2000+ 绘制命令淹没。
	# 游戏逻辑仍以完整帧率运行，只降低渲染刷新频率。
	_redraw_frame = (_redraw_frame + 1) % 3
	if _redraw_frame == 0:
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
	backpack_snapshot: Dictionary = {},
	session_options: Dictionary = {},
) -> void:
	_session_options = session_options.duplicate(true)
	_session_kind = str(_session_options.get("kind", "normal"))
	_phase_title_override = str(_session_options.get("phase_title", ""))
	_no_day_advance = bool(_session_options.get("no_day_advance", false))
	_allow_placement = allow_placement
	# 从快照创建本地背包副本（切断对白天状态的引用）
	_local_backpack = InventoryData.new()
	if not backpack_snapshot.is_empty():
		_local_backpack.load_from_dictionary(backpack_snapshot)
	_salvage_pending = {}
	_breach_losses = {}
	_event_log.clear()
	_converted_survivors.clear()
	_combat_tower_ids.clear()
	_exploration_inventory = maxi(inventory, 0)
	_starting_inventory = _exploration_inventory
	backpack_remaining = _compute_deploy_budget()
	resources_spent = 0
	difficulty = diff
	day_index = day
	var wave_override := str(_session_options.get("wave_plan_path", ""))
	wave_plan_path = wave_override if wave_override != "" else _resolve_wave_plan_path(day, diff)
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
	if _flow == null:
		_flow = NightTdFlowField.new()
	if _influence == null:
		_influence = NightTdInfluence.new()
	_danger_weight = _load_danger_weight(diff)
	if _commander == null:
		_commander = NightTdCommander.new()
	_commander.configure(diff, field.grid_cols, field.grid_rows, field.vehicle_cells)
	if _energy == null:
		_energy = NightTdEnergy.load_config(ENERGY_CONFIG_PATH)
	_energy.reset()
	_next_tower_id = 1
	_next_enemy_id = 1
	_selected_hacker_id = -1
	_shepherd_degrade_until = 0.0
	_combat_time = 0.0
	_flow_dirty = true
	_flow_rebuild_cooldown = 0.0
	_display_influence_dirty = true
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
	show_overlay = false   # 覆盖层默认关闭，玩家可通过按钮开启
	visible = true
	if is_instance_valid(hud):
		hud.show_session_ui()
		_refresh_resource_hud()
		if phase == Phase.PLACE:
			hud.set_place_mode(true)
			hud.set_phase_text(_session_phase_title("布防阶段"))
			hud.set_placement_timer(placement_remaining)
			if _local_backpack != null:
				hud.set_hint(
					"俯视图：青色箭头为敌群涌动方向。左键放置设施、右键撤销（资源全额退还）。\n"
					+ "用背包里的零件/废料建造设施；幸存设施夜末回收，被毁则折成少量废料。"
				)
			else:
				hud.set_hint(
					"俯视图：青色箭头为敌群涌动方向。左键放置设施、右键撤销。\n"
					+ "右侧列出每种设施消耗的部署点与效果，选中后点地图格子放置。"
				)
		else:
			hud.set_place_mode(false)
			hud.set_combat_mode()
			hud.set_phase_text(_session_phase_title("接敌中"))
			hud.set_hint("没有进入布防模式，敌人将直接来袭。")
		hud.clear_log()
	_update_hud_tools()


func _session_phase_title(suffix: String) -> String:
	if _phase_title_override != "":
		return "%s · %s" % [_phase_title_override, suffix]
	return "夜晚塔防 · %s" % suffix


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
	show_overlay = false
	_combat_done = false
	visible = false
	_towers.clear()
	_enemies.clear()
	# 清除污流场数据和显示缓存，防止下次布防阶段绘制过期箭头/热力图
	_flow = null
	_display_influence = null
	_display_influence_dirty = true
	if is_instance_valid(hud):
		hud.hide_session_ui()


func _process_place(delta: float) -> void:
	placement_remaining = maxf(placement_remaining - delta, 0.0)
	if is_instance_valid(hud):
		hud.set_placement_timer(placement_remaining)
	if placement_remaining <= 0.0:
		_begin_combat()



func _count_hostiles() -> int:
	var n := 0
	for e in _enemies:
		if str(e.get("faction", "enemy")) == "enemy":
			n += 1
	return n
func _process_combat(delta: float) -> void:
	if _combat_done:
		return
	_combat_time += delta
	_flow_rebuild_cooldown = maxf(_flow_rebuild_cooldown - delta, 0.0)
	if _wave_scheduler != null:
		for spec in _wave_scheduler.tick(delta):
			_spawn_from_spec(spec)
	else:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0 and _wave_queue.size() > 0:
			_spawn_next_enemy()
			_spawn_timer = spawn_interval_sec
	_update_energy(delta)
	_update_commander(delta)
	_update_enemy_specials(delta)
	_update_enemy_auras(delta)
	_update_hackers(delta)
	_update_enemies(delta)
	_update_towers(delta)
	if base_hp <= 0.0:
		_end_combat_vehicle_destroyed()
		return
	if is_instance_valid(hud) and int(Engine.get_frames_drawn()) % 15 == 0:
		var total := _wave_scheduler.total_spawn_events if _wave_scheduler != null else _enemies_spawned + _wave_queue.size()
		var remain := _wave_scheduler.remaining_count() if _wave_scheduler != null else _wave_queue.size()
		hud.set_combat_status("波次 %d/%d · 待刷 %d · 场上 %d 敌 · 车辆 HP %.0f" % [
			_enemies_spawned, total, remain, _count_hostiles(), base_hp
		])
	var waves_done := false
	if _wave_scheduler != null:
		waves_done = _wave_scheduler.is_finished(_count_hostiles())
	else:
		waves_done = _wave_queue.is_empty()
	if waves_done and _count_hostiles() == 0 and _enemies_spawned > 0:
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
	var spawn_point := str(spec.get("spawn_point", ""))
	var spawn_side := str(spec.get("spawn_side", ""))
	var spawn_cell := Vector2i.ZERO
	var pos: Vector2
	if spec.has("world_pos"):
		pos = spec["world_pos"] as Vector2
		spawn_cell = field.world_to_cell(pos)
	else:
		# 出生点：按 spawn_side 限制方向（集中威胁到 1-2 个正面），否则四面边缘随机
		spawn_cell = _resolve_spawn_cell(route_id, spawn_point, spawn_side)
		pos = _offgrid_spawn_pos(spawn_cell)
	var eid := _next_enemy_id
	_next_enemy_id += 1
	_enemies.append({
		"eid": eid,
		"type": type_id,
		"name": str(def.get("name", type_id)),
		"pos": pos,
		"hp": float(def.get("hp", 20)),
		"max_hp": float(def.get("hp", 20)),
		"speed": move_speed,
		"base_damage": float(def.get("base_damage", 5)),
		"color": def.get("color", Color.WHITE),
		"radius": float(def.get("radius", 10)),
		"move_dir": Vector2.LEFT,
		"faction": "enemy",
		"hacked_by": -1,
		"is_shepherd": bool(def.get("is_shepherd", false)),
		"hack_resist": float(def.get("hack_resist", 1.0)),
		"hack_immune": bool(def.get("hack_immune", false)),
		"effect_immune": bool(def.get("effect_immune", false)),
		"breach_damage_factor": float(def.get("breach_damage_factor", -1.0)),
		"summon_enemy": str(def.get("summon_enemy", "")),
		"summon_interval_sec": float(def.get("summon_interval_sec", 0.0)),
		"summon_timer": float(def.get("summon_interval_sec", 0.0)),
		"max_summoned_alive": int(def.get("max_summoned_alive", 0)),
		"summoned_by": int(spec.get("summoned_by", -1)),
		"heal_radius": float(def.get("heal_radius", 0.0)),
		"heal_per_sec": float(def.get("heal_per_sec", 0.0)),
	})
	_enemies_spawned += 1
	if is_instance_valid(hud):
		var route_hint := (" · 路线 %s" % route_id) if route_id != "" else ""
		if spec.has("world_pos"):
			hud.append_log("增援：%s 被召入战场" % def.get("name", type_id))
		else:
			hud.append_log("敌袭：%s 自 %s 出现%s" % [
				def.get("name", type_id),
				NightTdWavePlan.cell_label(spawn_cell),
				route_hint,
			])


func _resolve_spawn_cell(_route_id: String, _spawn_point: String, spawn_side: String = "") -> Vector2i:
	# 出生点：spawn_side 限制方向（使一段时间内敌人集中从 1-2 个正面来袭）
	# "north"=上, "south"=下, "east"=右, "west"=左, ""=四面随机
	var cols := field.grid_cols
	var rows := field.grid_rows
	var side := randi_range(0, 3)
	if spawn_side != "":
		match spawn_side:
			"north": side = 0
			"south": side = 1
			"west":  side = 2
			"east":  side = 3
	match side:
		0:  # 上边缘
			return Vector2i(randi_range(0, cols - 1), 0)
		1:  # 下边缘
			return Vector2i(randi_range(0, cols - 1), rows - 1)
		2:  # 左边缘
			return Vector2i(0, randi_range(0, rows - 1))
		_:  # 右边缘
			return Vector2i(cols - 1, randi_range(0, rows - 1))


## 把边缘格的世界坐标再往网格外推约 1.5 格，让敌人从画面外滑入而非凭空出现在格内。
func _offgrid_spawn_pos(edge_cell: Vector2i) -> Vector2:
	var cols := field.grid_cols
	var rows := field.grid_rows
	var tile := field.get_layout_tile_size()
	var out := Vector2.ZERO
	if edge_cell.y == 0:
		out = Vector2(0, -1.5 * tile)
	elif edge_cell.y == rows - 1:
		out = Vector2(0, 1.5 * tile)
	elif edge_cell.x == 0:
		out = Vector2(-1.5 * tile, 0)
	elif edge_cell.x == cols - 1:
		out = Vector2(1.5 * tile, 0)
	return field.cell_to_world(edge_cell) + out


func _update_enemy_specials(delta: float) -> void:
	var summon_specs: Array[Dictionary] = []
	for enemy in _enemies:
		if str(enemy.get("faction", "enemy")) != "enemy" or float(enemy.get("hp", 0.0)) <= 0.0:
			continue
		var summon_type := str(enemy.get("summon_enemy", ""))
		var interval := float(enemy.get("summon_interval_sec", 0.0))
		if summon_type == "" or interval <= 0.0:
			continue
		var max_alive := int(enemy.get("max_summoned_alive", 0))
		if max_alive > 0 and _count_summons_alive(int(enemy.get("eid", -1))) >= max_alive:
			continue
		var timer := maxf(float(enemy.get("summon_timer", interval)) - delta, 0.0)
		enemy["summon_timer"] = timer
		if timer > 0.0:
			continue
		enemy["summon_timer"] = interval
		var base_pos: Vector2 = enemy["pos"]
		var offset := Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * randf_range(24.0, 52.0)
		summon_specs.append({
			"enemy": summon_type,
			"world_pos": base_pos + offset,
			"summoned_by": int(enemy.get("eid", -1)),
			"move_speed": -1.0,
		})
	for spec in summon_specs:
		_spawn_from_spec(spec)


func _count_summons_alive(parent_eid: int) -> int:
	var count := 0
	for enemy in _enemies:
		if int(enemy.get("summoned_by", -1)) == parent_eid and str(enemy.get("faction", "enemy")) == "enemy" and float(enemy.get("hp", 0.0)) > 0.0:
			count += 1
	return count


func _update_enemy_auras(delta: float) -> void:
	for healer in _enemies:
		if str(healer.get("faction", "enemy")) != "enemy" or float(healer.get("hp", 0.0)) <= 0.0:
			continue
		var radius := float(healer.get("heal_radius", 0.0))
		var heal_per_sec := float(healer.get("heal_per_sec", 0.0))
		if radius <= 0.0 or heal_per_sec <= 0.0:
			continue
		var center: Vector2 = healer["pos"]
		var healer_eid := int(healer.get("eid", -1))
		for target in _enemies:
			if int(target.get("eid", -2)) == healer_eid:
				continue
			if str(target.get("faction", "enemy")) != "enemy" or float(target.get("hp", 0.0)) <= 0.0:
				continue
			if (target["pos"] as Vector2).distance_to(center) > radius:
				continue
			var max_hp := maxf(float(target.get("max_hp", 1.0)), 1.0)
			target["hp"] = minf(float(target.get("hp", max_hp)) + heal_per_sec * delta, max_hp)


func _slow_factor_at(pos: Vector2, enemy: Dictionary) -> float:
	if bool(enemy.get("effect_immune", false)):
		return 1.0
	var slow := 1.0
	for tower in _towers:
		if tower.get("removed", false):
			continue
		var tdef: Dictionary = NightTdDefs.get_tower_def(str(tower["type"]))
		if not bool(tdef.get("applies_slow", false)):
			continue
		var range_px := float(tdef.get("range", 0.0))
		if range_px <= 0.0 or (tower["world_pos"] as Vector2).distance_to(pos) > range_px:
			continue
		var scale := float(tower.get("power_scale", 1.0))
		if scale <= 0.05:
			continue
		var factor := clampf(float(tdef.get("slow_factor", 1.0)), 0.05, 1.0)
		var curve: Dictionary = tdef.get("power_curve", {})
		var extra := maxf(scale - 1.0, 0.0) * float(curve.get("slow_per_power", 0.0))
		slow = minf(slow, clampf(factor - extra, 0.05, 1.0))
	return slow


func _breach_damage_for(enemy: Dictionary) -> float:
	var override := float(enemy.get("breach_damage_factor", -1.0))
	if override >= 0.0:
		return base_max_hp * override
	return float(enemy["base_damage"]) * BASE_DAMAGE_FACTOR



func _update_enemies(delta: float) -> void:
	var base_pos: Vector2 = field.get_vehicle_center_world()
	# 流场按需重建（P1.3）：dirty 标记由放/拆塔、供电、黑入等触发。
	# 加冷却时间防止 brownout 振荡导致每帧 Dijkstra（504 格 × 5 场 = 极高开销）。
	if _flow_dirty and _flow_rebuild_cooldown <= 0.0:
		_rebuild_flow_field()
		_flow_rebuild_cooldown = FLOW_REBUILD_INTERVAL
	var to_remove: Array[int] = []
	for i in range(_enemies.size()):
		var enemy: Dictionary = _enemies[i]
		var pos: Vector2 = enemy["pos"]
		var cell: Vector2i = field.world_to_cell(pos)
		var is_ally := str(enemy.get("faction", "enemy")) == "ally"
		if is_ally:
			_update_ally(enemy, i, delta)
			if float(enemy.get("hp", 1.0)) <= 0.0:
				to_remove.append(i)
			continue
		var slow: float = _slow_factor_at(pos, enemy)
		for tower in _towers:
			if tower.get("removed", false):
				continue
			if tower["cell"] == cell and tower["type"] == "barrier":
				var bdef: Dictionary = NightTdDefs.get_tower_def("barrier")
				var sf := float(bdef.get("slow_factor", 0.0))
				if sf <= 0.0:
					slow = 0.0  # 路障完全阻挡：敌人停止移动，原地攻击路障
				else:
					slow = minf(slow, sf)
				_damage_tower(tower, float(enemy["base_damage"]) * delta)  # 敌人用自身攻击力破坏路障
		# 流场梯度 + 分离转向 + 每单位航向噪声，得到本帧前进方向。
		# 指挥官（P3）为编入小组的敌人提供专属目标流场（集结点/攻坚塔/佯攻基地）；
		# 无指挥或未编组时回退到主 base 流场。
		var flow_dir := Vector2.ZERO
		if _commander != null:
			flow_dir = _commander.dir_for(enemy, cell)
		if flow_dir == Vector2.ZERO:
			flow_dir = _flow_dir_at(pos, base_pos)
		var sep_dir := _separation_dir(i, pos, float(enemy["radius"]) * 2.2)
		var move_dir := flow_dir + sep_dir * SEPARATION_WEIGHT
		if move_dir.length_squared() > 0.0001:
			move_dir = move_dir.normalized()
			pos += move_dir * float(enemy["speed"]) * slow * delta
			enemy["pos"] = pos
			enemy["move_dir"] = move_dir
			cell = field.world_to_cell(pos)
		# 攻坚组贴到目标塔格/邻格时，对该塔施加近战伤害（P3.2：敌人能打塔）。
		if _commander != null:
			var atk_cell := _commander.attack_target_cell(enemy)
			if atk_cell.x >= 0 and _cell_adjacent_or_equal(cell, atk_cell):
				var tw := _tower_at_cell(atk_cell)
				if not tw.is_empty():
					_damage_tower(tw, TOWER_MELEE_DPS * delta)
		for tower in _towers:
			if tower.get("removed", false):
				continue
			if tower["type"] == "trap" and tower["cell"] == cell:
				_trigger_trap(tower, enemy)
		if pos.distance_to(base_pos) < 28.0:
			# 敌人是回收机器：突破后主要是"拖走物资"，对车辆只造成轻微伤害。
			# 这样资源匮乏的第一夜即使被突破，也是损失资源、而非车毁人亡。
			var loss := maxi(int(round(float(enemy["base_damage"]) * 0.5)), 1)
			backpack_remaining = maxi(backpack_remaining - loss, 0)
			_steal_resources(enemy)
			base_hp = maxf(base_hp - _breach_damage_for(enemy), 0.0)
			_enemies_reached += 1
			to_remove.append(i)
			_on_enemy_breached(enemy, pos)
			if is_instance_valid(hud):
				_refresh_resource_hud()
				var ename: String = str(enemy.get("name", enemy.get("type", "未知")))
				hud.append_log("[%.0f] ⚠ 突破! %s 抵达基地防线" % [_combat_time, ename], Color("#e87840"))
				hud.increment_breach_counter(_enemies_reached)
			if is_instance_valid(field) and field.has_method("play_breach_flash"):
				field.play_breach_flash(pos)
			_add_event_log("enemy_breached", str(enemy.get("type", "")), {})
		elif float(enemy["hp"]) <= 0.0:
			if bool(enemy.get("is_shepherd", false)):
				_trigger_shepherd_degrade("被击毁")
			_enemies_killed += 1
			var scrap_val := 2 if str(enemy.get("type","")) in ["heavy","shepherd"] else 1
			_add_salvage_drop(enemy)
			_add_event_log("enemy_killed", str(enemy.get("type", "")), {"scrap": scrap_val})
			if is_instance_valid(hud):
				var ename: String = str(enemy.get("name", enemy.get("type", "未知")))
				hud.append_log("[%.0f] 击毁%s +%d废料" % [_combat_time, ename, scrap_val], Color("#6ed08b"))
			to_remove.append(i)
	for idx in range(to_remove.size() - 1, -1, -1):
		_enemies.remove_at(to_remove[idx])


## 突破时从真实背包拖走物资：优先废料/木材，其次燃料/补给，最后才动零件（最珍贵）。
## 每次突破拿走 1~2 个非证据物品；记录到 _breach_losses 供夜末汇报。
func _steal_resources(enemy: Dictionary) -> void:
	if _local_backpack == null:
		return
	var take := 1
	if str(enemy.get("type", "")) == "scout":
		take = 2  # 回收侦察机专精搬运
	var priority := ["scrap", "wood", "fuel", "supplies", "parts"]
	for _n in range(take):
		var grabbed := false
		for item_id in priority:
			if _local_backpack.has(item_id, 1):
				_local_backpack.remove(item_id, 1)
				_breach_losses[item_id] = int(_breach_losses.get(item_id, 0)) + 1
				grabbed = true
				break
		if not grabbed:
			break


## 被策反的友军单位：扑向最近的敌方机器并近战；无敌可打则退回基地附近待命。
func _update_ally(ally: Dictionary, index: int, delta: float) -> void:
	var pos: Vector2 = ally["pos"]
	var tgt := NightTdHacking.pick_intercept_target(pos, _enemies)
	var move_dir := Vector2.ZERO
	if tgt >= 0:
		var foe: Dictionary = _enemies[tgt]
		var to_foe: Vector2 = foe["pos"] - pos
		if to_foe.length() <= float(ally["radius"]) + float(foe["radius"]) + 4.0:
			# 贴身互殴：双方按 base_damage 互掉血。
			foe["hp"] = float(foe["hp"]) - float(ally.get("base_damage", 5.0)) * 2.0 * delta
			ally["hp"] = float(ally.get("hp", 1.0)) - float(foe.get("base_damage", 5.0)) * 0.6 * delta
		else:
			move_dir = to_foe.normalized()
	else:
		# 无敌可拦：回到基地附近游弋。
		var to_base: Vector2 = field.get_vehicle_center_world() - pos
		if to_base.length() > 60.0:
			move_dir = to_base.normalized()
	if move_dir.length_squared() > 0.0001:
		var sep := _separation_dir(index, pos, float(ally["radius"]) * 2.2)
		move_dir = (move_dir + sep * SEPARATION_WEIGHT).normalized()
		pos += move_dir * float(ally["speed"]) * delta
		ally["pos"] = pos
		ally["move_dir"] = move_dir


func _update_towers(delta: float) -> void:
	for tower in _towers:
		if tower.get("removed", false):
			continue
		var tdef: Dictionary = NightTdDefs.get_tower_def(str(tower["type"]))
		# 数据驱动开火：任何有射程+伤害、且非黑入塔的设施都会自动攻击。
		# （路障 range=0、陷阱 fire_interval=999 由 one_shot 触发，均不在此开火。）
		if bool(tdef.get("is_hack_tower", false)):
			continue
		var range_px := float(tdef.get("range", 0.0))
		var fire_interval := float(tdef.get("fire_interval", 0.0))
		var base_damage := float(tdef.get("damage", 0.0))
		if range_px <= 0.0 or base_damage <= 0.0 or fire_interval <= 0.0 or fire_interval >= 900.0:
			continue
		var scale := float(tower.get("power_scale", 1.0))
		if scale <= 0.05:
			continue  # 断电塔停摆（其威胁场也已归零 → 敌人会重新涌入）
		tower["cooldown"] = maxf(float(tower["cooldown"]) - delta, 0.0)
		if float(tower["cooldown"]) > 0.0:
			continue
		var target: int = _find_enemy_in_range(tower["world_pos"], range_px)
		if target < 0:
			continue
		var enemy: Dictionary = _enemies[target]
		var curve: Dictionary = tdef.get("power_curve", {})
		var dmg_mul := maxf(1.0 + float(curve.get("damage_per_power", 0.0)) * (scale - 1.0), 0.05)
		var rate_mul := maxf(1.0 + float(curve.get("firerate_per_power", 0.0)) * (scale - 1.0), 0.2)
		var hit_dmg := base_damage * dmg_mul
		var splash := float(tdef.get("splash_radius", 0.0))
		if splash > 0.0:
			# 溅射：对目标点附近所有敌人造成伤害。
			var center: Vector2 = enemy["pos"]
			for foe in _enemies:
				if str(foe.get("faction", "enemy")) != "enemy":
					continue
				if (foe["pos"] as Vector2).distance_to(center) <= splash:
					foe["hp"] = float(foe["hp"]) - hit_dmg
		else:
			enemy["hp"] = float(enemy["hp"]) - hit_dmg
		_projectiles.append({
			"from": tower["world_pos"],
			"to": enemy["pos"],
			"life": 0.16,
			"color": tdef.get("color", Color.WHITE),
			"splash": splash,
		})
		tower["cooldown"] = fire_interval / rate_mul

	for i in range(_projectiles.size() - 1, -1, -1):
		_projectiles[i]["life"] = float(_projectiles[i]["life"]) - delta
		if float(_projectiles[i]["life"]) <= 0.0:
			_projectiles.remove_at(i)


func _find_enemy_in_range(origin: Vector2, range_px: float) -> int:
	var best: int = -1
	var best_dist: float = range_px
	for i in range(_enemies.size()):
		if str(_enemies[i].get("faction", "enemy")) != "enemy":
			continue  # 不打已策反的友军
		var dist: float = origin.distance_to(_enemies[i]["pos"])
		if dist <= best_dist:
			best_dist = dist
			best = i
	return best


func _cell_adjacent_or_equal(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1


func _tower_at_cell(cell: Vector2i) -> Dictionary:
	for tower in _towers:
		if tower.get("removed", false):
			continue
		if tower["cell"] == cell:
			return tower
	return {}


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
		# 路障消失 → 流场出现缺口；攻击塔消失 → 危险场出现缺口。两者都要重算。
		_mark_flow_dirty()


func _mark_flow_dirty() -> void:
	_flow_dirty = true
	_mark_display_influence_dirty()


## 重建流场（P1.3）：目标=车辆格；路障作为软性高代价格（见 _build_flow_extra_cost）。
## P2 会在 extra_cost 里叠加 危险权重×影响 实现"绕开火力"。
func _rebuild_flow_field() -> void:
	if _flow == null:
		_flow = NightTdFlowField.new()
	var cols := field.grid_cols
	var rows := field.grid_rows
	var goals: Array = []
	for cell in field.vehicle_cells:
		goals.append(cell)
	# 车辆格本身设为目标（积分=0），不计入障碍；返回基地的路径由此收敛。
	var extra := _build_flow_extra_cost(cols, rows)
	_flow.rebuild(cols, rows, goals, [], extra)
	_flow_dirty = false


## 能源每帧推进（P4）：结算反应堆电池，把每塔有效功率写回 power_scale。
## 功率变化会改变威胁场（影响敌人绕避），故有效系数显著变动时标记流场重算（P4.4）。
func _update_energy(delta: float) -> void:
	if _energy == null:
		return
	var upkeeps := {}
	for tower in _towers:
		if tower.get("removed", false):
			continue
		if not tower.has("id"):
			continue
		var tdef: Dictionary = NightTdDefs.get_tower_def(str(tower["type"]))
		var up := float(tdef.get("upkeep", 0.0))
		if up > 0.0:
			upkeeps[int(tower["id"])] = up
	_energy.tick(delta, upkeeps)
	var any_changed := false
	for tower in _towers:
		if tower.get("removed", false) or not tower.has("id"):
			continue
		var tdef: Dictionary = NightTdDefs.get_tower_def(str(tower["type"]))
		var new_scale := 1.0
		if float(tdef.get("upkeep", 0.0)) > 0.0:
			new_scale = _energy.effective_scale(int(tower["id"]))
		if absf(new_scale - float(tower.get("power_scale", 1.0))) > 0.05:
			any_changed = true
		tower["power_scale"] = new_scale
	if any_changed:
		_mark_flow_dirty()
	# 刷新 HUD 能源显示与始终在场的功率列表。
	if is_instance_valid(hud):
		hud.set_energy_status(_energy.current, _energy.capacity, _energy.current_demand(upkeeps))
		hud.update_power_list(_powered_tower_rows())


## 收集所有耗电塔供 HUD 功率列表显示。
func _powered_tower_rows() -> Array:
	var rows: Array = []
	for tower in _towers:
		if tower.get("removed", false) or not tower.has("id"):
			continue
		var tdef: Dictionary = NightTdDefs.get_tower_def(str(tower["type"]))
		if float(tdef.get("upkeep", 0.0)) <= 0.0:
			continue  # 不耗电的塔（路障/陷阱）不进调度列表
		var tid := int(tower["id"])
		rows.append({
			"id": tid,
			"name": str(tdef.get("name", tower["type"])),
			"level": _energy.power_level(tid) if _energy != null else 1.0,
			"scale": float(tower.get("power_scale", 1.0)),
		})
	return rows


## 玩家在战斗中调节某塔功率档（P4.3 UI 调用）。
func adjust_tower_power(tower_id: int, delta_step: float) -> void:
	if _energy == null:
		return
	_energy.step_power(tower_id, delta_step)
	_mark_flow_dirty()


## 黑入天线每帧推进（P5）：对各 hacker 的指定目标累计黑入进度，达标即策反。
func _update_hackers(delta: float) -> void:
	for tower in _towers:
		if tower.get("removed", false):
			continue
		var tdef: Dictionary = NightTdDefs.get_tower_def(str(tower["type"]))
		if not bool(tdef.get("is_hack_tower", false)):
			continue
		var target_eid := int(tower.get("target_eid", -1))
		if target_eid < 0:
			tower["hack_progress"] = 0.0
			continue
		var enemy := _enemy_by_eid(target_eid)
		# 目标已死/越界/已策反/超出射程 → 取消引导，进度清零。
		if enemy.is_empty() or str(enemy.get("faction", "enemy")) != "enemy" or bool(enemy.get("hack_immune", false)):
			tower["target_eid"] = -1
			tower["hack_progress"] = 0.0
			continue
		var dist: float = (tower["world_pos"] as Vector2).distance_to(enemy["pos"])
		if dist > float(tdef.get("range", 150.0)):
			tower["hack_progress"] = maxf(float(tower.get("hack_progress", 0.0)) - delta * 10.0, 0.0)
			continue
		enemy["hacked_by"] = int(tower.get("id", -1))
		var curve: Dictionary = tdef.get("power_curve", {})
		var inc := NightTdHacking.progress_delta(
			delta,
			float(tdef.get("hack_rate", 25.0)),
			float(tower.get("power_scale", 1.0)),
			float(curve.get("hackrate_per_power", 0.0)),
			float(enemy.get("hack_resist", 1.0)),
		)
		tower["hack_progress"] = float(tower.get("hack_progress", 0.0)) + inc
		if NightTdHacking.is_complete(float(tower["hack_progress"])):
			_convert_enemy(enemy)
			tower["target_eid"] = -1
			tower["hack_progress"] = 0.0


## 把一个敌方单位策反为我方。牧羊者被策反则触发敌方 AI 退化。
func _convert_enemy(enemy: Dictionary) -> void:
	enemy["faction"] = "ally"
	enemy["hacked_by"] = -1
	enemy["goal_key"] = "ally"
	enemy["_converted_at"] = _combat_time
	var ename := str(NightTdDefs.get_enemy_def(str(enemy["type"])).get("name", enemy["type"]))
	if is_instance_valid(hud):
		hud.append_log("[%.0f] 策反成功：%s 已倒戈！" % [_combat_time, ename], Color("#5ac8e0"))
	_add_event_log("enemy_converted", str(enemy.get("type", "")), {})
	if bool(enemy.get("is_shepherd", false)):
		_trigger_shepherd_degrade("策反")


func _on_enemy_breached(enemy: Dictionary, pos: Vector2) -> void:
	enemy_breached.emit(str(enemy.get("type", "")), pos)


func _add_event_log(ev_type: String, detail: String, resource_change: Dictionary) -> void:
	_event_log.append({
		"time": _combat_time,
		"type": ev_type,
		"detail": detail,
		"resource_change": resource_change.duplicate(),
	})


## 牧羊者被击杀/策反 → 敌方指挥能力短时退化为各自冲锋。
func _trigger_shepherd_degrade(reason: String) -> void:
	_shepherd_degrade_until = _combat_time + SHEPHERD_DEGRADE_SEC
	if _commander != null:
		_commander.set_suppressed(true)
	if is_instance_valid(hud):
		hud.append_log("牧羊者%s！敌群指挥中断 %.0f 秒。" % [reason, SHEPHERD_DEGRADE_SEC])


func _enemy_by_eid(eid: int) -> Dictionary:
	for e in _enemies:
		if int(e.get("eid", -1)) == eid:
			return e
	return {}


## 战斗中左键点选（功率调度走右侧常驻列表，这里只管黑入指派）：
##   1) 已选入侵天线 + 点到敌人 → 指派黑入目标。
##   2) 点到一座入侵天线 → 选中它，等待指派目标。
##   3) 其它 → 取消天线选择。
func _on_cell_combat_clicked(cell: Vector2i) -> void:
	if phase != Phase.COMBAT:
		return
	# 1) 已选入侵天线 + 点到敌人 → 指派目标
	if _selected_hacker_id >= 0:
		var enemy := _enemy_at_cell(cell)
		if not enemy.is_empty() and str(enemy.get("faction", "enemy")) == "enemy":
			if bool(enemy.get("hack_immune", false)):
				if is_instance_valid(hud):
					var immune_name := str(NightTdDefs.get_enemy_def(str(enemy["type"])).get("name", enemy["type"]))
					hud.append_log("%s 拒绝入侵：目标具备黑入免疫。" % immune_name, Color("#e87840"))
				_selected_hacker_id = -1
				return
			var hacker := _tower_by_id(_selected_hacker_id)
			if not hacker.is_empty():
				hacker["target_eid"] = int(enemy["eid"])
				hacker["hack_progress"] = float(hacker.get("hack_progress", 0.0))
				if is_instance_valid(hud):
					var en := str(NightTdDefs.get_enemy_def(str(enemy["type"])).get("name", enemy["type"]))
					hud.append_log("入侵天线锁定目标：%s" % en)
				return
	# 2) 点到入侵天线 → 选中等待指派
	var tw := _tower_at_cell(cell)
	if not tw.is_empty() and tw.has("id"):
		var tdef: Dictionary = NightTdDefs.get_tower_def(str(tw["type"]))
		if bool(tdef.get("is_hack_tower", false)):
			_selected_hacker_id = int(tw["id"])
			if is_instance_valid(hud):
				hud.append_log("已选入侵天线：再点击一个敌人指派黑入目标")
			return
	# 2.5) 点到有功耗的塔 → 高亮右侧电力面板对应行
	if not tw.is_empty() and tw.has("id") and _energy != null:
		if is_instance_valid(hud) and hud.has_method("highlight_power_row"):
			hud.highlight_power_row(int(tw["id"]))
			if is_instance_valid(field) and field.has_method("set_highlighted_tower"):
				field.set_highlighted_tower(int(tw["id"]))
	# 3) 其它 → 取消天线选择
	_selected_hacker_id = -1


func _on_power_tower_selected(tower_id: int) -> void:
	if is_instance_valid(field) and field.has_method("set_highlighted_tower"):
		field.set_highlighted_tower(tower_id)
	sync_selection_to_hud()


## 框选多塔后同步 HUD 电力面板高亮（field 调用）
func sync_selection_to_hud() -> void:
	if is_instance_valid(field) and field.has_method("get_selected_tower_ids"):
		var ids: Array[int] = field.get_selected_tower_ids()
		if is_instance_valid(hud) and hud.has_method("highlight_power_rows"):
			if ids.is_empty():
				hud.clear_power_highlight()
			else:
				hud.highlight_power_rows(ids)


## 覆盖层切换（HUD 按钮 → controller → field）
func _on_overlay_toggled(state: bool) -> void:
	show_overlay = state
	_display_influence_dirty = true
	if is_instance_valid(field):
		field.queue_redraw()


## 获取热力图数据（供 field 绘制）：{cols, rows, threat:PackedFloat32Array, max_threat:float}
func get_influence_display_data() -> Dictionary:
	_ensure_display_influence_fresh()
	if _display_influence == null:
		return {}
	var threat := _display_influence.get_threat_array()
	return {
		"cols": _display_influence.cols,
		"rows": _display_influence.rows,
		"threat": threat,
		"max_threat": _display_influence.max_threat(),
	}


## 确保热力图缓存有效：布防阶段按需重建，战斗阶段同步自流场用的 _influence。
func _ensure_display_influence_fresh() -> void:
	if _display_influence == null:
		_display_influence = NightTdInfluence.new()
		_display_influence_dirty = true

	if not _display_influence_dirty:
		return

	if phase == Phase.COMBAT:
		# 战斗阶段：直接复用流场重建时写入的 _influence（已经在 _build_danger_cost 更新）
		# 但 _influence 可能只在 _build_danger_cost 中才被 rebuild，这里做一次浅拷贝引用即可。
		# 若 _influence 尚未创建，则从当前塔数据重建。
		if _influence != null and _influence.cols > 0:
			# 从 _influence 复制威胁数据
			_display_influence.copy_from(_influence)
			_display_influence_dirty = false
			return

	# 布防阶段 / 无现有数据 → 从当前塔重建
	var tile := field.get_layout_tile_size() if is_instance_valid(field) else 48.0
	if tile <= 0.0:
		tile = 48.0
	var threats := _collect_tower_threats()
	_display_influence.rebuild(field.grid_cols, field.grid_rows, threats)
	_display_influence_dirty = false


## 布防/拆塔 / 供电变化时标记热力图脏。
func _mark_display_influence_dirty() -> void:
	_display_influence_dirty = true


## 获取指挥官可视化数据（供 field 绘制集结/突击标记）
func get_commander_display_data() -> Dictionary:
	if _commander == null or not _commander.enabled:
		return {}
	return {
		"missions": _commander.last_missions,
		"pressure_active": _commander.last_pressure_active,
		"assault_keys": _commander.last_assault_keys,
		"suppressed": _commander.suppressed,
	}


func _enemy_at_cell(cell: Vector2i) -> Dictionary:
	# 选最接近该格中心、且在格内的活体单位。
	var center := field.cell_to_world(cell)
	var best := {}
	var best_d := INF
	for e in _enemies:
		if float(e.get("hp", 0.0)) <= 0.0:
			continue
		if field.world_to_cell(e["pos"]) != cell:
			continue
		var d: float = center.distance_to(e["pos"])
		if d < best_d:
			best_d = d
			best = e
	return best


## HUD 功率列表里某塔的 +/− 按钮 → 调节该塔（若多选则调节所有选中塔）的功率。
func _on_tower_power_step(tower_id: int, delta_step: float) -> void:
	if is_instance_valid(field) and field.has_method("get_selected_tower_ids"):
		var sel: Array[int] = field.get_selected_tower_ids()
		if sel.size() > 1 and sel.has(tower_id):
			# Multi-select: apply to all selected towers
			for tid in sel:
				adjust_tower_power(tid, delta_step)
			return
	adjust_tower_power(tower_id, delta_step)


func _tower_by_id(tower_id: int) -> Dictionary:
	if tower_id < 0:
		return {}
	for tower in _towers:
		if tower.get("removed", false):
			continue
		if int(tower.get("id", -1)) == tower_id:
			return tower
	return {}


## 指挥官 AI 每帧驱动（P3）：构造上下文、节流重规划、把意图日志吐到 HUD。
func _update_commander(delta: float) -> void:
	if _commander == null or not _commander.enabled:
		return
	# 牧羊者失能计时结束 → 恢复指挥。
	if _commander.suppressed and _combat_time >= _shepherd_degrade_until:
		_commander.set_suppressed(false)
		if is_instance_valid(hud):
			hud.append_log("敌群重新建立指挥链。")
	var cols := field.grid_cols
	var rows := field.grid_rows
	var ctx := {
		"enemies": _enemies,
		"towers": _towers,
		"barrier_cost": _build_barrier_cost(cols, rows),
		"danger_cost": _build_danger_cost(cols, rows),
	}
	_commander.update(delta, ctx)
	if is_instance_valid(hud):
		for line: String in _commander.drain_logs():
			hud.append_log(line)


## 每格额外进入代价 = 路障软绕行 + 危险场（P2）。危险场让敌人在高难度下绕开炮塔射程。
func _build_flow_extra_cost(cols: int, rows: int) -> PackedFloat32Array:
	var extra := _build_barrier_cost(cols, rows)
	var danger := _build_danger_cost(cols, rows)
	if danger.size() == extra.size():
		for i in range(extra.size()):
			extra[i] += danger[i]
	return extra


## 路障软代价场（敌人优先绕行，被逼到墙角才硬挤）。
func _build_barrier_cost(cols: int, rows: int) -> PackedFloat32Array:
	var extra := PackedFloat32Array()
	extra.resize(cols * rows)
	for tower in _towers:
		if tower.get("removed", false):
			continue
		if str(tower["type"]) != "barrier":
			continue
		var c: Vector2i = tower["cell"]
		if c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows:
			extra[c.y * cols + c.x] += BARRIER_FLOW_COST
	return extra


## 危险场 = 威胁影响图 × 难度危险权重。难度0 时为全 0。
func _build_danger_cost(cols: int, rows: int) -> PackedFloat32Array:
	if _influence == null or _danger_weight <= 0.0:
		var zero := PackedFloat32Array()
		zero.resize(cols * rows)
		return zero
	_influence.rebuild(cols, rows, _collect_tower_threats())
	return _influence.to_extra_cost(_danger_weight)


## 收集攻击塔的威胁条目供影响图使用。range 由像素换算成"格"。
func _collect_tower_threats() -> Array:
	var threats: Array = []
	var tile := field.get_layout_tile_size()
	if tile <= 0.0:
		tile = 48.0
	for tower in _towers:
		if tower.get("removed", false):
			continue
		var tdef: Dictionary = NightTdDefs.get_tower_def(str(tower["type"]))
		var range_px := float(tdef.get("range", 0.0))
		var fire_interval := float(tdef.get("fire_interval", 1.0))
		var damage := float(tdef.get("damage", 0.0))
		if range_px <= 0.0 or damage <= 0.0 or fire_interval <= 0.0:
			continue  # 路障/陷阱等无射程塔不产生火力威胁场
		var power_scale := float(tower.get("power_scale", 1.0))  # P4 会写入；默认满功率
		threats.append({
			"cell": tower["cell"],
			"range_cells": range_px / tile,
			"dps": (damage / fire_interval) * power_scale,
		})
	return threats


## 从 energy.json 读取该难度的危险权重（敌人绕避炮塔火力的强度）。
func _load_danger_weight(diff: int) -> float:
	var fallback := {0: 0.0, 1: 6.0, 2: 14.0}
	var file := FileAccess.open(ENERGY_CONFIG_PATH, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary:
			var weights: Variant = (parsed as Dictionary).get("difficulty_danger_weight", {})
			if weights is Dictionary and weights.has(str(diff)):
				return float(weights[str(diff)])
	return float(fallback.get(diff, 6.0))


## 流场梯度方向（世界系）。不可达或无梯度时回退为"直指基地"。
func _flow_dir_at(pos: Vector2, base_pos: Vector2) -> Vector2:
	var cell := field.world_to_cell(pos)
	var dir := _flow.sample_dir(cell) if _flow != null else Vector2.ZERO
	if dir == Vector2.ZERO:
		var fallback := base_pos - pos
		return fallback.normalized() if fallback.length_squared() > 0.0001 else Vector2.ZERO
	return dir


## 分离转向：远离过近的同类，避免挤成一条线。
func _separation_dir(index: int, pos: Vector2, radius: float) -> Vector2:
	var push := Vector2.ZERO
	var r2 := radius * radius
	for j in range(_enemies.size()):
		if j == index:
			continue
		var other_pos: Vector2 = _enemies[j]["pos"]
		var delta := pos - other_pos
		var d2 := delta.length_squared()
		if d2 > 0.0001 and d2 < r2:
			push += delta / d2  # 越近推力越大
	return push.normalized() if push.length_squared() > 0.0001 else Vector2.ZERO


func _on_cell_clicked(cell: Vector2i) -> void:
	if phase != Phase.PLACE:
		return
	var tdef: Dictionary = NightTdDefs.get_tower_def(_selected_tower)
	if tdef.is_empty():
		return
	var cost: int = int(tdef.get("cost", 1))
	if not _can_afford(tdef, cost):
		if is_instance_valid(hud):
			hud.append_log("资源不足，无法部署 %s（需 %s）" % [tdef.get("name", ""), _cost_label(tdef)])
		return
	var occupied: Dictionary = {}
	for tower in _towers:
		if not tower.get("removed", false):
			occupied[tower["cell"]] = true
	if not field.can_place_tower(cell, occupied):
		if is_instance_valid(hud):
			hud.append_log("该格无法部署（车辆/占用/越界）")
		return
	_pay_cost(tdef, cost)
	resources_spent += cost
	var tower_id := _next_tower_id
	_next_tower_id += 1
	_towers.append({
		"id": tower_id,
		"type": _selected_tower,
		"cell": cell,
		"world_pos": field.cell_to_world(cell),
		"cooldown": 0.0,
		"hp": float(tdef.get("hp", 30)),
		"removed": false,
		"power_scale": 1.0,
	})
	# 耗电塔登记进能源系统（额定功率 1.0）。upkeep=0 的塔登记后不影响电池。
	if _energy != null and float(tdef.get("upkeep", 0.0)) > 0.0:
		_energy.register_tower(tower_id, 1.0)
	_mark_flow_dirty()
	if is_instance_valid(hud):
		_refresh_resource_hud()
		hud.append_log("已部署 %s" % tdef.get("name", ""))


func _on_cell_right_clicked(cell: Vector2i) -> void:
	if phase != Phase.PLACE:
		return
	var removed := _remove_tower_at_cell(cell)
	if removed and is_instance_valid(hud):
		_refresh_resource_hud()
		hud.append_log("已撤销 %s（资源已退还）" % removed)
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
		# 布防阶段撤销：全额退还建造资源。
		_refund_cost(tdef, refund)
		resources_spent = maxi(resources_spent - refund, 0)
		if _energy != null and tower.has("id"):
			_energy.unregister_tower(int(tower["id"]))
		tower["removed"] = true
		_mark_flow_dirty()
		return str(tdef.get("name", tower["type"]))
	return ""


# --- P6 资源经济：真实背包 vs 旧 deploy-point 预算 ---

## 能否支付建造成本。有背包时检查 build_cost；否则用 deploy-point 预算。
func _can_afford(tdef: Dictionary, deploy_cost: int) -> bool:
	if _local_backpack == null:
		return backpack_remaining >= deploy_cost
	var build_cost: Dictionary = tdef.get("build_cost", {})
	for item_id: String in build_cost.keys():
		if not _local_backpack.has(str(item_id), int(build_cost[item_id])):
			return false
	return true


func _pay_cost(tdef: Dictionary, deploy_cost: int) -> void:
	if _local_backpack == null:
		backpack_remaining -= deploy_cost
		return
	var build_cost: Dictionary = tdef.get("build_cost", {})
	for item_id: String in build_cost.keys():
		_local_backpack.remove(str(item_id), int(build_cost[item_id]))


func _refund_cost(tdef: Dictionary, deploy_cost: int) -> void:
	if _local_backpack == null:
		backpack_remaining += deploy_cost
		return
	var build_cost: Dictionary = tdef.get("build_cost", {})
	for item_id: String in build_cost.keys():
		_local_backpack.add(str(item_id), int(build_cost[item_id]))


func _cost_label(tdef: Dictionary) -> String:
	if _local_backpack == null:
		return "%d 部署点" % int(tdef.get("cost", 1))
	var build_cost: Dictionary = tdef.get("build_cost", {})
	var parts: Array[String] = []
	for item_id: String in build_cost.keys():
		parts.append("%s×%d" % [ItemDefs.get_item_name(str(item_id)), int(build_cost[item_id])])
	return "、".join(parts) if not parts.is_empty() else "无"


## 刷新布防阶段的资源显示：真实背包模式列出关键建材，否则显示部署点。
func _refresh_resource_hud() -> void:
	if not is_instance_valid(hud):
		return
	if _local_backpack == null:
		hud.set_resources(backpack_remaining, resources_spent)
		return
	var parts := int(_local_backpack.count("parts"))
	var scrap := int(_local_backpack.count("scrap"))
	hud.set_resource_text("零件 %d · 废料 %d" % [parts, scrap])
	# Also update card costs so they show (剩余 N)
	if hud.has_method("update_card_costs"):
		var counts := {"parts": parts, "scrap": scrap}
		if _local_backpack.has_method("to_dictionary"):
			var full := _local_backpack.to_dictionary()
			for k in full.keys():
				counts[str(k)] = int(full[k])
		hud.update_card_costs(counts)


func _on_tower_selected(type_id: String) -> void:
	_selected_tower = type_id


func _begin_combat() -> void:
	if phase == Phase.COMBAT:
		return
	# 快照：进入战斗时实际放置的塔（排除布防阶段已撤销的）
	_combat_tower_ids.clear()
	for tower in _towers:
		if not tower.get("removed", false):
			_combat_tower_ids.append(int(tower.get("id", -1)))
	phase = Phase.COMBAT
	show_route_overlay = false
	_spawn_timer = 0.0
	if is_instance_valid(field):
		field.queue_redraw()
	if is_instance_valid(hud):
		hud.set_combat_mode()
		hud.set_phase_text(_session_phase_title("接敌中"))
		hud.set_hint("接敌中：敌人头顶箭头为当前前进方向，设施自动开火/阻挡。")
		var total := _wave_scheduler.total_spawn_events if _wave_scheduler != null else _enemies_spawned + _wave_queue.size()
		hud.set_combat_status("波次 %d/%d · 场上 %d 敌" % [_enemies_spawned, total, _count_hostiles()])
		hud.append_log("—— 夜间威胁来袭 ——")


func _end_combat_vehicle_destroyed() -> void:
	if _combat_done:
		return
	_combat_done = true
	_last_result = _build_result()
	_last_result["outcome"] = "vehicle_destroyed"
	_last_result["loss_severity"] = "total"
	_last_result["inventory_loss"] = _exploration_inventory
	_last_result["message"] = "车辆防线被突破，车外物资被拖走，乘员失联。本局勘探终止。"
	base_hp = 0.0
	phase = Phase.RESULT
	if is_instance_valid(hud):
		hud.show_result(_compose_result_message(_last_result))
		hud.set_phase_text(_session_phase_title("车辆损毁"))
		hud.set_combat_status("车辆 HP 归零")


func _end_combat() -> void:
	_combat_done = true
	_last_result = _build_result()
	phase = Phase.RESULT
	if is_instance_valid(hud):
		hud.show_result(_compose_result_message(_last_result))
		hud.set_phase_text(_session_phase_title("结算"))
		hud.set_combat_status("交互结束，请确认结算")


func _compose_result_message(result: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("══════ 夜间结算 ══════")
	lines.append("")
	lines.append(str(result.get("message", "")))
	lines.append("")

	# — 防御塔返还 —
	lines.append("—— 防御塔返还 ——")
	var tower_refund: Dictionary = result.get("tower_refund", {})
	if tower_refund.is_empty():
		lines.append("  （无）")
	else:
		for key in tower_refund.keys():
			var def := NightTdDefs.get_tower_def(str(key))
			var info: Dictionary = tower_refund[key]
			for entry in info.get("survived", []):
				lines.append("  幸存: %s → 退还 %s" % [_fmt_tower_name(str(key)), _fmt_items(entry)])
			for entry in info.get("destroyed", []):
				lines.append("  损毁: %s → 残骸 %s" % [_fmt_tower_name(str(key)), _fmt_items(entry)])

	# — 击毁回收 —
	lines.append("")
	lines.append("—— 击毁回收 ——")
	var kill_log: Array = result.get("kill_log", [])
	if kill_log.is_empty():
		lines.append("  （无）")
	else:
		var by_type: Dictionary = {}
		for entry in kill_log:
			var t := str(entry.get("type", "?"))
			by_type[t] = int(by_type.get(t, 0)) + 1
		for t in by_type.keys():
			var def := NightTdDefs.get_enemy_def(t)
			var ename := str(def.get("name", t))
			var cnt := int(by_type[t])
			var scrap_per := 2 if t in ["heavy", "shepherd"] else 1
			lines.append("  %s×%d → 废料×%d" % [ename, cnt, cnt * scrap_per])

	# — 策反回收 —
	lines.append("")
	lines.append("—— 策反回收 ——")
	var converted: Array = result.get("converted_survivors", [])
	if converted.is_empty():
		lines.append("  （无）")
	else:
		var by_type: Dictionary = {}
		for entry in converted:
			var t := str(entry.get("enemy_type", "?"))
			by_type[t] = int(by_type.get(t, 0)) + 1
		for t in by_type.keys():
			var def := NightTdDefs.get_enemy_def(t)
			var ename := str(def.get("name", t))
			var cnt := int(by_type[t])
			var parts_val := 2 if t in ["heavy", "shepherd"] else 1
			lines.append("  %s×%d → 零件×%d" % [ename, cnt, cnt * parts_val])

	# — 突破损失 —
	lines.append("")
	lines.append("—— 突破损失 ——")
	var bl: Dictionary = result.get("breach_losses", {})
	if bl.is_empty():
		lines.append("  （无）")
	else:
		for item_id: String in (bl as Dictionary).keys():
			var n := int((bl as Dictionary)[item_id])
			lines.append("  %s×%d 被拖走" % [ItemDefs.get_item_name(str(item_id)), n])

	# — 汇总 —
	lines.append("")
	lines.append("—— 车辆状态 ——")
	lines.append("  HP: %.0f/%.0f" % [float(result.get("base_hp", 0)), float(result.get("base_hp_max", 100))])

	return "\n".join(lines)


func _fmt_tower_name(type_id: String) -> String:
	var def := NightTdDefs.get_tower_def(type_id)
	return str(def.get("name", type_id))


func _fmt_items(d: Variant) -> String:
	if not (d is Dictionary) or (d as Dictionary).is_empty():
		return "无"
	var parts: Array[String] = []
	for item_id: String in (d as Dictionary).keys():
		var n := int((d as Dictionary)[item_id])
		if n > 0:
			parts.append("%s×%d" % [ItemDefs.get_item_name(str(item_id)), n])
	return "、".join(parts) if not parts.is_empty() else "无"


func _resolve_wave_plan_path(day: int, diff: int) -> String:
	if day >= 6 or diff >= 2:
		return "res://data/night_td/waves/night_wave_heavy.json"
	if day >= 3:
		return "res://data/night_td/waves/night_wave_mid.json"
	return "res://data/night_td/waves/night_wave_demo.json"


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
	var hp_ratio := base_hp / base_max_hp if base_max_hp > 0.0 else 0.0
	if hp_ratio < 0.35:
		outcome = "fail"
		loss_severity = "severe"
		fuel_loss = 10.0
		msg = "防线失守！车辆严重受损（HP %.0f/%.0f）。" % [base_hp, base_max_hp]
	elif _enemies_reached > 0 or hp_ratio < 0.7:
		outcome = "partial"
		loss_severity = "partial"
		fuel_loss = 4.0
		if _enemies_reached > 0:
			msg = "%d 个回收机突破防线，拖走了一些物资（车辆 HP %.0f/%.0f）。" % [
				_enemies_reached, base_hp, base_max_hp,
			]
		else:
			msg = "防线承压，损失少量物资（车辆 HP %.0f/%.0f）。" % [base_hp, base_max_hp]
	else:
		outcome = "success"
		loss_severity = "none"
		msg = "防线稳固！车辆完好，今夜安全度过。"
	var inv_loss: int = 0
	match loss_severity:
		"partial":
			inv_loss = randi_range(1, 2)
		"severe":
			inv_loss = randi_range(3, 5)
	var salvage := _settle_salvage()
	# 关键：把回收物资加回本地背包，这样 final_backpack_dict 才包含它们
	if _local_backpack != null:
		for item_id: String in salvage.keys():
			_local_backpack.add(str(item_id), int(salvage[item_id]))
	# 真实背包模式：突破物资已在战斗中实时拖走（_steal_resources），
	# 这里把 inventory_loss 置 0；改用 breach_losses 汇报实拿明细。
	var breach_total := 0
	for k: String in _breach_losses.keys():
		breach_total += int(_breach_losses[k])
	if _local_backpack != null:
		inv_loss = 0
	# 导出最终背包快照（含所有建造消耗、突破损失、夜末回收）
	var final_backpack_dict: Dictionary = {}
	if _local_backpack != null and _local_backpack.has_method("to_dictionary"):
		final_backpack_dict = _local_backpack.to_dictionary().duplicate()
	return {
		"kind": _session_kind,
		"no_day_advance": _no_day_advance,
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
		"resources_spent": _compute_resources_spent(),
		"defense_power": _count_active_towers() * 2 + _enemies_killed,
		"threat_power": _enemies_spawned,
		"salvage": salvage,
		"breach_losses": _breach_losses.duplicate(),
		"breach_total": breach_total,
		"final_backpack_dict": final_backpack_dict,
		"tower_refund": _build_tower_refund_detail(),
		"kill_log": _build_kill_log(),
		"converted_survivors": _converted_survivors.duplicate(),
	}


## 夜末回收结算（P6.2）：幸存塔全额退还 build_cost；被毁塔产出 salvage（残骸）；
## 加上战斗中累计的敌人废料掉落。返回 item_id -> count。
func _settle_salvage() -> Dictionary:
	var out: Dictionary = {}
	# 策反单位存活到夜末 → 零件回收
	for enemy in _enemies:
		if str(enemy.get("faction", "enemy")) == "ally":
			var parts_val := 2 if str(enemy.get("type","")) in ["heavy","shepherd"] else 1
			_converted_survivors.append({"enemy_type": str(enemy.get("type","")), "parts_value": parts_val})
			out["parts"] = int(out.get("parts", 0)) + parts_val
			_add_event_log("ally_survived", str(enemy.get("type","")), {"parts": parts_val})
	for item_id: String in _salvage_pending.keys():
		out[item_id] = int(out.get(item_id, 0)) + int(_salvage_pending[item_id])
	for tower in _towers:
		# 只统计进入战斗的塔
		if not _combat_tower_ids.has(int(tower.get("id", -1))):
			continue
		var tdef: Dictionary = NightTdDefs.get_tower_def(str(tower["type"]))
		var src: Dictionary = {}
		if tower.get("removed", false):
			src = tdef.get("salvage", {})        # 被毁 → 少量残骸
		else:
			src = tdef.get("build_cost", {})     # 幸存 → 全额退还
		for item_id: String in src.keys():
			out[item_id] = int(out.get(item_id, 0)) + int(src[item_id])
	return out


## 敌人被击毁时累计废料掉落（夜末统一结算，不在战斗中即时入袋）。
func _build_tower_refund_detail() -> Dictionary:
	var out: Dictionary = {}
	for tower in _towers:
		# 只统计进入战斗的塔（布防阶段撤销的不算）
		if not _combat_tower_ids.has(int(tower.get("id", -1))):
			continue
		var tid := str(tower.get("type", ""))
		if not out.has(tid):
			out[tid] = {"survived": [], "destroyed": []}
		if tower.get("removed", false):
			var tdef := NightTdDefs.get_tower_def(tid)
			out[tid]["destroyed"].append(tdef.get("salvage", {}))
		else:
			var tdef := NightTdDefs.get_tower_def(tid)
			out[tid]["survived"].append(tdef.get("build_cost", {}))
	return out


func _build_kill_log() -> Array:
	var log: Array = []
	for entry in _event_log:
		if str(entry.get("type", "")) == "enemy_killed":
			log.append({"type": str(entry.get("detail", "?")), "scrap": int(entry.get("resource_change", {}).get("scrap", 0))})
	return log


func _add_salvage_drop(enemy: Dictionary) -> void:
	# 已策反的友军不计回收；普通敌人掉 1 废料，重型/牧羊者掉 2。
	if str(enemy.get("faction", "enemy")) != "enemy":
		return
	var amount := 1
	var t := str(enemy.get("type", ""))
	if t == "heavy" or bool(enemy.get("is_shepherd", false)):
		amount = 2
	_salvage_pending["scrap"] = int(_salvage_pending.get("scrap", 0)) + amount


## 从当前实际放置的塔（排除已撤销）计算资源消耗。
func _compute_resources_spent() -> int:
	var total := 0
	for tower in _towers:
		if tower.get("removed", false):
			continue
		var tdef: Dictionary = NightTdDefs.get_tower_def(str(tower["type"]))
		if _local_backpack == null:
			total += int(tdef.get("cost", 1))
		else:
			# backpack 模式下计入实际建造材料（用于结算汇报）
			for item_id: String in tdef.get("build_cost", {}).keys():
				total += int(tdef["build_cost"][item_id])
	return total


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
