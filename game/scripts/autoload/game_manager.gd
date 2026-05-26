extends Node

enum Difficulty { EASY, NORMAL, HARD }
const RUN_CONFIG_PATH := "res://data/run_config.json"

const SCENE_MAIN_MENU := "res://scenes/menu/main_menu.tscn"
const SCENE_OPENING_PROLOGUE := "res://scenes/menu/opening_prologue.tscn"
const SCENE_DIFFICULTY := "res://scenes/menu/difficulty_select.tscn"
const SCENE_SQUAD := "res://scenes/menu/squad_select.tscn"
const SCENE_GAME := "res://scenes/main.tscn"

var _difficulty_names := {
	Difficulty.EASY: "简单",
	Difficulty.NORMAL: "普通",
	Difficulty.HARD: "困难",
}

var _squad_defs := {
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
var _run_config: Dictionary = {}

var _pending_new_game := false
var _pending_load_save := false

func _ready() -> void:
	_load_run_config()


func _load_run_config() -> void:
	if not FileAccess.file_exists(RUN_CONFIG_PATH):
		return
	var file := FileAccess.open(RUN_CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_warning("无法打开运行配置文件：%s，将使用默认配置。" % RUN_CONFIG_PATH)
		return
	var parsed := JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("运行配置 JSON 无效：%s，将使用默认配置。" % RUN_CONFIG_PATH)
		return
	var cfg: Dictionary = parsed
	_run_config = cfg
	var names: Dictionary = cfg.get("difficulty_names", {})
	if not names.is_empty():
		_difficulty_names = {
			Difficulty.EASY: str(names.get("easy", _difficulty_names[Difficulty.EASY])),
			Difficulty.NORMAL: str(names.get("normal", _difficulty_names[Difficulty.NORMAL])),
			Difficulty.HARD: str(names.get("hard", _difficulty_names[Difficulty.HARD])),
		}
	var squads: Dictionary = cfg.get("squads", {})
	if not squads.is_empty():
		_squad_defs = squads.duplicate(true)


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
	get_tree().change_scene_to_file(SCENE_OPENING_PROLOGUE)


func go_to_difficulty_select() -> void:
	get_tree().change_scene_to_file(SCENE_DIFFICULTY)


func go_to_squad_select() -> void:
	get_tree().change_scene_to_file(SCENE_SQUAD)


func start_run() -> void:
	_pending_new_game = false
	get_tree().change_scene_to_file(SCENE_GAME)


func get_difficulty_name(value: int = -1) -> String:
	if value < 0:
		value = difficulty
	return _difficulty_names.get(value, "未知")


func get_squad_name(id: String = "") -> String:
	var key := id if id != "" else squad_id
	var def: Dictionary = _squad_defs.get(key, {})
	return str(def.get("name", "未知分队"))


func get_squad_description(id: String = "") -> String:
	var key := id if id != "" else squad_id
	var def: Dictionary = _squad_defs.get(key, {})
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
	var squad_def: Dictionary = _squad_defs.get(squad_id, {})
	cost = maxi(cost - int(squad_def.get("repair_discount", 0)), 1)
	return cost


func get_starting_inventory() -> int:
	var squad_def: Dictionary = _squad_defs.get(squad_id, {})
	return int(squad_def.get("inventory_bonus", 0))


func get_starting_items() -> Dictionary:
	var items := {
		"supplies": 4,
		"wood": 1,
		"parts": 1,
		"scrap": 1,
	}
	var start_cfg: Dictionary = _run_config.get("starting_items", {})
	var default_items: Dictionary = start_cfg.get("default", {})
	if not default_items.is_empty():
		items = default_items.duplicate(true)
	var squad_overrides: Dictionary = start_cfg.get("squad_overrides", {})
	if squad_overrides.has(squad_id):
		var override_data: Variant = squad_overrides[squad_id]
		if typeof(override_data) == TYPE_DICTIONARY:
			var override_items: Dictionary = override_data
			for key in override_items.keys():
				items[str(key)] = int(override_items[key])
	var diff_adjustments: Dictionary = start_cfg.get("difficulty_adjustments", {})
	match difficulty:
		Difficulty.EASY:
			var easy_add: Dictionary = diff_adjustments.get("easy_add", {})
			for key in easy_add.keys():
				items[str(key)] = int(items.get(key, 0)) + int(easy_add[key])
		Difficulty.HARD:
			var hard_reduce: Dictionary = diff_adjustments.get("hard_reduce", {})
			for key in hard_reduce.keys():
				items[str(key)] = maxi(int(items.get(key, 0)) - int(hard_reduce[key]), 0)
	return items
