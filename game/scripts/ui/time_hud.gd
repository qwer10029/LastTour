extends Control

@onready var phase_label: Label = %PhaseLabel
@onready var day_label: Label = %DayLabel
@onready var timer_label: Label = %TimerLabel
@onready var progress_bar: ProgressBar = %DayProgressBar

var _time_system: TimeSystem


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
