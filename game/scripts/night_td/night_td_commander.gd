class_name NightTdCommander
extends RefCounted

## 指挥官 / 牧羊人 AI（P3）：让敌群像受指挥的军队那样行动 ——
## 分组、集结、集中兵力逐个击破防御塔，而不是各自独立涌向基地。
##
## 所有难度均启用（v2）：difficulty 只影响兵力阈值与激进程度，
## 敌人策略行为一致 —— 集结、攻坚、佯攻在所有难度都有体现，
## 让玩家在任何难度下都能看到"有组织的敌群"。
##
## 设计要点：
## - 决策与寻路解耦：指挥官只决定"每个敌人的目标(goal_key)"并维护若干目标流场；
##   具体移动仍由 NightTdFlowField 完成（与 P1/P2 一致）。
## - 性能：目标流场数量有界(≤4)，每 TICK_INTERVAL 秒整体重算一次。

# goal_key 约定：
#   "base"      → 走完整危险场的流场，奔向车辆（保守，绕开火力）
#   "pressure"  → 无视危险场直冲基地（佯攻/压制，吸引炮塔火力）
#   "m:<x>:<y>" → 攻坚任务：集结后扑向坐标(x,y)处的防御塔
const KEY_BASE := "base"
const KEY_PRESSURE := "pressure"

var enabled := true          # 始终启用（v2）
var difficulty := 1
var suppressed := false      # 牧羊者被击杀/策反时由控制器置位，临时退化为各自冲锋

var _cols := 0
var _rows := 0
var _vehicle_cells: Array = []
var _tick_interval := 0.5
var _tick_accum := 0.0
var _age := 0.0

# 难度派生参数（在 configure 中计算）
var _staging_threshold := 3     # 集结多少兵力后发动突击
var _pressure_ratio := 0.0      # 佯攻组比例（0=无佯攻）
var _max_target_towers := 1     # 最多同时攻坚几座塔
var _staging_timeout := 6.0     # 集结超时（秒），到时强制突击

# 任务表：goal_key -> { target_cell:Vector2i, staging_cell:Vector2i, state:"stage"/"push",
#                       created_at:float, pushed:bool }
var _missions: Dictionary = {}
# 目标流场：goal_key -> NightTdFlowField
var _fields: Dictionary = {}
var _pending_logs: Array[String] = []

# 指挥官状态快照（供可视化）
var last_missions: Array = []       # [{target_cell, staging_cell, state, key}]
var last_pressure_active := false
var last_assault_keys: Array = []
var last_only_non_attack_targets := false

var _was_only_non_attack_targets := false


func configure(diff: int, cols: int, rows: int, vehicle_cells: Array) -> void:
	difficulty = diff
	enabled = true  # v2：所有难度启用
	_cols = cols
	_rows = rows
	_vehicle_cells = vehicle_cells.duplicate()
	_missions.clear()
	_fields.clear()
	_pending_logs.clear()
	last_missions.clear()
	last_pressure_active = false
	last_assault_keys.clear()
	last_only_non_attack_targets = false
	_was_only_non_attack_targets = false

	# 难度派生参数
	match difficulty:
		0:
			_tick_interval = 0.75       # 慢半拍，给玩家更多反应时间
			_staging_threshold = 4       # 需要更多兵力才发动突击
			_pressure_ratio = 0.0        # 无佯攻组
			_max_target_towers = 1       # 只攻坚 1 座塔
			_staging_timeout = 8.0       # 更长的集结超时
		1:
			_tick_interval = 0.5
			_staging_threshold = 3
			_pressure_ratio = 0.0
			_max_target_towers = 1
			_staging_timeout = 6.0
		_:
			_tick_interval = 0.5
			_staging_threshold = 3
			_pressure_ratio = 0.33       # 1/3 兵力佯攻
			_max_target_towers = 2        # 可同时攻坚 2 座塔
			_staging_timeout = 5.0

	_tick_accum = _tick_interval  # 首帧立即规划
	_age = 0.0


func drain_logs() -> Array[String]:
	var out := _pending_logs.duplicate()
	_pending_logs.clear()
	return out


func set_suppressed(value: bool) -> void:
	suppressed = value


## 每帧调用；内部按 TICK_INTERVAL 节流重新规划。
func update(delta: float, ctx: Dictionary) -> void:
	_age += delta
	if suppressed:
		return
	_tick_accum += delta
	if _tick_accum < _tick_interval:
		return
	_tick_accum = 0.0
	_replan(ctx)


