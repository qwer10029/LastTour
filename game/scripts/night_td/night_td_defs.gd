class_name NightTdDefs
extends RefCounted

const TOWER_DATA_PATH := "res://data/night_td/tower_defs.json"
const ENEMY_DATA_PATH := "res://data/night_td/enemy_defs.json"

static var _towers: Dictionary = {}
static var _enemies: Dictionary = {}


static func _static_init() -> void:
	_load_data()


static func _load_data() -> void:
	_towers = {
		"jammer": {
			"name": "干扰信标",
			"cost": 1,
			"range": 112.0,
			"damage": 14.0,
			"fire_interval": 0.75,
			"hp": 40.0,
			"color": Color("#6ed08b"),
			"radius": 14.0,
			"desc": "自动攻击射程内敌人，适合持续输出。",
		},
		"barrier": {
			"name": "物理路障",
			"cost": 1,
			"range": 0.0,
			"damage": 0.0,
			"fire_interval": 0.0,
			"hp": 150.0,
			"slow_factor": 0.0,
			"color": Color("#9e8564"),
			"radius": 18.0,
			"desc": "完全阻挡敌人前进，敌人会攻击路障直到将其摧毁。耐久较高，宜布置在要道形成防线。",
		},
		"trap": {
			"name": "电磁陷阱",
			"cost": 2,
			"range": 0.0,
			"damage": 45.0,
			"fire_interval": 999.0,
			"hp": 1.0,
			"one_shot": true,
			"color": Color("#e87840"),
			"radius": 12.0,
			"desc": "单次高额伤害，触发后消失，宜放在要道。",
		},
		"cryo_beacon": {
			"name": "噪声信标",
			"cost": 2,
			"range": 130.0,
			"damage": 0.0,
			"fire_interval": 0.0,
			"hp": 38.0,
			"slow_factor": 0.55,
			"applies_slow": true,
			"color": Color("#c6d65c"),
			"radius": 14.0,
			"desc": "广播刺耳噪声与伪信标，拖慢射程内敌人；无法影响特殊免疫目标。",
		},
		"hacker": {
			"name": "入侵天线",
			"cost": 13,
			"range": 150.0,
			"damage": 0.0,
			"fire_interval": 0.0,
			"hp": 35.0,
			"color": Color("#5ac8e0"),
			"radius": 14.0,
			"desc": "战斗中点选它再点敌人，持续引导即可策反该机器为我方。耗电，可随时改派目标。",
			"build_cost": {"parts": 10, "wood": 3},
			"salvage": {"parts": 1, "scrap": 1},
			"is_hack_tower": true,
			"upkeep": 1.5,
			"hack_rate": 80.0,
		},
		"sniper": {
			"name": "炮塔",
			"cost": 2,
			"range": 220.0,
			"damage": 40.0,
			"fire_interval": 2.2,
			"hp": 30.0,
			"color": Color("#7aa6ff"),
			"radius": 13.0,
			"desc": "超远射程单体炮击，伤害极高但射速慢。适合点杀重甲或高价值目标。",
		},
		"splash": {
			"name": "电弧塔",
			"cost": 2,
			"range": 162.0,
			"damage": 12.0,
			"fire_interval": 1.1,
			"hp": 45.0,
			"splash_radius": 56.0,
			"color": Color("#e0a23a"),
			"radius": 15.0,
			"desc": "中等射程范围伤害，每次攻击对目标点附近所有敌人造成电弧溅射，适合对付密集群体。",
		},
	}
	_enemies = {
		"drone": {
			"name": "巡逻无人机",
			"hp": 55.0,
			"speed": 40.0,
			"base_damage": 4.0,
			"color": Color("#9ec9ff"),
			"radius": 14.0,
			"hack_resist": 2.0,
		},
		"scout": {
			"name": "回收侦察机",
			"hp": 90.0,
			"speed": 32.0,
			"base_damage": 7.0,
			"color": Color("#ff7b6b"),
			"radius": 16.0,
			"hack_resist": 2.0,
		},
		"swarm": {
			"name": "集群微型机",
			"hp": 24.0,
			"speed": 55.0,
			"base_damage": 3.0,
			"color": Color("#b8e86a"),
			"radius": 10.0,
			"hack_resist": 2.0,
		},
		"heavy": {
			"name": "重装破障机",
			"hp": 220.0,
			"speed": 22.0,
			"base_damage": 12.0,
			"color": Color("#c97bff"),
			"radius": 20.0,
			"hack_resist": 2.0,
		},
		"shepherd": {
			"name": "牧羊者指挥机",
			"hp": 150.0,
			"speed": 28.0,
			"base_damage": 5.0,
			"color": Color("#ffd24a"),
			"radius": 18.0,
			"hack_resist": 4.4,
			"is_shepherd": true,
		},
		"armored": {
			"name": "装甲清道机",
			"hp": 140.0,
			"speed": 20.0,
			"base_damage": 10.0,
			"color": Color("#b0b0c0"),
			"radius": 18.0,
			"hack_resist": 2.8,
		},
		"saboteur": {
			"name": "破障突击机",
			"hp": 70.0,
			"speed": 48.0,
			"base_damage": 12.0,
			"color": Color("#ff9a3c"),
			"radius": 14.0,
			"hack_resist": 2.0,
		},
		"sprinter": {
			"name": "高速突破机",
			"hp": 20.0,
			"speed": 70.0,
			"base_damage": 2.0,
			"color": Color("#7df9ff"),
			"radius": 8.0,
			"hack_resist": 2.0,
		},
		"tank": {
			"name": "重型攻坚机",
			"hp": 350.0,
			"speed": 12.0,
			"base_damage": 20.0,
			"color": Color("#ff4444"),
			"radius": 22.0,
			"hack_resist": 3.6,
		},
		"repair_mender": {
			"name": "修复中继机",
			"hp": 95.0,
			"speed": 24.0,
			"base_damage": 4.0,
			"color": Color("#64dca0"),
			"radius": 15.0,
			"hack_resist": 2.4,
			"heal_radius": 82.0,
			"heal_per_sec": 8.0,
		},
		"terminal_overseer": {
			"name": "终端监管者",
			"hp": 900.0,
			"speed": 16.0,
			"base_damage": 30.0,
			"color": Color("#ff3658"),
			"radius": 28.0,
			"hack_resist": 999.0,
			"hack_immune": true,
			"effect_immune": true,
			"breach_damage_factor": 0.66,
			"summon_enemy": "swarm",
			"summon_interval_sec": 8.0,
			"max_summoned_alive": 8,
		},
	}

	var tower_file := FileAccess.open(TOWER_DATA_PATH, FileAccess.READ)
	if tower_file == null:
		printerr("[NightTdDefs] Failed to open tower defs: %s" % TOWER_DATA_PATH)
	else:
		var parsed: Variant = JSON.parse_string(tower_file.get_as_text())
		tower_file.close()
		if typeof(parsed) != TYPE_DICTIONARY:
			printerr("[NightTdDefs] Invalid tower defs JSON, using defaults: %s" % TOWER_DATA_PATH)
		else:
			var loaded: Dictionary = (parsed as Dictionary).get("towers", {})
			if not loaded.is_empty():
				_towers.clear()
				for tower_id in loaded.keys():
					var raw: Variant = loaded[tower_id]
					if typeof(raw) != TYPE_DICTIONARY:
						continue
					var normalized: Dictionary = raw.duplicate()
					normalized["color"] = Color(str(normalized.get("color", "#ffffff")))
					_towers[str(tower_id)] = normalized

	var enemy_file := FileAccess.open(ENEMY_DATA_PATH, FileAccess.READ)
	if enemy_file == null:
		printerr("[NightTdDefs] Failed to open enemy defs: %s" % ENEMY_DATA_PATH)
	else:
		var parsed: Variant = JSON.parse_string(enemy_file.get_as_text())
		enemy_file.close()
		if typeof(parsed) != TYPE_DICTIONARY:
			printerr("[NightTdDefs] Invalid enemy defs JSON, using defaults: %s" % ENEMY_DATA_PATH)
		else:
			var loaded: Dictionary = (parsed as Dictionary).get("enemies", {})
			if not loaded.is_empty():
				_enemies.clear()
				for enemy_id in loaded.keys():
					var raw: Variant = loaded[enemy_id]
					if typeof(raw) != TYPE_DICTIONARY:
						continue
					var normalized: Dictionary = raw.duplicate()
					normalized["color"] = Color(str(normalized.get("color", "#ffffff")))
					_enemies[str(enemy_id)] = normalized


