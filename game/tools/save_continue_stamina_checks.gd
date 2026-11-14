extends SceneTree

## 回归检查：暂停菜单「保存并退出」→ 主菜单「继续游戏」→ 立刻按 B，体力与白天时间一个点都不能少。
## 1) 保存并退出写下的体力 / 时间就是暂停时 HUD 上的值；
## 2) 读档完成后游戏停在暂停菜单：玩家还没操作（这里等 2 秒物理帧模拟反应时间）时不扣体力、不走时间；
## 3) 暂停菜单上按 B 直接打开背包（收起暂停层），体力仍不变；
## 4) 关掉背包后恢复正常探索，体力照常下降。
## 旧代码读档后立即恢复计时，第 2 步会失败。
## 运行：godot --headless --path . --script res://tools/save_continue_stamina_checks.gd
## 请设置独立的 XDG_DATA_HOME（会写 user://run_save.json）。

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _covering() -> bool:
	var t := root.get_node_or_null("RunTransition")
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


func _hud_stamina_text(day: Node) -> String:
	var lbl = day.get("_stamina_bar_label")
	return str(lbl.text) if is_instance_valid(lbl) else ""


func _run() -> void:
	await process_frame
	var gm := root.get_node("GameManager")
	gm.start_day_exploration(null)
	var day: Node = await _wait_for_day_scene(3000)
	_expect(day != null, "day scene should load")
	if day == null:
		_finish()
		return
	await _wait_uncovered(3000)
	await _physics_frames(5)

	# 白天探索到体力 24 左右，然后 Esc 打开暂停菜单。
	day._survival.stamina = 24.3
	await _physics_frames(30)
	_expect(float(day._survival.stamina) < 24.3, "baseline: exploration should drain stamina")
	day._pause_game()
	await _physics_frames(30)
	var paused_stamina := float(day._survival.stamina)
	var paused_elapsed := float(day.time_system.elapsed_in_phase)
	var paused_hud := _hud_stamina_text(day)

	# 点「保存并退出」（按钮的同一个处理函数）。
	var day_id := day.get_instance_id()
	day._save_and_exit_to_menu()
	var saved: Dictionary = root.get_node("SaveManager").load_game()
	var saved_stamina := float(saved.get("travel", {}).get("survival", {}).get("stamina", -1.0))
	var saved_elapsed := float(saved.get("time", {}).get("elapsed_in_phase", -1.0))
	_expect(absf(saved_stamina - paused_stamina) < 0.0001, "save should write the paused stamina (%.4f vs %.4f)" % [saved_stamina, paused_stamina])
	_expect(absf(saved_elapsed - paused_elapsed) < 0.0001, "save should write the paused day time (%.4f vs %.4f)" % [saved_elapsed, paused_elapsed])

	for i in 90:
		await process_frame
	gm.continue_from_save()
	var loaded: Node = await _wait_for_day_scene(3000, day_id)
	_expect(loaded != null, "continue should load the day scene")
	if loaded == null:
		_finish()
		return

	# 玩家看到画面、按下 B 之前的反应时间（2 秒物理帧）。
	await _physics_frames(120)
	var s_wait := float(loaded._survival.stamina)
	var e_wait := float(loaded.time_system.elapsed_in_phase)
	_expect(absf(s_wait - saved_stamina) < 0.0001, "continue: stamina must not drain before the player acts (saved %.3f → %.3f after 2 s)" % [saved_stamina, s_wait])
	_expect(absf(e_wait - saved_elapsed) < 0.0001, "continue: day time must not run before the player acts (saved %.3f → %.3f)" % [saved_elapsed, e_wait])
	_expect(bool(loaded._game_paused), "continue: the run should resume on the pause menu")
	_expect(_hud_stamina_text(loaded) == paused_hud, "continue: HUD stamina should read the same as before saving (%s vs %s)" % [_hud_stamina_text(loaded), paused_hud])

	# 暂停菜单上按 B：背包打开、暂停层收起，体力仍不变。
	loaded._toggle_backpack()
	await _physics_frames(60)
	_expect(bool(loaded._backpack_open), "B on the pause menu should open the backpack")
	_expect(not bool(loaded._game_paused) and not bool(loaded._pause_layer.visible), "B on the pause menu should hide the pause menu")
	_expect(absf(float(loaded._survival.stamina) - saved_stamina) < 0.0001, "backpack open: stamina must stay at the saved value (%.3f)" % loaded._survival.stamina)

	# 关背包后恢复探索：体力照常下降。
	loaded._toggle_backpack()
	await _physics_frames(60)
	_expect(not bool(loaded._backpack_open), "B again should close the backpack")
	_expect(float(loaded._survival.stamina) < saved_stamina - 0.2, "after closing the backpack exploration should drain again (%.3f → %.3f)" % [saved_stamina, loaded._survival.stamina])

	# Esc 继续：同样恢复计时。
	loaded._pause_game()
	var s_p := float(loaded._survival.stamina)
	await _physics_frames(30)
	_expect(absf(float(loaded._survival.stamina) - s_p) < 0.0001, "pause menu should hold stamina")
	loaded._resume_from_pause()
	await _physics_frames(60)
	_expect(float(loaded._survival.stamina) < s_p - 0.2, "resuming from the pause menu should drain again")
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("SAVE_CONTINUE_STAMINA_CHECKS_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
