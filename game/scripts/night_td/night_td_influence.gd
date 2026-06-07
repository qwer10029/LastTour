class_name NightTdInfluence
extends RefCounted

## 威胁影响图（P2）：把每座攻击塔的"火力危险"铺成一张网格标量场。
## 流场（NightTdFlowField）用 danger_weight × value(cell) 作为额外进入代价，
## 于是"绕开炮塔射程"和寻路在同一遍 Dijkstra 里完成 —— 高难度敌人会主动避开杀伤区。
##
## 威胁模型：每格威胁 = Σ_towers  dps × falloff(dist/range) ，仅统计射程能覆盖该格的塔。
## dps = damage / fire_interval，再乘以当前供电系数（P4 会传入 power_scale）。

var cols: int = 0
var rows: int = 0
var _threat: PackedFloat32Array = PackedFloat32Array()
var _max_threat: float = 0.0


func _index(x: int, y: int) -> int:
	return y * cols + x


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows


func value(cell: Vector2i) -> float:
	if not is_inside(cell):
		return 0.0
	return _threat[_index(cell.x, cell.y)]


func max_threat() -> float:
	return _max_threat


func get_threat_array() -> PackedFloat32Array:
	return _threat


## 从另一 Influence 浅拷贝威胁数据（供热力图快照复用）。
func copy_from(other: NightTdInfluence) -> void:
	cols = other.cols
	rows = other.rows
	_threat = other._threat
	_max_threat = other._max_threat


func total_threat() -> float:
	var t := 0.0
	for v in _threat:
		t += v
	return t


## 重建威胁场。
##   grid_cols/grid_rows：网格尺寸
##   tower_threats：Array[Dictionary]，每项 { "cell": Vector2i, "range_cells": float, "dps": float }
##     range_cells 已换算为"格"为单位的射程；dps 已含供电系数。
func rebuild(grid_cols: int, grid_rows: int, tower_threats: Array) -> void:
	cols = maxi(grid_cols, 0)
	rows = maxi(grid_rows, 0)
	var n := cols * rows
	_threat = PackedFloat32Array()
	_threat.resize(n)
	_max_threat = 0.0
	if n == 0:
		return
	for entry in tower_threats:
		if not (entry is Dictionary):
			continue
		var cell: Vector2i = entry.get("cell", Vector2i(-1, -1))
		var range_cells := float(entry.get("range_cells", 0.0))
		var dps := float(entry.get("dps", 0.0))
		if dps <= 0.0 or range_cells <= 0.0 or not is_inside(cell):
			continue
		_stamp_tower(cell, range_cells, dps)
	for v in _threat:
		if v > _max_threat:
			_max_threat = v


## 把单座塔的威胁按线性衰减盖到射程内的格子上。
func _stamp_tower(center: Vector2i, range_cells: float, dps: float) -> void:
	var r := int(ceil(range_cells))
	var x0 := maxi(center.x - r, 0)
	var x1 := mini(center.x + r, cols - 1)
	var y0 := maxi(center.y - r, 0)
	var y1 := mini(center.y + r, rows - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := float(x - center.x)
			var dy := float(y - center.y)
			var dist := sqrt(dx * dx + dy * dy)
			if dist > range_cells:
				continue
			# 线性衰减：塔心处满威胁，射程边缘趋近 0（保留少量底值以示"边缘也危险"）。
			var falloff := 1.0 - (dist / range_cells) * 0.85
			_threat[_index(x, y)] += dps * falloff


## 生成供流场使用的 extra_cost 数组：danger_weight × 每格威胁。
## danger_weight=0（简单）时返回全 0 → 敌人无视火力（P1 行为）。
func to_extra_cost(danger_weight: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := cols * rows
	out.resize(n)
	if danger_weight <= 0.0:
		return out
	for i in range(n):
		out[i] = _threat[i] * danger_weight
	return out
