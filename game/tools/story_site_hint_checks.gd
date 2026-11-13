extends SceneTree

## 回归检查：M 地图 / 小地图上未探索的剧情据点显示淡「?」。
## - 开雾且未探索：剧情据点（第 1 层 S-09 / 编史者 / 熔炉，第 2 层 参谋-07 / AD-1 / 玛丽安）显示「?」；
## - 探索后、关雾时不显示；隐藏物资点、普通建筑永不显示。
## 运行：godot --headless --path . --script res://tools/story_site_hint_checks.gd
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


func _check_layer(minimap, map, layer: int, expected_ids: Array) -> void:
	var fog_before := bool(minimap.war_fog_enabled)
	var map_before = minimap.world_map
	minimap.world_map = map
	minimap.war_fog_enabled = true
	var found: Array = []
	var normal_checked := 0
	var dormant_checked := 0
	for idx in map.district_indices:
		var cell: Dictionary = map.get_cell(idx)
		var story_id := str(cell.get("story_id", ""))
		var was_explored := bool(cell.get("explored", false))
		cell["explored"] = false
		if map.is_tactical_dormant(idx):
			dormant_checked += 1
			_expect(not minimap.story_site_hint_visible(idx), "L%d: hidden cache %d must not show '?'" % [layer, idx])
		elif story_id != "":
			found.append(story_id)
			_expect(minimap.story_site_hint_visible(idx), "L%d: unexplored %s should show '?'" % [layer, story_id])
			cell["explored"] = true
			_expect(not minimap.story_site_hint_visible(idx), "L%d: explored %s should not show '?'" % [layer, story_id])
			cell["explored"] = false
			minimap.war_fog_enabled = false
			_expect(not minimap.story_site_hint_visible(idx), "L%d: %s should not show '?' with fog off" % [layer, story_id])
			minimap.war_fog_enabled = true
		else:
			normal_checked += 1
			_expect(not minimap.story_site_hint_visible(idx), "L%d: normal building %d must not show '?'" % [layer, idx])
		cell["explored"] = was_explored
	for sid in expected_ids:
		_expect(sid in found, "L%d: story district %s should exist on the map" % [layer, sid])
	_expect(normal_checked > 0, "L%d: should have normal buildings to check" % layer)
	_expect(dormant_checked > 0, "L%d: should have hidden caches to check" % layer)
	minimap.world_map = map_before
	minimap.war_fog_enabled = fog_before


func _run() -> void:
	await process_frame
	root.get_node("GameManager").start_day_exploration(null)
	var day: Node = await _wait_for_day_scene(1200)
	_expect(day != null, "day scene should load")
	if day == null:
		_finish()
		return
	var minimap = day.minimap_view
	_check_layer(minimap, day._map, 1, ["sentinel_s09", "chronicler_04", "furnace_qc"])
	# 第 2 层：按游戏同样的流程生成一张地图
	var map2 = load("res://scripts/world_map_data.gd").new()
	map2.generate(24, 18, Vector2i(720, 720), 0, false, false, Callable(), 1.0)
	root.get_node("StoryData").ensure_story_districts(map2, 2)
	root.get_node("StoryData").setup_tactical_hidden_sites(map2, 2)
	load("res://scripts/armory_site_data.gd").place_on_map(map2, 2)
	_check_layer(minimap, map2, 2, ["staff_officer_07", "ad_1_radar", "marian_k142"])
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("STORY_SITE_HINT_CHECKS_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
