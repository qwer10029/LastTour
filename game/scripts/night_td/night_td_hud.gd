extends CanvasLayer

signal tower_selected(type_id: String)
signal start_wave_pressed
signal continue_pressed
signal tower_power_step(tower_id: int, delta_step: float)
signal power_tower_selected(tower_id: int)
signal overlay_toggled(state: bool)

@onready var top_bar: PanelContainer = $TopBar
@onready var side_panel: PanelContainer = $Sidebar
@onready var phase_label: Label = $TopBar/HBox/PhaseLabel
@onready var resource_label: Label = $TopBar/HBox/ResourceLabel
@onready var timer_label: Label = $TopBar/HBox/TimerLabel
@onready var start_btn: Button = $Sidebar/Margin/VBox/StartWaveBtn
@onready var event_log_vbox: VBoxContainer = $Sidebar/Margin/VBox/ScrollContainer/EventLog
@onready var event_scroll: ScrollContainer = $Sidebar/Margin/VBox/ScrollContainer
@onready var breach_label: Label = $BreachCounter
@onready var result_overlay: Control = $ResultOverlay
@onready var continue_btn: Button = %ContinueBtn
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_label: Label = %ResultLabel

var _tower_card_data := {
	"jammer":  {"icon": "⚡", "name": "干扰信标", "color": "#6ed08b"},
	"barrier": {"icon": "▣", "name": "物理路障", "color": "#9e8564"},
	"trap":    {"icon": "▲", "name": "电磁陷阱", "color": "#e87840"},
	"cryo_beacon": {"icon": "❄", "name": "低温信标", "color": "#83d8ff"},
	"hacker":  {"icon": "⌁", "name": "入侵天线", "color": "#5ac8e0"},
	"sniper":  {"icon": "◎", "name": "炮塔", "color": "#7aa6ff"},
	"splash":  {"icon": "❖", "name": "电弧塔",   "color": "#e0a23a"},
}

var _selected: String = "jammer"
var _continue_locked := false
var _breach_count := 0
var _tower_cards: Dictionary = {}
var _cards_vbox: VBoxContainer = null
var _overlay_btn: Button = null
var _overlay_active := false

# Tooltip
var _tooltip: PanelContainer = null
var _tooltip_label: Label = null
var _hover_timer: float = 0.0
var _hovered_card_type: String = ""
const HOVER_DELAY: float = 0.45

# Power
var _power_panel: VBoxContainer = null
var _energy_label: Label = null
var _power_list: VBoxContainer = null
var _power_empty_label: Label = null
var _power_rows: Dictionary = {}
var _selected_power_tower_ids: Array[int] = []   # 多选支持：框选多塔时同时高亮多行
var _power_pulse_tweens: Array[Tween] = []        # 多选时每个高亮行各一个脉冲动画

const COLORS := {
	"bg": "#0b1018", "panel": "#141c28", "border": "#2a3a4f",
	"title": "#d8e4f0", "subtitle": "#8fa3b8", "accent": "#6ed08b",
	"danger": "#e87840", "hack": "#5ac8e0", "amber": "#f0a040",
}


func _ready() -> void:
	hide_session_ui()
	_build_tooltip()
	_build_cards_in_sidebar()
	if is_instance_valid(start_btn):
		start_btn.pressed.connect(func(): start_wave_pressed.emit())
	if is_instance_valid(continue_btn):
		continue_btn.pressed.connect(_on_continue_pressed)
	_build_power_panel()
	_build_overlay_button()
	if is_instance_valid(breach_label): breach_label.visible = false
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
	if is_instance_valid(top_bar): top_bar.show()
	if is_instance_valid(side_panel): side_panel.show()
	if is_instance_valid(breach_label):
		breach_label.visible = false
		breach_label.text = "⚠ 突破: 0"
	clear_log()
	hide_result_dialog()
	if is_instance_valid(_overlay_btn): _overlay_btn.show()


func hide_session_ui() -> void:
	hide_result_dialog()
	if is_instance_valid(top_bar): top_bar.hide()
	if is_instance_valid(side_panel): side_panel.hide()
	if is_instance_valid(breach_label): breach_label.visible = false
	if is_instance_valid(_overlay_btn): _overlay_btn.hide()
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


# -- Overlay Toggle Button ------------------------------------------

func _build_overlay_button() -> void:
	_overlay_btn = Button.new()
	_overlay_btn.name = "OverlayBtn"
	_overlay_btn.text = "📊 热力图: 关"
	_overlay_btn.flat = true
	_overlay_btn.add_theme_font_size_override("font_size", 11)
	_overlay_btn.custom_minimum_size = Vector2(120, 28)

	var s := StyleBoxFlat.new()
	s.bg_color = Color(COLORS["panel"])
	s.border_color = Color(COLORS["border"])
	s.set_border_width_all(1); s.set_corner_radius_all(4)
	_overlay_btn.add_theme_stylebox_override("normal", s)

	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(COLORS["accent"], 0.2)
	sh.border_color = Color(COLORS["accent"])
	sh.set_border_width_all(1); sh.set_corner_radius_all(4)
	_overlay_btn.add_theme_stylebox_override("hover", sh)

	_overlay_btn.pressed.connect(_on_overlay_btn_pressed)

	# Position: inside top bar, next to the timer/phase labels
	if is_instance_valid(top_bar):
		var hbox := top_bar.get_node_or_null("HBox")
		if hbox != null:
			hbox.add_child(_overlay_btn)
		else:
			add_child(_overlay_btn)
			_overlay_btn.position = Vector2(300, 10)
	else:
		add_child(_overlay_btn)
		_overlay_btn.position = Vector2(300, 10)

	_overlay_btn.show()


