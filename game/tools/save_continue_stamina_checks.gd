extends SceneTree

## 回归检查：主菜单点「继续游戏」后必须停在暂停菜单，体力和白天时间都不变。
##
## 真实路径：暂停菜单「保存并退出」→ 主菜单「继续游戏」按钮 → 场景切换到 day_exploration。
## 旧的检查直接调用 GameManager.continue_from_save()，不经过按钮，也没有鼠标松开，
## 因此在 PR #20 下就会误报通过。
##
## 在 1000×560 窗口里，主菜单「继续游戏」和暂停菜单「继续游戏」位置重叠。
## 主菜单上按下、场景加载完成后再松开（或加载刚结束时一次残留点击）会点到暂停菜单的
## 「继续游戏」，暂停刚出现就被关掉，看起来像「读档后直接开始扣体力」。
## 本检查按这条真实路径走：点主菜单按钮、按住鼠标直到读档完成、再松开，然后等 2 秒。
## 旧代码第 2 步会失败；修好后应停在暂停菜单，体力与时间都不动。
##
## 之后仍检查：守卫结束后，暂停菜单上按 B 打开背包不扣体力；关掉背包后照常下降。
##
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


func _physics_frames(n: int) -> void:
	for i in n:
		await physics_frame


func _wait_uncovered(max_frames: int) -> void:
	for i in max_frames:
		if not _covering():
			return
		await process_frame


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


func _wait_for_main_menu(max_frames: int) -> Node:
	for i in max_frames:
		await process_frame
		var scene := current_scene
		if scene != null and scene.has_method("_on_continue_pressed") and scene.get("continue_button") != null:
			return scene
	return null


func _hud_stamina_text(day: Node) -> String:
	var lbl = day.get("_stamina_bar_label")
	return str(lbl.text) if is_instance_valid(lbl) else ""


func _set_window_size() -> void:
	DisplayServer.window_set_size(Vector2i(1000, 560))
	root.size = Vector2(1000, 560)
	var vp := root.get_viewport()
	if vp != null:
		vp.size = Vector2i(1000, 560)


func _find_button_by_text(root_node: Node, text: String) -> Button:
	if root_node is Button and str((root_node as Button).text) == text:
		return root_node as Button
	for child in root_node.get_children():
		var found := _find_button_by_text(child, text)
		if found != null:
			return found
	return null


func _mouse_at(pos: Vector2, pressed: Variant = null) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	if pressed != null and bool(pressed):
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	var vp := root.get_viewport()
	if vp != null:
		vp.push_input(motion)
	if pressed == null:
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = bool(pressed)
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if bool(pressed) else 0
	Input.parse_input_event(ev)
	if vp != null:
		vp.push_input(ev)


func _run() -> void:
	await process_frame
	_set_window_size()
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

	var menu: Node = await _wait_for_main_menu(600)
	_expect(menu != null, "save and exit should open the main menu")
	if menu == null:
		_finish()
		return
	_set_window_size()
	await process_frame
	await process_frame

	var btn: Button = menu.continue_button
	_expect(is_instance_valid(btn) and not btn.disabled, "main menu Continue should be enabled")
	if not is_instance_valid(btn):
		_finish()
		return
	# 用真实主菜单按钮，不要直接调用 GameManager.continue_from_save()。
	var continue_pos := btn.get_global_rect().get_center()
	_mouse_at(continue_pos, true)
	await process_frame
	btn.emit_signal("pressed")
	var loaded: Node = await _wait_for_day_scene(4000, day_id)
	_expect(loaded != null, "main-menu Continue should load the day scene")
	if loaded == null:
		_finish()
		return

	# 读档完成、暂停菜单出现后：松开加载期间按着的鼠标（移到角落，避免点到
	# 「保存并退出」），再激活暂停菜单的「继续游戏」。这就是 1000×560 下
	# 主菜单按钮重叠造成的残留点击。旧代码会因此立刻恢复探索。
	_set_window_size()
	await process_frame
	_mouse_at(Vector2(4, 4), false)
	await process_frame
	var pause_layer = loaded.get("_pause_layer")
	var resume_btn: Button = _find_button_by_text(pause_layer, "继续游戏") if is_instance_valid(pause_layer) else null
	_expect(is_instance_valid(resume_btn), "pause menu should have a 继续游戏 button")
	if is_instance_valid(resume_btn):
		var leftover_pos := resume_btn.get_global_rect().get_center()
		_expect(
			resume_btn.get_global_rect().grow(48.0).has_point(continue_pos) or leftover_pos.distance_to(continue_pos) < 120.0,
			"main-menu Continue and pause 继续游戏 should overlap at 1000x560 (menu %s vs pause %s)" % [continue_pos, leftover_pos]
		)
		# 直接走按钮的 pressed（同一条槽函数），避免headless下命中相邻的「保存并退出」。
		resume_btn.emit_signal("pressed")
		await process_frame
		await process_frame

	# 玩家看到画面、按下按键之前的反应时间（2 秒物理帧）。
	await _physics_frames(120)
	if not is_instance_valid(loaded):
		_expect(false, "continue: leftover click on 继续游戏 must not end the loaded scene")
		_finish()
		return
	var s_wait := float(loaded._survival.stamina)
	var e_wait := float(loaded.time_system.elapsed_in_phase)
	_expect(absf(s_wait - saved_stamina) < 0.0001, "continue: stamina must not drain before the player acts (saved %.3f → %.3f after 2 s)" % [saved_stamina, s_wait])
	_expect(absf(e_wait - saved_elapsed) < 0.0001, "continue: day time must not run before the player acts (saved %.3f → %.3f)" % [saved_elapsed, e_wait])
	_expect(bool(loaded._game_paused), "continue: the run should resume on the pause menu")
	_expect(is_instance_valid(loaded._pause_layer) and bool(loaded._pause_layer.visible), "continue: the pause menu should be visible")
	_expect(_hud_stamina_text(loaded) == paused_hud, "continue: HUD stamina should read the same as before saving (%s vs %s)" % [_hud_stamina_text(loaded), paused_hud])

	# 等输入守卫结束后，暂停菜单上按 B：背包打开、暂停层收起，体力仍不变。
	# 旧代码没有这个字段，get 会得到 null，不能丢给 float()。
	for i in 30:
		var guard: Variant = loaded.get("_continue_input_guard_left")
		if guard == null or float(guard) <= 0.0:
			break
		await process_frame
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
