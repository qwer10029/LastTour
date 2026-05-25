extends CanvasLayer


signal ceremony_choice_made(choice_id: String)
signal summary_closed

var _phase := "hidden"
var _dim: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _body_label: Label
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
	_dim.color = Color(0.02, 0.04, 0.08, 0.88)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -360.0
	_panel.offset_top = -280.0
	_panel.offset_right = 360.0
	_panel.offset_bottom = 280.0
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_title_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.custom_minimum_size = Vector2(640, 280)
	root.add_child(_body_label)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 10)
	_choices_box.visible = false
	root.add_child(_choices_box)

	_confirm_btn = Button.new()
	_confirm_btn.text = "返回主菜单"
	_confirm_btn.custom_minimum_size = Vector2(320, 48)
	_confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_confirm_btn.visible = false
	_confirm_btn.pressed.connect(_on_summary_closed)
	root.add_child(_confirm_btn)


func show_ceremony() -> void:
	_phase = "ceremony"
	visible = true
	_confirm_btn.visible = false
	_choices_box.visible = true
	_title_label.text = "归档仪式 · 真相揭示"
	_body_label.text = (
		"%s\n\n通信终端中，在回答地表宜居性之前可为下一位勘探者留言（写留言时可阅读前代留言）。"
	) % RunEndingDefs.TRUTH_REVEAL_TEXT
	_rebuild_choice_buttons()


func show_summary(title: String, body: String) -> void:
	_phase = "summary"
	visible = true
	_title_label.text = title
	_body_label.text = body
	_choices_box.visible = false
	_clear_choice_buttons()
	_confirm_btn.visible = true


func hide_overlay() -> void:
	_phase = "hidden"
	visible = false
	_clear_choice_buttons()


func _rebuild_choice_buttons() -> void:
	_clear_choice_buttons()
	for choice_id in RunEndingDefs.FINAL_CHOICES.keys():
		var def: Dictionary = RunEndingDefs.FINAL_CHOICES[choice_id]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 44)
		btn.text = "%s\n%s" % [def.get("title", ""), def.get("summary", "")]
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
