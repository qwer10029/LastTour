extends CanvasLayer

signal tower_selected(type_id: String)
signal start_wave_pressed
signal continue_pressed
signal tower_power_step(tower_id: int, delta_step: float)
signal power_tower_selected(tower_id: int)
signal overlay_toggled(state: bool)
signal fuel_boost_pressed
signal intro_finished

@onready var shell: Control = $Shell
@onready var frame_overlay: TextureRect = $Shell/FrameOverlay
@onready var top_bar: PanelContainer = $Shell/TopStatusPanel
@onready var side_panel: PanelContainer = $Shell/SidebarPanel
@onready var log_panel: PanelContainer = $Shell/LogPanel
@onready var phase_label: Label = $Shell/TopStatusPanel/Margin/StatusHBox/PhaseLabel
@onready var resource_label: Label = $Shell/TopStatusPanel/Margin/StatusHBox/ResourceLabel
@onready var timer_label: Label = $Shell/TopStatusPanel/Margin/StatusHBox/TimerLabel
@onready var heatmap_switch: Button = $Shell/TopStatusPanel/Margin/StatusHBox/HeatmapSwitch
@onready var durability_bar: NightTdDurabilityBar = $Shell/DurabilityBar
@onready var start_btn: Button = $Shell/SidebarPanel/Margin/VBox/StartWaveBtn
@onready var event_log_vbox: VBoxContainer = $Shell/LogPanel/Margin/VBox/ScrollContainer/EventLog
@onready var event_scroll: ScrollContainer = $Shell/LogPanel/Margin/VBox/ScrollContainer
@onready var breach_label: Label = $Shell/LogPanel/Margin/VBox/BreachCounter
@onready var result_overlay: Control = $Shell/ResultOverlay
@onready var continue_btn: Button = %ContinueBtn
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_label: Label = %ResultLabel

var _tower_card_data := {
	"jammer":  {"icon": "⚡", "name": "干扰信标", "color": "#6ed08b"},
	"barrier": {"icon": "▣", "name": "物理路障", "color": "#9e8564"},
	"trap":    {"icon": "▲", "name": "电磁陷阱", "color": "#e87840"},
	"cryo_beacon": {"icon": "≋", "name": "噪声信标", "color": "#c6d65c"},
	"hacker":  {"icon": "⌁", "name": "入侵天线", "color": "#5ac8e0"},
	"sniper":  {"icon": "◎", "name": "炮塔", "color": "#7aa6ff"},
	"splash":  {"icon": "❖", "name": "电弧塔",   "color": "#e0a23a"},
}

var _selected: String = "jammer"
var _continue_locked := false
var _breach_count := 0
var _tower_cards: Dictionary = {}
var _cards_vbox: VBoxContainer = null
var _overlay_active := false
var _intro_played := false
var _heatmap_hover_tween: Tween
var _log_hover_tween: Tween
const HOVER_SCALE := Vector2(1.04, 1.04)

# Tooltip
var _tooltip: PanelContainer = null
var _tooltip_label: Label = null
var _hover_timer: float = 0.0
var _hovered_card_type: String = ""
const HOVER_DELAY: float = 0.45

# Power
var _power_panel: VBoxContainer = null
var _energy_label: Label = null
var _energy_rate_row: HBoxContainer = null
var _energy_production_label: Label = null
var _energy_production_bar: ProgressBar = null
var _energy_draw_label: Label = null
var _energy_draw_bar: ProgressBar = null
var _fuel_boost_btn: Button = null
var _fuel_boost_label: Label = null
var _power_list: VBoxContainer = null
var _power_empty_label: Label = null
var _power_rows: Dictionary = {}
var _selected_power_tower_ids: Array[int] = []   # 多选支持：框选多塔时同时高亮多行
var _power_pulse_tweens: Array[Tween] = []        # 多选时每个高亮行各一个脉冲动画
var _night_fuel_bar: ProgressBar = null
var _night_fuel_label: Label = null
var _night_vehicle_bar: ProgressBar = null
var _night_vehicle_label: Label = null
var _countdown_warning_label: Label = null
var _gallery_btn: Button = null
var _gallery_overlay: Control = null
var _gallery_title: Label = null
var _gallery_list: ItemList = null
var _gallery_detail: Label = null
var _seen_enemy_types: Array[String] = []
var _gallery_auto_hide_timer: Timer = null
var _gallery_fade_tween: Tween = null
const GALLERY_AUTO_HIDE_SEC := 4.0
const GALLERY_FADE_SEC := 0.28

# 事件日志：单个 RichTextLabel + 定长环形缓冲，避免每条日志各建一个 Label 节点
# （旧方案节点数随波次单调增长 → 布局/滚动开销越打越卡）。
const MAX_LOG_LINES := 14
var _log_lines: Array[String] = []
var _log_label: RichTextLabel = null

const COLORS := {
	"bg": "#0b1018", "panel": "#141c28", "border": "#2a3a4f",
	"title": "#d8e4f0", "subtitle": "#8fa3b8", "accent": "#6ed08b",
	"danger": "#e87840", "hack": "#5ac8e0", "amber": "#f0a040",
}


func _ready() -> void:
	hide_session_ui()
	_apply_holo_shell_styles()
	_build_tooltip()
	_build_cards_in_sidebar()
	if is_instance_valid(start_btn):
		start_btn.pressed.connect(func(): start_wave_pressed.emit())
	if is_instance_valid(continue_btn):
		continue_btn.pressed.connect(_on_continue_pressed)
	_build_countdown_warning()
	_build_power_panel()
	_build_night_status_meters()
	_build_enemy_gallery()
	_setup_heatmap_switch()
	_wire_hover_feedback()
	for lbl in [phase_label, resource_label, timer_label]:
		NightTdUiTheme.apply_holo_label(lbl)
	if is_instance_valid(timer_label):
		timer_label.custom_minimum_size = Vector2(156, 0)
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer_label.add_theme_font_size_override("font_size", 24)
	NightTdUiTheme.apply_holo_label(breach_label, true)
	if is_instance_valid(breach_label):
		breach_label.visible = false
	_select("jammer")


