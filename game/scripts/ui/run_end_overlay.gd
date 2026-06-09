extends CanvasLayer

const SciFiFramePanelScript = preload("res://scripts/ui/sci_fi_frame_panel.gd")

signal ceremony_choice_made(choice_id: String)
signal summary_closed

const COLOR_ALERT := Color("#ff3d4a")
const COLOR_SUCCESS := Color("#6eb8ff")
const COLOR_SECTION := Color("#5a8aaa")
const COLOR_STAT_LABEL := Color("#6a8498")
const COLOR_STAT_VALUE := Color("#e4eef8")
const COLOR_LOG := Color("#5a7080")
const COLOR_EMPTY := Color("#4a6070")

var _phase := "hidden"
var _dim: ColorRect
var _frame: SciFiFramePanel
var _title_label: Label
var _ceremony_header_label: Label
var _ceremony_section_label: Label
var _body_label: Label
var _summary_section: VBoxContainer
var _stats_grid: GridContainer
var _inventory_flow: HFlowContainer
var _inventory_empty_label: Label
var _log_label: RichTextLabel
var _choices_box: VBoxContainer
var _confirm_btn: Button
var _choice_buttons: Array[Button] = []


func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.01, 0.03, 0.06, 0.9)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_frame = SciFiFramePanelScript.new()
	_frame.custom_minimum_size = Vector2(760, 560)
	center.add_child(_frame)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	_frame.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	HudTheme.apply_label(_title_label)
	root.add_child(_title_label)

	_summary_section = VBoxContainer.new()
	_summary_section.add_theme_constant_override("separation", 10)
	root.add_child(_summary_section)

	var record_header := _make_section_label("◈ 勘探记录")
	_summary_section.add_child(record_header)

	_stats_grid = GridContainer.new()
	_stats_grid.columns = 4
	_stats_grid.add_theme_constant_override("h_separation", 18)
	_stats_grid.add_theme_constant_override("v_separation", 8)
	_summary_section.add_child(_stats_grid)

	var inv_header := _make_section_label("◈ 物资清单")
	_summary_section.add_child(inv_header)

	_inventory_flow = HFlowContainer.new()
	_inventory_flow.add_theme_constant_override("h_separation", 10)
	_inventory_flow.add_theme_constant_override("v_separation", 8)
	_inventory_flow.custom_minimum_size = Vector2(0, 52)
	_summary_section.add_child(_inventory_flow)

	_inventory_empty_label = Label.new()
	_inventory_empty_label.text = "（空）"
	_inventory_empty_label.add_theme_font_size_override("font_size", 11)
	_inventory_empty_label.add_theme_color_override("font_color", COLOR_EMPTY)
	_inventory_empty_label.visible = false
	_summary_section.add_child(_inventory_empty_label)

	var log_header := _make_section_label("◈ 系统日志")
	_summary_section.add_child(log_header)

	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = false
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.fit_content = true
	_log_label.scroll_active = false
	_log_label.custom_minimum_size = Vector2(0, 72)
	_log_label.add_theme_font_size_override("normal_font_size", 10)
	_log_label.add_theme_color_override("default_color", COLOR_LOG)
	_summary_section.add_child(_log_label)

	_ceremony_header_label = Label.new()
	_ceremony_header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ceremony_header_label.visible = false
	HudTheme.apply_terminal_section(_ceremony_header_label)
	root.add_child(_ceremony_header_label)

	_ceremony_section_label = _make_section_label("◈ 系统日志")
	_ceremony_section_label.visible = false
	root.add_child(_ceremony_section_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.custom_minimum_size = Vector2(680, 220)
	HudTheme.apply_terminal_log_label(_body_label)
	_body_label.visible = false
	root.add_child(_body_label)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 10)
	_choices_box.visible = false
	root.add_child(_choices_box)

	_confirm_btn = Button.new()
	_confirm_btn.text = "返回主菜单"
	_confirm_btn.custom_minimum_size = Vector2(300, 46)
	_confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_confirm_btn.visible = false
	HudTheme.apply_sci_fi_terminal_button(_confirm_btn)
	_confirm_btn.pressed.connect(_on_summary_closed)
	root.add_child(_confirm_btn)


func show_ceremony() -> void:
	_phase = "ceremony"
	visible = true
	_play_music_cue("truth_reveal", 1.0)
	_summary_section.visible = false
	_body_label.visible = true
	_ceremony_header_label.visible = true
	_ceremony_section_label.visible = true
	_confirm_btn.visible = false
	_choices_box.visible = true
	_apply_title("归档仪式 · 真相揭示", false)
	_ceremony_header_label.text = HudTheme.extract_terminal_header(RunEndingDefs.TRUTH_REVEAL_TEXT)
	_body_label.text = "%s\n\n> 通信终端将上传本局勘探日记，并展示前代已上传的记录。" % HudTheme.format_terminal_log(
		RunEndingDefs.TRUTH_REVEAL_TEXT
	)
	_rebuild_choice_buttons()


