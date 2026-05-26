class_name PlayerSurvival
extends RefCounted

const CONFIG_PATH := "res://data/survival_config.json"

static var STAMINA_MAX := 100.0
static var STAMINA_DECAY_PER_SEC := 0.45

var stamina: float = STAMINA_MAX


static func _static_init() -> void:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		printerr("[PlayerSurvival] Failed to open config: %s" % CONFIG_PATH)
		return
	var parsed := JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		printerr("[PlayerSurvival] Invalid survival config JSON, using defaults: %s" % CONFIG_PATH)
		return
	var cfg: Dictionary = parsed
	STAMINA_MAX = maxf(float(cfg.get("stamina_max", STAMINA_MAX)), 1.0)
	STAMINA_DECAY_PER_SEC = maxf(float(cfg.get("stamina_decay_per_sec", STAMINA_DECAY_PER_SEC)), 0.0)


func reset_for_new_run() -> void:
	stamina = STAMINA_MAX


func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	stamina = maxf(stamina - STAMINA_DECAY_PER_SEC * delta, 0.0)


func apply_night_defense_outcome(outcome: String) -> void:
	# 保留接口以兼容现有调用，生命值倒计时已移除。
	_ = outcome


func is_alive() -> bool:
	return stamina > 0.0


func use_supplies(amount: float = -1.0) -> void:
	if amount < 0.0:
		amount = float(ItemDefs.get_def("supplies").get("restore_stamina", 45.0))
	stamina = minf(stamina + amount, STAMINA_MAX)


func to_dictionary() -> Dictionary:
	return {
		"stamina": stamina,
	}


func load_from_dictionary(data: Variant) -> void:
	if data is Dictionary:
		if data.has("stamina"):
			stamina = clampf(float(data.get("stamina", STAMINA_MAX)), 0.0, STAMINA_MAX)
			return
		var hunger := clampf(float(data.get("hunger", 100.0)), 0.0, 100.0)
		var thirst := clampf(float(data.get("thirst", 100.0)), 0.0, 100.0)
		stamina = clampf((hunger + thirst) * 0.5, 0.0, STAMINA_MAX)
