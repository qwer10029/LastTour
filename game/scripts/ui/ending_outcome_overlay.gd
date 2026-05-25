extends CanvasLayer

signal closed

enum Mode { CREDITS, FAKE_SUCCESS, MESSAGE_ONLY_EPILOGUE }

var _mode: int = Mode.CREDITS
var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _body: RichTextLabel
var _credits_scroll: ScrollContainer
var _primary_btn: Button
var _credits_scroll_speed: float = 28.0


func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _process(delta: float) -> void:
	if not visible or _mode != Mode.CREDITS:
		return
	if not is_instance_valid(_credits_scroll):
		return
	var bar := _credits_scroll.get_v_scroll_bar()
	if bar == null:
		return
	bar.value = minf(bar.value + _credits_scroll_speed * delta, bar.max_value)


func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.04, 0.08, 0.92)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -380.0
	_panel.offset_top = -280.0
	_panel.offset_right = 380.0
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

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_title)

	_body = RichTextLabel.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.custom_minimum_size = Vector2(660, 200)
	_body.scroll_active = false
	_body.fit_content = true
	_body.visible = false
	root.add_child(_body)

	_credits_scroll = ScrollContainer.new()
	_credits_scroll.custom_minimum_size = Vector2(680, 220)
	_credits_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_credits_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_credits_scroll.visible = false
	root.add_child(_credits_scroll)

	var credits_body := RichTextLabel.new()
	credits_body.name = "CreditsBody"
	credits_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits_body.custom_minimum_size = Vector2(660, 480)
	credits_body.scroll_active = false
	credits_body.fit_content = true
	_credits_scroll.add_child(credits_body)

	_primary_btn = Button.new()
	_primary_btn.custom_minimum_size = Vector2(280, 44)
	_primary_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_primary_btn.pressed.connect(_on_primary_pressed)
	root.add_child(_primary_btn)


func show_outcome(choice_id: String, _run_layer: int, _day_index: int = 1) -> void:
	visible = true
	match choice_id:
		"stop_signal":
			_enter_credits()
		"message_only":
			_enter_message_only_epilogue()
		"fake_success":
			_enter_fake_success()
		_:
			_enter_credits()


func hide_overlay() -> void:
	visible = false


func _enter_credits() -> void:
	_mode = Mode.CREDITS
	_title.text = "克隆循环 · 终止"
	_body.visible = false
	_credits_scroll.visible = true
	var credits_body := _credits_scroll.get_node_or_null("CreditsBody") as RichTextLabel
	if credits_body != null:
		var lines: PackedStringArray = []
		for line in RunEndingDefs.CREDITS_LINES:
			lines.append(line)
		credits_body.text = "[center]%s[/center]" % "\n".join(lines)
	call_deferred("_reset_credits_scroll")
	_primary_btn.text = "返回主菜单"


func _reset_credits_scroll() -> void:
	if not is_instance_valid(_credits_scroll):
		return
	var bar := _credits_scroll.get_v_scroll_bar()
	if bar != null:
		bar.value = 0.0


func _enter_fake_success() -> void:
	_mode = Mode.FAKE_SUCCESS
	_title.text = "勘探成功 · 伪造"
	_credits_scroll.visible = false
	_body.visible = true
	_body.text = """昆仑中继收到一条伪造的「勘探成功」信号。

程序不会追问真伪。
它只是需要一个理由停下来。

循环以讽刺的方式停摆了。
也许这就是人类能给出的最后答案。"""
	_primary_btn.text = "返回主菜单"


func _enter_message_only_epilogue() -> void:
	_mode = Mode.MESSAGE_ONLY_EPILOGUE
	_title.text = "只留言，不发停机"
	_credits_scroll.visible = false
	_body.visible = true
	_body.text = """你没有发送终止信号。

若已在通信终端留言，话语已写入前代勘探者档案。
昆仑程序将把新的克隆体送上来——循环继续。"""
	_primary_btn.text = "返回主菜单"


func _on_primary_pressed() -> void:
	closed.emit()
