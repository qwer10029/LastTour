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
}

static func get_tower_def(type_id: String) -> Dictionary:
	return TOWER_TYPES.get(type_id, {})


static func get_enemy_def(type_id: String) -> Dictionary:
	return ENEMY_TYPES.get(type_id, {})