func _process(delta: float) -> void:
	if _hovered_card_type != "":
		_hover_timer += delta
		if _hover_timer >= HOVER_DELAY and not _tooltip.visible:
			_show_tooltip(_hovered_card_type)


func show_session_ui() -> void:
	show()
	_continue_locked = false
	_breach_count = 0
	_intro_played = false
	if is_instance_valid(shell):
		shell.show()
	if is_instance_valid(top_bar):
		top_bar.show()
	if is_instance_valid(side_panel):
		side_panel.show()
	if is_instance_valid(log_panel):
		log_panel.show()
	if is_instance_valid(breach_label):
		breach_label.visible = false
		breach_label.text = "⚠ 突破: 0"
	clear_log()
	hide_result_dialog()
	if is_instance_valid(heatmap_switch):
		heatmap_switch.show()
	if is_instance_valid(_gallery_btn):
		_gallery_btn.show()
	hide_enemy_gallery()
	_play_intro_animation()


func hide_session_ui() -> void:
	hide_result_dialog()
	show_power_panel(false)
	clear_power_highlight()
	if is_instance_valid(shell):
		shell.hide()
	if is_instance_valid(breach_label):
		breach_label.visible = false
	if is_instance_valid(_countdown_warning_label):
		_countdown_warning_label.hide()
	hide_enemy_gallery()
	hide()


func hide_result_dialog() -> void:
	_continue_locked = true
	if is_instance_valid(result_overlay):
		result_overlay.hide(); result_overlay.visible = false
	if is_instance_valid(continue_btn):
		continue_btn.disabled = true


func _on_continue_pressed() -> void:
	if _continue_locked: return
	_continue_locked = true
	if is_instance_valid(continue_btn): continue_btn.disabled = true
	hide_result_dialog()
	continue_pressed.emit()


# -- Tooltip ------------------------------------------------------

func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.name = "TowerTooltip"
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.z_index = 100
	add_child(_tooltip)
	var m := MarginContainer.new()
	for side in ["left","top","right","bottom"]:
		m.add_theme_constant_override("margin_" + side, 6)
	_tooltip.add_child(m)
	_tooltip_label = Label.new()
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	m.add_child(_tooltip_label)


func _show_tooltip(type_id: String) -> void:
	var tdef: Dictionary = NightTdDefs.get_tower_def(type_id)
	var parts: PackedStringArray = []
	if int(tdef.get("range", 0)) > 0:
		parts.append("射程%dpx" % int(tdef.get("range", 0)))
	if float(tdef.get("damage", 0)) > 0:
		parts.append("伤害%.0f" % float(tdef.get("damage", 0)))
	var fi := float(tdef.get("fire_interval", 0))
	if fi > 0 and fi < 900:
		parts.append("射速%.1fs" % fi)
	if int(tdef.get("hp", 0)) > 0:
		parts.append("HP%d" % int(tdef.get("hp", 0)))
	if int(tdef.get("splash_radius", 0)) > 0:
		parts.append("AOE%dpx" % int(tdef.get("splash_radius", 0)))
	if float(tdef.get("hack_rate", 0)) > 0:
		parts.append("黑入%.0f/s" % float(tdef.get("hack_rate", 0)))
	if float(tdef.get("slow_factor", 0)) > 0:
		parts.append("减速%.0f%%" % (float(tdef.get("slow_factor", 0)) * 100))
	if tdef.get("one_shot", false):
		parts.append("一次性")
	var desc: String = str(tdef.get("desc", tdef.get("description", "")))
	if desc != "":
		parts.insert(0, desc)
	_tooltip_label.text = " · ".join(parts)
	var card: PanelContainer = _tower_cards[type_id]["panel"]
	var p := card.global_position
	_tooltip.position = Vector2(p.x - 210, p.y - 2)
	_tooltip.custom_minimum_size = Vector2(200, 0)
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(COLORS["panel"])
	ts.border_color = Color(COLORS["border"])
	ts.set_border_width_all(1); ts.set_corner_radius_all(6)
	_tooltip.add_theme_stylebox_override("panel", ts)
	_tooltip.visible = true


# -- Tower Cards (right sidebar, vertical list) -------------------

func _build_cards_in_sidebar() -> void:
	var vbox := side_panel.get_node_or_null("Margin/VBox")
	if vbox == null: return

	_cards_vbox = VBoxContainer.new()
	_cards_vbox.name = "TowerCards"
	_cards_vbox.add_theme_constant_override("separation", 3)
	vbox.add_child(_cards_vbox)
	vbox.move_child(_cards_vbox, 0)

	for type_id in ["jammer","barrier","trap","cryo_beacon","hacker","sniper","splash"]:
		var data: Dictionary = _tower_card_data.get(type_id, {})
		var card := _make_card_row(type_id, data)
		_cards_vbox.add_child(card)


