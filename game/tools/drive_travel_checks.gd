extends SceneTree
## 白天驾车网格移动回归检查（headless）。
## Regression checks for day-exploration grid travel: a started road step must
## never leave the vehicle stranded mid-segment (tap input, perpendicular input,
## reversing, or a save taken mid-segment).
##
## Run: godot --headless --path game --script res://tools/drive_travel_checks.gd

const DAY_SCENE := "res://scenes/day_exploration.tscn"
const MAX_STEP_FRAMES := 240
const MOVE_ACTIONS := ["move_up", "move_down", "move_left", "move_right"]

var _failures: Array[String] = []
var _game: Node = null


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var packed: PackedScene = load(DAY_SCENE)
	_game = packed.instantiate()
	root.add_child(_game)
	var booted := await _wait_until_drivable()
	_expect(booted, "day scene should boot into a drivable state")
	if booted:
		await _check_hold_forward_drives()
		await _check_tap_completes_step()
		await _check_perpendicular_input_does_not_stall()
		await _check_reverse_returns_to_origin()
		await _check_mid_segment_save_recovers()
		await _check_repeated_taps_keep_moving()
	_release_all()
	if _failures.is_empty():
		print("DRIVE_TRAVEL_CHECKS_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _release_all() -> void:
	for action in MOVE_ACTIONS:
		if InputMap.has_action(action):
			Input.action_release(action)


func _action_for(direction: String) -> String:
	match direction:
		"up":
			return "move_up"
		"down":
			return "move_down"
		"left":
			return "move_left"
		"right":
			return "move_right"
	return ""


func _perpendicular(direction: String) -> String:
	return "down" if direction == "left" or direction == "right" else "left"


func _wait_until_drivable() -> bool:
	for _i in range(600):
		await physics_frame
		if _game.get("_map") == null:
			continue
		if int(_game.get("_current_node_index")) < 0:
			continue
		if not _game._is_exploration_allowed():
			continue
		# 新开局可能弹出开局指引并暂停探索；关掉它，只测驾车逻辑。
		if bool(_game.get("_game_paused")):
			_game.set("_game_paused", false)
		if bool(_game.get("_backpack_open")):
			continue
		if (_game.get("_exit_options") as Dictionary).is_empty():
			continue
		return true
	return false


func _is_idle_at_node() -> bool:
	return int(_game.get("_segment_target_index")) < 0


func _wait_until_idle() -> bool:
	for _i in range(MAX_STEP_FRAMES):
		await physics_frame
		if _is_idle_at_node():
			return true
	return false


func _pick_exit() -> String:
	var options: Dictionary = _game.get("_exit_options")
	for direction in ["right", "left", "down", "up"]:
		if options.has(direction):
			return direction
	return ""


## 模拟一次极短的按键（按下与松开落在同一帧）：只有 just_pressed，没有持续按住。
func _start_step_like_tap(direction: String) -> int:
	_release_all()
	var options: Dictionary = _game.get("_exit_options")
	var target := int(options.get(direction, -1))
	_game.set("_drive_exit_locked", false)
	_game._choose_exit_direction(direction)
	return target


func _check_hold_forward_drives() -> void:
	# 原有操作方式（按住方向键）必须继续有效。
	var direction := _pick_exit()
	if direction == "":
		return
	var target := _start_step_like_tap(direction)
	var action := _action_for(direction)
	Input.action_press(action)
	var idle := await _wait_until_idle()
	Input.action_release(action)
	await physics_frame
	_expect(idle, "holding the travel key should drive the vehicle to the next node")
	_expect(int(_game.get("_current_node_index")) == target, "held step should arrive at the target node")


func _check_tap_completes_step() -> void:
	var direction := _pick_exit()
	_expect(direction != "", "start node should have at least one exit")
	if direction == "":
		return
	var target := _start_step_like_tap(direction)
	_expect(int(_game.get("_segment_target_index")) == target, "tap should start a road step")
	var idle := await _wait_until_idle()
	_expect(idle, "a tapped road step must finish without holding the key (vehicle stranded mid-road)")
	_expect(int(_game.get("_current_node_index")) == target, "tapped step should arrive at the target node")
	_expect(not (_game.get("_exit_options") as Dictionary).is_empty(), "arrived node should offer exits again")


func _check_perpendicular_input_does_not_stall() -> void:
	var direction := _pick_exit()
	if direction == "":
		return
	var target := _start_step_like_tap(direction)
	var side_action := _action_for(_perpendicular(direction))
	Input.action_press(side_action)
	var idle := await _wait_until_idle()
	Input.action_release(side_action)
	_expect(idle, "holding a perpendicular key mid-step must not freeze the vehicle")
	_expect(int(_game.get("_current_node_index")) == target, "perpendicular input should not change the step target")


func _check_reverse_returns_to_origin() -> void:
	var direction := _pick_exit()
	if direction == "":
		return
	var origin := int(_game.get("_current_node_index"))
	_start_step_like_tap(direction)
	await physics_frame
	var back_action := _action_for(_game._map.opposite_direction(direction))
	# 只需按一下反方向（之后即使松开），车辆也应自动倒回起点。
	Input.action_press(back_action)
	await physics_frame
	Input.action_release(back_action)
	var idle := false
	for _i in range(MAX_STEP_FRAMES):
		if _is_idle_at_node():
			idle = true
			break
		await physics_frame
	_expect(idle, "reversing mid-step should end at a node, not mid-road")
	_expect(int(_game.get("_current_node_index")) == origin, "reversing mid-step should return to the origin node")
	await physics_frame


func _check_mid_segment_save_recovers() -> void:
	# 复现玩家存档里的卡死状态：segment_target >= 0，progress = 0，无按键。
	var direction := _pick_exit()
	if direction == "":
		return
	var origin := int(_game.get("_current_node_index"))
	var target := int((_game.get("_exit_options") as Dictionary)[direction])
	_release_all()

	_game.set("_segment_from_index", origin)
	_game.set("_segment_target_index", target)
	_game.set("_segment_progress", 0.0)
	_game.set("_segment_length", 720.0)
	_game._restore_drive_state_after_load()
	var idle := await _wait_until_idle()
	_expect(idle, "a save taken mid-step must not load into a permanently stuck vehicle")
	_expect(
		not (_game.get("_exit_options") as Dictionary).is_empty(),
		"recovered vehicle should have route options",
	)


func _check_repeated_taps_keep_moving() -> void:
	# 连续短按若干次，每次都应前进一格并重新出现可选方向。
	for i in range(4):
		var direction := _pick_exit()
		if direction == "":
			_failures.append("no exit available on tap step %d" % i)
			return
		var target := _start_step_like_tap(direction)
		var idle := await _wait_until_idle()
		_expect(idle, "tap step %d should complete" % i)
		_expect(int(_game.get("_current_node_index")) == target, "tap step %d should reach its target" % i)
