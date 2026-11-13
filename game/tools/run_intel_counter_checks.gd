extends SceneTree

## 回归检查：背包「勘探日记」页的「本局关键情报 N / 4」与 ★ 标记。
## - 计数只看本局日记中的 required_for_truth（不看数据片物品、不看跨局 meta）；
## - 关键情报条目带 ★，其它条目不带；
## - 编史者修复日记写明「已作为一条关键情报记进了日记」。
## 运行：godot --headless --path . --script res://tools/run_intel_counter_checks.gd

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _labels(bp) -> Array[String]:
	var out: Array[String] = []
	for i in bp._journal_list.item_count:
		out.append(bp._journal_list.get_item_text(i))
	return out


func _run() -> void:
	await process_frame
	var jd := root.get_node("JournalData")
	var bp: Control = load("res://scripts/ui/backpack_ui.gd").new()
	bp.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bp)
	await process_frame
	var inv = load("res://scripts/items/inventory_data.gd").new()
	var journal = load("res://scripts/run_journal.gd").new()

	bp.show_backpack(inv, journal, true)
	await process_frame
	_expect(bp._journal_intel_label.text == "本局关键情报 0 / 4", "empty journal should read 0 / 4 (got '%s')" % bp._journal_intel_label.text)

	journal.add_story_outcome("sentinel_s09_parts_gave2", 1, 1)
	journal.add_story_outcome("chronicler_repair", 1, 3)
	journal.add_story_outcome("furnace_truth", 1, 3)
	bp.show_backpack(inv, journal, true)
	await process_frame
	_expect(bp._journal_intel_label.text == "本局关键情报 2 / 4", "S-09 + Chronicler repair + Furnace truth should read 2 / 4 (got '%s')" % bp._journal_intel_label.text)
	_expect(bp._journal_intel_label.visible and bp._journal_view.visible, "intel line should be visible on the journal tab")
	for text in _labels(bp):
		var is_truth := text.contains("编史者") or text.contains("熔炉")
		_expect(text.begins_with("★ ") == is_truth, "★ marker wrong for '%s'" % text)

	var body := str(jd.body_of("chronicler_repair"))
	_expect(body.contains("没有数据片") and body.contains("关键情报"), "Chronicler repair journal should say it still counts as key intel")
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("RUN_INTEL_COUNTER_CHECKS_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
