extends SceneTree

## 回归检查：体力只在白天/黄昏真正探索时下降。
## 1) 新开局 / 黎明切场景时白天场景在加载遮罩后面已经开始跑物理帧，遮罩（含淡出）期间不扣体力；
## 2) 暂停菜单、M 地图打开时不扣体力；
## 3) 存档 → 读档后体力与存档一致（只差读档后真实经过的探索时间）；
## 4) 夜战结算的体力变化只有失败 -15 / 部分失守 -5（成功不变）。
## 运行：godot --headless --path . --script res://tools/stamina_pause_checks.gd
## 建议设置独立的 XDG_DATA_HOME（会写 user://run_save.json）。

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _transition() -> Node:
	return root.get_node_or_null("RunTransition")


func _covering() -> bool:
	var t := _transition()
	return t != null and bool(t.is_covering())


func _wait_for_day_scene(max_frames: int, previous_id: int = 0) -> Node:
	for i in max_frames:
		await process_frame
		var scene := current_scene
		if scene == null or scene.get_instance_id() == previous_id or not scene.has_method("_tick_survival"):
			continue
		if scene.get("_map") != null and is_instance_valid(scene.get("time_system")) and scene.get("_survival") != null:
			if scene.time_system.phase == TimeSystem.Phase.DAY:
				return scene
	return null


func _physics_frames(n: int) -> void:
	for i in n:
		await physics_frame


func _wait_uncovered(max_frames: int) -> void:
	for i in max_frames:
		if not _covering():
			return
		await process_frame


func _check_dawn_cover(day: Node) -> Node:
	# 模拟夜战结束切回白天：走 start_day_via_loading（显示「黎明将至」遮罩）。
	var rs = day.export_run_state()
	rs.survival_dict = {"stamina": 50.0}
	var day_id := day.get_instance_id()
	root.get_node("GameManager").start_day_via_loading(rs)
	var next: Node = await _wait_for_day_scene(3000, day_id)
	_expect(next != null, "dawn: day scene should load again")
	if next == null:
		return null
	_expect(_covering(), "dawn: the loading cover should still be up when the day scene is ready")
	var during := float(next._survival.stamina)
	await _wait_uncovered(3000)
	var after := float(next._survival.stamina)
	_expect(absf(during - 50.0) < 0.001, "dawn: stamina should not drain while the cover is up (got %.3f)" % during)
	_expect(absf(after - 50.0) < 0.05, "dawn: stamina should not drain behind the fading cover (50 → %.3f)" % after)
	return next


func _run() -> void:
	await process_frame
	root.get_node("GameManager").start_day_exploration(null)
	var day: Node = await _wait_for_day_scene(3000)
	_expect(day != null, "day scene should load")
	if day == null:
		_finish()
		return
	await _wait_uncovered(3000)
	await _physics_frames(5)
	var surv = day._survival

	# 正常白天探索：会扣体力（基准）。
	var s0 := float(surv.stamina)
	await _physics_frames(60)
	_expect(float(surv.stamina) < s0 - 0.2, "daytime exploration should still drain stamina (%.3f → %.3f)" % [s0, surv.stamina])

	# 遮罩盖着时不扣。
	var t := _transition()
	_expect(t != null, "RunTransition autoload should exist")
	if t != null:
		t.show_cover()
		var s1 := float(surv.stamina)
		await _physics_frames(60)
		_expect(absf(float(surv.stamina) - s1) < 0.001, "stamina should not drain while the loading cover is up (%.3f → %.3f)" % [s1, surv.stamina])
		t.hide_cover()

	# 暂停菜单。
	day._pause_game()
	var s2 := float(surv.stamina)
	await _physics_frames(60)
	_expect(absf(float(surv.stamina) - s2) < 0.001, "stamina should not drain on the pause menu")
	day._resume_from_pause()

	# M 地图。
	day._open_world_map()
	var s3 := float(surv.stamina)
	await _physics_frames(60)
	_expect(absf(float(surv.stamina) - s3) < 0.001, "stamina should not drain while the map is open")
	day._close_world_map()
	await _physics_frames(2)

	# 存档 → 读档。
	surv.stamina = 71.0
	var saved_elapsed := float(day.time_system.elapsed_in_phase)
	_expect(root.get_node("SaveManager").save_game(day.capture_save_data()), "save should succeed")
	var day_id := day.get_instance_id()
	root.get_node("GameManager").go_to_main_menu()
	for i in 90:
		await process_frame
	root.get_node("GameManager").continue_from_save()
	var loaded: Node = await _wait_for_day_scene(3000, day_id)
	_expect(loaded != null, "continue should load the day scene")
	if loaded != null:
		await _physics_frames(1)
		var played := maxf(float(loaded.time_system.elapsed_in_phase) - saved_elapsed, 0.0)
		var expected := 71.0 - PlayerSurvival.STAMINA_DECAY_PER_SEC * played
		_expect(absf(float(loaded._survival.stamina) - expected) < 0.1, "stamina after load should match the save (expected ≈%.2f, got %.2f, %.2fs played)" % [expected, loaded._survival.stamina, played])
		day = loaded
		var dawn: Node = await _check_dawn_cover(day)
		if dawn != null:
			day = dawn

	# 夜战结算体力：成功不变、部分失守 -5、失败 -15。
	var rs_script: GDScript = load("res://scripts/run_state.gd")
	for case in [["success", 0.0], ["partial", 5.0], ["fail", 15.0]]:
		var rs = rs_script.new()
		rs.survival_dict = {"stamina": 60.0}
		rs.apply_night_result({"outcome": case[0]})
		_expect(absf(float(rs.survival_dict["stamina"]) - (60.0 - float(case[1]))) < 0.001, "night outcome %s should cost %.0f stamina" % [case[0], case[1]])
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("STAMINA_PAUSE_CHECKS_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