static func get_tower_def(type_id: String) -> Dictionary:
	if _towers.is_empty():
		_load_data()
	return _towers.get(type_id, {})


static func get_tower_button_text(type_id: String, selected: bool) -> String:
	var def: Dictionary = get_tower_def(type_id)
	if def.is_empty():
		return type_id
	var mark := "► " if selected else "   "
	var cost: int = int(def.get("cost", 1))
	var lines: PackedStringArray = []
	lines.append("%s%s" % [mark, def.get("name", type_id)])
	lines.append("消耗 %d 部署点 / 放置 1 个" % cost)
	lines.append(str(def.get("desc", "")))
	match type_id:
		"jammer":
			lines.append("射程 %.0f · 伤害 %.0f · 射速 %.1fs" % [
				float(def.get("range", 0)),
				float(def.get("damage", 0)),
				float(def.get("fire_interval", 1)),
			])
		"barrier":
			lines.append("耐久 %.0f · 减速至 %.0f%%" % [
				float(def.get("hp", 0)),
				float(def.get("slow_factor", 0.25)) * 100.0,
			])
		"trap":
			lines.append("触发伤害 %.0f · 一次性" % float(def.get("damage", 0)))
		"cryo_beacon":
			lines.append("范围 %.0f · 减速至 %.0f%%" % [
				float(def.get("range", 0)),
				float(def.get("slow_factor", 1.0)) * 100.0,
			])
		"hacker":
			lines.append("范围 %.0f · 黑入速率 %.0f/s" % [
				float(def.get("range", 0)),
				float(def.get("hack_rate", 0)),
			])
		"sniper":
			lines.append("射程 %.0f · 伤害 %.0f · 射速 %.1fs" % [
				float(def.get("range", 0)),
				float(def.get("damage", 0)),
				float(def.get("fire_interval", 1)),
			])
		"splash":
			lines.append("射程 %.0f · 范围 %.0f · 伤害 %.0f" % [
				float(def.get("range", 0)),
				float(def.get("splash_radius", 0)),
				float(def.get("damage", 0)),
			])
	return "\n".join(lines)


static func get_enemy_def(type_id: String) -> Dictionary:
	if _enemies.is_empty():
		_load_data()
	return _enemies.get(type_id, {})


static func get_enemy_type_ids() -> Array[String]:
	if _enemies.is_empty():
		_load_data()
	var ids: Array[String] = []
	for key in _enemies.keys():
		ids.append(str(key))
	ids.sort_custom(func(a: String, b: String) -> bool:
		return str(_enemies.get(a, {}).get("name", a)) < str(_enemies.get(b, {}).get("name", b))
	)
	return ids
