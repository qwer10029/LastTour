extends CanvasLayer

const SciFiFramePanelScript = preload("res://scripts/ui/sci_fi_frame_panel.gd")

signal guide_closed

const COLOR_TITLE := Color("#6eb8ff")
const COLOR_SECTION := Color("#5a8aaa")
const COLOR_TIP_LABEL := Color("#e4eef8")
const COLOR_EMPTY := Color("#4a6070")

var _dim: ColorRect
var _frame: SciFiFramePanel
var _title_label: Label
var _tips_section: VBoxContainer
var _ops_section: VBoxContainer
var _confirm_btn: Button


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
	_frame.custom_minimum_size = Vector2(620, 440)
	center.add_child(_frame)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	_frame.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.text = "终末旅行"
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", COLOR_TITLE)
	HudTheme.apply_label(_title_label)
	root.add_child(_title_label)

	# ---- 关键提示 ----
	_tips_section = VBoxContainer.new()
	_tips_section.add_theme_constant_override("separation", 8)
	root.add_child(_tips_section)

	var tips_header := _make_section_label("◈ 关键提示")
	_tips_section.add_child(tips_header)

	_tips_section.add_child(_make_tip_line("黄色燃料桶", "加油"))
	_tips_section.add_child(_make_tip_line("绿色补给包", "回复体力"))
	_tips_section.add_child(_make_tip_line("修理电梯", "前往更高层"))

	# ---- 常用操作 ----
	_ops_section = VBoxContainer.new()
	_ops_section.add_theme_constant_override("separation", 8)
	root.add_child(_ops_section)

	var ops_header := _make_section_label("◈ 常用操作")
	_ops_section.add_child(ops_header)

	_ops_section.add_child(_make_op_line("W A S D", "驾驶车辆 / 室内人物移动"))
	_ops_section.add_child(_make_op_line("E", "下车进入建筑"))
	_ops_section.add_child(_make_op_line("靠近物品", "自动拾取"))
	_ops_section.add_child(_make_op_line("傍晚按 F", "准备夜晚塔防"))

	_confirm_btn = Button.new()
	_confirm_btn.text = "开始游戏"
	_confirm_btn.custom_minimum_size = Vector2(260, 46)
	_confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	HudTheme.apply_sci_fi_terminal_button(_confirm_btn)
	_confirm_btn.pressed.connect(_on_confirm)
	root.add_child(_confirm_btn)


func show_guide() -> void:
	visible = true
	_confirm_btn.grab_focus()


func hide_overlay() -> void:
	visible = false


func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", COLOR_SECTION)
	return label


func _make_tip_line(item: String, effect: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_font_size_override("font_size", 13)
	arrow.add_theme_color_override("font_color", COLOR_SECTION)
	row.add_child(arrow)

	var label := Label.new()
	label.text = "捡%s → %s" % [item, effect]
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", COLOR_TIP_LABEL)
	HudTheme.apply_label(label)
	row.add_child(label)

	return row


func _make_op_line(key: String, desc: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var key_label := Label.new()
	key_label.text = key
	key_label.add_theme_font_size_override("font_size", 12)
	key_label.add_theme_color_override("font_color", Color("#5ec8ff"))
	row.add_child(key_label)

	var desc_label := Label.new()
	desc_label.text = "：%s" % desc
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", COLOR_TIP_LABEL)
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HudTheme.apply_label(desc_label)
	row.add_child(desc_label)

	return row


func _on_confirm() -> void:
	guide_closed.emit()