func _make_card_row(type_id: String, data: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = type_id.capitalize() + "Card"
	card.custom_minimum_size = Vector2(0, 28)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLORS["panel"])
	style.border_color = Color(COLORS["border"])
	style.set_border_width_all(1); style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(row)

	var icon := Label.new()
	icon.text = str(data.get("icon", "?"))
	icon.custom_minimum_size = Vector2(22, 0)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 14)
	icon.add_theme_color_override("font_color", Color(str(data.get("color", "#ffffff"))))
	row.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = str(data.get("name", type_id))
	name_lbl.custom_minimum_size = Vector2(66, 0)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(COLORS["title"]))
	row.add_child(name_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = ""
	cost_lbl.custom_minimum_size = Vector2(70, 0)
	cost_lbl.add_theme_font_size_override("font_size", 10)
	cost_lbl.add_theme_color_override("font_color", Color(COLORS["subtitle"]))
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(cost_lbl)

	card.gui_input.connect(_on_card_input.bind(type_id))
	card.mouse_entered.connect(func(): _hovered_card_type = type_id; _hover_timer = 0.0)
	card.mouse_exited.connect(func():
		_hovered_card_type = ""; _hover_timer = 0.0; _tooltip.visible = false)

	_tower_cards[type_id] = {"panel": card, "icon": icon, "name": name_lbl, "cost": cost_lbl}
	return card


func _on_card_input(event: InputEvent, type_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select(type_id)


func _select(type_id: String) -> void:
	_selected = type_id
	tower_selected.emit(type_id)
	_refresh_card_highlights()


func refresh_tool_buttons() -> void:
	_refresh_card_highlights()

func get_selected_tower() -> String:
	return _selected


func _refresh_card_highlights() -> void:
	for tid in _tower_cards.keys():
		var card: PanelContainer = _tower_cards[tid]["panel"]
		var s := StyleBoxFlat.new()
		if tid == _selected:
			s.bg_color = Color("#2d4a3a"); s.border_color = Color(COLORS["accent"])
			s.set_border_width_all(2)
		else:
			s.bg_color = Color(COLORS["panel"]); s.border_color = Color(COLORS["border"])
			s.set_border_width_all(1)
		s.set_corner_radius_all(4)
		card.add_theme_stylebox_override("panel", s)


func update_card_costs(backpack_counts: Dictionary) -> void:
	for tid in _tower_cards.keys():
		var cost_lbl: Label = _tower_cards[tid]["cost"]
		var tdef := NightTdDefs.get_tower_def(tid)
		var build_cost: Dictionary = tdef.get("build_cost", {})
		var pcs: Array[String] = []
		for item_id: String in build_cost.keys():
			pcs.append("%s×%d" % [ItemDefs.get_item_name(item_id), int(build_cost[item_id])])
		cost_lbl.text = "、".join(pcs) if not pcs.is_empty() else ""
		var ok := true
		for item_id: String in build_cost.keys():
			if int(backpack_counts.get(item_id, 0)) < int(build_cost[item_id]):
				ok = false; break
		cost_lbl.add_theme_color_override("font_color", Color(COLORS["accent"]) if ok else Color(COLORS["danger"]))


# -- 全息外壳 / 热力图 / 载入动画 --------------------------------

func _apply_holo_shell_styles() -> void:
	if is_instance_valid(frame_overlay):
		var frame_tex := NightTdUiTheme.load_texture(NightTdUiTheme.FRAME_INTERFACE)
		if frame_tex != null:
			frame_overlay.texture = frame_tex
	if is_instance_valid(top_bar):
		top_bar.add_theme_stylebox_override(
			"panel",
			NightTdUiTheme.panel_style(
				NightTdUiTheme.PANEL_TOP_STATUS,
				NightTdUiTheme.PANEL_MARGINS[NightTdUiTheme.PANEL_TOP_STATUS],
			),
		)
	if is_instance_valid(side_panel):
		side_panel.add_theme_stylebox_override(
			"panel",
			NightTdUiTheme.panel_style(
				NightTdUiTheme.PANEL_SIDEBAR,
				NightTdUiTheme.PANEL_MARGINS[NightTdUiTheme.PANEL_SIDEBAR],
			),
		)
	if is_instance_valid(log_panel):
		log_panel.add_theme_stylebox_override(
			"panel",
			NightTdUiTheme.panel_style(
				NightTdUiTheme.PANEL_DIALOG_LOG,
				NightTdUiTheme.PANEL_MARGINS[NightTdUiTheme.PANEL_DIALOG_LOG],
			),
		)
	if is_instance_valid(result_panel):
		result_panel.add_theme_stylebox_override("panel", NightTdUiTheme.panel_style(NightTdUiTheme.PANEL_DIALOG_LOG, 18))


func _setup_heatmap_switch() -> void:
	if not is_instance_valid(heatmap_switch):
		return
	heatmap_switch.focus_mode = Control.FOCUS_NONE
	heatmap_switch.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	HudTheme.apply_sci_fi_terminal_button(heatmap_switch, Color(COLORS["hack"]))
	heatmap_switch.add_theme_font_size_override("font_size", 12)
	heatmap_switch.custom_minimum_size = Vector2(112, 30)
	heatmap_switch.toggle_mode = true
	set_overlay_active(false)
	heatmap_switch.pressed.connect(_on_heatmap_switch_pressed)


func _build_countdown_warning() -> void:
	if not is_instance_valid(shell):
		return
	_countdown_warning_label = Label.new()
	_countdown_warning_label.name = "CountdownWarning"
	_countdown_warning_label.visible = false
	_countdown_warning_label.z_index = 90
	_countdown_warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_countdown_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_warning_label.add_theme_font_size_override("font_size", 34)
	_countdown_warning_label.add_theme_color_override("font_color", Color(COLORS["danger"]))
	_countdown_warning_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_countdown_warning_label.offset_left = 240.0
	_countdown_warning_label.offset_top = 86.0
	_countdown_warning_label.offset_right = -300.0
	_countdown_warning_label.offset_bottom = 138.0
	shell.add_child(_countdown_warning_label)


func show_placement_warning(seconds_left: int) -> void:
	if not is_instance_valid(_countdown_warning_label):
		return
	_countdown_warning_label.text = "布防倒计时 %d 秒" % seconds_left
	_countdown_warning_label.modulate = Color.WHITE
	_countdown_warning_label.scale = Vector2.ONE
	_countdown_warning_label.show()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_countdown_warning_label, "scale", Vector2(1.12, 1.12), 0.18)
	tween.tween_property(_countdown_warning_label, "modulate:a", 0.58, 0.18)
	tween.set_parallel(false)
	tween.tween_property(_countdown_warning_label, "scale", Vector2.ONE, 0.24)
	tween.tween_property(_countdown_warning_label, "modulate:a", 1.0, 0.24)
	tween.tween_interval(2.6)
	tween.tween_property(_countdown_warning_label, "modulate:a", 0.0, 0.35)
	tween.finished.connect(func():
		if is_instance_valid(_countdown_warning_label):
			_countdown_warning_label.hide()
			_countdown_warning_label.modulate.a = 1.0
	)


func _build_enemy_gallery() -> void:
	var status_hbox := get_node_or_null("Shell/TopStatusPanel/Margin/StatusHBox")
	if status_hbox != null:
		_gallery_btn = Button.new()
		_gallery_btn.text = "敌情图鉴"
		_gallery_btn.custom_minimum_size = Vector2(104, 30)
		_gallery_btn.focus_mode = Control.FOCUS_NONE
		_gallery_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		HudTheme.apply_sci_fi_terminal_button(_gallery_btn, Color(COLORS["amber"]))
		_gallery_btn.add_theme_font_size_override("font_size", 12)
		_gallery_btn.pressed.connect(show_enemy_gallery)
		status_hbox.add_child(_gallery_btn)
	if not is_instance_valid(shell):
		return
	_gallery_overlay = Control.new()
	_gallery_overlay.name = "EnemyGalleryOverlay"
	_gallery_overlay.visible = false
	_gallery_overlay.z_index = 110
	_gallery_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gallery_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(_gallery_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.24)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gallery_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "EnemyGalleryPanel"
	panel.custom_minimum_size = Vector2(252, 320)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.offset_left = -292.0
	panel.offset_right = -40.0
	panel.offset_top = 88.0
	panel.offset_bottom = 408.0
	panel.add_theme_stylebox_override("panel", NightTdUiTheme.panel_style(NightTdUiTheme.PANEL_DIALOG_LOG, 18))
	_gallery_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	outer.add_child(top)
	_gallery_title = Label.new()
	_gallery_title.text = "敌情图鉴"
	_gallery_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gallery_title.add_theme_font_size_override("font_size", 16)
	_gallery_title.add_theme_color_override("font_color", Color(COLORS["title"]))
	top.add_child(_gallery_title)
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(hide_enemy_gallery)
	top.add_child(close_btn)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	_gallery_list = ItemList.new()
	_gallery_list.custom_minimum_size = Vector2(220, 86)
	_gallery_list.item_selected.connect(_on_gallery_enemy_selected)
	body.add_child(_gallery_list)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.custom_minimum_size = Vector2(220, 150)
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(detail_scroll)
	_gallery_detail = Label.new()
	_gallery_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gallery_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gallery_detail.add_theme_color_override("font_color", Color(COLORS["title"]))
	detail_scroll.add_child(_gallery_detail)

	_gallery_auto_hide_timer = Timer.new()
	_gallery_auto_hide_timer.name = "AutoHideTimer"
	_gallery_auto_hide_timer.one_shot = true
	_gallery_auto_hide_timer.wait_time = GALLERY_AUTO_HIDE_SEC
	_gallery_auto_hide_timer.timeout.connect(_on_gallery_auto_hide_timeout)
	_gallery_overlay.add_child(_gallery_auto_hide_timer)


func set_seen_enemy_types(types: Array) -> void:
	_seen_enemy_types.clear()
	for type_id in types:
		_seen_enemy_types.append(str(type_id))
	_refresh_enemy_gallery_list()


func show_enemy_first_seen(type_id: String) -> void:
	set_seen_enemy_types(_seen_enemy_types)
	if is_instance_valid(_gallery_overlay) and _gallery_overlay.visible:
		_select_gallery_type(type_id)
		return
	show_enemy_gallery(type_id, true)


func show_enemy_gallery(type_id: String = "", first_seen: bool = false) -> void:
	if not is_instance_valid(_gallery_overlay):
		return
	_cancel_gallery_auto_hide()
	_refresh_enemy_gallery_list()
	_gallery_title.text = "新敌人出现" if first_seen else "敌情图鉴"
	_gallery_overlay.modulate = Color.WHITE
	_gallery_overlay.show()
	if type_id != "":
		_select_gallery_type(type_id)
	elif is_instance_valid(_gallery_list) and _gallery_list.get_item_count() > 0:
		_gallery_list.select(0)
		_on_gallery_enemy_selected(0)
	else:
		_gallery_detail.text = "尚未遭遇已知敌方机体。"
	_start_gallery_auto_hide()


func hide_enemy_gallery() -> void:
	if is_instance_valid(_gallery_overlay):
		_cancel_gallery_auto_hide()
		_gallery_overlay.hide()
		_gallery_overlay.modulate = Color.WHITE


func _refresh_enemy_gallery_list() -> void:
	if not is_instance_valid(_gallery_list):
		return
	_gallery_list.clear()
	var all_types := NightTdDefs.get_enemy_type_ids()
	for type_id in all_types:
		var def := NightTdDefs.get_enemy_def(type_id)
		var seen := _seen_enemy_types.has(type_id)
		if not seen:
			continue
		var label := str(def.get("name", type_id))
		var idx := _gallery_list.add_item(label)
		_gallery_list.set_item_metadata(idx, type_id)
		var color: Color = def.get("color", Color.WHITE)
		_gallery_list.set_item_custom_fg_color(idx, color)


func _select_gallery_type(type_id: String) -> void:
	if not is_instance_valid(_gallery_list):
		return
	for i in range(_gallery_list.get_item_count()):
		if str(_gallery_list.get_item_metadata(i)) == type_id:
			_gallery_list.select(i)
			_on_gallery_enemy_selected(i)
			_restart_gallery_auto_hide()
			return
	_gallery_detail.text = _enemy_gallery_text(type_id)
	_restart_gallery_auto_hide()


func _on_gallery_enemy_selected(index: int) -> void:
	if index < 0 or not is_instance_valid(_gallery_list):
		return
	var meta: Variant = _gallery_list.get_item_metadata(index)
	if meta == null:
		return
	_gallery_detail.text = _enemy_gallery_text(str(meta))
	_restart_gallery_auto_hide()


func _start_gallery_auto_hide() -> void:
	if not is_instance_valid(_gallery_auto_hide_timer):
		return
	_gallery_auto_hide_timer.start(GALLERY_AUTO_HIDE_SEC)


func _restart_gallery_auto_hide() -> void:
	if not is_instance_valid(_gallery_auto_hide_timer) or not _gallery_overlay.visible:
		return
	_gallery_auto_hide_timer.start(GALLERY_AUTO_HIDE_SEC)


func _cancel_gallery_auto_hide() -> void:
	if is_instance_valid(_gallery_auto_hide_timer):
		_gallery_auto_hide_timer.stop()
	if _gallery_fade_tween != null and _gallery_fade_tween.is_valid():
		_gallery_fade_tween.kill()
	_gallery_fade_tween = null


func _on_gallery_auto_hide_timeout() -> void:
	if not is_instance_valid(_gallery_overlay) or not _gallery_overlay.visible:
		return
	_cancel_gallery_auto_hide()
	_gallery_fade_tween = create_tween()
	_gallery_fade_tween.tween_property(_gallery_overlay, "modulate:a", 0.0, GALLERY_FADE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_gallery_fade_tween.finished.connect(func():
		if is_instance_valid(_gallery_overlay):
			_gallery_overlay.hide()
			_gallery_overlay.modulate = Color.WHITE
		_gallery_fade_tween = null
	)


func _enemy_gallery_text(type_id: String) -> String:
	var def := NightTdDefs.get_enemy_def(type_id)
	if def.is_empty():
		return type_id
	var lines: PackedStringArray = []
	lines.append(str(def.get("name", type_id)))
	lines.append("")
	lines.append("耐久 %.0f · 速度 %.0f · 突破伤害 %.0f" % [
		float(def.get("hp", 0.0)),
		float(def.get("speed", 0.0)),
		float(def.get("base_damage", 0.0)),
	])
	var armor := float(def.get("armor", 0.0))
	if armor > 0.0:
		lines.append("装甲 %.0f%%：更耐打。" % (armor * 100.0))
	if bool(def.get("hack_immune", false)):
		lines.append("黑入免疫：入侵天线无法策反。")
	elif float(def.get("hack_resist", 1.0)) > 1.0:
		lines.append("黑入抗性 %.1fx：策反需要更久。" % float(def.get("hack_resist", 1.0)))
	if bool(def.get("effect_immune", false)):
		lines.append("效果免疫：不受减速等控制影响。")
	if bool(def.get("is_shepherd", false)):
		lines.append("指挥机：组织敌群绕开火力、压迫薄弱处；击毁或策反后指挥链会短暂中断。")
	if float(def.get("heal_per_sec", 0.0)) > 0.0:
		lines.append("修复中继：每秒修复附近敌人 %.0f 点。" % float(def.get("heal_per_sec", 0.0)))
	var summon := str(def.get("summon_enemy", ""))
	if summon != "":
		var summon_def := NightTdDefs.get_enemy_def(summon)
		lines.append("召唤：周期性呼叫 %s 增援。" % str(summon_def.get("name", summon)))
	if float(def.get("breach_damage_factor", -1.0)) >= 0.0:
		lines.append("突破特性：抵达车辆时造成高额固定比例伤害。")
	return "\n".join(lines)


func set_overlay_active(active: bool) -> void:
	_overlay_active = active
	if is_instance_valid(heatmap_switch):
		heatmap_switch.button_pressed = active
	_refresh_heatmap_switch_visual()


func _wire_hover_feedback() -> void:
	if is_instance_valid(heatmap_switch):
		heatmap_switch.mouse_entered.connect(_on_heatmap_mouse_entered)
		heatmap_switch.mouse_exited.connect(_on_heatmap_mouse_exited)
	if is_instance_valid(log_panel):
		log_panel.mouse_entered.connect(_on_log_panel_mouse_entered)
		log_panel.mouse_exited.connect(_on_log_panel_mouse_exited)


func _play_intro_animation() -> void:
	if _intro_played or not is_instance_valid(frame_overlay):
		return
	_intro_played = true
	frame_overlay.modulate = NightTdUiTheme.COLOR_CHARGE_DARK
	var tween := create_tween()
	tween.tween_property(frame_overlay, "modulate", NightTdUiTheme.COLOR_CHARGE_GLOW, 0.42)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(frame_overlay, "modulate", Color(0.72, 0.82, 0.95, 1.0), 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func(): intro_finished.emit())


func play_defence_core_shield_intro(core_visual: NightTdDefenceCoreVisual) -> void:
	if is_instance_valid(core_visual):
		core_visual.play_shield_activate()


func _on_heatmap_switch_pressed() -> void:
	_overlay_active = heatmap_switch.button_pressed
	_refresh_heatmap_switch_visual()
	overlay_toggled.emit(_overlay_active)


func _refresh_heatmap_switch_visual() -> void:
	if not is_instance_valid(heatmap_switch):
		return
	var alpha := 1.0 if _overlay_active else 0.5
	heatmap_switch.modulate = Color(1, 1, 1, alpha)
	heatmap_switch.text = "热力图: 开" if _overlay_active else "热力图: 关"


func _on_heatmap_mouse_entered() -> void:
	if not is_instance_valid(heatmap_switch):
		return
	if _heatmap_hover_tween != null and _heatmap_hover_tween.is_valid():
		_heatmap_hover_tween.kill()
	_heatmap_hover_tween = create_tween().set_parallel(true)
	_heatmap_hover_tween.tween_property(heatmap_switch, "scale", HOVER_SCALE, 0.16)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_heatmap_hover_tween.tween_property(heatmap_switch, "modulate:a", 1.0, 0.16)


func _on_heatmap_mouse_exited() -> void:
	if not is_instance_valid(heatmap_switch):
		return
	if _heatmap_hover_tween != null and _heatmap_hover_tween.is_valid():
		_heatmap_hover_tween.kill()
	_heatmap_hover_tween = create_tween().set_parallel(true)
	_heatmap_hover_tween.tween_property(heatmap_switch, "scale", Vector2.ONE, 0.16)
	var target_a := 1.0 if _overlay_active else 0.5
	_heatmap_hover_tween.tween_property(heatmap_switch, "modulate:a", target_a, 0.16)


func _on_log_panel_mouse_entered() -> void:
	if not is_instance_valid(log_panel):
		return
	if _log_hover_tween != null and _log_hover_tween.is_valid():
		_log_hover_tween.kill()
	_log_hover_tween = create_tween().set_parallel(true)
	_log_hover_tween.tween_property(log_panel, "scale", HOVER_SCALE, 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_log_hover_tween.tween_property(log_panel, "modulate", Color(0.82, 0.95, 1.15, 1.0), 0.18)


func _on_log_panel_mouse_exited() -> void:
	if not is_instance_valid(log_panel):
		return
	if _log_hover_tween != null and _log_hover_tween.is_valid():
		_log_hover_tween.kill()
	_log_hover_tween = create_tween().set_parallel(true)
	_log_hover_tween.tween_property(log_panel, "scale", Vector2.ONE, 0.18)
	_log_hover_tween.tween_property(log_panel, "modulate", Color.WHITE, 0.18)


func set_vehicle_durability(current: float, maximum: float, animate: bool = true) -> void:
	if maximum <= 0.0:
		_set_status_meter(_night_vehicle_bar, _night_vehicle_label, "车辆耐久", current, maximum)
		return
	if is_instance_valid(durability_bar):
		durability_bar.show()
		durability_bar.set_ratio(current / maximum, animate)
	_set_status_meter(_night_vehicle_bar, _night_vehicle_label, "车辆耐久", current, maximum)


# -- Phase --------------------------------------------------------

func set_phase_text(text: String) -> void:
	if is_instance_valid(phase_label): phase_label.text = text

func set_resources(remaining: int, spent: int) -> void:
	if is_instance_valid(resource_label):
		resource_label.text = "部署点: %d (已用 %d)" % [remaining, spent]

func set_resource_text(text: String) -> void:
	if is_instance_valid(resource_label): resource_label.text = text

func set_placement_timer(sec: float) -> void:
	if not is_instance_valid(timer_label):
		return
	var remaining := maxf(sec, 0.0)
	timer_label.text = "布防 %.0fs" % remaining
	timer_label.add_theme_color_override("font_color", Color(COLORS["danger"]) if remaining <= 30.0 else Color(COLORS["title"]))
	timer_label.add_theme_font_size_override("font_size", 26 if remaining <= 30.0 else 24)

func set_combat_status(text: String) -> void:
	if is_instance_valid(timer_label): timer_label.text = text

func set_hint(text: String) -> void:
	pass


# -- Breach Counter ------------------------------------------------

func increment_breach_counter(count: int) -> void:
	_breach_count = count
	if is_instance_valid(breach_label):
		breach_label.text = "⚠ 突破: %d" % count
		breach_label.visible = true
		var tween := create_tween()
		tween.tween_property(breach_label, "modulate:a", 0.4, 0.15)
		tween.tween_property(breach_label, "modulate:a", 1.0, 0.3)


# -- Event Log ----------------------------------------------------

func _ensure_log_label() -> RichTextLabel:
	if is_instance_valid(_log_label):
		return _log_label
	if not is_instance_valid(event_log_vbox):
		return null
	# 清掉旧方案可能遗留的逐条 Label 子节点。
	for child in event_log_vbox.get_children():
		child.queue_free()
	_log_label = RichTextLabel.new()
	_log_label.name = "LogText"
	_log_label.bbcode_enabled = true
	_log_label.scroll_active = false   # 由外层 ScrollContainer 负责滚动
	_log_label.fit_content = true
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.add_theme_font_size_override("normal_font_size", 10)
	_log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_log_vbox.add_child(_log_label)
	return _log_label


func clear_log() -> void:
	_log_lines.clear()
	if is_instance_valid(_log_label):
		_log_label.text = ""
	elif is_instance_valid(event_log_vbox):
		for child in event_log_vbox.get_children():
			child.queue_free()

func _scroll_to_bottom() -> void:
	if is_instance_valid(event_scroll):
		event_scroll.scroll_vertical = int(event_scroll.get_v_scroll_bar().max_value)


func append_log(line: String, text_color: Color = Color(COLORS["subtitle"])) -> void:
	var label := _ensure_log_label()
	if label == null:
		return
	# 环形缓冲：只保留最近 MAX_LOG_LINES 行，整体重渲染一次，
	# 节点数恒为 1，开销与夜晚时长无关。
	_log_lines.append("[color=#%s]%s[/color]" % [text_color.to_html(false), line])
	while _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	label.text = "\n".join(_log_lines)
	# 用 call_deferred 替代 await，避免每次日志创建协程对象（GDScriptFunctionState）
	if is_instance_valid(event_scroll):
		_scroll_to_bottom.call_deferred()


# -- Mode Switching ------------------------------------------------

func set_place_mode(active: bool) -> void:
	if is_instance_valid(start_btn): start_btn.show() if active else start_btn.hide()
	hide_result_dialog()
	if is_instance_valid(_cards_vbox): _cards_vbox.visible = active
	show_power_panel(false)
	_update_card_states(active)
	if is_instance_valid(heatmap_switch):
		heatmap_switch.show()


func set_combat_mode() -> void:
	if is_instance_valid(start_btn): start_btn.hide()
	hide_result_dialog()
	if is_instance_valid(_cards_vbox): _cards_vbox.visible = false
	_update_card_states(false)
	show_power_panel(true)
	if is_instance_valid(heatmap_switch):
		heatmap_switch.show()


func _update_card_states(enabled: bool) -> void:
	for tid in _tower_cards.keys():
		var card: PanelContainer = _tower_cards[tid]["panel"]
		card.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		card.modulate = Color(1,1,1,1) if enabled else Color(1,1,1,0.4)


# -- Result Screen ------------------------------------------------

func show_result(text: String, button_text: String = "确认结算，进入下一天") -> void:
	_continue_locked = false
	if is_instance_valid(result_label): result_label.text = text
	if is_instance_valid(continue_btn):
		continue_btn.text = button_text
		continue_btn.disabled = false
	if is_instance_valid(result_overlay):
		result_overlay.show(); result_overlay.visible = true
	show_power_panel(false)
	clear_power_highlight()
	if is_instance_valid(start_btn): start_btn.hide()
	if is_instance_valid(_cards_vbox): _cards_vbox.visible = false


# -- Power Panel ---------------------------------------------------

func _build_power_panel() -> void:
	_power_panel = VBoxContainer.new()
	_power_panel.name = "PowerPanel"
	_power_panel.custom_minimum_size = Vector2(0, 0)
	_power_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_power_panel.add_theme_constant_override("separation", 5)
	_power_panel.visible = false
	_power_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var side_vbox := get_node_or_null("Shell/SidebarPanel/Margin/VBox")
	if side_vbox != null:
		side_vbox.add_child(_power_panel)
	else:
		add_child(_power_panel)

	var title := Label.new()
	title.text = "⚡ 电力调度"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(COLORS["title"]))
	_power_panel.add_child(title)

	_energy_label = Label.new()
	_energy_label.text = "储能: --"
	_energy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_energy_label.add_theme_font_size_override("font_size", 15)
	_energy_label.add_theme_color_override("font_color", Color(COLORS["title"]))
	_power_panel.add_child(_energy_label)

	_energy_rate_row = HBoxContainer.new()
	_energy_rate_row.add_theme_constant_override("separation", 8)
	_energy_rate_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_power_panel.add_child(_energy_rate_row)

	var production_box := _make_energy_rate_box("发电", Color("#6ed08b"))
	_energy_rate_row.add_child(production_box)
	_energy_production_label = production_box.get_node("ValueLabel") as Label
	_energy_production_bar = production_box.get_node("Bar") as ProgressBar

	var draw_box := _make_energy_rate_box("耗电", Color("#f0a040"))
	_energy_rate_row.add_child(draw_box)
	_energy_draw_label = draw_box.get_node("ValueLabel") as Label
	_energy_draw_bar = draw_box.get_node("Bar") as ProgressBar

	_fuel_boost_btn = Button.new()
	_fuel_boost_btn.text = "应急供能"
	_fuel_boost_btn.custom_minimum_size = Vector2(0, 32)
	HudTheme.apply_sci_fi_terminal_button(_fuel_boost_btn, Color(COLORS["amber"]))
	_fuel_boost_btn.pressed.connect(func(): fuel_boost_pressed.emit())
	_power_panel.add_child(_fuel_boost_btn)

	_fuel_boost_label = Label.new()
	_fuel_boost_label.text = "燃料: --"
	_fuel_boost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fuel_boost_label.add_theme_font_size_override("font_size", 10)
	_fuel_boost_label.add_theme_color_override("font_color", Color(COLORS["subtitle"]))
	_power_panel.add_child(_fuel_boost_label)

	_power_list = VBoxContainer.new()
	_power_list.add_theme_constant_override("separation", 2)
	_power_panel.add_child(_power_list)

	_power_empty_label = Label.new()
	_power_empty_label.text = "（暂无耗电设施）"
	_power_empty_label.add_theme_color_override("font_color", Color(COLORS["subtitle"]))
	_power_panel.add_child(_power_empty_label)


func _make_energy_rate_box(title: String, accent: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 3)
	var label := Label.new()
	label.name = "ValueLabel"
	label.text = "%s 0.0/s" % title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(COLORS["title"]))
	box.add_child(label)
	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 0.0
	bar.custom_minimum_size = Vector2(0, 14)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.11, 0.16, 0.82)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)
	return box


