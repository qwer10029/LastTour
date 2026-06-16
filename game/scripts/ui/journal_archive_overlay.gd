extends CanvasLayer
class_name JournalArchiveOverlay
## 主菜单「查看日志」— 与局末汇总相同的 Sci-Fi 终端面板；仅显示到顶上传记录，条目可点开。

const SciFiFramePanelScript = preload("res://scripts/ui/sci_fi_frame_panel.gd")

signal closed
signal archive_cleared

const COLOR_STAT_LABEL := Color("#6a8498")
const COLOR_STAT_VALUE := Color("#e4eef8")
const COLOR_ALERT := Color("#ff6b6b")

var _dim: ColorRect
var _frame: SciFiFramePanel
var _stats_box: VBoxContainer
var _list_host: Control
var _list_scroll: ScrollContainer
var _list_root: VBoxContainer
var _detail_root: VBoxContainer
var _detail_title: Label
var _detail_body: RichTextLabel
var _close_btn: Button
var _reset_btn: Button
var _back_btn: Button
var _confirm_layer: ColorRect
var _confirm_panel: PanelContainer


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func show_archive() -> void:
	_show_list_view()
	_refresh_content()
	visible = true


func hide_archive() -> void:
	_hide_reset_confirm()
	visible = false
	_show_list_view()
	closed.emit()


func _build_reset_confirm_ui() -> void:
	_confirm_layer = ColorRect.new()
	_confirm_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.color = Color(0.01, 0.02, 0.05, 0.72)
	_confirm_layer.visible = false
	_confirm_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.add_child(_confirm_layer)

	var confirm_center := CenterContainer.new()
	confirm_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.add_child(confirm_center)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.08, 0.12, 0.96)
	panel_style.border_color = Color("#ff6b6b", 0.85)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 28
	panel_style.content_margin_right = 28
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 24

	_confirm_panel = PanelContainer.new()
	_confirm_panel.custom_minimum_size = Vector2(520, 0)
	_confirm_panel.add_theme_stylebox_override("panel", panel_style)
	confirm_center.add_child(_confirm_panel)

	var confirm_root := VBoxContainer.new()
	confirm_root.add_theme_constant_override("separation", 14)
	_confirm_panel.add_child(confirm_root)

	var confirm_title := Label.new()
	confirm_title.text = "清空勘探日志档案"
	confirm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_title.add_theme_font_size_override("font_size", 22)
	confirm_title.add_theme_color_override("font_color", COLOR_ALERT)
	HudTheme.apply_label(confirm_title)
	confirm_root.add_child(confirm_title)

	var confirm_body := Label.new()
	confirm_body.text = (
		"将永久删除昆仑终端内全部到顶上传记录，\n"
		+ "并清空已解锁的关键情报与结局记录。\n\n"
		+ "若存在进行中的单局存档，也会一并删除。\n"
		+ "教程完成标记会保留。\n\n"
		+ "此操作不可撤销。确定要重新开始吗？"
	)
	confirm_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_body.add_theme_font_size_override("font_size", 14)
	confirm_body.add_theme_color_override("font_color", Color("#c8dce8"))
	HudTheme.apply_label(confirm_body)
	confirm_root.add_child(confirm_body)

	var confirm_actions := HBoxContainer.new()
	confirm_actions.add_theme_constant_override("separation", 16)
	confirm_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_root.add_child(confirm_actions)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(180, 42)
	HudTheme.apply_sci_fi_terminal_button(cancel_btn, Color("#8ec8e8"))
	cancel_btn.pressed.connect(_hide_reset_confirm)
	confirm_actions.add_child(cancel_btn)

	var execute_btn := Button.new()
	execute_btn.text = "确认清空并重开"
	execute_btn.custom_minimum_size = Vector2(180, 42)
	HudTheme.apply_sci_fi_terminal_button(execute_btn, COLOR_ALERT)
	execute_btn.pressed.connect(_execute_reset_archive)
	confirm_actions.add_child(execute_btn)


func _show_reset_confirm() -> void:
	if is_instance_valid(_confirm_layer):
		_confirm_layer.visible = true


func _hide_reset_confirm() -> void:
	if is_instance_valid(_confirm_layer):
		_confirm_layer.visible = false


func _execute_reset_archive() -> void:
	MetaManager.reset_journal_archive()
	if SaveManager.has_save():
		SaveManager.delete_save()
	_hide_reset_confirm()
	_show_list_view()
	_refresh_content()
	archive_cleared.emit()


