class_name NightTdFlowField
extends RefCounted

## 流场寻路：对整张网格做一次带权 Dijkstra 积分场，所有单位 O(1) 采样梯度方向。
## 多对一（众多敌人 → 基地）场景下比逐单位 A* 便宜，且威胁规避与寻路在同一遍完成：
## 进入某格的代价 = 1.0 + danger（P2 把 危险权重×影响 填入 extra_cost）。

const INF := 1.0e20
const SQRT2 := 1.4142135623730951

const _NEIGHBORS := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

var cols: int = 0
var rows: int = 0
var integration: PackedFloat32Array = PackedFloat32Array()  # 每格到最近目标的加权距离；INF=不可达
var _dir: PackedVector2Array = PackedVector2Array()         # 每格梯度方向（朝向目标），已归一化
var _blocked: PackedByteArray = PackedByteArray()           # 1=不可通行


func _index(x: int, y: int) -> int:
	return y * cols + x


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows


func sample_dir(cell: Vector2i) -> Vector2:
	if not is_inside(cell):
		return Vector2.ZERO
	return _dir[_index(cell.x, cell.y)]


func is_reachable(cell: Vector2i) -> bool:
	if not is_inside(cell):
		return false
	return integration[_index(cell.x, cell.y)] < INF


func integration_at(cell: Vector2i) -> float:
	if not is_inside(cell):
		return INF
	return integration[_index(cell.x, cell.y)]

## 重建积分场。
##   grid_cols/grid_rows：网格尺寸
##   goal_cells：目标格（基地占用的格子），多源 Dijkstra 的起点
##   blocked_cells：不可通行格（实心障碍/路障/车辆体）
##   extra_cost：可选，每格的额外进入代价（P2 危险场：danger_weight × influence）。
##              传入的数组长度需为 cols*rows；否则视为全 0。
func rebuild(
	grid_cols: int,
	grid_rows: int,
	goal_cells: Array,
	blocked_cells: Array = [],
	extra_cost: PackedFloat32Array = PackedFloat32Array(),
) -> void:
	cols = maxi(grid_cols, 0)
	rows = maxi(grid_rows, 0)
	var n := cols * rows
	integration = PackedFloat32Array()
	integration.resize(n)
	integration.fill(INF)
	_dir = PackedVector2Array()
	_dir.resize(n)
	_blocked = PackedByteArray()
	_blocked.resize(n)
	if n == 0:
		return
	var has_extra := extra_cost.size() == n
	for cell in blocked_cells:
		if cell is Vector2i and is_inside(cell):
			_blocked[_index(cell.x, cell.y)] = 1

	# 二叉最小堆：并行数组（dist, index），手写以避免每次分配对象
	var heap_dist := PackedFloat32Array()
	var heap_idx := PackedInt32Array()
	for cell in goal_cells:
		if not (cell is Vector2i) or not is_inside(cell):
			continue
		var gi := _index(cell.x, cell.y)
		if _blocked[gi] == 1:
			continue  # 目标本身被标记为障碍则跳过（车辆格通常不传进 blocked）
		if integration[gi] == 0.0:
			continue
		integration[gi] = 0.0
		_heap_push(heap_dist, heap_idx, 0.0, gi)

	while heap_idx.size() > 0:
		var cur_d: float = heap_dist[0]
		var cur_i: int = heap_idx[0]
		_heap_pop(heap_dist, heap_idx)
		if cur_d > integration[cur_i]:
			continue  # 过期堆条目
		var cx := cur_i % cols
		var cy := cur_i / cols
		for off: Vector2i in _NEIGHBORS:
			var nx := cx + off.x
			var ny := cy + off.y
			if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
				continue
			var ni := _index(nx, ny)
			if _blocked[ni] == 1:
				continue
			# 对角线不允许穿过两个障碍角（避免贴墙抄近路穿过实心夹角）
			if off.x != 0 and off.y != 0:
				if _blocked[_index(cx + off.x, cy)] == 1 and _blocked[_index(cx, cy + off.y)] == 1:
					continue
			var step := SQRT2 if (off.x != 0 and off.y != 0) else 1.0
			if has_extra:
				step += maxf(extra_cost[ni], 0.0)
			var nd := cur_d + step
			if nd < integration[ni]:
				integration[ni] = nd
				_heap_push(heap_dist, heap_idx, nd, ni)

	_build_gradient()


## 由积分场计算每格梯度：指向 8 邻域中积分值最小的方向（即下坡 = 朝目标）。
func _build_gradient() -> void:
	for y in range(rows):
		for x in range(cols):
			var i := _index(x, y)
			if _blocked[i] == 1 or integration[i] >= INF:
				_dir[i] = Vector2.ZERO
				continue
			var best := integration[i]
			var best_dir := Vector2.ZERO
			for off: Vector2i in _NEIGHBORS:
				var nx := x + off.x
				var ny := y + off.y
				if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
					continue
				var ni := _index(nx, ny)
				if _blocked[ni] == 1:
					continue
				var v := integration[ni]
				if v < best:
					best = v
					best_dir = Vector2(off.x, off.y)
			_dir[i] = best_dir.normalized() if best_dir != Vector2.ZERO else Vector2.ZERO


# --- 手写二叉最小堆（并行数组）---

func _heap_push(hd: PackedFloat32Array, hi: PackedInt32Array, d: float, idx: int) -> void:
	hd.append(d)
	hi.append(idx)
	var c := hd.size() - 1
	while c > 0:
		var p := (c - 1) / 2
		if hd[p] <= hd[c]:
			break
		var td := hd[p]; hd[p] = hd[c]; hd[c] = td
		var ti := hi[p]; hi[p] = hi[c]; hi[c] = ti
		c = p


func _heap_pop(hd: PackedFloat32Array, hi: PackedInt32Array) -> void:
	var last := hd.size() - 1
	if last < 0:
		return
	hd[0] = hd[last]
	hi[0] = hi[last]
	hd.remove_at(last)
	hi.remove_at(last)
	var size := hd.size()
	var p := 0
	while true:
		var l := p * 2 + 1
		var r := p * 2 + 2
		var smallest := p
		if l < size and hd[l] < hd[smallest]:
			smallest = l
		if r < size and hd[r] < hd[smallest]:
			smallest = r
		if smallest == p:
			break
		var td := hd[p]; hd[p] = hd[smallest]; hd[smallest] = td
		var ti := hi[p]; hi[p] = hi[smallest]; hi[smallest] = ti
		p = smallest

