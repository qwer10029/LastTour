extends Node

enum Difficulty { EASY, NORMAL, HARD }

const SCENE_MAIN_MENU := "res://scenes/menu/main_menu.tscn"
const SCENE_DIFFICULTY := "res://scenes/menu/difficulty_select.tscn"
const SCENE_SQUAD := "res://scenes/menu/squad_select.tscn"
const SCENE_GAME := "res://scenes/main.tscn"

const DIFFICULTY_NAMES := {
	Difficulty.EASY: "简单",
	Difficulty.NORMAL: "普通",
	Difficulty.HARD: "困难",
}

const SQUAD_DEFS := {
	"scavenger": {
		"name": "拾荒者",
		"description": "开箱与拾取时更容易获得额外资源。",
		"inventory_bonus": 1,
		"repair_discount": 0,
		"fuel_multiplier": 1.0,
	},
	"logistics": {
		"name": "后勤型",
		"description": "修复电梯时消耗的资源更少。",
		"inventory_bonus": 0,
		"repair_discount": 1,
		"fuel_multiplier": 1.0,
	},
}

var difficulty: int = Difficulty.NORMAL
var squad_id: String = "scavenger"

var _pending_new_game := false
var _pending_load_save := false


func go_to_main_menu() -> void:
	_pending_new_game = false
	_pending_load_save = false
	get_tree().change_scene_to_file(SCENE_MAIN_MENU)


func continue_from_save() -> void:
	if not SaveManager.has_save():
		return
	_pending_new_game = false
	_pending_load_save = true
	get_tree().change_scene_to_file(SCENE_GAME)


func consume_load_save_request() -> bool:
	var should_load := _pending_load_save
	_pending_load_save = false
	return should_load


func begin_new_game_flow() -> void:
	_pending_new_game = true
	difficulty = Difficulty.NORMAL
	squad_id = "scavenger"
	get_tree().change_scene_to_file(SCENE_DIFFICULTY)


func go_to_squad_select() -> void:
	get_tree().change_scene_to_file(SCENE_SQUAD)


func start_run() -> void:
	_pending_new_game = false
	get_tree().change_scene_to_file(SCENE_GAME)


func get_difficulty_name(value: int = -1) -> String:
	if value < 0:
		value = difficulty
	return DIFFICULTY_NAMES.get(value, "未知")


func get_squad_name(id: String = "") -> String:
	var key := id if id != "" else squad_id
	var def: Dictionary = SQUAD_DEFS.get(key, {})
	return str(def.get("name", "未知分队"))


func get_squad_description(id: String = "") -> String:
	var key := id if id != "" else squad_id
	var def: Dictionary = SQUAD_DEFS.get(key, {})
	return str(def.get("description", ""))


func apply_run_config_to_game(game: Node) -> void:
	if not game.has_method("apply_run_config"):
		return
	game.apply_run_config(self)


func get_fuel_max(base: float) -> float:
	match difficulty:
		Difficulty.EASY:
			return base * 1.25
		Difficulty.HARD:
			return base * 0.75
		_:
			return base


func get_elevator_repair_cost(base: int) -> int:
	var cost := base
	match difficulty:
		Difficulty.EASY:
			cost = maxi(cost - 1, 1)
		Difficulty.HARD:
			cost += 1
	var squad_def: Dictionary = SQUAD_DEFS.get(squad_id, {})
	cost = maxi(cost - int(squad_def.get("repair_discount", 0)), 1)
	return cost


func get_starting_inventory() -> int:
	var squad_def: Dictionary = SQUAD_DEFS.get(squad_id, {})
	return int(squad_def.get("inventory_bonus", 0))


func get_starting_items() -> Dictionary:
	var items := {
		"food": 2,
		"water": 2,
		"wood": 1,
		"parts": 1,
		"scrap": 1,
	}
	match squad_id:
		"logistics":
			items["parts"] = 3
			items["wood"] = 2
			items["food"] = 1
		"scavenger":
			items["scrap"] = 3
			items["food"] = 3
	match difficulty:
		Difficulty.EASY:
			items["medkit"] = int(items.get("medkit", 0)) + 1
			items["water"] = int(items.get("water", 0)) + 1
		Difficulty.HARD:
			items["food"] = maxi(int(items.get("food", 0)) - 1, 0)
	return items
