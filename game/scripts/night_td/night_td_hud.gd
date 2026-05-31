extends CanvasLayer

signal tower_selected(type_id: String)
signal start_wave_pressed
signal continue_pressed

@onready var top_bar: PanelContainer = $TopBar
@onready var side_panel: PanelContainer = $SidePanel
@onready var phase_label: Label = %PhaseLabel
@onready var resource_label: Label = %ResourceLabel
@onready var timer_label: Label = %TimerLabel
@onready var hint_label: Label = %HintLabel
@onready var log_label: Label = %LogLabel
@onready var jammer_btn: Button = %JammerBtn
@onready var barrier_btn: Button = %BarrierBtn
@onready var trap_btn: Button = %TrapBtn
@onready var start_btn: Button = %StartWaveBtn
@onready var result_overlay: Control = %ResultOverlay
@onready var continue_btn: Button = %ContinueBtn
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_label: Label = %ResultLabel

var _selected: String = "jammer"
var _continue_locked: bool = false
var _hacker_btn: Button = null   # P5：入侵天线建造按钮（代码创建）

# P4.3 战斗功率面板（运行时构建，不改 .tscn）：每座耗电塔一行，含功率条 + 增减按钮。
signal tower_power_step(tower_id: int, delta_step: float)   # 列表内某塔的功率增减
var _power_panel: PanelContainer = null
var _energy_label: Label = null
var _power_list: VBoxContainer = null
var _power_empty_label: Label = null
var _power_rows: Dictionary = {}   # tower_id -> { row, name_label, bar, value_label }


func _ready() -> void:
	hide_session_ui()
	if is_instance_valid(jammer_btn):
		jammer_btn.pressed.connect(func(): _select("jammer"))
	if is_instance_valid(barrier_btn):
		barrier_btn.pressed.connect(func(): _select("barrier"))
	if is_instance_valid(trap_btn):
		trap_btn.pressed.connect(func(): _select("trap"))
	_build_hacker_button()
	if is_instance_valid(start_btn):
		start_btn.pressed.connect(func(): start_wave_pressed.emit())
	if is_instance_valid(continue_btn):
		continue_btn.pressed.connect(_on_continue_pressed)
	_build_power_panel()
	_select("jammer")


func show_session_ui() -> void:
	show()
	_continue_locked = false
	if is_instance_valid(top_bar):
		top_bar.show()
	if is_instance_valid(side_panel):
		side_panel.show()
	hide_result_dialog()


func hide_session_ui() -> void:
	hide_result_dialog()
	if is_instance_valid(top_bar):
		top_bar.hide()
	if is_instance_valid(side_panel):
		side_panel.hide()
	hide()


func hide_result_dialog() -> void:
	_continue_locked = true
	if is_instance_valid(result_overlay):
		result_overlay.hide()
		result_overlay.visible = false
	if is_instance_valid(continue_btn):
		continue_btn.disabled = true


func _on_continue_pressed() -> void:
	if _continue_locked:
		return
	_continue_locked = true
	if is_instance_valid(continue_btn):
		continue_btn.disabled = true
	hide_result_dialog()
	continue_pressed.emit()


func _select(type_id: String) -> void:
	_selected = type_id
	tower_selected.emit(type_id)
	refresh_tool_buttons()


func get_selected_tower() -> String:
	return _selected


func set_phase_text(text: String) -> void:
	if is_instance_valid(phase_label):
		phase_label.text = text


func set_resources(remaining: int, spent: int) -> void:
	if is_instance_valid(resource_label):
		resource_label.text = "布防部署点: %d（已用 %d）" % [remaining, spent]


## 直接设置资源行文本（P6 真实背包模式：显示零件/废料数量）。
func set_resource_text(text: String) -> void:
	if is_instance_valid(resource_label):
		resource_label.text = text


func set_placement_timer(sec: float) -> void:
	if is_instance_valid(timer_label):
		timer_label.text = "布防剩余 %.0f 秒（时间到将自动接敌）" % maxf(sec, 0.0)


func set_combat_status(text: String) -> void:
	if is_instance_valid(timer_label):
		timer_label.text = text


func set_hint(text: String) -> void:
	if is_instance_valid(hint_label):
		hint_label.text = text + "\n右键可撤销已放置防御"


func clear_log() -> void:
	if is_instance_valid(log_label):
		log_label.text = ""


func append_log(line: String) -> void:
	if not is_instance_valid(log_label):
		return
	var lines: PackedStringArray = PackedStringArray()
	if log_label.text != "":
		lines = log_label.text.split("\n")
	lines.append(line)
	while lines.size() > 6:
		lines.remove_at(0)
	log_label.text = "\n".join(lines)


func set_place_mode(active: bool) -> void:
	if is_instance_valid(start_btn):
		start_btn.visible = active
	hide_result_dialog()
	if is_instance_valid(jammer_btn):
		jammer_btn.disabled = not active
	if is_instance_valid(barrier_btn):
		barrier_btn.disabled = not active
	if is_instance_valid(trap_btn):
		trap_btn.disabled = not active
	if is_instance_valid(_hacker_btn):
		_hacker_btn.disabled = not active
	show_power_panel(false)


func set_combat_mode() -> void:
	if is_instance_valid(start_btn):
		start_btn.visible = false
	hide_result_dialog()
	if is_instance_valid(jammer_btn):
		jammer_btn.disabled = true
	if is_instance_valid(barrier_btn):
		barrier_btn.disabled = true
	if is_instance_valid(trap_btn):
		trap_btn.disabled = true
	if is_instance_valid(_hacker_btn):
		_hacker_btn.disabled = true
	show_power_panel(true)