func _build_night_status_meters() -> void:
	var status_hbox := get_node_or_null("Shell/TopStatusPanel/Margin/StatusHBox")
	if status_hbox == null:
		return
	status_hbox.add_theme_constant_override("separation", 14)
	var fuel := _make_status_meter("燃料", Color("#f4d03f"))
	status_hbox.add_child(fuel)
	_night_fuel_label = fuel.get_node("ValueLabel") as Label
	_night_fuel_bar = fuel.get_node("Bar") as ProgressBar
	var vehicle := _make_status_meter("车辆耐久", Color("#bb8fce"))
	status_hbox.add_child(vehicle)
	_night_vehicle_label = vehicle.get_node("ValueLabel") as Label
	_night_vehicle_bar = vehicle.get_node("Bar") as ProgressBar


func _make_status_meter(title: String, accent: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(124, 32)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.name = "ValueLabel"
	label.text = "%s --/--" % title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(COLORS["title"]))
	box.add_child(label)
	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.custom_minimum_size = Vector2(124, 8)
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.11, 0.16, 0.82)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)
	return box


func _set_status_meter(bar: ProgressBar, label: Label, title: String, current: float, maximum: float) -> void:
	if not is_instance_valid(bar) or not is_instance_valid(label):
		return
	if maximum <= 0.0:
		bar.max_value = 1.0
		bar.value = 0.0
		label.text = "%s --/--" % title
		return
	var safe_max := maxf(maximum, 1.0)
	bar.max_value = safe_max
	bar.value = clampf(current, 0.0, safe_max)
	label.text = "%s %.0f/%.0f" % [title, clampf(current, 0.0, safe_max), maximum]


