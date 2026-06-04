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
		push_error("NightTdRoot: GameManager.run_state is null, cannot start night defense.")
		return

	# 加载 NightTd 子场景
	if night_td_scene == null:
		night_td_scene = load("res://scenes/night_td/night_td.tscn")
	_td = night_td_scene.instantiate()
	add_child(_td)

	# 连接结算信号
	if _td != null and not _td.session_finished.is_connected(_on_td_finished):
		_td.session_finished.connect(_on_td_finished)

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
	)

	# 暂停检查：将 GameManager 的暂停状态同步过来
	if GameManager.has_method("is_game_paused") and GameManager.is_game_paused():
		if _td.has_method("set_session_paused"):
			_td.set_session_paused(true)


func _on_td_finished(result: Dictionary) -> void:
	# 把夜间结果应用到 RunState
	if _run_state != null:
		_run_state.apply_night_result(result)
	# 通知 GameManager 切回白天
	GameManager.apply_night_result_and_continue(result)
