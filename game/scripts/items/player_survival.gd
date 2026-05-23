class_name PlayerSurvival
extends RefCounted

const HP_MAX := 100.0
const HUNGER_MAX := 100.0
const THIRST_MAX := 100.0
## 低于此值才开始扣生命（饥饿 / 口渴）
const CRITICAL_VITAL_THRESHOLD := 20.0

var hp: float = HP_MAX
var hunger: float = HUNGER_MAX
var thirst: float = THIRST_MAX
## 昨夜布防失利（部分失守 / 失守 / 车辆被破）时为 true，成功守夜后清除
var night_defense_wounded: bool = false

var hunger_decay_per_sec: float = 0.35
var thirst_decay_per_sec: float = 0.5
var critical_hp_loss_per_sec: float = 1.2
var night_wound_hp_loss_per_sec: float = 0.9


func reset_for_new_run() -> void:
	hp = HP_MAX
	hunger = HUNGER_MAX
	thirst = THIRST_MAX
	night_defense_wounded = false


func is_hunger_critical() -> bool:
	return hunger < CRITICAL_VITAL_THRESHOLD


func is_thirst_critical() -> bool:
	return thirst < CRITICAL_VITAL_THRESHOLD


func should_bleed_hp() -> bool:
	return is_hunger_critical() or is_thirst_critical() or night_defense_wounded


func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	hunger = maxf(hunger - hunger_decay_per_sec * delta, 0.0)
	thirst = maxf(thirst - thirst_decay_per_sec * delta, 0.0)
	if not should_bleed_hp():
		return
	var hp_loss := 0.0
	if is_hunger_critical() or is_thirst_critical():
		hp_loss += critical_hp_loss_per_sec * delta
	if night_defense_wounded:
		hp_loss += night_wound_hp_loss_per_sec * delta
	hp = maxf(hp - hp_loss, 0.0)


func apply_night_defense_outcome(outcome: String) -> void:
	match outcome:
		"success":
			night_defense_wounded = false
		"partial", "fail", "vehicle_destroyed":
			night_defense_wounded = true
		_:
			pass


func is_alive() -> bool:
	return hp > 0.0


func eat_food(amount: float = -1.0) -> void:
	if amount < 0.0:
		amount = float(ItemDefs.get_def("food").get("restore_hunger", 35.0))
	hunger = minf(hunger + amount, HUNGER_MAX)


func drink_water(amount: float = -1.0) -> void:
	if amount < 0.0:
		amount = float(ItemDefs.get_def("water").get("restore_thirst", 40.0))
	thirst = minf(thirst + amount, THIRST_MAX)


func use_medkit(amount: float = -1.0) -> void:
	if amount < 0.0:
		amount = float(ItemDefs.get_def("medkit").get("restore_hp", 45.0))
	hp = minf(hp + amount, HP_MAX)


func to_dictionary() -> Dictionary:
	return {
		"hp": hp,
		"hunger": hunger,
		"thirst": thirst,
		"night_defense_wounded": night_defense_wounded,
	}


func load_from_dictionary(data: Variant) -> void:
	if data is Dictionary:
		hp = clampf(float(data.get("hp", HP_MAX)), 0.0, HP_MAX)
		hunger = clampf(float(data.get("hunger", HUNGER_MAX)), 0.0, HUNGER_MAX)
		thirst = clampf(float(data.get("thirst", THIRST_MAX)), 0.0, THIRST_MAX)
		night_defense_wounded = bool(data.get("night_defense_wounded", false))
