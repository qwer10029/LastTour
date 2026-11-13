extends SceneTree

## 回归检查：背包「丢弃」误触保护。
## 1) 选中不同物品时「使用 / 丢弃」按钮位置不变；
## 2) 可使用物品（补给等）需两次点击才丢弃，超时或切换物品会取消确认；
## 3) 不可使用物品（废料等）一次点击即丢弃。
## 运行：godot --headless --path . --script res://tools/backpack_discard_checks.gd

var _failures: Array[String] = []
var _discarded: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _select(bp: Node, item_id: String) -> void:
	for i in bp._item_list.item_count:
		if str(bp._item_list.get_item_metadata(i)) == item_id:
			bp._item_list.select(i)
			bp._on_item_selected(i)
			break
	await process_frame
	await process_frame


func _run() -> void:
	await process_frame
	# 运行时加载，避免 --script 编译阶段 autoload（JournalData 等）尚未注册导致的编译错误
	var bp: Control = load("res://scripts/ui/backpack_ui.gd").new()
	bp.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bp)
	await process_frame
	bp.item_discard_requested.connect(func(id: String): _discarded.append(id))
	var inv = load("res://scripts/items/inventory_data.gd").new()
	for id in ["supplies", "scrap", "fuel", "parts", "tower_mod", "radar_coords"]:
		inv.add(id, 3)
	bp.show_backpack(inv)
	await process_frame
	await process_frame

	# 1) 按钮位置固定
	var use_pos := {}
	var discard_pos := {}
	for i in bp._item_list.item_count:
		var id := str(bp._item_list.get_item_metadata(i))
		await _select(bp, id)
		use_pos[bp._use_btn.get_global_rect().position] = true
		discard_pos[bp._discard_btn.get_global_rect().position] = true
	_expect(use_pos.size() == 1, "使用 button should not move between items: %s" % str(use_pos.keys()))
	_expect(discard_pos.size() == 1, "丢弃 button should not move between items: %s" % str(discard_pos.keys()))

	# 2) 可使用物品：两步确认
	await _select(bp, "supplies")
	_expect(_item_defs().is_usable("supplies"), "supplies should be usable")
	bp._on_discard_pressed()
	_expect(_discarded.is_empty(), "first 丢弃 press on supplies should only arm the confirmation")
	_expect(bp._discard_btn.text == bp.DISCARD_CONFIRM_TEXT, "button should show the confirm text")
	bp._on_discard_pressed()
	_expect(_discarded == ["supplies"], "second press should discard supplies (got %s)" % str(_discarded))
	_expect(bp._discard_btn.text == bp.DISCARD_TEXT, "button text should reset after discarding")

	# 切换物品取消确认
	_discarded.clear()
	await _select(bp, "supplies")
	bp._on_discard_pressed()
	await _select(bp, "fuel")
	_expect(bp._discard_btn.text == bp.DISCARD_TEXT, "changing selection should cancel the confirmation")
	bp._on_discard_pressed()
	_expect(_discarded.is_empty(), "first press on another usable item should arm again, not discard")

	# 超时取消确认
	await create_timer(bp.DISCARD_CONFIRM_SECONDS + 0.5).timeout
	_expect(bp._discard_btn.text == bp.DISCARD_TEXT, "confirmation should time out")
	bp._on_discard_pressed()
	_expect(_discarded.is_empty(), "press after timeout should arm again, not discard")

	# 3) 不可使用物品：一次即丢
	_discarded.clear()
	await _select(bp, "scrap")
	_expect(not _item_defs().is_usable("scrap"), "scrap should not be usable")
	bp._on_discard_pressed()
	_expect(_discarded == ["scrap"], "scrap should discard on one press (got %s)" % str(_discarded))
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("BACKPACK_DISCARD_CHECKS_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _item_defs() -> GDScript:
	return load("res://scripts/items/item_defs.gd")