func _on_overlay_btn_pressed() -> void:
	_overlay_active = not _overlay_active
	_refresh_overlay_btn_text()
	overlay_toggled.emit(_overlay_active)


func _refresh_overlay_btn_text() -> void:
	if is_instance_valid(_overlay_btn):
		if _overlay_active:
			_overlay_btn.text = "📊 热力图: 开"
			var s := StyleBoxFlat.new()
			s.bg_color = Color(COLORS["accent"], 0.18)
			s.border_color = Color(COLORS["accent"])
			s.set_border_width_all(2); s.set_corner_radius_all(4)
			_overlay_btn.add_theme_stylebox_override("normal", s)
		else:
			_overlay_btn.text = "📊 热力图: 关"
			var s := StyleBoxFlat.new()
			s.bg_color = Color(COLORS["panel"])
			s.border_color = Color(COLORS["border"])
			s.set_border_width_all(1); s.set_corner_radius_all(4)
			_overlay_btn.add_theme_stylebox_override("normal", s)


# -- Phase --------------------------------------------------------

func set_phase_text(text: String) -> void:
	if is_instance_valid(phase_label): phase_label.text = text

func set_resources(remaining: int, spent: int) -> void:
	if is_instance_valid(resource_label):
		resource_label.text = "部署点: %d (已用 %d)" % [remaining, spent]

func set_resource_text(text: String) -> void:
	if is_instance_valid(resource_label): resource_label.text = text

func set_placement_timer(sec: float) -> void:
	if is_instance_valid(timer_label): timer_label.text = "布防 %.0fs" % maxf(sec, 0.0)

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

func clear_log() -> void:
	if is_instance_valid(event_log_vbox):
		for child in event_log_vbox.get_children():
			child.queue_free()

func _scroll_to_bottom() -> void:
	if is_instance_valid(event_scroll):
		event_scroll.scroll_vertical = int(event_scroll.get_v_scroll_bar().max_value)


func append_log(line: String, text_color: Color = Color(COLORS["subtitle"])) -> void:
	if not is_instance_valid(event_log_vbox): return
	var entry := Label.new()
	entry.text = line
	entry.add_theme_font_size_override("font_size", 10)
	entry.add_theme_color_override("font_color", text_color)
	entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_log_vbox.add_child(entry)
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
	if is_instance_valid(_overlay_btn): _overlay_btn.show()


func set_combat_mode() -> void:
	if is_instance_valid(start_btn): start_btn.hide()
	hide_result_dialog()
	if is_instance_valid(_cards_vbox): _cards_vbox.visible = false
	_update_card_states(false)
	show_power_panel(true)
	if is_instance_valid(_overlay_btn): _overlay_btn.show()


func _update_card_states(enabled: bool) -> void:
	for tid in _tower_cards.keys():
		var card: PanelContainer = _tower_cards[tid]["panel"]
		card.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		card.modulate = Color(1,1,1,1) if enabled else Color(1,1,1,0.4)


# -- Result Screen ------------------------------------------------

func show_result(text: String) -> void:
	_continue_locked = false
	if is_instance_valid(result_label): result_label.text = text
	if is_instance_valid(continue_btn): continue_btn.disabled = false
	if is_instance_valid(result_overlay):
		result_overlay.show(); result_overlay.visible = true
	if is_instance_valid(start_btn): start_btn.hide()
	if is_instance_valid(_cards_vbox): _cards_vbox.visible = false


# -- Power Panel ---------------------------------------------------

func _build_power_panel() -> void:
	_power_panel = VBoxContainer.new()
	_power_panel.name = "PowerPanel"
	_power_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_power_panel.offset_left = 12.0
	_power_panel.offset_top = 96.0
	_power_panel.custom_minimum_size = Vector2(200, 0)
	_power_panel.add_theme_constant_override("separation", 3)
	_power_panel.visible = false
	_power_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_power_panel)

	var title := Label.new()
	title.text = "⚡ 电力调度"
	title.add_theme_color_override("font_color", Color(COLORS["title"]))
	_power_panel.add_child(title)

	_energy_label = Label.new()
	_energy_label.text = "反应堆: --"
	_energy_label.add_theme_color_override("font_color", Color(COLORS["subtitle"]))
	_power_panel.add_child(_energy_label)

	_power_list = VBoxContainer.new()
	_power_list.add_theme_constant_override("separation", 2)
	_power_panel.add_child(_power_list)

	_power_empty_label = Label.new()
	_power_empty_label.text = "（暂无耗电设施）"
	_power_empty_label.add_theme_color_override("font_color", Color(COLORS["subtitle"]))
	_power_panel.add_child(_power_empty_label)


func set_energy_status(current: float, capacity: float, demand: float) -> void:
	if is_instance_valid(_energy_label):
		_energy_label.text = "反应堆: %.0f/%.0f  耗能 %.1f/s" % [current, capacity, demand]


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
