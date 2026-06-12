extends Node
class_name TimeSystem

## 昼夜计时与阶段切换。仅负责时间与阶段，不处理探索或布防逻辑。
## 并行开发：队友 A 接 day_started / evening_warning；队友 B 接 night_setup_started / night_resolved。

signal phase_changed(old_phase: int, new_phase: int)
signal evening_warning_triggered(remaining_sec: float)
signal day_started(day_index: int)
signal night_setup_started(day_index: int, manual_setup: bool)
signal night_resolved(day_index: int)

enum Phase { DAY, EVENING, NIGHT_SETUP, NIGHT_RESOLVE }

const PHASE_NAMES := {
	Phase.DAY: "白天",
	Phase.EVENING: "傍晚",
	Phase.NIGHT_SETUP: "夜晚·塔防",
	Phase.NIGHT_RESOLVE: "夜晚·结算",
}

@export var day_duration_sec: float = 30.0
@export var evening_warning_sec: float = 8.0
@export var night_resolve_display_sec: float = 1.5
@export var auto_start: bool = true

var phase: int = Phase.DAY
var day_index: int = 1
var elapsed_in_phase: float = 0.0
var _evening_warning_sent := false
var _paused := false


func _ready() -> void:
	if auto_start:
		start_day(1)


func _process(delta: float) -> void:
	if _paused:
		return
	match phase:
		Phase.DAY:
			_tick_day(delta)
		Phase.EVENING:
			_tick_evening(delta)
		Phase.NIGHT_RESOLVE:
			_tick_night_resolve(delta)


func get_phase_name(value: int = -1) -> String:
	if value < 0:
		value = phase
	return PHASE_NAMES.get(value, "未知")


func is_daytime() -> bool:
	return phase == Phase.DAY or phase == Phase.EVENING


func is_exploration_allowed() -> bool:
	return phase == Phase.DAY or phase == Phase.EVENING


func can_manual_enter_defense() -> bool:
	return phase == Phase.EVENING or (phase == Phase.DAY and _evening_warning_sent)


func get_day_remaining_sec() -> float:
	if phase == Phase.DAY:
		return maxf(day_duration_sec - elapsed_in_phase, 0.0)
	if phase == Phase.EVENING:
		return maxf(evening_warning_sec - elapsed_in_phase, 0.0)
	return 0.0


func get_day_progress() -> float:
	if day_duration_sec <= 0.0:
		return 0.0
	if phase == Phase.DAY:
		return clampf(elapsed_in_phase / day_duration_sec, 0.0, 1.0)
	if phase == Phase.EVENING:
		return 1.0
	return 0.0


func pause() -> void:
	_paused = true


func resume() -> void:
	_paused = false


func is_paused() -> bool:
	return _paused


func to_dictionary() -> Dictionary:
	return {
		"phase": phase,
		"day_index": day_index,
		"elapsed_in_phase": elapsed_in_phase,
		"evening_warning_sent": _evening_warning_sent,
	}


func load_from_dictionary(data: Dictionary) -> void:
	phase = int(data.get("phase", Phase.DAY))
	day_index = maxi(int(data.get("day_index", 1)), 1)
	elapsed_in_phase = maxf(float(data.get("elapsed_in_phase", 0.0)), 0.0)
	_evening_warning_sent = bool(data.get("evening_warning_sent", false))
	_paused = false


func start_day(index: int = -1) -> void:
	if index > 0:
		day_index = index
	_set_phase(Phase.DAY)
	elapsed_in_phase = 0.0
	_evening_warning_sent = false
	day_started.emit(day_index)


func begin_evening_phase() -> void:
	if phase == Phase.EVENING:
		return
	_evening_warning_sent = true
	_enter_evening()


func enter_night_setup(manual_setup: bool = false) -> void:
	_set_phase(Phase.NIGHT_SETUP)
	elapsed_in_phase = 0.0
	night_setup_started.emit(day_index, manual_setup)


func begin_night_resolve() -> void:
	_paused = false
	_set_phase(Phase.NIGHT_RESOLVE)
	elapsed_in_phase = 0.0


func finish_night_and_advance_day() -> void:
	_paused = false
	night_resolved.emit(day_index)
	day_index += 1
	start_day(day_index)


func _tick_day(delta: float) -> void:
	elapsed_in_phase += delta
	var remaining := day_duration_sec - elapsed_in_phase
	if not _evening_warning_sent and remaining <= evening_warning_sec:
		_evening_warning_sent = true
		evening_warning_triggered.emit(remaining)
		_enter_evening()
	elif elapsed_in_phase >= day_duration_sec:
			enter_night_setup(false)


func _tick_evening(delta: float) -> void:
	elapsed_in_phase += delta
	if elapsed_in_phase >= evening_warning_sec:
		enter_night_setup(false)


func _tick_night_resolve(delta: float) -> void:
	elapsed_in_phase += delta
	if elapsed_in_phase >= night_resolve_display_sec:
		finish_night_and_advance_day()


func _enter_evening() -> void:
	_set_phase(Phase.EVENING)
	elapsed_in_phase = 0.0


func _set_phase(new_phase: int) -> void:
	if phase == new_phase:
		return
	var old := phase
	phase = new_phase
	phase_changed.emit(old, new_phase)
