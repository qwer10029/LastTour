extends Node2D

## NightTdRoot — night_td_standalone.tscn 的根脚本。
## 作为独立场景运行时，从 GameManager.run_state 读取数据，
## 启动 NightTdController，结束后通知 GameManager 切回白天场景。

@export var night_td_scene: PackedScene = null

var _td  # NightTdController
var _run_state  # RunState


func _ready() -> void:
	# 从 GameManager 获取 RunState
	_run_state = GameManager.consume_run_state()
	if _run_state == null:
		print("NightTdRoot: no GameManager.run_state; starting standalone demo session.")
		_start_demo_session()
		return

	# 加载 NightTd 子场景
	_instantiate_td()

	# 启动塔防会话：使用背包快照（非 live 引用）
	var backpack_total := 0
	var snapshot: Dictionary = _run_state.backpack_dict.duplicate()
	for key in snapshot.keys():
		backpack_total += int(snapshot[key])

	_td.start_session(
		backpack_total,
		_run_state.difficulty,
		_run_state.day_index,
		true,  # allow_placement
		_run_state.vehicle_hp,
		_run_state.vehicle_hp_max,
		snapshot,
		_run_state.night_session_options,
		_run_state.fuel,
		_run_state.fuel_max,
	)

	# 暂停检查：将 GameManager 的暂停状态同步过来
	if GameManager.has_method("is_game_paused") and GameManager.is_game_paused():
		if _td.has_method("set_session_paused"):
			_td.set_session_paused(true)


func _instantiate_td() -> void:
	if night_td_scene == null:
		night_td_scene = load("res://scenes/night_td/night_td.tscn")
	_td = night_td_scene.instantiate()
	add_child(_td)

	# 连接结算信号
	if _td != null and not _td.session_finished.is_connected(_on_td_finished):
		_td.session_finished.connect(_on_td_finished)


func _start_demo_session() -> void:
	_instantiate_td()
	_td.start_session(
		30,
		1,
		1,
		true,  # allow_placement
		100.0,
		100.0,
		{"scrap": 20, "wood": 10, "parts": 20, "fuel": 5, "supplies": 5},
		{},
		20.0,
		100.0,
	)


func _on_td_finished(result: Dictionary) -> void:
	if _run_state == null:
		_td.hide_session()
		return
	# 通知 GameManager 切回白天
	GameManager.apply_night_result_and_continue(result)
