extends SceneTree

## 回归检查：夜间布防开始时不预选任何设施。
## 黄昏强制入夜时玩家常还在点对话/背包，残留点击落到网格上就会直接放下默认的「干扰信标」。
## 1) 正式夜战开局 _selected_tower 与 HUD 都为空，开局宽限期内的网格点击被忽略；
## 2) 没选设施时点网格不放任何东西；点一次「电弧塔」卡片后再点网格放下的就是电弧塔；
## 3) 下一晚开局又清空选择；教程夜仍默认选中（教程依赖）；
## 4) 入夜加载遮罩（不拦截鼠标）还盖着时，落到网格上的点击不放设施。
## 运行：godot --headless --path . --script res://tools/night_setup_selection_checks.gd

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _live_towers(td: Node) -> Array:
	var out: Array = []
	for tower in td._towers:
		if not bool(tower.get("removed", false)):
			out.append(tower)
	return out


func _start(td: Node, options: Dictionary = {}) -> void:
	td.start_session(
		10, 1, 2, true, 100.0, 100.0,
		{"scrap": 20, "wood": 10, "parts": 10, "fuel": 5, "supplies": 5},
		options, 20.0, 100.0
	)


func _click_card(hud: Node, type_id: String) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	hud._on_card_input(ev, type_id)


func _free_cell(td: Node) -> Vector2i:
	var field = td.field
	for y in range(3, field.grid_rows - 3):
		for x in range(3, field.grid_cols - 3):
			var c := Vector2i(x, y)
			if field.can_place_tower(c, td._occupied_cells):
				return c
	return Vector2i(-1, -1)


func _check_td_scene() -> void:
	var td: Node = load("res://scenes/night_td/night_td.tscn").instantiate()
	root.add_child(td)
	await process_frame
	_start(td)
	await process_frame
	td.set_process(false)
	var hud: Node = td.get_node("Hud")
	_expect(str(td._selected_tower) == "", "night setup should start with no build preselected (got %s)" % td._selected_tower)
	_expect(str(hud.get_selected_tower()) == "", "night HUD should not highlight a default build card")
	var cell := _free_cell(td)
	_expect(cell.x >= 0, "should find a free placement cell")
	td._on_cell_clicked(cell)
	_expect(_live_towers(td).is_empty(), "a click right after night setup starts should be swallowed")
	td._place_input_ready_msec = 0
	td._on_cell_clicked(cell)
	_expect(_live_towers(td).is_empty(), "with nothing selected a grid click must not place a beacon")
	var transition := root.get_node_or_null("RunTransition")
	_expect(transition != null, "RunTransition autoload should exist")
	if transition != null:
		_click_card(hud, "jammer")
		transition.show_cover()
		td._on_cell_clicked(cell)
		_expect(_live_towers(td).is_empty(), "grid clicks under the night loading cover should be ignored")
		transition.hide_cover()
		td._selected_tower = ""
		hud.clear_tower_selection()
	_click_card(hud, "splash")
	_expect(str(td._selected_tower) == "splash", "one click on the 电弧塔 card should select it")
	td._on_cell_clicked(cell)
	var towers := _live_towers(td)
	_expect(towers.size() == 1 and str(towers[0].get("type", "")) == "splash", "after picking 电弧塔 the grid click should place an arc tower (%s)" % [towers])
	# 下一晚：选择重新清空。
	td.hide_session()
	_start(td)
	await process_frame
	_expect(str(td._selected_tower) == "" and str(hud.get_selected_tower()) == "", "the next night should start with no build preselected again")
	td.hide_session()
	# 教程夜保留默认选中（教程脚本假设已选中一座塔）。
	_start(td, {"kind": "tutorial"})
	await process_frame
	_expect(str(td._selected_tower) != "", "tutorial night should still preselect a tower")
	td.hide_session()
	td.queue_free()
	await process_frame


func _run() -> void:
	await process_frame
	await _check_td_scene()
	if _failures.is_empty():
		print("NIGHT_SETUP_SELECTION_CHECKS_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
