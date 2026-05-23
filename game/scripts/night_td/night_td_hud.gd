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


func _ready() -> void:
	hide_session_ui()
	if is_instance_valid(jammer_btn):
		jammer_btn.pressed.connect(func(): _select("jammer"))
	if is_instance_valid(barrier_btn):
		barrier_btn.pressed.connect(func(): _select("barrier"))
	if is_instance_valid(trap_btn):
		trap_btn.pressed.connect(func(): _select("trap"))
	if is_instance_valid(start_btn):
		start_btn.pressed.connect(func(): start_wave_pressed.emit())
	if is_instance_valid(continue_btn):
		continue_btn.pressed.connect(_on_continue_pressed)
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
	]:
		var btn: Button = btn_data[0]
		var id: String = btn_data[1]
		if not is_instance_valid(btn):
			continue
		btn.text = NightTdDefs.get_tower_button_text(id, id == _selected)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