func show_summary(data: Dictionary) -> void:
	_phase = "summary"
	visible = true
	if bool(data.get("is_failure", false)):
		_play_music_stinger("run_reset", -12.0)
	_summary_section.visible = true
	_body_label.visible = false
	_ceremony_header_label.visible = false
	_ceremony_section_label.visible = false
	_choices_box.visible = false
	_clear_choice_buttons()
	_confirm_btn.visible = true
	_apply_title(str(data.get("title", "本局结算")), bool(data.get("is_failure", false)))
	_populate_stats(data.get("stats", []))
	_populate_inventory(data.get("inventory", []))
	_populate_log(data.get("log_lines", []))


func hide_overlay() -> void:
	_phase = "hidden"
	visible = false
	_clear_choice_buttons()


func _music_manager() -> Node:
	return get_tree().root.get_node_or_null("MusicManager") if get_tree() != null else null


func _play_music_cue(cue_id: String, fade_sec: float = -1.0) -> void:
	var music := _music_manager()
	if music != null and music.has_method("play_cue"):
		music.play_cue(cue_id, fade_sec)


func _play_music_stinger(cue_id: String, volume_db: float = INF) -> void:
	var music := _music_manager()
	if music != null and music.has_method("play_stinger"):
		music.play_stinger(cue_id, volume_db)


func _apply_title(title: String, is_failure: bool) -> void:
	_title_label.text = title
	if is_failure:
		_title_label.add_theme_font_size_override("font_size", 30)
		_title_label.add_theme_color_override("font_color", COLOR_ALERT)
	else:
		_title_label.add_theme_font_size_override("font_size", 26)
		_title_label.add_theme_color_override("font_color", COLOR_SUCCESS)


func _populate_stats(stats: Variant) -> void:
	_clear_children(_stats_grid)
	if typeof(stats) != TYPE_ARRAY:
		return
	for entry in stats:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var label_text := str(entry.get("label", ""))
		var value_text := str(entry.get("value", ""))
		if label_text.is_empty():
			continue
		var label := Label.new()
		label.text = label_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.custom_minimum_size = Vector2(88, 0)
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", COLOR_STAT_LABEL)
		_stats_grid.add_child(label)
		var value := Label.new()
		value.text = value_text
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.add_theme_font_size_override("font_size", 13)
		value.add_theme_color_override("font_color", COLOR_STAT_VALUE)
		_stats_grid.add_child(value)


func _populate_inventory(inventory: Variant) -> void:
	_clear_children(_inventory_flow)
	if typeof(inventory) != TYPE_ARRAY or inventory.is_empty():
		_inventory_empty_label.visible = true
		return
	_inventory_empty_label.visible = false
	for entry in inventory:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item_id := str(entry.get("id", ""))
		var count := int(entry.get("count", 0))
		if item_id == "" or count <= 0:
			continue
		_inventory_flow.add_child(_make_inventory_chip(item_id, count))


func _make_inventory_chip(item_id: String, count: int) -> Control:
	var chip := PanelContainer.new()
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color(0.06, 0.10, 0.14, 0.72)
	chip_style.border_color = Color("#3a5870", 0.55)
	chip_style.set_border_width_all(1)
	chip_style.set_corner_radius_all(4)
	chip_style.content_margin_left = 6
	chip_style.content_margin_right = 8
	chip_style.content_margin_top = 4
	chip_style.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", chip_style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	chip.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.texture = ItemIconFactory.get_texture(item_id, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var qty := Label.new()
	qty.text = "×%d" % count
	qty.add_theme_font_size_override("font_size", 13)
	qty.add_theme_color_override("font_color", COLOR_STAT_VALUE)
	row.add_child(qty)
	return chip


func _populate_log(log_lines: Variant) -> void:
	if typeof(log_lines) != TYPE_ARRAY:
		_log_label.text = ""
		return
	var lines: PackedStringArray = []
	for raw in log_lines:
		var line := str(raw).strip_edges()
		if line.is_empty():
			continue
		lines.append("> %s" % line)
	_log_label.text = "\n".join(lines)


func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", COLOR_SECTION)
	return label


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _rebuild_choice_buttons() -> void:
	_clear_choice_buttons()
	for choice_id in RunEndingDefs.FINAL_CHOICES.keys():
		var def: Dictionary = RunEndingDefs.FINAL_CHOICES[choice_id]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 44)
		btn.text = "%s\n%s" % [def.get("title", ""), def.get("summary", "")]
		HudTheme.apply_sci_fi_terminal_button(btn, Color("#8ec8e8"))
		btn.pressed.connect(_on_choice_pressed.bind(str(choice_id)))
		_choices_box.add_child(btn)
		_choice_buttons.append(btn)


func _clear_choice_buttons() -> void:
	for btn in _choice_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_choice_buttons.clear()


func _on_choice_pressed(choice_id: String) -> void:
	ceremony_choice_made.emit(choice_id)


func _on_summary_closed() -> void:
	summary_closed.emit()