func show_result(text: String) -> void:
	_continue_locked = false
	if is_instance_valid(result_label):
		result_label.text = text
	if is_instance_valid(continue_btn):
		continue_btn.disabled = false
	if is_instance_valid(result_overlay):
		result_overlay.show()
		result_overlay.visible = true
	if is_instance_valid(jammer_btn):
		jammer_btn.disabled = true
	if is_instance_valid(barrier_btn):
		barrier_btn.disabled = true
	if is_instance_valid(trap_btn):
		trap_btn.disabled = true
	if is_instance_valid(start_btn):
		start_btn.visible = false


func refresh_tool_buttons() -> void:
	for btn_data in [
		[jammer_btn, "jammer"],
		[barrier_btn, "barrier"],
		[trap_btn, "trap"],
		[_hacker_btn, "hacker"],
	]:
		var btn: Button = btn_data[0]
		var id: String = btn_data[1]
		if not is_instance_valid(btn):
			continue
		btn.text = NightTdDefs.get_tower_button_text(id, id == _selected)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


# --- P4.3 战斗功率面板（代码构建，挂在 SidePanel 下方）---

func _build_hacker_button() -> void:
	if not is_instance_valid(trap_btn):
		return
	_hacker_btn = Button.new()
	_hacker_btn.name = "HackerBtn"
	_hacker_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hacker_btn.pressed.connect(func(): _select("hacker"))
	# 插到陷阱按钮后面
	var parent := trap_btn.get_parent()
	if parent != null:
		parent.add_child(_hacker_btn)
		parent.move_child(_hacker_btn, trap_btn.get_index() + 1)


func _build_power_panel() -> void:
	if not is_instance_valid(side_panel):
		return
	var vbox := side_panel.get_node_or_null("Margin/VBox")
	if vbox == null:
		return
	# 独立面板，锚定在屏幕左侧空白区（不挤占右侧已塞满的布防面板）。
	_power_panel = PanelContainer.new()
	_power_panel.name = "PowerPanel"
	_power_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_power_panel.offset_left = 16.0
	_power_panel.offset_top = 130.0
	_power_panel.custom_minimum_size = Vector2(240, 0)
	_power_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_power_panel.add_child(margin)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 3)
	margin.add_child(inner)

	var title := Label.new()
	title.text = "⚡ 电力调度"
	inner.add_child(title)

	_energy_label = Label.new()
	_energy_label.text = "反应堆: --"
	inner.add_child(_energy_label)

	var hint := Label.new()
	hint.text = "每座耗电设施单独供电（功率↑伤害/射速↑）："
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(hint)

	_power_list = VBoxContainer.new()
	_power_list.add_theme_constant_override("separation", 2)
	inner.add_child(_power_list)

	_power_empty_label = Label.new()
	_power_empty_label.text = "（暂无耗电设施。建造干扰信标/入侵天线后在此调度电力。）"
	_power_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_power_empty_label)

	hud_root_for_power().add_child(_power_panel)
	_power_panel.visible = false


## 功率面板挂载点：优先挂到 CanvasLayer 自身，保证浮在最上层、不受布防面板布局影响。
func hud_root_for_power() -> Node:
	return self


## 刷新反应堆电量显示。
func set_energy_status(current: float, capacity: float, demand: float) -> void:
	if is_instance_valid(_energy_label):
		_energy_label.text = "反应堆: %.0f/%.0f  耗能 %.1f/s" % [current, capacity, demand]


## 用当前耗电塔列表重建/更新功率行。towers: Array[{id:int, name:String, level:float, scale:float}]
func update_power_list(towers: Array) -> void:
	if not is_instance_valid(_power_list):
		return
	var seen := {}
	for t: Dictionary in towers:
		var tid := int(t.get("id", -1))
		seen[tid] = true
		if not _power_rows.has(tid):
			_add_power_row(tid)
		_update_power_row(tid, t)
	# 移除已不存在的塔行
	for tid: int in _power_rows.keys():
		if not seen.has(tid):
			var row: Control = _power_rows[tid]["row"]
			if is_instance_valid(row):
				row.queue_free()
			_power_rows.erase(tid)
	if is_instance_valid(_power_empty_label):
		_power_empty_label.visible = _power_rows.is_empty()


func _add_power_row(tower_id: int) -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(96, 0)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(name_label)
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(28, 0)
	minus.pressed.connect(func(): tower_power_step.emit(tower_id, -NightTdEnergy.POWER_STEP))
	row.add_child(minus)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(40, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(28, 0)
	plus.pressed.connect(func(): tower_power_step.emit(tower_id, NightTdEnergy.POWER_STEP))
	row.add_child(plus)
	_power_list.add_child(row)
	_power_rows[tower_id] = {"row": row, "name": name_label, "value": value_label}


func _update_power_row(tower_id: int, data: Dictionary) -> void:
	var entry: Dictionary = _power_rows.get(tower_id, {})
	if entry.is_empty():
		return
	var name_label: Label = entry["name"]
	var value_label: Label = entry["value"]
	name_label.text = str(data.get("name", "设施"))
	var level := float(data.get("level", 1.0))
	var scale := float(data.get("scale", level))
	# 用方块条直观显示功率档（0 / 0.5 / 1.0 / 1.5 / 2.0）。
	var bars := int(round(level / 0.5))
	var filled := ""
	for i in range(4):
		filled += "▮" if i < bars else "▯"
	value_label.text = "%s %.1fx" % [filled, scale]


func show_power_panel(visible_now: bool) -> void:
	if is_instance_valid(_power_panel):
		_power_panel.visible = visible_now
