extends CanvasLayer

signal closed

enum Mode { CREDITS, MESSAGE, FAKE_SUCCESS }

var _mode: int = Mode.CREDITS
var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _body: RichTextLabel
var _msg_input: LineEdit
var _msg_history: RichTextLabel
var _primary_btn: Button
var _layer_at_choice: int = 0

var _credits_section: Control
var _message_section: Control
var _fake_section: Control


func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.04, 0.08, 0.85)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(560, 460)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -280
	_panel.offset_top = -230
	_panel.offset_right = 280
	_panel.offset_bottom = 230
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.13, 0.20, 0.97)
	panel_style.border_color = Color(0.55, 0.72, 0.88, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color("#eef8ff"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(_title)

	# Credits section
	_credits_section = Control.new()
	_credits_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_credits_section.visible = false
	outer.add_child(_credits_section)

	var credits_vbox := VBoxContainer.new()
	credits_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_credits_section.add_child(credits_vbox)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = false
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_color_override("default_color", Color("#c8dff0"))
	credits_vbox.add_child(_body)

	# Message section
	_message_section = Control.new()
	_message_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_message_section.visible = false
	outer.add_child(_message_section)

	var msg_vbox := VBoxContainer.new()
	msg_vbox.add_theme_constant_override("separation", 10)
	msg_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message_section.add_child(msg_vbox)

	var prompt_lbl := Label.new()
	prompt_lbl.text = "留下一行话，给下一代克隆人："
	prompt_lbl.add_theme_color_override("font_color", Color("#aac8e0"))
	msg_vbox.add_child(prompt_lbl)

	_msg_input = LineEdit.new()
	_msg_input.max_length = 80
	_msg_input.placeholder_text = "（最多80字）"
	msg_vbox.add_child(_msg_input)

	var history_lbl := Label.new()
	history_lbl.text = "历史留言："
	history_lbl.add_theme_color_override("font_color", Color("#aac8e0"))
	msg_vbox.add_child(history_lbl)

	_msg_history = RichTextLabel.new()
	_msg_history.bbcode_enabled = false
	_msg_history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_msg_history.add_theme_color_override("default_color", Color("#8aa8c0"))
	msg_vbox.add_child(_msg_history)

	# Fake success section
	_fake_section = Control.new()
	_fake_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fake_section.visible = false
	outer.add_child(_fake_section)

	var fake_vbox := VBoxContainer.new()
	fake_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fake_section.add_child(fake_vbox)

	var fake_body := RichTextLabel.new()
	fake_body.bbcode_enabled = false
	fake_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fake_body.text = "系统已接收信号。\n\n任务完成。地面指挥部将在接收确认后发送后续指令。\n\n……\n\n……\n\n……\n\n（指挥部无响应。信道持续开放中。）"
	fake_body.add_theme_color_override("default_color", Color("#8a9aaa"))
	fake_vbox.add_child(fake_body)

	_primary_btn = Button.new()
	_primary_btn.pressed.connect(_on_primary_pressed)
	outer.add_child(_primary_btn)


func show_outcome(choice_id: String, run_layer: int) -> void:
	_layer_at_choice = run_layer
	visible = true
	match choice_id:
		"stop_signal":
			_enter_credits()
		"message_only":
			_enter_message()
		"fake_success":
			_enter_fake_success()
		_:
			_enter_credits()


func hide_overlay() -> void:
	visible = false


func _enter_credits() -> void:
	_mode = Mode.CREDITS
	_title.text = "克隆循环 · 终止"
	_body.text = "感谢游玩《终末旅行》。\n\n制作：\n  程序员：…\n  美术：…\n  音效：…\n\n克隆人的旅途到此终结。\n信号已发出。循环停止。"
	_credits_section.visible = true
	_message_section.visible = false
	_fake_section.visible = false
	_primary_btn.text = "返回主菜单"


func _enter_message() -> void:
	_mode = Mode.MESSAGE
	_title.text = "致下一代克隆人"
	_msg_input.text = ""
	var wall := MetaManager.message_wall
	var lines: Array[String] = []
	var start := max(0, wall.size() - 10)
	for i in range(start, wall.size()):
		var entry: Dictionary = wall[i]
		lines.append("第%d层 · %s" % [int(entry.get("layer", 0)), str(entry.get("text", ""))])
	_msg_history.text = "\n".join(lines) if not lines.is_empty() else "（暂无留言）"
	_credits_section.visible = false
	_message_section.visible = true
	_fake_section.visible = false
	_primary_btn.text = "留下留言"


func _enter_fake_success() -> void:
	_mode = Mode.FAKE_SUCCESS
	_title.text = "任务完成"
	_credits_section.visible = false
	_message_section.visible = false
	_fake_section.visible = true
	_primary_btn.text = "返回主菜单"


func _on_primary_pressed() -> void:
	if _mode == Mode.MESSAGE:
		MetaManager.append_message(_msg_input.text, _layer_at_choice)
		MetaManager.save_meta()
	closed.emit()
