extends SceneTree

## 回归检查：未揭示的隐藏物资点（tactical_hidden）在揭示前
## 1) 车停在它门口的路口时不应被标记为已探索；
## 2) M 地图 / 小地图视为空地（开雾、关雾都不可见，即使旧存档里已被标成 explored）；
## 揭示后正常显示，停车后可被标记为已探索。
## 运行：godot --headless --path . --script res://tools/hidden_cache_map_checks.gd
## 建议设置独立的 XDG_DATA_HOME。

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _wait_for_day_scene(max_frames: int) -> Node:
	for i in max_frames:
		await process_frame
		var scene := current_scene
		if scene == null or not scene.has_method("_halt_at_node"):
			continue
		if is_instance_valid(scene.get("minimap_view")) and scene.get("_map") != null:
			for j in 10:
				await process_frame
			return scene
	return null


func _run() -> void:
	await process_frame
	root.get_node("GameManager").start_day_exploration(null)
	var day: Node = await _wait_for_day_scene(1200)
	_expect(day != null, "day scene should load")
	if day == null:
		_finish()
		return
	var map = day._map
	var minimap = day.minimap_view
	var site := -1
	var source := ""
	for idx in map.district_indices:
		if map.is_tactical_dormant(idx):
			site = idx
			source = str(map.get_cell(idx).get("tactical_source", ""))
			break
	_expect(site >= 0, "layer 1 should have a dormant hidden cache")
	if site < 0:
		_finish()
		return
	var approach := int(map.get_cell(site).get("approach_road_index", -1))
	_expect(map.is_valid_index(approach), "hidden cache should have an approach road")

	map.get_cell(site)["explored"] = false
	day._halt_at_node(approach)
	_expect(not bool(map.get_cell(site).get("explored", false)),
		"halting at a dormant cache's door should not mark it explored")

	var fog_before := bool(minimap.war_fog_enabled)
	minimap.war_fog_enabled = true
	_expect(not minimap._cell_visible(site), "dormant cache should be hidden on the map with fog on")
	minimap.war_fog_enabled = false
	_expect(not minimap._cell_visible(site), "dormant cache should be hidden on the map with fog off")
	# 旧存档可能已把它标成 explored：仍应视为空地
	map.get_cell(site)["explored"] = true
	minimap.war_fog_enabled = true
	_expect(not minimap._cell_visible(site), "dormant cache marked explored by an old save should stay hidden")
	map.get_cell(site)["explored"] = false

	_expect(map.reveal_tactical_hidden_sites(source), "reveal should succeed")
	_expect(not map.is_tactical_dormant(site), "cache should no longer be dormant after reveal")
	_expect(minimap._cell_visible(site), "revealed cache should be visible on the map with fog on")
	_expect(map.building_label(site) == str(map.get_cell(site).get("tactical_label", "")),
		"revealed cache should show its tactical label")
	day._halt_at_node(approach)
	_expect(bool(map.get_cell(site).get("explored", false)),
		"halting at a revealed cache's door should mark it explored")
	minimap.war_fog_enabled = fog_before
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("HIDDEN_CACHE_MAP_CHECKS_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
