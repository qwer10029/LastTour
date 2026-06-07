extends CanvasLayer

signal quest_started
signal reward_chosen(option: Dictionary)
signal closed

enum Mode { HIDDEN, INTRO, REWARD }

var _mode: int = Mode.HIDDEN
var _intro_index: int = 0

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _body: Label
var _options: VBoxContainer
var _primary: Button
var _option_buttons: Array[Button] = []


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.05, 0.1, 0.88)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -420.0
	_panel.offset_top = -280.0
	_panel.offset_right = 420.0
	_panel.offset_bottom = 280.0
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", Color("#eef8ff"))
	root.add_child(_title)

	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(760, 220)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_color_override("font_color", Color("#d8e4f0"))
	root.add_child(_body)

	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 8)
	_options.visible = false
	root.add_child(_options)

	_primary = Button.new()
	_primary.custom_minimum_size = Vector2(260, 42)
	_primary.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_primary.pressed.connect(_on_primary_pressed)
	root.add_child(_primary)


func start_sentinel_intro() -> void:
	_intro_index = 0
	visible = true
	_enter_mode(Mode.INTRO)


func start_sentinel_reward() -> void:
	visible = true
	_enter_mode(Mode.REWARD)


func hide_overlay() -> void:
	_mode = Mode.HIDDEN
	visible = false
	_clear_option_buttons()


func is_active() -> bool:
	return visible


func _enter_mode(mode: int) -> void:
	_mode = mode
	_clear_option_buttons()
	_options.visible = false
	_primary.visible = true
	match mode:
		Mode.INTRO:
			_title.text = "荒废军营 · 哨兵 S-09"
			_body.text = SentinelEncounterDefs.INTRO_PAGES[_intro_index]
			if _intro_index >= SentinelEncounterDefs.INTRO_PAGES.size() - 1:
				_primary.text = "前往东侧仓库"
			else:
				_primary.text = "继续"
		Mode.REWARD:
			_title.text = "哨兵 S-09 · 选择报酬"
			_body.text = SentinelEncounterDefs.REWARD_PROMPT
			_primary.visible = false
			_options.visible = true
			for option in SentinelEncounterDefs.REWARD_OPTIONS:
				var btn := Button.new()
				btn.text = "%s\n%s" % [str(option.get("label", "")), str(option.get("summary", ""))]
				btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				btn.custom_minimum_size = Vector2(0, 44)
				btn.pressed.connect(_on_reward_pressed.bind(option.duplicate(true)))
				_options.add_child(btn)
				_option_buttons.append(btn)


func _on_primary_pressed() -> void:
	if _mode != Mode.INTRO:
		return
	if _intro_index < SentinelEncounterDefs.INTRO_PAGES.size() - 1:
		_intro_index += 1
		_enter_mode(Mode.INTRO)
		return
	hide_overlay()
	quest_started.emit()


func _on_reward_pressed(option: Dictionary) -> void:
	reward_chosen.emit(option)
	hide_overlay()
	closed.emit()


func _clear_option_buttons() -> void:
	for btn in _option_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_option_buttons.clear()
