class_name NightTutorialOverlay
extends CanvasLayer

## 夜晚塔防新手教程（Part C）：首次进入夜晚布防时弹出的独立图文引导。
## 以 prepare_for_night 概念图为背景，逐步讲解夜晚能做的所有事。
## 看完/跳过后通过 MetaManager 记住，不再自动弹出；可在设置里重看。

signal finished

const BG_PATH := "res://assets/ui/tutorial/prepare_for_night.png"
const NightTdHintTextScript := preload("res://scripts/night_td/night_td_hint_text.gd")

# 每页：标题 + 正文。聚焦点（女孩+炮塔）在左下，故文本面板居中偏右下，避免遮挡。
const PAGES: Array = [
	{
		"title": "夜幕降临 · 布防准备",
		"body": "白天你在废墟间搜寻物资；入夜后，废土的造物会循着你的车辆涌来。\n这一夜，你要把白天的收获变成防线，守住车辆耐久直到天明。",
	},
	{
		"title": "布防界面提示",
		"body": NightTdHintTextScript.PLACE_BACKPACK,
	},
	{
		"title": "1 · 建造防御设施",
		"body": "右侧卡片列出可建造的设施（炮塔、干扰信标、路障、入侵天线…），\n每种消耗背包里的零件/废料。选中卡片后，左键点击地图格子放置；\n右键撤销并全额退还资源。",
	},
	{
		"title": "2 · 资源回收",
		"body": "夜末结算时，仍存活的设施会把建造消耗的零件/废料全额回收进背包；\n被摧毁的设施则折算成少量废料返还。所以放置不会「血亏」，大胆布防。",
	},
	{
		"title": "3 · 强化蓝图（重要）",
		"body": "白天从剧情获得的强化道具（如雷达加固模块、自动炮塔授权码、复合装甲板、\n防御塔蓝图）不会自动生效——需在背包里点选该道具并「使用」，\n才会写入夜间防御系统、提升防御塔的伤害/射程/耐久。",
	},
	{
		"title": "4 · 读懂来袭方向",
		"body": "地图边缘的青色箭头指示敌群的涌动方向（与布防顶栏说明一致）。\n每一波敌人会集中从 1-2 个正面来袭，并在波次间轮换方向。\n把火力集中部署到当前正面，比四处分散更划算。",
	},
	{
		"title": "5 · 查看火力覆盖 & 全局地图",
		"body": "点击顶部的热力开关，可叠加显示防御塔的火力/威胁覆盖范围，\n用它检查防线缺口。白天探索时按 M 可随时查看全局地图与已探明区域。",
	},
	{
		"title": "6 · 调度电力",
		"body": "战斗开始后，右侧「电力调度」面板列出每座耗电设施。\n反应堆产能有限：用 +/- 为单塔升/降功率——超频提升伤害与射速，\n断电则塔停摆、其威胁范围归零（敌人会改道涌入）。量入为出。",
	},
	{
		"title": "7 · 应急供能",
		"body": "「应急供能」按钮会临时燃烧车辆燃料，短时提升反应堆产能。\n燃料是宝贵的赶路资源，危急时再用——烧掉的部分会计入夜末结算。",
	},
	{
		"title": "8 · 入侵与转化",
		"body": "建造入侵天线后，战斗中点选它、再点一个敌人，即可持续黑入（消耗电力）。\n被转化的敌人会倒戈为你作战，且最终被清除时会回收成零件，归入夜末结算——\n黑入越多，回收越丰。牧者类敌人抗性高，但击杀/黑入它能削弱整群。",
	},
	{
		"title": "守到天明",
		"body": "防线被突破会扣车辆耐久并可能丢失物资；撑过所有波次即可进入下一天。\n随时可按 ESC 暂停。准备好了吗？",
	},
]

var _bg: TextureRect
var _panel: PanelContainer
var _title_label: Label
var _body_label: Label
var _step_label: Label
var _prev_btn: Button
var _next_btn: Button
var _skip_btn: Button
var _index := 0

# PLACEHOLDER_BUILD


func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_show_page(0)


func _build_ui() -> void:
	_bg = TextureRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var tex := load(BG_PATH)
	if tex is Texture2D:
		_bg.texture = tex
	add_child(_bg)

	# 压暗一层，保证文字可读
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.07, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# 文本面板：锚定到画面右上方，避开左下角色立绘和头发。
	# 直接锚定（不再用 CenterContainer 垂直居中，否则面板高于居中带时会溢出到脸上）。
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(640, 0)
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_END
	_panel.offset_left = -680.0
	_panel.offset_right = -40.0
	_panel.offset_top = 40.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.11, 0.92)
	sb.border_color = Color(0.36, 0.66, 0.78, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color("#d8e4f0"))
	vbox.add_child(_title_label)

	_body_label = Label.new()
	_body_label.add_theme_font_size_override("font_size", 15)
	_body_label.add_theme_color_override("font_color", Color("#b8c8d8"))
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(580, 64)
	vbox.add_child(_body_label)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	vbox.add_child(footer)

	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", 13)
	_step_label.add_theme_color_override("font_color", Color("#7f93a8"))
	_step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_step_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_step_label)

	_skip_btn = Button.new()
	_skip_btn.text = "跳过"
	HudTheme.apply_sci_fi_terminal_button(_skip_btn, Color("#8aa0b4"))
	_skip_btn.pressed.connect(_on_finish)
	footer.add_child(_skip_btn)

	_prev_btn = Button.new()
	_prev_btn.text = "上一步"
	HudTheme.apply_sci_fi_terminal_button(_prev_btn, Color("#8aa0b4"))
	_prev_btn.pressed.connect(func(): _show_page(_index - 1))
	footer.add_child(_prev_btn)

	_next_btn = Button.new()
	_next_btn.text = "下一步"
	HudTheme.apply_sci_fi_terminal_button(_next_btn, Color("#6ed08b"))
	_next_btn.pressed.connect(_on_next)
	footer.add_child(_next_btn)


func _show_page(i: int) -> void:
	_index = clampi(i, 0, PAGES.size() - 1)
	var page: Dictionary = PAGES[_index]
	_title_label.text = str(page.get("title", ""))
	_body_label.text = str(page.get("body", ""))
	_step_label.text = "%d / %d" % [_index + 1, PAGES.size()]
	_prev_btn.disabled = _index == 0
	_next_btn.text = "开始布防" if _index == PAGES.size() - 1 else "下一步"


func _on_next() -> void:
	if _index >= PAGES.size() - 1:
		_on_finish()
	else:
		_show_page(_index + 1)


func _on_finish() -> void:
	finished.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_finish()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_on_next()
		get_viewport().set_input_as_handled()
