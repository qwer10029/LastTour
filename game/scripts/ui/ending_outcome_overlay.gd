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


func _ready() -> void:
	layer = 130
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
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.custom_minimum_size = Vector2(680, 200)
	_body.scroll_following = true
	root.add_child(_body)

	_msg_input = LineEdit.new()
	_msg_input.max_length = 80
	_msg_input.placeholder_text = "输入留言（最多80字）…"
	_msg_input.custom_minimum_size = Vector2(0, 36)
	_msg_input.visible = false
	root.add_child(_msg_input)

	_msg_history = RichTextLabel.new()
	_msg_history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg_history.custom_minimum_size = Vector2(680, 80)
	_msg_history.visible = false
	root.add_child(_msg_history)

	_primary_btn = Button.new()
	_primary_btn.custom_minimum_size = Vector2(280, 44)
	_primary_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_primary_btn.pressed.connect(_on_primary_pressed)
	root.add_child(_primary_btn)


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
	_body.text = """[center]—— 制作名单 ——[/center]

程序员：……
美术：……
音效：……
剧本：……

[center]感谢游玩。[/center]

[center]克隆程序至此终止。
地表的风第一次吹进了地下控制室。[/center]"""
	_body.visible = true
	_msg_input.visible = false
	_msg_history.visible = false
	_primary_btn.text = "返回主菜单"


func _enter_message() -> void:
	_mode = Mode.MESSAGE
	_title.text = "留言墙"
	_body.text = "你选择不发送终止信号。\n请为下一代勘探者留下一段话，他们抵达顶层时会看到它。"
	_body.visible = true
	_msg_input.visible = true
	_msg_input.text = ""
	_msg_history.visible = true
	_refresh_message_history()
	_primary_btn.text = "留下留言"


func _enter_fake_success() -> void:
	_mode = Mode.FAKE_SUCCESS
	_title.text = "勘探成功 · 伪造"
	_body.text = """昆仑中继收到一条伪造的「勘探成功」信号。

程序不会追问真伪。
它只是需要一个理由停下来。

循环以讽刺的方式停摆了。
也许这就是人类能给出的最后答案。"""
	_body.visible = true
	_msg_input.visible = false
	_msg_history.visible = false
	_primary_btn.text = "返回主菜单"


func _refresh_message_history() -> void:
	var entries := MetaManager.message_wall
	if entries.is_empty():
		_msg_history.text = "（还没有人留下留言。）"
		return
	var lines: PackedStringArray = []
	var start := maxi(0, entries.size() - 10)
	for i in range(start, entries.size()):
		var entry: Dictionary = entries[i]
		lines.append("[%s]" % entry.get("text", ""))
	_msg_history.text = "—— 前代留言 ——\n" + "\n".join(lines)


func _on_primary_pressed() -> void:
	match _mode:
		Mode.MESSAGE:
			var text := _msg_input.text
			if text.strip_edges() != "":
				MetaManager.append_message(text, _layer_at_choice)
				MetaManager.save_meta()
			_msg_input.text = ""
		_:
			pass
	closed.emit()
