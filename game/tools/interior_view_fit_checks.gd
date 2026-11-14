extends SceneTree

## 回归检查：步行进入建筑后，室内俯视面板（屏幕坐标绘制，没有跟随相机）必须完整落在视口里、
## 不压在顶部 HUD 下面。之前固定 2.15 倍缩放的 14×10 面板在 1000x560 窗口（视口 1157x648）
## 和工程默认 1152x648 下都会超出底边，玩家走到底排/顶排就出屏。
## 运行：godot --headless --path . --script res://tools/interior_view_fit_checks.gd

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _run() -> void:
	await process_frame
	# 与 WorldMapData.INTERIOR_COLS / INTERIOR_ROWS / FOOT_TILE_SIZE 一致（WorldMapData 依赖 StoryData 自动加载，
	# --script 编译阶段直接引用会报找不到，这里写常量并在下面对照运行时的值）。
	var cols := 14
	var rows := 10
	var foot_tile := 28.0
	var map_script: GDScript = load("res://scripts/world_map_data.gd")
	_expect(int(map_script.INTERIOR_COLS) == cols and int(map_script.INTERIOR_ROWS) == rows and int(map_script.FOOT_TILE_SIZE) == int(foot_tile), "interior grid constants changed; update this check")
	var scale := 2.15
	var hud_bottom := HudTheme.TOP_HUD_Y + HudTheme.TOP_BAR_HEIGHT
	# 1000x560、1280x720、默认 1152x648 窗口按 canvas_items + expand 拉伸后的视口尺寸，以及较大的窗口。
	var views: Array[Vector2] = [
		Vector2(1157.0, 648.0),
		Vector2(1152.0, 648.0),
		Vector2(1152.0, 720.0),
		Vector2(1280.0, 720.0),
		Vector2(1600.0, 900.0),
		Vector2(1920.0, 1080.0),
	]
	for view in views:
		var panel: Rect2 = HudTheme.interior_panel_rect_for_view(view, cols, rows, foot_tile * scale)
		var tag := "%dx%d" % [int(view.x), int(view.y)]
		_expect(panel.position.x >= 0.0 and panel.end.x <= view.x, "%s: interior panel should fit horizontally (%s)" % [tag, panel])
		_expect(panel.end.y <= view.y + 0.01, "%s: interior panel bottom row should stay on screen (%s)" % [tag, panel])
		_expect(panel.position.y >= hud_bottom, "%s: interior top row should not sit under the top HUD (%s)" % [tag, panel])
		_expect(absf(panel.size.x / float(cols) - panel.size.y / float(rows)) < 0.01, "%s: interior tiles should stay square" % tag)
		_expect(panel.size.x / float(cols) <= foot_tile * scale + 0.01, "%s: interior should never grow past the configured scale" % tag)
	# 大窗口下保持原来的尺寸和位置（只在放不下时才缩小）。
	var legacy_size := Vector2(float(cols), float(rows)) * foot_tile * scale
	var big_view := Vector2(1152.0, 720.0)
	var big: Rect2 = HudTheme.interior_panel_rect_for_view(big_view, cols, rows, foot_tile * scale)
	_expect(big.size.is_equal_approx(legacy_size), "1152x720: interior panel should keep the original 2.15x size")
	_expect(big.position.is_equal_approx((big_view - legacy_size) * 0.5 + Vector2(0.0, 36.0)), "1152x720: interior panel should keep the original position")
	if _failures.is_empty():
		print("INTERIOR_VIEW_FIT_CHECKS_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
