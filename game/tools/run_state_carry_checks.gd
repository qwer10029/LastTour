extends SceneTree

## 回归检查：白天 → 夜间塔防 → 白天的真实场景切换中，
## 1) 防御塔升级、累计探索格数等「layer」存档字段不应丢失；
## 2) 夜战车辆损毁后回到白天的结算面板应显示真实天数（而非新场景的第 1 天）与整局探索。
## 运行：godot --headless --path . --script res://tools/run_state_carry_checks.gd
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
		if is_instance_valid(scene.get("minimap_view")) and is_instance_valid(scene.get("time_system")):
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


func _collect_label_text(node: Node, out: PackedStringArray) -> void:
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		_collect_label_text(child, out)


func _run_night(day: Node, result: Dictionary) -> Node:
	day._on_night_setup_scene_switch(1, false)
	var night: Node = await _wait_for_night_scene(3000)
	_expect(night != null, "night TD scene should load")
	if night == null:
		return null
	for i in 30:
		await process_frame
	root.get_node("GameManager").apply_night_result_and_continue(result)
	return await _wait_for_day_scene(night, 3000)


func _run() -> void:
	await process_frame
	var gm := root.get_node("GameManager")
	gm.start_day_exploration(null)
	var day1: Node = await _wait_for_day_scene(null, 1200)
	_expect(day1 != null, "first day scene should load")
	if day1 == null:
		_finish()
		return
	day1._tower_upgrades["damage_mult"] = 1.25
	day1._explored_prior_layers = 37

	var day2: Node = await _run_night(day1, {"outcome": "success", "kind": "normal"})
	_expect(day2 != null, "day 2 scene should load after a normal night")
	if day2 == null:
		_finish()
		return
	_expect(is_equal_approx(float(day2._tower_upgrades.get("damage_mult", 0.0)), 1.25),
		"tower upgrades should survive the night (got %s)" % str(day2._tower_upgrades))
	_expect(int(day2._explored_prior_layers) == 37,
		"explored_prior_layers should survive the night (got %d)" % int(day2._explored_prior_layers))
	var day_before_death := int(day2.time_system.day_index)
	_expect(day_before_death == 2, "day index should be 2 after one night (got %d)" % day_before_death)

	var day3: Node = await _run_night(day2, {"outcome": "vehicle_destroyed", "kind": "normal", "base_hp": 0.0})
	_expect(day3 != null, "day scene should load after the fatal night")
	if day3 != null:
		_expect(bool(day3._run_ended), "run should be ended after vehicle destroyed")
		var overlay: Node = day3._run_end_overlay
		_expect(is_instance_valid(overlay) and overlay.visible, "run summary should be visible")
		if is_instance_valid(overlay):
			var texts := PackedStringArray()
			_collect_label_text(overlay, texts)
			var idx := texts.find("生存天数")
			_expect(idx >= 0 and idx + 1 < texts.size() and texts[idx + 1] == str(day_before_death),
				"summary 生存天数 should be %d (labels: %s)" % [day_before_death, " | ".join(texts)])
			var explored_total := 37 + int(day3._map.explored_count())
			var joined := " | ".join(texts)
			_expect(joined.contains("共 %d 格" % explored_total),
				"summary 地图探索 should include whole-run total %d (labels: %s)" % [explored_total, joined])
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("RUN_STATE_CARRY_CHECKS_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
