extends CanvasLayer

signal strike_completed
signal transfer_completed

enum Phase { HIDDEN, INTRO, REPORT, CAPTCHA, RESULT_FAIL, RESULT_PASS }

var _phase: int = Phase.HIDDEN
var _is_evidence_sufficient: bool = false
var _report_choice: String = ""

var _dim: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _body_label: Label
var _options_box: VBoxContainer
var _captcha_box: VBoxContainer
var _captcha_slider: HSlider
var _captcha_hint: Label
var _primary_btn: Button
var _option_buttons: Array[Button] = []


func _ready() -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.04, 0.08, 0.92)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -380.0
	_panel.offset_top = -260.0
	_panel.offset_right = 380.0
	_panel.offset_bottom = 260.0
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
	_body_label.custom_minimum_size = Vector2(680, 220)
	root.add_child(_body_label)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 8)
	_options_box.visible = false
	root.add_child(_options_box)

	_captcha_box = VBoxContainer.new()
	_captcha_box.add_theme_constant_override("separation", 8)
	_captcha_box.visible = false
	root.add_child(_captcha_box)

	_captcha_hint = Label.new()
	_captcha_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_captcha_box.add_child(_captcha_hint)

	_captcha_slider = HSlider.new()
	_captcha_slider.min_value = 0.0
	_captcha_slider.max_value = 100.0
	_captcha_slider.step = 1.0
	_captcha_slider.value = 0.0
	_captcha_slider.custom_minimum_size = Vector2(560, 36)
	_captcha_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_captcha_slider.value_changed.connect(_on_captcha_value_changed)
	_captcha_box.add_child(_captcha_slider)

	_primary_btn = Button.new()
	_primary_btn.text = "继续"
	_primary_btn.custom_minimum_size = Vector2(280, 44)
	_primary_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_primary_btn.pressed.connect(_on_primary_pressed)
	root.add_child(_primary_btn)


func start_flow(evidence_count: int, threshold: int) -> void:
	_is_evidence_sufficient = evidence_count >= threshold
	_report_choice = ""
	visible = true
	_enter_phase(Phase.INTRO)


func hide_terminal() -> void:
	_phase = Phase.HIDDEN
	visible = false


func _enter_phase(phase: int) -> void:
	_phase = phase
	_clear_option_buttons()
	_options_box.visible = false
	_captcha_box.visible = false
	_primary_btn.visible = true
	match phase:
		Phase.INTRO:
			_title_label.text = "通信终端 · 接入"
			_body_label.text = RunEndingDefs.TERMINAL_INTRO_TEXT
			_primary_btn.text = "继续"
		Phase.REPORT:
			_title_label.text = "通信终端 · 勘探汇报"
			_body_label.text = RunEndingDefs.TERMINAL_REPORT_PROMPT
			_options_box.visible = true
			_primary_btn.visible = false
			_build_report_options()
		Phase.CAPTCHA:
			_title_label.text = "通信终端 · 身份识别"
			_body_label.text = RunEndingDefs.TERMINAL_CAPTCHA_PROMPT
			_captcha_box.visible = true
			_captcha_slider.value = 0.0
			_captcha_hint.text = "滑块进度：0 / 100"
			_primary_btn.text = "提交验证"
			_primary_btn.disabled = true
		Phase.RESULT_FAIL:
			_title_label.text = "通信终端 · 验证失败"
			_body_label.text = "%s\n\n%s" % [RunEndingDefs.TERMINAL_VERIFY_FAIL_TEXT, RunEndingDefs.TERMINAL_STRIKE_TEXT]
			_primary_btn.text = "接受结算"
			_primary_btn.disabled = false
		Phase.RESULT_PASS:
			_title_label.text = "通信终端 · 权限移交"
			_body_label.text = "%s\n\n%s" % [RunEndingDefs.TERMINAL_VERIFY_PASS_TEXT, RunEndingDefs.TERMINAL_TRANSFER_TEXT]
			_primary_btn.text = "接管控制台"
			_primary_btn.disabled = false


func _build_report_options() -> void:
	for key in RunEndingDefs.TERMINAL_REPORT_OPTIONS.keys():
		var label: String = RunEndingDefs.TERMINAL_REPORT_OPTIONS[key]
		var btn := Button.new()
		btn.text = label
		btn.custom_minimum_size = Vector2(0, 40)
		btn.pressed.connect(_on_report_chosen.bind(str(key)))
		_options_box.add_child(btn)
		_option_buttons.append(btn)


func _clear_option_buttons() -> void:
	for btn in _option_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_option_buttons.clear()


func _on_report_chosen(choice_id: String) -> void:
	_report_choice = choice_id
	_enter_phase(Phase.CAPTCHA)


func _on_captcha_value_changed(value: float) -> void:
	_captcha_hint.text = "滑块进度：%d / 100" % int(value)
	_primary_btn.disabled = value < 100.0


func _on_primary_pressed() -> void:
	match _phase:
		Phase.INTRO:
			_enter_phase(Phase.REPORT)
		Phase.CAPTCHA:
			if _captcha_slider.value < 100.0:
				return
			if _is_evidence_sufficient:
				_enter_phase(Phase.RESULT_PASS)
			else:
				_enter_phase(Phase.RESULT_FAIL)
		Phase.RESULT_FAIL:
			hide_terminal()
			strike_completed.emit()
		Phase.RESULT_PASS:
			hide_terminal()
			transfer_completed.emit()