## 重新规划：选出要攻坚的塔、给敌人分配 goal_key、重建相应目标流场。
func _replan(ctx: Dictionary) -> void:
	var enemies: Array = ctx.get("enemies", [])
	var towers: Array = ctx.get("towers", [])
	var live_enemies := _live_enemies(enemies)
	if live_enemies.is_empty():
		last_missions.clear()
		last_pressure_active = false
		last_assault_keys.clear()
		last_only_non_attack_targets = false
		return

	# 1) 选定攻坚目标塔。按"威胁高且耐久低"打分；路障、陷阱等无攻击能力的设施不成为目标。
	var target_towers := _pick_target_towers(towers)

	# 若场上已没有能攻击的塔，指挥官不再分配攻坚/佯攻任务，所有敌人回退为直冲车辆。
	var has_attack_tower := _has_attack_tower(towers)
	last_only_non_attack_targets = not has_attack_tower
	if last_only_non_attack_targets and not _was_only_non_attack_targets:
		_queue_log("指挥官：场上已无有效火力点，全体直冲车辆")
	_was_only_non_attack_targets = last_only_non_attack_targets

	# 2) 维护任务表：为每个目标塔建立/更新攻坚任务。
	var active_keys := {}
	for t: Dictionary in target_towers:
		var cell: Vector2i = t["cell"]
		var key := "m:%d:%d" % [cell.x, cell.y]
		active_keys[key] = true
		if not _missions.has(key):
			_missions[key] = {
				"target_cell": cell,
				"staging_cell": _staging_cell_for(cell),
				"state": "stage",
				"created_at": _age,
				"pushed": false,
			}
			_queue_log("指挥官：锁定目标设施 %s，开始集结" % _cell_label(cell))
	for key: String in _missions.keys():
		if not active_keys.has(key):
			_missions.erase(key)

	# 3) 分配敌人到 goal_key。
	var assault_keys: Array = active_keys.keys()
	_assign_enemies(live_enemies, assault_keys)

	# 4) 推进每个攻坚任务的 stage→push 状态机。
	_advance_missions(live_enemies)

	# 5) 重建所需目标流场。
	_rebuild_fields(ctx, assault_keys)

	# 6) 保存快照供可视化
	last_pressure_active = _pressure_ratio > 0.0 and has_attack_tower
	last_assault_keys = assault_keys.duplicate()
	last_missions.clear()
	for key: String in _missions.keys():
		var m: Dictionary = _missions[key]
		last_missions.append({
			"key": key,
			"target_cell": m["target_cell"],
			"staging_cell": m["staging_cell"],
			"state": str(m["state"]),
		})


func _pick_target_towers(towers: Array) -> Array:
	var scored: Array = []
	for tower: Dictionary in towers:
		if tower.get("removed", false):
			continue
		if not _tower_can_attack(tower):
			continue
		var hp := float(tower.get("hp", 1.0))
		var threat := _tower_threat_hint(tower)
		var score := threat * 2.0 - hp * 0.15
		scored.append({"tower": tower, "score": score})
	scored.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
	var out: Array = []
	for i in range(mini(_max_target_towers, scored.size())):
		out.append(scored[i]["tower"])
	return out


func _tower_can_attack(tower: Dictionary) -> bool:
	var tdef: Dictionary = NightTdDefs.get_tower_def(str(tower.get("type", "")))
	var range_px := float(tdef.get("range", 0.0))
	var fire_interval := float(tdef.get("fire_interval", 0.0))
	var damage := float(tdef.get("damage", 0.0))
	return range_px > 0.0 and fire_interval > 0.0 and damage > 0.0


func _has_attack_tower(towers: Array) -> bool:
	for tower: Dictionary in towers:
		if tower.get("removed", false):
			continue
		if _tower_can_attack(tower):
			return true
	return false


func _tower_threat_hint(tower: Dictionary) -> float:
	var tdef: Dictionary = NightTdDefs.get_tower_def(str(tower.get("type", "")))
	var dmg := float(tdef.get("damage", 0.0))
	var fi := float(tdef.get("fire_interval", 1.0))
	var rng := float(tdef.get("range", 0.0))
	if rng <= 0.0 or fi <= 0.0:
		return 0.0
	return (dmg / fi) * float(tower.get("power_scale", 1.0))


func _assign_enemies(live: Array, assault_keys: Array) -> void:
	if assault_keys.is_empty():
		for e: Dictionary in live:
			e["goal_key"] = KEY_BASE
		return
	var pressure_cut := 0
	if _pressure_ratio > 0.0:
		pressure_cut = int(floor(float(live.size()) * _pressure_ratio))
	var ai := 0
	for idx in range(live.size()):
		var e: Dictionary = live[idx]
		if idx < pressure_cut:
			e["goal_key"] = KEY_PRESSURE
		else:
			e["goal_key"] = str(assault_keys[ai % assault_keys.size()])
			ai += 1


