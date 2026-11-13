extends SceneTree

## 回归检查：暂停菜单关闭战争黑雾后，经过「白天 → 夜间塔防 → 白天」的真实场景切换，
## 新的白天场景仍应保持黑雾关闭（复选框、主地图、小地图一致）。
## 运行：godot --headless --path . --script res://tools/fog_day_night_checks.gd
## 建议设置独立的 XDG_DATA_HOME，避免黎明自动存档写入正在使用的存档目录。

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _wait_for_day_scene(previous: Node, max_frames: int) -> Node:
	for i in max_frames:
		await process_frame
		var scene := current_scene
		if scene == null or scene == previous:
			continue
		if not scene.has_method("_on_night_setup_scene_switch"):
			continue
		var checkbox = scene.get("_war_fog_checkbox")
		if checkbox != null and is_instance_valid(checkbox) and is_instance_valid(scene.get("minimap_view")):
			for j in 10:
				await process_frame
			return scene
	return null


func _wait_for_night_scene(max_frames: int) -> Node:
	for i in max_frames:
		await process_frame
		var scene := current_scene
		if scene != null and scene.scene_file_path.contains("night_td"):
			return scene
	return null


func _run() -> void:
	await process_frame
	var gm := root.get_node("GameManager")
	gm.start_day_exploration(null)
	var day1: Node = await _wait_for_day_scene(null, 1200)
	_expect(day1 != null, "first day scene should load")
	if day1 == null:
		_finish()
		return
	_expect(bool(day1.war_fog_enabled), "fog should start enabled")
	day1._war_fog_checkbox.button_pressed = false
	_expect(not bool(day1.war_fog_enabled), "toggling the checkbox should disable fog")

	day1._on_night_setup_scene_switch(1, false)
	var night: Node = await _wait_for_night_scene(3000)
	_expect(night != null, "night TD scene should load")
	if night == null:
		_finish()
		return
	for i in 30:
		await process_frame
	gm.apply_night_result_and_continue({"outcome": "success", "kind": "normal"})
	var day2: Node = await _wait_for_day_scene(night, 3000)
	_expect(day2 != null, "next day scene should load after the night")
	if day2 != null:
		_expect(not bool(day2.war_fog_enabled), "fog should stay disabled on the next day")
		_expect(not day2._war_fog_checkbox.button_pressed, "pause-menu fog checkbox should stay unchecked")
		_expect(not bool(day2.minimap_view.war_fog_enabled), "minimap should stay fog-free")
		# 恢复默认，避免影响同进程内的其它检查
		day2._war_fog_checkbox.button_pressed = true
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("FOG_DAY_NIGHT_CHECKS_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
