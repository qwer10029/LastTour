class_name NightTdHacking
extends RefCounted

## 黑入系统（P5）：玩家驱动的"策反"机制。
## 交互在控制器/HUD：战斗中点选一座入侵天线(hacker)，再点一个敌人，把它指派为该塔目标。
## 本类只提供纯逻辑（进度推进、能否黑入、策反后归属判定），便于独立测试。
##
## 每座 hacker 在 tower 字典上维护：
##   target_eid:int     当前目标敌人的 eid（-1 表示空闲）
##   hack_progress:float 0..100，达到 100 完成策反
## 每个敌人在 enemy 字典上维护：
##   eid:int            稳定编号（控制器分配）
##   faction:String     "enemy"（默认）/ "ally"（已被策反）
##   hacked_by:int      正在黑入它的 hacker tower id（-1 无）

const HACK_COMPLETE := 100.0


## 本帧某 hacker 对其目标推进的黑入进度增量。
##   base_rate: 塔的 hack_rate（额定每秒进度）
##   power_scale: 该塔有效功率（断电=0 则无进度）
##   hackrate_per_power: 功率曲线系数
##   hack_resist: 目标敌人的抗性（牧羊者更高）
static func progress_delta(
	delta: float,
	base_rate: float,
	power_scale: float,
	hackrate_per_power: float,
	hack_resist: float,
) -> float:
	if power_scale <= 0.05 or hack_resist <= 0.0:
		return 0.0
	var rate_mul := 1.0 + hackrate_per_power * (power_scale - 1.0)
	rate_mul = maxf(rate_mul, 0.1)
	return (base_rate * rate_mul / hack_resist) * delta


## 策反完成判定。
static func is_complete(progress: float) -> bool:
	return progress >= HACK_COMPLETE


## 给一个已策反的友军单位选择拦截目标：最近的敌方单位索引（-1 表示无敌可拦 → 撤退）。
static func pick_intercept_target(ally_pos: Vector2, enemies: Array) -> int:
	var best := -1
	var best_d := INF
	for i in range(enemies.size()):
		var e: Dictionary = enemies[i]
		if str(e.get("faction", "enemy")) != "enemy":
			continue
		if float(e.get("hp", 0.0)) <= 0.0:
			continue
		var d: float = ally_pos.distance_to(e["pos"])
		if d < best_d:
			best_d = d
			best = i
	return best
