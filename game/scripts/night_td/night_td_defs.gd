class_name NightTdDefs
extends RefCounted

const TOWER_TYPES := {
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
		"damage": 6.0,
		"fire_interval": 0.35,
		"hp": 90.0,
		"slow_factor": 0.25,
		"color": Color("#9e8564"),
		"radius": 18.0,
		"desc": "阻挡并大幅减速踩到的敌人，耐久较高。",
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
}

const ENEMY_TYPES := {
	"drone": {
		"name": "巡逻无人机",
		"hp": 28.0,
		"speed": 58.0,
		"base_damage": 6.0,
		"color": Color("#9ec9ff"),
		"radius": 14.0,
	},
	"scout": {
		"name": "回收侦察机",
		"hp": 52.0,
		"speed": 42.0,
		"base_damage": 10.0,
		"color": Color("#ff7b6b"),
		"radius": 16.0,
	},
	"swarm": {
		"name": "集群微型机",
		"hp": 14.0,
		"speed": 72.0,
		"base_damage": 4.0,
		"color": Color("#b8e86a"),
		"radius": 10.0,
	},
	"heavy": {
		"name": "重装破障机",
		"hp": 120.0,
		"speed": 32.0,
		"base_damage": 18.0,
		"color": Color("#c97bff"),
		"radius": 20.0,
	},
}

static func get_tower_def(type_id: String) -> Dictionary:
	return TOWER_TYPES.get(type_id, {})


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
	return "\n".join(lines)


static func get_enemy_def(type_id: String) -> Dictionary:
	return ENEMY_TYPES.get(type_id, {})
