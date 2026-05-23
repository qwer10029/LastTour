class_name NightTdWavePlan
extends RefCounted

## 明日方舟式关卡数据：路线、出生点、波次表（数量 / 移速 / 站场时间）
## 格子坐标用 "F8" 表示：列 1-9（→右），行 A-F（A=下，F=上）

const DEFAULT_PLAN_PATH := "res://data/night_td/waves/night_wave_demo.json"
## 站场时间上限（秒）；JSON 里写再大也会被压到这个值
const MAX_STANDBY_SEC := 5.0

var plan_name: String = ""
var spawn_points: Dictionary = {}  # id -> Array[String] 格子标签
var routes: Dictionary = {}  # id -> { label, waypoints: [{cell, standby}, ...] }
var waves: Array = []  # [{ id, trigger, entries: [...] }]


static func load_from_json(path: String) -> NightTdWavePlan:
	var plan := NightTdWavePlan.new()
	if path.is_empty() or not FileAccess.file_exists(path):
		push_warning("NightTdWavePlan: 找不到 %s，将使用内置默认" % path)
		plan._load_builtin_default()
		return plan
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("NightTdWavePlan: 无法读取 %s" % path)
		plan._load_builtin_default()
		return plan
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("NightTdWavePlan: JSON 格式错误 %s" % path)
		plan._load_builtin_default()
		return plan
	plan.import_dictionary(parsed)
	return plan


static func parse_cell_label(label: String) -> Vector2i:
	var text := str(label).strip_edges().to_upper()
	if text.is_empty():
		return Vector2i(-1, -1)
	var col := 0
	var row := 0
	var i := 0
	while i < text.length() and text[i] >= "A" and text[i] <= "Z":
		row = row * 26 + (text.unicode_at(i) - "A".unicode_at(0))
		i += 1
	var num_str := text.substr(i)
	if num_str.is_empty():
		return Vector2i(-1, -1)
	col = int(num_str) - 1
	return Vector2i(col, row)


static func cell_label(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0:
		return "?"
	var row_char := char(ord("A") + cell.y)
	return "%s%d" % [row_char, cell.x + 1]


func import_dictionary(data: Dictionary) -> void:
	plan_name = str(data.get("name", "未命名"))
	spawn_points = {}
	for key in data.get("spawn_points", {}).keys():
		var raw: Variant = data["spawn_points"][key]
		var labels: Array[String] = []
		if raw is Array:
			for item in raw:
				labels.append(str(item))
		else:
			labels.append(str(raw))
		spawn_points[str(key)] = labels
	routes = {}
	for route_id in data.get("routes", {}).keys():
		var block: Dictionary = data["routes"][route_id]
		var waypoints: Array = []
		for wp in block.get("waypoints", []):
			if wp is Dictionary:
				waypoints.append({
					"cell_label": str(wp.get("cell", "")),
					"standby_sec": _clamp_standby(float(wp.get("standby", wp.get("standby_sec", 0.0)))),
				})
		routes[str(route_id)] = {
			"label": str(block.get("label", route_id)),
			"waypoints": waypoints,
		}
	waves = []
	for wave_block in data.get("waves", []):
		if wave_block is Dictionary:
			waves.append(wave_block.duplicate(true))


func get_route_waypoints(route_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var block: Dictionary = routes.get(route_id, {})
	for wp in block.get("waypoints", []):
		if wp is Dictionary:
			var label := str(wp.get("cell_label", wp.get("cell", "")))
			var cell := parse_cell_label(label)
			if cell.x >= 0:
				result.append({
					"cell": cell,
					"standby_sec": float(wp.get("standby_sec", 0.0)),
				})
	return result


func pick_spawn_cell(route_id: String, spawn_point: String, field_cols: int, field_rows: int) -> Vector2i:
	if spawn_point != "":
		var direct := parse_cell_label(spawn_point)
		if direct.x >= 0:
			return _clamp_cell(direct, field_cols, field_rows)
	var labels: Array = spawn_points.get(spawn_point, [])
	if labels.size() > 0:
		var label := str(labels[0])
		var cell := parse_cell_label(label)
		if cell.x >= 0:
			return _clamp_cell(cell, field_cols, field_rows)
	var waypoints := get_route_waypoints(route_id)
	if not waypoints.is_empty():
		return _clamp_cell(waypoints[0]["cell"], field_cols, field_rows)
	return Vector2i(clampi(field_cols - 1, 0, field_cols - 1), 0)


func _clamp_cell(cell: Vector2i, cols: int, rows: int) -> Vector2i:
	return Vector2i(clampi(cell.x, 0, maxi(cols - 1, 0)), clampi(cell.y, 0, maxi(rows - 1, 0)))


static func _clamp_standby(sec: float) -> float:
	if sec <= 0.0:
		return 0.0
	return clampf(sec, 0.0, MAX_STANDBY_SEC)


func _load_builtin_default() -> void:
	plan_name = "builtin_default"
	spawn_points = {"sp_east": ["F8", "E9", "D8"]}
	routes = {
		"route_main": {
			"label": "东侧迂回",
			"waypoints": [
				{"cell_label": "F8", "standby_sec": 0.0},
				{"cell_label": "F5", "standby_sec": 0.0},
				{"cell_label": "D2", "standby_sec": 0.0},
				{"cell_label": "B2", "standby_sec": 0.0},
				{"cell_label": "B8", "standby_sec": 0.0},
			],
		},
	}
	waves = [{
		"id": 1,
		"entries": [
			{"enemy": "drone", "count": 5, "spawn_interval": 1.2, "move_speed": 58, "route_id": "route_main", "spawn_point": "F8"},
			{"enemy": "scout", "count": 2, "spawn_interval": 2.0, "pre_delay": 8.0, "move_speed": 42, "route_id": "route_main", "spawn_point": "D8"},
		],
	}]


func export_dictionary() -> Dictionary:
	return {
		"name": plan_name,
		"spawn_points": spawn_points,
		"routes": routes,
		"waves": waves,
	}


func save_to_json(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(export_dictionary(), "\t"))
	file.close()
	return true
