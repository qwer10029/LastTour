extends Node
class_name NightDefenseSystem

## 夜晚布防入口：驱动俯视角塔防会话。

signal session_finished(result: Dictionary)

var _td: NightTdController
var _last_result: Dictionary = {}


func bind_td_controller(td: NightTdController) -> void:
	_td = td
	if _td != null and not _td.session_finished.is_connected(_on_td_finished):
		_td.session_finished.connect(_on_td_finished)


func start_td_session(
	inventory: int,
	difficulty: int,
	day_index: int,
	allow_placement: bool = true,
	vehicle_hp: float = -1.0,
	vehicle_hp_max: float = -1.0,
	backpack_snapshot: Dictionary = {},
) -> void:
	if _td == null:
		return
	_last_result = {}
	_td.start_session(inventory, difficulty, day_index, allow_placement, vehicle_hp, vehicle_hp_max, backpack_snapshot)


func hide_td_session() -> void:
	if _td != null:
		_td.hide_session()


func reset_defenses() -> void:
	_last_result = {}
	if _td != null:
		_td.hide_session()


func get_last_result() -> Dictionary:
	return _last_result


func _on_td_finished(result: Dictionary) -> void:
	_last_result = result
	session_finished.emit(result)