func set_energy_status(current: float, capacity: float, _planned_demand: float, production: float, actual_draw: float, brownout: float) -> void:
	if is_instance_valid(_energy_label):
		_energy_label.text = "储能 %.0f/%.0f · 供电 %.0f%%" % [
			clampf(current, 0.0, capacity),
			capacity,
			clampf(brownout * 100.0, 0.0, 100.0),
		]
	var displayed_draw := minf(actual_draw, production) if current <= 0.01 else actual_draw
	var rate_scale := maxf(maxf(production, displayed_draw), 1.0)
	if is_instance_valid(_energy_production_label):
		_energy_production_label.text = "发电 +%.1f/s" % production
	if is_instance_valid(_energy_production_bar):
		_energy_production_bar.max_value = rate_scale
		_energy_production_bar.value = clampf(production, 0.0, rate_scale)
	if is_instance_valid(_energy_draw_label):
		_energy_draw_label.text = "耗电 -%.1f/s" % displayed_draw
	if is_instance_valid(_energy_draw_bar):
		_energy_draw_bar.max_value = rate_scale
		_energy_draw_bar.value = clampf(displayed_draw, 0.0, rate_scale)


func set_fuel_boost_status(fuel: float, fuel_max: float, active: bool, remaining: float, burn_rate: float, production_bonus: float) -> void:
	_set_status_meter(_night_fuel_bar, _night_fuel_label, "燃料", fuel, fuel_max)
	if active and is_instance_valid(_night_fuel_label) and fuel_max > 0.0:
		_night_fuel_label.text = "燃料 %.0f/%.0f -%.1f/s" % [
			clampf(fuel, 0.0, fuel_max),
			fuel_max,
			burn_rate,
		]
	if is_instance_valid(_fuel_boost_btn):
		_fuel_boost_btn.disabled = fuel <= 0.0
	if not is_instance_valid(_fuel_boost_label):
		return
	var max_text := "%.0f" % fuel_max if fuel_max > 0.0 else "--"
	if active:
		_fuel_boost_label.text = "燃料 %.0f/%s · 供能 %.0fs · +%.1f/s · 燃烧 %.1f/s" % [
			fuel,
			max_text,
			remaining,
			production_bonus,
			burn_rate,
		]
	else:
		_fuel_boost_label.text = "燃料 %.0f/%s · 应急供能待命" % [fuel, max_text]


