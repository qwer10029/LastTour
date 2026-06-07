extends Control

@onready var phase_label: Label = %PhaseLabel
@onready var day_label: Label = %DayLabel
@onready var layer_label: Label = %LayerLabel
@onready var timer_label: Label = %TimerLabel
@onready var progress_bar: ProgressBar = %DayProgressBar
@onready var _vbox: VBoxContainer = $VBox

var _time_system: TimeSystem
var _layer_current := 1
var _layer_total := 1


func set_layer(current: int, total: int) -> void:
	_layer_current = maxi(current, 1)
	_layer_total = maxi(total, 1)
	_update_layer_label()


func _update_layer_label() -> void:
	if is_instance_valid(layer_label):
		layer_label.text = "第 %d / %d 层" % [_layer_current, _layer_total]


func _ready() -> void:
	if is_instance_valid(_vbox):
		_vbox.add_theme_constant_override("separation", 1)
		_vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	for lbl in [phase_label, day_label, layer_label, timer_label]:
		if is_instance_valid(lbl):
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.set_meta("hud_compact", true)
			HudTheme.apply_compact_label(lbl)
			lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if is_instance_valid(progress_bar):
		HudTheme.apply_slim_progress_bar(progress_bar, Color("#52a872"))
		progress_bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func bind_time_system(time_system: TimeSystem) -> void:
	if _time_system != null:
		if _time_system.phase_changed.is_connected(_on_phase_changed):
			_time_system.phase_changed.disconnect(_on_phase_changed)
	_time_system = time_system
	if _time_system == null:
		return
	_time_system.phase_changed.connect(_on_phase_changed)
	_on_phase_changed(_time_system.phase, _time_system.phase)
	_refresh()


func _process(_delta: float) -> void:
	if _time_system != null:
		_refresh()


func _on_phase_changed(_old_phase: int, _new_phase: int) -> void:
	_refresh()


func _refresh() -> void:
	if _time_system == null:
		return
	if is_instance_valid(phase_label):
		phase_label.text = "时段: %s" % _time_system.get_phase_name()
	if is_instance_valid(day_label):
		day_label.text = "第 %d 天" % _time_system.day_index
	if is_instance_valid(timer_label):
		var remaining := _time_system.get_day_remaining_sec()
		if _time_system.phase == TimeSystem.Phase.NIGHT_SETUP:
			timer_label.text = "请完成布防"
		elif _time_system.phase == TimeSystem.Phase.NIGHT_RESOLVE:
			timer_label.text = "结算中…"
		else:
			timer_label.text = "剩余 %.0f 秒" % remaining
	if is_instance_valid(progress_bar):
		progress_bar.value = _time_system.get_day_progress() * 100.0
		match _time_system.phase:
			TimeSystem.Phase.EVENING:
				progress_bar.modulate = Color("#f0a040")
			TimeSystem.Phase.DAY:
				progress_bar.modulate = Color("#6ed08b")
			_:
				progress_bar.modulate = Color("#7da0be")
