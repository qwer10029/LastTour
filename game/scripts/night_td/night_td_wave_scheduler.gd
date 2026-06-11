class_name NightTdWaveScheduler
extends RefCounted

## 把 NightTdWavePlan 展开为按时间触发的刷怪队列（类似明日方舟波次表）

var total_spawn_events: int = 0
var spawned_count: int = 0
var elapsed_sec: float = 0.0

var _events: Array[Dictionary] = []  # 按 spawn_at 升序
var _next_index: int = 0


func build_from_plan(plan: NightTdWavePlan, difficulty: int = 1, day_index: int = 1) -> void:
	_events.clear()
	_next_index = 0
	spawned_count = 0
	elapsed_sec = 0.0
	if plan == null:
		total_spawn_events = 0
		return
	for wave_block in plan.waves:
		if wave_block is Dictionary:
			var wave_offset := float(wave_block.get("wave_delay", 0.0))
			if wave_offset <= 0.0:
				wave_offset = float(maxi(int(wave_block.get("id", 1)) - 1, 0)) * 20.0
			_append_wave_entries(wave_block, wave_offset, difficulty, day_index)
	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("spawn_at", 0.0)) < float(b.get("spawn_at", 0.0))
	)
	total_spawn_events = _events.size()


func build_legacy_queue(type_queue: Array[String]) -> void:
	_events.clear()
	_next_index = 0
	spawned_count = 0
	elapsed_sec = 0.0
	var t := 0.0
	for type_id in type_queue:
		_events.append({
			"spawn_at": t,
			"enemy": type_id,
			"move_speed": -1.0,
			"route_id": "",
			"spawn_point": "",
		})
		t += 1.2
	total_spawn_events = _events.size()


func tick(delta: float) -> Array[Dictionary]:
	elapsed_sec += delta
	var ready: Array[Dictionary] = []
	while _next_index < _events.size():
		var event: Dictionary = _events[_next_index]
		if float(event.get("spawn_at", 0.0)) > elapsed_sec:
			break
		ready.append(event.duplicate(true))
		_next_index += 1
		spawned_count += 1
	return ready


func remaining_count() -> int:
	return maxi(_events.size() - _next_index, 0)


func is_finished(spawned_on_field: int) -> bool:
	return remaining_count() == 0 and spawned_on_field <= 0 and spawned_count > 0


func _append_wave_entries(wave_block: Dictionary, base_time: float, difficulty: int, day_index: int) -> void:
	var entries: Array = wave_block.get("entries", [])
	var entry_index := 0
	for raw_entry in entries:
		if raw_entry is Dictionary:
			_append_single_entry(raw_entry, base_time, entry_index, difficulty, day_index)
			entry_index += 1


func _append_single_entry(
	entry: Dictionary,
	base_time: float,
	entry_index: int,
	difficulty: int,
	day_index: int,
) -> void:
	var enemy := str(entry.get("enemy", "drone"))
	var count := maxi(int(entry.get("count", 1)), 1)
	var interval := maxf(float(entry.get("spawn_interval", 1.0)), 0.05)
	var pre_delay := maxf(float(entry.get("pre_delay", 0.0)), 0.0)
	var move_speed := float(entry.get("move_speed", -1.0))
	var spawn_side := str(entry.get("spawn_side", ""))   # 限制出生方向（空=四面随机）
	var day_bonus := maxi((day_index - 1) / 2, 0)
	if bool(entry.get("scale_with_day", true)):
		count += day_bonus
	match difficulty:
		0:
			count = maxi(count - 1, 1)
		1:
			pass
		2:
			count += 2
			if move_speed > 0.0:
				move_speed *= 1.1
	var group_start := base_time + pre_delay + float(entry_index) * 0.01
	for i in range(count):
		_events.append({
			"spawn_at": group_start + float(i) * interval,
			"enemy": enemy,
			"move_speed": move_speed,
			"spawn_side": spawn_side,
			"wave_id": int(entry.get("wave_id", 0)),
		})
