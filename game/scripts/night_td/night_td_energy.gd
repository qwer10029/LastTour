class_name NightTdEnergy
extends RefCounted

## 能源系统（P4）：战斗期间唯一的能源来源是基地反应堆（持续产能、有上限）。
## 击杀/黑入不产能（回收在夜末统一结算，见 P6），所以电力分配是一种真实的紧约束 ——
## 玩家要在"炮塔火力"和"黑入引导"之间调度同一份电。
##
## 每座耗电塔有一个功率档 power_level ∈ [0, MAX_POWER]；
##   - 持续耗电 = Σ upkeep(tower) × power_level
##   - 攻击塔的伤害/射速随 power_level 提升（见控制器 power_scale 派生）
## 产能 production_rate 是"满负荷可供养的功率点数/秒"的近似；这里用简化模型：
##   current 像电池：+production_rate×dt，−总功耗×dt，夹在 [0, capacity]。
##   若电量见底，按比例对所有耗电塔降功率（brownout），保证不为负。

const MAX_POWER := 2.0   # 单塔最高功率档（0=关停, 1=额定, 2=超频）
const MIN_POWER := 0.0
const POWER_STEP := 0.5  # UI 调档步长

var production_rate := 4.0
var capacity := 60.0
var current := 20.0

# tower_id(int) -> power_level(float)
var _levels: Dictionary = {}
# 上一帧实际供给系数（brownout 时 <1），tower_id -> effective_scale
var _effective: Dictionary = {}


static func load_config(path: String) -> NightTdEnergy:
	var e := NightTdEnergy.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary:
			var r: Variant = (parsed as Dictionary).get("reactor", {})
			if r is Dictionary:
				e.production_rate = float(r.get("production_rate", e.production_rate))
				e.capacity = float(r.get("capacity", e.capacity))
				e.current = clampf(float(r.get("starting", e.current)), 0.0, e.capacity)
	return e


func reset() -> void:
	_levels.clear()
	_effective.clear()
	current = clampf(current, 0.0, capacity)


## 注册一座耗电塔（默认额定功率 1.0）。无耗电的塔（upkeep=0）也可注册，level 不影响电池。
func register_tower(tower_id: int, default_level: float = 1.0) -> void:
	if not _levels.has(tower_id):
		_levels[tower_id] = clampf(default_level, MIN_POWER, MAX_POWER)
		_effective[tower_id] = 1.0


func unregister_tower(tower_id: int) -> void:
	_levels.erase(tower_id)
	_effective.erase(tower_id)


func power_level(tower_id: int) -> float:
	return float(_levels.get(tower_id, 1.0))


func set_power_level(tower_id: int, level: float) -> void:
	if _levels.has(tower_id):
		_levels[tower_id] = clampf(level, MIN_POWER, MAX_POWER)


func step_power(tower_id: int, delta_step: float) -> void:
	set_power_level(tower_id, power_level(tower_id) + delta_step)


## 本帧某塔实际生效的功率系数（含 brownout 折减）。攻击塔伤害/射速用它。
func effective_scale(tower_id: int) -> float:
	return float(_effective.get(tower_id, power_level(tower_id)))


## 每帧推进电池。upkeeps: tower_id(int) -> upkeep(float)。
## 返回 brownout 系数（1=供电充足，<1=本帧限电）。
func tick(delta: float, upkeeps: Dictionary) -> float:
	# 计划总功耗
	var demand := 0.0
	for tower_id: int in _levels.keys():
		var up := float(upkeeps.get(tower_id, 0.0))
		demand += up * float(_levels[tower_id])
	# 可用功率 = 反应堆产能 + 电池放电（本帧最多放 current/delta）
	var available := production_rate
	if delta > 0.0:
		available += current / delta
	var brownout := 1.0
	if demand > available and demand > 0.0:
		brownout = available / demand
	# 结算电池：净流入 =（产能 − 实际功耗）
	var actual_draw := demand * brownout
	current = clampf(current + (production_rate - actual_draw) * delta, 0.0, capacity)
	# 写每塔有效系数
	for tower_id: int in _levels.keys():
		_effective[tower_id] = float(_levels[tower_id]) * brownout
	return brownout


func current_demand(upkeeps: Dictionary) -> float:
	var demand := 0.0
	for tower_id: int in _levels.keys():
		demand += float(upkeeps.get(tower_id, 0.0)) * float(_levels[tower_id])
	return demand
