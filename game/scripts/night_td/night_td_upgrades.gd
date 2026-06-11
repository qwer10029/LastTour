class_name NightTdUpgrades
extends RefCounted

## 防御塔强化（Part B）：故事奖励道具 → 真实塔属性。消耗式可叠加。
## 玩家在背包使用一个升级道具时，main.gd 把对应 deltas 累加进 run-scoped 的
## tower_upgrades 字典；夜晚建塔时 night_td_controller 读取它，乘到伤害/射程/耐久上。
##
## tower_upgrades 数据形态（存档/昼夜传递）：
##   { "damage_mult": 1.0, "range_mult": 1.0, "tower_hp_mult": 1.0 }
## mult 字段以乘法累加：每安装一个 delta=d 的道具 → mult *= (1 + d)。

const CONFIG_PATH := "res://data/night_td/tower_upgrades.json"

static var _cache: Dictionary = {}


static func _config() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary:
			_cache = parsed
	return _cache


## 该道具是否是一个防御塔强化道具。
static func is_upgrade_item(item_id: String) -> bool:
	var upgrades: Dictionary = _config().get("upgrades", {})
	return upgrades.has(item_id)


## 道具的面向玩家文案（用于安装提示）。
static func effect_text(item_id: String) -> String:
	var upgrades: Dictionary = _config().get("upgrades", {})
	var entry: Dictionary = upgrades.get(item_id, {})
	return str(entry.get("effect_text", ""))


static func display_name(item_id: String) -> String:
	var upgrades: Dictionary = _config().get("upgrades", {})
	var entry: Dictionary = upgrades.get(item_id, {})
	return str(entry.get("name", item_id))


## 全 1.0 的初始强化字典（深拷贝默认值）。
static func default_state() -> Dictionary:
	var defaults: Dictionary = _config().get("defaults", {})
	if defaults.is_empty():
		return {"damage_mult": 1.0, "range_mult": 1.0, "tower_hp_mult": 1.0}
	return defaults.duplicate(true)


## 把一个升级道具的 deltas 以乘法累加进 state，返回是否成功。state 原地修改。
static func apply_item(state: Dictionary, item_id: String) -> bool:
	var upgrades: Dictionary = _config().get("upgrades", {})
	if not upgrades.has(item_id):
		return false
	var deltas: Dictionary = (upgrades[item_id] as Dictionary).get("deltas", {})
	for key: String in deltas.keys():
		var cur := float(state.get(key, 1.0))
		state[key] = cur * (1.0 + float(deltas[key]))
	return true


## 规整一个从存档/选项读入的强化字典：补齐缺省键、夹到合理范围。
static func sanitize(raw: Variant) -> Dictionary:
	var state := default_state()
	if raw is Dictionary:
		for key: String in state.keys():
			if (raw as Dictionary).has(key):
				state[key] = clampf(float((raw as Dictionary)[key]), 1.0, 10.0)
	return state


## 是否存在任何已生效的强化（任一 mult > 1）。
static func has_any(state: Dictionary) -> bool:
	for key: String in state.keys():
		if float(state[key]) > 1.0001:
			return true
	return false


## 面向 HUD 的一行摘要，例如 "伤害 ×1.2 · 射程 ×1.15 · 耐久 ×1.1"。无强化时返回空串。
static func summary_text(state: Dictionary) -> String:
	if not has_any(state):
		return ""
	var parts: Array[String] = []
	var dmg := float(state.get("damage_mult", 1.0))
	var rng := float(state.get("range_mult", 1.0))
	var hp := float(state.get("tower_hp_mult", 1.0))
	if dmg > 1.0001:
		parts.append("伤害 ×%.2f" % dmg)
	if rng > 1.0001:
		parts.append("射程 ×%.2f" % rng)
	if hp > 1.0001:
		parts.append("耐久 ×%.2f" % hp)
	return " · ".join(parts)