func update_power_list(towers: Array) -> void:
	if not is_instance_valid(_power_list): return
	var seen := {}
	for t: Dictionary in towers:
		var tid := int(t.get("id", -1))
		seen[tid] = true
		if not _power_rows.has(tid): _add_power_row(tid)
		_update_power_row(tid, t)
	for tid: int in _power_rows.keys():
		if not seen.has(tid):
			if is_instance_valid(_power_rows[tid]["row"]): _power_rows[tid]["row"].queue_free()
			_power_rows.erase(tid)
	if is_instance_valid(_power_empty_label): _power_empty_label.visible = _power_rows.is_empty()


func clear_power_highlight() -> void:
	_clear_all_power_highlights()


func highlight_power_row(tower_id: int) -> void:
	highlight_power_rows([tower_id])


## 高亮多行（框选多塔时同时显示）。传入空数组则清除全部高亮。
func highlight_power_rows(tower_ids: Array[int]) -> void:
	_clear_all_power_highlights()
	for tid in tower_ids:
		var d: Dictionary = _power_rows.get(tid, {})
		if d.is_empty(): continue
		var panel: PanelContainer = d["panel"]
		panel.modulate = Color.WHITE

		var s := StyleBoxFlat.new()
		s.bg_color = Color(COLORS["amber"], 0.35)
		s.border_color = Color(COLORS["amber"])
		s.set_border_width_all(4); s.set_corner_radius_all(4)
		panel.add_theme_stylebox_override("panel", s)

		var tw := create_tween()
		tw.set_loops()
		tw.tween_property(s, "bg_color:a", 0.18, 0.35)
		tw.tween_property(s, "bg_color:a", 0.40, 0.35)
		_power_pulse_tweens.append(tw)
	_selected_power_tower_ids = tower_ids.duplicate()


