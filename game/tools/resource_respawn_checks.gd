extends SceneTree

## 回归检查：建筑里捡走的物资不会再刷新。
## 对每个特殊建筑（揭示后的隐藏物资点：燃料储备点 / 备件藏匿点 / 隐藏仓库，以及军械库）和一座普通建筑：
## 步行进去用真实的拾取逻辑捡走除一件以外的全部物资 → 出门 → 再进门；存档 → 读档；
## 黎明切场景（RunState 往返）之后，捡走的都不回来，没捡的那件还在。
## 运行：godot --headless --path . --script res://tools/resource_respawn_checks.gd
## 建议设置独立的 XDG_DATA_HOME（会写 user://run_save.json）。

var _failures: Array[String] = []
var _expected_left: Dictionary = {}   # district -> Array[String]（剩下的 item_id）
var _labels: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _wait_for_day_scene(max_frames: int, previous_id: int = 0) -> Node:
	for i in max_frames:
		await process_frame
		var scene := current_scene
		if scene == null or scene.get_instance_id() == previous_id or not scene.has_method("_try_collect_interior_pickups"):
			continue
		if scene.get("_map") != null and is_instance_valid(scene.get("time_system")) and scene.time_system.phase == TimeSystem.Phase.DAY:
			for j in 10:
				await process_frame
			return scene
	return null


func _live(day: Node, district: int) -> Array:
	var out: Array = []
	for n in day._resource_nodes:
		if is_instance_valid(n) and int(n.get_meta("district_index", -1)) == district and not bool(n.get_meta("picked_up", false)):
			out.append(str(n.get_meta("item_id", "")))
	out.sort()
	return out


func _enter(day: Node, district: int) -> void:
	day._current_node_index = int(day._map.get_cell(district).get("approach_road_index", day._current_node_index))
	day._begin_foot_mode(district)
	for i in 3:
		await process_frame


func _leave(day: Node) -> void:
	day._return_to_vehicle()
	for i in 3:
		await process_frame


func _collect_all_but_one(day: Node, district: int) -> void:
	var nodes: Array = []
	for n in day._resource_nodes:
		if is_instance_valid(n) and int(n.get_meta("district_index", -1)) == district and not bool(n.get_meta("picked_up", false)):
			nodes.append(n)
	_expect(nodes.size() >= 2, "%s should have at least 2 pickups (has %d)" % [_labels[district], nodes.size()])
	var keep: Area2D = nodes[nodes.size() - 1]
	var origin: Vector2 = day._map.get_foot_origin(district)
	for n in nodes:
		if n == keep:
			continue
		day._foot_local_pos = n.global_position - origin
		day._try_collect_interior_pickups()
	_expected_left[district] = [str(keep.get_meta("item_id", ""))]
	var live := _live(day, district)
	_expect(live == _expected_left[district], "%s: walking over the pickups should collect them (left %s)" % [_labels[district], live])


func _check_all(day: Node, stage: String) -> void:
	for district in _expected_left.keys():
		var live := _live(day, district)
		_expect(live == _expected_left[district], "%s after %s: collected loot respawned (live %s, expected %s)" % [_labels[district], stage, live, _expected_left[district]])
		await _enter(day, district)
		live = _live(day, district)
		_expect(live == _expected_left[district], "%s after %s + re-entry: collected loot respawned (live %s)" % [_labels[district], stage, live])
		await _leave(day)


func _run() -> void:
	await process_frame
	root.get_node("GameManager").start_day_exploration(null)
	var day: Node = await _wait_for_day_scene(3000)
	_expect(day != null, "day scene should load")
	if day == null:
		_finish()
		return
	var map = day._map
	map.reveal_tactical_hidden_sites("")
	day._spawn_resources()
	day._refresh_resource_pickups()
	var targets: Array[int] = []
	var plain := -1
	for idx in map.district_indices:
		var cell: Dictionary = map.get_cell(idx)
		if str(cell.get("story_id", "")) != "" or bool(cell.get("has_elevator", false)):
			continue
		var spawns: Array = cell.get("resource_spawns", [])
		if spawns.size() < 2:
			continue
		var special := bool(cell.get("tactical_revealed", false)) or str(cell.get("building_type", "")) == "armory"
		if special:
			targets.append(idx)
			_labels[idx] = "%s %s#%d" % [str(cell.get("building_type", "")), str(cell.get("tactical_label", cell.get("building_label_override", ""))), idx]
		elif plain < 0:
			plain = idx
	_expect(targets.size() >= 3, "layer 1 should have the 3 hidden caches revealed (found %d special buildings)" % targets.size())
	if plain >= 0:
		targets.append(plain)
		_labels[plain] = "%s#%d" % [str(map.get_cell(plain).get("building_type", "")), plain]
	for district in targets:
		await _enter(day, district)
		_expect(int(day._mode) == int(day.TravelMode.FOOT) and int(day._current_district_index) == district, "%s: should be able to enter on foot" % _labels[district])
		_collect_all_but_one(day, district)
		await _leave(day)
	await _check_all(day, "leaving and re-entering")

	# 存档 → 读档。
	_expect(root.get_node("SaveManager").save_game(day.capture_save_data()), "save should succeed")
	var day_id := day.get_instance_id()
	root.get_node("GameManager").continue_from_save()
	day = await _wait_for_day_scene(3000, day_id)
	_expect(day != null, "continue should load the day scene")
	if day != null:
		await _check_all(day, "save/load")
		# 黎明切场景：RunState 往返。
		day_id = day.get_instance_id()
		root.get_node("GameManager").start_day_via_loading(day.export_run_state())
		day = await _wait_for_day_scene(3000, day_id)
		_expect(day != null, "dawn reload should load the day scene")
		if day != null:
			await _check_all(day, "night/dawn reload")
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("checked: ", _labels.values())
		print("RESOURCE_RESPAWN_CHECKS_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