func _advance_missions(live: Array) -> void:
	var counts := {}
	for e: Dictionary in live:
		var k := str(e.get("goal_key", KEY_BASE))
		counts[k] = int(counts.get(k, 0)) + 1
	for key: String in _missions.keys():
		var m: Dictionary = _missions[key]
		var assigned := int(counts.get(key, 0))
		if m["state"] == "stage":
			if assigned >= _staging_threshold or (_age - float(m["created_at"])) > _staging_timeout:
				m["state"] = "push"
				m["pushed"] = true
				_queue_log("指挥官：兵力就位，向 %s 发起突击" % _cell_label(m["target_cell"]))


func _rebuild_fields(ctx: Dictionary, assault_keys: Array) -> void:
	var barrier_cost: PackedFloat32Array = ctx.get("barrier_cost", PackedFloat32Array())
	var danger_cost: PackedFloat32Array = ctx.get("danger_cost", PackedFloat32Array())
	var needed := {}
	# 佯攻组：无视危险场直冲基地。没有攻坚目标时佯攻无意义，不建场。
	if _pressure_ratio > 0.0 and not assault_keys.is_empty():
		needed[KEY_PRESSURE] = _combine_cost(barrier_cost, PackedFloat32Array(), _cols, _rows)
	# 攻坚组：走完整流场（含危险），到集结/突击点
	for key: String in assault_keys:
		var m: Dictionary = _missions.get(key, {})
		if m.is_empty():
			continue
		needed[key] = _combine_cost(barrier_cost, danger_cost, _cols, _rows)
	for key: String in needed.keys():
		var goals := _goals_for(key)
		var ff: NightTdFlowField = _fields.get(key, null)
		if ff == null:
			ff = NightTdFlowField.new()
			_fields[key] = ff
		ff.rebuild(_cols, _rows, goals, [], needed[key])
	for key: String in _fields.keys():
		if not needed.has(key):
			_fields.erase(key)


func _goals_for(key: String) -> Array:
	if key == KEY_PRESSURE:
		return _vehicle_cells.duplicate()
	var m: Dictionary = _missions.get(key, {})
	if m.is_empty():
		return _vehicle_cells.duplicate()
	if str(m.get("state", "stage")) == "stage":
		return [m["staging_cell"]]
	var c: Vector2i = m["target_cell"]
	var goals: Array = [c]
	for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := c + off
		if n.x >= 0 and n.y >= 0 and n.x < _cols and n.y < _rows:
			goals.append(n)
	return goals


## 查询某敌人本帧应当采用的流场方向。无对应场时返回 ZERO（控制器回退到主 base 流场）。
func dir_for(enemy: Dictionary, cell: Vector2i) -> Vector2:
	if suppressed:
		return Vector2.ZERO
	var key := str(enemy.get("goal_key", KEY_BASE))
	if key == KEY_BASE:
		return Vector2.ZERO
	var ff: NightTdFlowField = _fields.get(key, null)
	if ff == null:
		return Vector2.ZERO
	return ff.sample_dir(cell)


## 敌人是否正攻坚某塔且处于 push 状态——返回目标塔格（控制器据此触发近战伤害）。
func attack_target_cell(enemy: Dictionary) -> Vector2i:
	if suppressed:
		return Vector2i(-1, -1)
	var key := str(enemy.get("goal_key", KEY_BASE))
	if not key.begins_with("m:"):
		return Vector2i(-1, -1)
	var m: Dictionary = _missions.get(key, {})
	if m.is_empty() or str(m.get("state", "stage")) != "push":
		return Vector2i(-1, -1)
	return m["target_cell"]


# --- helpers ---

func _live_enemies(enemies: Array) -> Array:
	var out: Array = []
	for e: Dictionary in enemies:
		if float(e.get("hp", 0.0)) > 0.0:
			out.append(e)
	return out


func _staging_cell_for(target: Vector2i) -> Vector2i:
	var sx := target.x
	var sy := clampi(target.y - 2, 0, _rows - 1)
	return Vector2i(sx, sy)


func _combine_cost(a: PackedFloat32Array, b: PackedFloat32Array, cols: int, rows: int) -> PackedFloat32Array:
	var n := cols * rows
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var va := a[i] if i < a.size() else 0.0
		var vb := b[i] if i < b.size() else 0.0
		out[i] = va + vb
	return out


func _queue_log(line: String) -> void:
	_pending_logs.append(line)


func _cell_label(cell: Vector2i) -> String:
	return NightTdWavePlan.cell_label(cell)