func _clear_all_power_highlights() -> void:
	for tw in _power_pulse_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_power_pulse_tweens.clear()
	for tid in _selected_power_tower_ids:
		var prev: Dictionary = _power_rows.get(tid, {})
		if not prev.is_empty() and is_instance_valid(prev["panel"]):
			prev["panel"].remove_theme_stylebox_override("panel")
			prev["panel"].modulate = Color.WHITE
	_selected_power_tower_ids.clear()


func _add_power_row(tower_id: int) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			power_tower_selected.emit(tower_id))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)
	var nl := Label.new()
	nl.custom_minimum_size = Vector2(80, 0); nl.add_theme_font_size_override("font_size", 11)
	row.add_child(nl)
	var mb := Button.new()
	mb.text = "−"; mb.custom_minimum_size = Vector2(24, 0)
	mb.pressed.connect(func(): tower_power_step.emit(tower_id, -NightTdEnergy.POWER_STEP))
	row.add_child(mb)
	var vl := Label.new()
	vl.custom_minimum_size = Vector2(36, 0)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(vl)
	var pb := Button.new()
	pb.text = "+"; pb.custom_minimum_size = Vector2(24, 0)
	pb.pressed.connect(func(): tower_power_step.emit(tower_id, NightTdEnergy.POWER_STEP))
	row.add_child(pb)
	_power_list.add_child(panel)
	_power_rows[tower_id] = {"panel": panel, "row": row, "name": nl, "value": vl}


func _update_power_row(tower_id: int, data: Dictionary) -> void:
	var entry: Dictionary = _power_rows.get(tower_id, {})
	if entry.is_empty(): return
	entry["name"].text = str(data.get("name", "设施"))
	var lv := float(data.get("level", 1.0))
	var sc := float(data.get("scale", lv))
	var bars := int(round(lv / 0.5))
	var filled := ""
	for i in range(4): filled += "▮" if i < bars else "▯"
	entry["value"].text = "%s %.1fx" % [filled, sc]


func show_power_panel(visible_now: bool) -> void:
	if is_instance_valid(_power_panel): _power_panel.visible = visible_now