func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.01, 0.03, 0.06, 0.9)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_frame = SciFiFramePanelScript.new()
	_frame.custom_minimum_size = Vector2(760, 620)
	center.add_child(_frame)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.clip_contents = true
	_frame.add_child(margin)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 10)
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(shell)

	var title := Label.new()
	title.text = "昆仑终端 · 勘探日志档案"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#6eb8ff"))
	HudTheme.apply_label(title)
	shell.add_child(title)

	shell.add_child(_make_section_label("◈ 情报进度"))

	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 6)
	shell.add_child(_stats_box)

	shell.add_child(_make_section_label("◈ 系统日志"))

	_list_host = Control.new()
	_list_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_host.custom_minimum_size = Vector2(0, 220)
	_list_host.clip_contents = true
	shell.add_child(_list_host)

	_list_scroll = ScrollContainer.new()
	_list_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_host.add_child(_list_scroll)

	_list_root = VBoxContainer.new()
	_list_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_root.add_theme_constant_override("separation", 8)
	_list_scroll.add_child(_list_root)

	_detail_root = VBoxContainer.new()
	_detail_root.visible = false
	_detail_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail_root.add_theme_constant_override("separation", 10)
	_list_host.add_child(_detail_root)

	_detail_root.add_child(_make_section_label("◈ 日志详情"))

	_detail_title = Label.new()
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_title.add_theme_font_size_override("font_size", 15)
	_detail_title.add_theme_color_override("font_color", Color("#e4eef8"))
	HudTheme.apply_label(_detail_title)
	_detail_root.add_child(_detail_title)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.custom_minimum_size = Vector2(0, 160)
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_root.add_child(detail_scroll)

	_detail_body = RichTextLabel.new()
	_detail_body.bbcode_enabled = false
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.scroll_active = false
	_detail_body.fit_content = true
	_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HudTheme.apply_terminal_log_rich(_detail_body)
	detail_scroll.add_child(_detail_body)

	_back_btn = Button.new()
	_back_btn.text = "返回列表"
	_back_btn.custom_minimum_size = Vector2(220, 42)
	_back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	HudTheme.apply_sci_fi_terminal_button(_back_btn, Color("#8ec8e8"))
	_back_btn.pressed.connect(_show_list_view)
	_detail_root.add_child(_back_btn)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	shell.add_child(footer)

	_reset_btn = Button.new()
	_reset_btn.text = "清空档案并重开"
	_reset_btn.custom_minimum_size = Vector2(240, 46)
	HudTheme.apply_sci_fi_terminal_button(_reset_btn, COLOR_ALERT)
	_reset_btn.pressed.connect(_show_reset_confirm)
	footer.add_child(_reset_btn)

	_close_btn = Button.new()
	_close_btn.text = "关闭"
	_close_btn.custom_minimum_size = Vector2(240, 46)
	HudTheme.apply_sci_fi_terminal_button(_close_btn)
	_close_btn.pressed.connect(hide_archive)
	footer.add_child(_close_btn)

	_build_reset_confirm_ui()


func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("#5a8aaa"))
	return label


func _show_list_view() -> void:
	if is_instance_valid(_list_scroll):
		_list_scroll.visible = true
	if is_instance_valid(_detail_root):
		_detail_root.visible = false


func _show_detail_view(upload_index: int, entry_index: int) -> void:
	var entry: Dictionary = MetaManager.get_archived_entry(upload_index, entry_index)
	if entry.is_empty():
		return
	_detail_title.text = str(entry.get("title", entry.get("encounter_id", "未命名")))
	var body := str(entry.get("body", ""))
	if body.is_empty():
		body = "（该条日志正文缺失。）"
	_detail_body.text = HudTheme.format_terminal_log(body, false)
	_list_scroll.visible = false
	_detail_root.visible = true


func _refresh_content() -> void:
	_clear_children(_stats_box)
	_clear_children(_list_root)
	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 24)
	_stats_box.add_child(summary_row)
	summary_row.add_child(_make_stat_pair(
		"关键情报",
		"%d / %d" % [MetaManager.encounters_unlocked_count(), MetaManager.required_encounter_count()],
	))
	summary_row.add_child(_make_stat_pair("到顶上传", "%d" % MetaManager.journal_upload_count()))
	var status_label := Label.new()
	status_label.text = "档案状态：%s" % MetaManager.archive_status_label()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", COLOR_STAT_VALUE)
	_stats_box.add_child(status_label)
	var uploads: Array[Dictionary] = MetaManager.get_archived_uploads()
	if uploads.is_empty():
		var empty := Label.new()
		empty.text = "> 终端暂无到顶上传记录。\n只有抵达顶层并完成通信终端上传的日记会归档于此。"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color("#5a7080"))
		_list_root.add_child(empty)
		call_deferred("_reset_list_scroll")
		return
	for upload_index in range(uploads.size()):
		var upload: Dictionary = uploads[upload_index]
		var header := Label.new()
		header.text = "—— 上传 #%d · 第%d层·第%d天 ——" % [
			upload_index + 1,
			int(upload.get("layer", 0)),
			int(upload.get("day_index", 0)),
		]
		header.add_theme_font_size_override("font_size", 11)
		header.add_theme_color_override("font_color", Color("#5a8aaa"))
		_list_root.add_child(header)
		var upload_entries: Variant = upload.get("entries", [])
		if typeof(upload_entries) != TYPE_ARRAY:
			continue
		for entry_index in range(upload_entries.size()):
			var entry_var: Variant = upload_entries[entry_index]
			if typeof(entry_var) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_var
			var btn := Button.new()
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.text = "> · %s" % str(entry.get("title", entry.get("encounter_id", "未命名")))
			btn.custom_minimum_size = Vector2(0, 38)
			HudTheme.apply_sci_fi_terminal_button(btn, Color("#7eb8d8"))
			var captured_upload := upload_index
			var captured_entry := entry_index
			btn.pressed.connect(func() -> void: _show_detail_view(captured_upload, captured_entry))
			_list_root.add_child(btn)
	call_deferred("_reset_list_scroll")


func _reset_list_scroll() -> void:
	if not is_instance_valid(_list_scroll):
		return
	var bar := _list_scroll.get_v_scroll_bar()
	if bar != null:
		bar.value = 0.0


func _make_stat_pair(label_text: String, value_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", COLOR_STAT_LABEL)
	row.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 13)
	value.add_theme_color_override("font_color", COLOR_STAT_VALUE)
	row.add_child(value)
	return row


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_instance_valid(_confirm_layer) and _confirm_layer.visible:
			return
		if is_instance_valid(_detail_root) and _detail_root.visible:
			_show_list_view()
		else:
			hide_archive()
