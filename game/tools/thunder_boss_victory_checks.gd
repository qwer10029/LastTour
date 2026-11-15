extends SceneTree

## 回归检查（BUG C）：雷霆首领战「击毁雷霆但有敌人突破」时，结算 outcome 为 partial，
## 场景切换路径只认 outcome == "success"，于是回到白天时雷霆仍封锁大门、时间冻结、体力持续流失，
## 最终乘员倒下 / 回到主菜单，无法进入通信终端。
## 本检查走真实的 白天 → 雷霆首领战（夜间场景）→ 结算 → 白天 场景切换：
##   1) 真实的 _update_enemies 击毁雷霆后，结算里应带 boss_defeated=true；
##   2) 击毁雷霆 + 1 次突破（partial）→ 白天场景 thunder_leiting_defeated=true，并补发胜利奖励；
##   3) 车辆损毁仍判负；没击毁雷霆的 partial 也不应被当作胜利。
## 运行：XDG_DATA_HOME=<临时目录> godot --headless --path . --script res://tools/thunder_boss_victory_checks.gd

var _failures: Array[String] = []
var _armor_before := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		print("FAIL: ", message)


func _wait_day(prev: Node, max_frames: int) -> Node:
	for i in max_frames:
		await process_frame
		var s := current_scene
		if s != null and s != prev and s.has_method("_on_night_setup_scene_switch") and is_instance_valid(s.get("time_system")):
			for j in 10:
				await process_frame
			return s
	return null


func _wait_night(max_frames: int) -> Node:
	for i in max_frames:
		await process_frame
		if current_scene != null and current_scene.scene_file_path.contains("night_td"):
			for j in 30:
				await process_frame
			return current_scene
	return null


func _kunlun_district(day: Node) -> int:
	var n: int = day._map.nodes.size() if day._map.get("nodes") != null else 400
	for i in n:
		if day._map.is_district(i) and day._map.district_has_kunlun_control(i):
			return i
	return -1


## 从新开局走到最终层并发起雷霆首领战，返回 [白天场景, 夜间场景]。
func _start_boss_fight() -> Array:
	var gm := root.get_node("GameManager")
	gm.start_day_exploration(null)
	var day: Node = await _wait_day(null, 1500)
	if day == null:
		return []
	while day._current_layer < day.total_layers:
		day._advance_layer()
	var k := _kunlun_district(day)
	if k < 0:
		# 窗口模式下地图节点可能尚未全部登记；首领战本身不依赖具体格子。
		print("note: Kunlun control district not found on the generated map; using -1")
	_armor_before = int(day._backpack.count("composite_armor_panel"))
	day._on_thunder_boss_requested(k)
	var night: Node = await _wait_night(1500)
	_expect(night != null, "thunder boss should open the night TD scene")
	if night == null:
		return []
	return [night]


func _run() -> void:
	await process_frame
	var gm := root.get_node("GameManager")

	# —— 1) 真实击毁路径会记录 boss_defeated ——
	var pair: Array = await _start_boss_fight()
	if pair.is_empty():
		_finish()
		return
	var night: Node = pair[0]
	var td = night.get("_td")
	_expect(td != null, "night scene should expose its TD controller")
	if td == null:
		_finish()
		return
	var field_pos: Vector2 = td.field.cell_to_world(Vector2i(1, 1)) if td.field.has_method("cell_to_world") else Vector2(40, 40)
	td._enemies.append({
		"type": "thunder_leiting", "name": "不败之盾-雷霆", "faction": "enemy",
		"pos": field_pos, "hp": 0.0, "max_hp": 1100.0, "speed": 14.0, "radius": 34.0,
		"base_damage": 34.0, "armor": 0.42, "eid": 999001,
	})
	td._update_enemies(0.016)
	td._enemies_reached = 1   # 一只无人机突破 → partial
	var res: Dictionary = td._build_result()
	_expect(str(res.get("kind", "")) == "thunder_leiting_boss", "result kind should be thunder_leiting_boss")
	_expect(str(res.get("outcome", "")) == "partial", "one breach should still give outcome partial (got %s)" % res.get("outcome"))
	_expect(bool(res.get("boss_defeated", false)), "killing Thunder should set boss_defeated in the TD result")

	# —— 2) partial + 击毁雷霆 → 白天场景视为胜利 ——
	night._on_td_finished(res)
	var day2: Node = await _wait_day(night, 2500)
	if day2 != null and DisplayServer.get_name() != "headless":
		for i in 60:
			await process_frame
		day2.get_viewport().get_texture().get_image().save_png("user://thunder_victory_day.png")
	_expect(day2 != null, "should return to the day scene after the boss fight")
	if day2 != null:
		_expect(not bool(day2._run_ended), "run should not end after beating Thunder")
		_expect(bool(day2._thunder_leiting_defeated), "Thunder killed with a breach should count as defeated (gate must open)")
		_expect(bool(day2._final_defense_cleared), "final defense should be cleared after the Thunder win")
		_expect(int(day2._backpack.count("composite_armor_panel")) >= _armor_before + 3,
			"scene-switch Thunder win should grant the victory rewards (composite_armor_panel ×3)")
		var entries: Array = day2._run_journal.get_entries()
		var has_victory := false
		for e in entries:
			if str(e.get("id", e.get("encounter_id", ""))).begins_with("thunder_leiting_victory"):
				has_victory = true
		_expect(has_victory, "scene-switch Thunder win should add the thunder_leiting_victory journal entry")
		_expect(day2.time_system.is_paused(), "day time should stay paused for the terminal sequence after the win")

	# —— 3) 判定函数边界 ——
	_expect(gm.has_method("is_thunder_boss_victory"), "GameManager.is_thunder_boss_victory should exist")
	if gm.has_method("is_thunder_boss_victory"):
		_expect(not gm.is_thunder_boss_victory({"outcome": "vehicle_destroyed", "boss_defeated": true}), "vehicle destroyed is a loss")
		_expect(not gm.is_thunder_boss_victory({"outcome": "partial", "boss_defeated": false}), "partial without killing Thunder is not a win")
		_expect(gm.is_thunder_boss_victory({"outcome": "fail", "boss_defeated": true}), "Thunder killed with heavy car damage is still a win")
		_expect(gm.is_thunder_boss_victory({"outcome": "success"}), "legacy success result without the flag is a win")
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("thunder_boss_victory_checks: PASS")
		quit(0)
	else:
		print("thunder_boss_victory_checks: FAIL (%d)" % _failures.size())
		quit(1)
