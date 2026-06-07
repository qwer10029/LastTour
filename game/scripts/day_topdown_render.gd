class_name DayTopdownRender
extends RefCounted

const PIXEL := 16
const VEHICLE_PIXEL := 3.0
const VEHICLE_BODY_UNITS := 14.0
const VEHICLE_DISPLAY_SCALE := 1.62  ## 俯视角贴图相对路面宽度的显示倍率
const ROAD_TILE_DIR := "res://assets/tiles/road/"
const INTERIOR_TILE_DIR := "res://assets/tiles/interior/"
const TILE_OVERLAP_WORLD := 1.5

static var _settings: RoadRenderSettings = RoadRenderSettings.new()

static var _road_textures_ready := false
static var _tex_road_ns: Texture2D
static var _tex_road_ew: Texture2D
static var _tex_road_cross: Texture2D
static var _tex_road_corner: Texture2D
static var _tex_road_t: Texture2D

static var _interior_textures_ready := false
static var _tex_interior_floor: Texture2D
static var _tex_interior_obstacle: Texture2D

const PLAYER_FOOT_SPRITE := "res://assets/sprites/player_foot.png"
const PLAYER_FOOT_WALK_SHEET := "res://assets/sprites/player_foot_walk_all.png"
const PLAYER_FOOT_WALK_UP := "res://assets/sprites/player_foot_walk_up.png"
const PLAYER_WALK_SHEET_FRAMES := 8
## 8 帧横条：0-2 背(上) 3-4 正(下) 5-7 右(左镜像)
const PLAYER_WALK_FRAMES_UP := [0, 1, 2]
const PLAYER_WALK_FRAMES_DOWN := [3, 4, 3]
const PLAYER_WALK_FRAMES_SIDE := [5, 6, 7]
const VEHICLE_TOPDOWN_SPRITE := "res://assets/sprites/vehicle_topdown.png"
const VEHICLE_SPRITE_FORWARD := Vector2.LEFT  ## 贴图默认车头朝左
static var _player_sprite_ready := false
static var _tex_player_foot: Texture2D
static var _vehicle_sprite_ready := false
static var _tex_vehicle: Texture2D

static func hash_cell(seed: int, gx: int, gy: int) -> float:
	return fmod(sin(float(seed * 1271 + gx * 3117 + gy * 7493)) * 43758.5453, 1.0)


static func draw_ruin_cell(canvas: CanvasItem, rect: Rect2, kind: String, explored: bool, seed: int) -> void:
	var px := maxi(1, int(floor(rect.size.x / float(PIXEL))))
	var py := maxi(1, int(floor(rect.size.y / float(PIXEL))))
	var base := _base_color(kind, explored)
	for ix in range(px):
		for iy in range(py):
			var local := Rect2(
				rect.position + Vector2(float(ix * PIXEL), float(iy * PIXEL)),
				Vector2(
					minf(float(PIXEL), rect.size.x - float(ix * PIXEL)),
					minf(float(PIXEL), rect.size.y - float(iy * PIXEL)),
				),
			)
			var h := hash_cell(seed, ix, iy)
			var c := base
			if kind == "empty" or not explored:
				c = base.darkened(0.12 + h * 0.22)
			elif h > 0.72:
				c = base.lightened(0.08)
			elif h < 0.18:
				c = base.darkened(0.1)
			canvas.draw_rect(local, c, true)
			if explored and kind == "district" and h > 0.86:
				canvas.draw_rect(local.grow_individual(-5, -5, -5, -5), Color("#3d4a38"), true)
			if explored and kind == "junction" and h > 0.8:
				canvas.draw_rect(local.grow_individual(-4, -4, -4, -4), Color("#6a5a40"), true)


static func _base_color(kind: String, explored: bool) -> Color:
	if not explored:
		return Color("#0a0c10")
	match kind:
		"district":
			return Color("#3a4f36")
		"hub":
			return Color("#3d4f5c")
		"junction":
			return Color("#454035")
		"road":
			return Color("#2e3338")
		"trail":
			return Color("#3a4a34")
		_:
			return Color("#1a1f24")


# 路面宽度约为车辆宽度的两倍；车辆居中行驶
static func vehicle_display_width() -> float:
	return VEHICLE_BODY_UNITS * VEHICLE_PIXEL


static func road_width() -> float:
	return vehicle_display_width() * 2.0


static func _road_strip_half_width(_cell_size: Vector2) -> float:
	return road_width() * 0.5


static func _road_surface_color(explored: bool) -> Color:
	return Color("#a89472") if explored else Color("#5c5448")


static func _road_edge_color(explored: bool) -> Color:
	return Color("#7a6a52") if explored else Color("#403830")


static func _road_modulate(explored: bool) -> Color:
	return Color.WHITE if explored else Color(0.58, 0.54, 0.5, 1.0)


static func reload_road_textures() -> void:
	_road_textures_ready = false
	_tex_road_ns = null
	_tex_road_ew = null
	_tex_road_cross = null
	_tex_road_corner = null
	_tex_road_t = null
	ArtAssetLoader.clear_road_alpha_cache()


static func apply_settings(settings: RoadRenderSettings) -> void:
	if settings != null:
		_settings = settings


static func get_settings() -> RoadRenderSettings:
	return _settings


static func _ensure_road_textures() -> void:
	if _road_textures_ready:
		return
	_road_textures_ready = true
	_tex_road_ns = ArtAssetLoader.load_texture_road_alpha_key(ROAD_TILE_DIR + "road_ns_segment.png")
	_tex_road_ew = ArtAssetLoader.load_texture_road_alpha_key(ROAD_TILE_DIR + "road_ew_segment.png")
	_tex_road_cross = ArtAssetLoader.load_texture_road_alpha_key(ROAD_TILE_DIR + "road_cross.png")
	_tex_road_corner = ArtAssetLoader.load_texture_road_alpha_key(ROAD_TILE_DIR + "road_corner.png")
	_tex_road_t = _load_road_t_texture()


static func _load_road_t_texture() -> Texture2D:
	var path := ROAD_TILE_DIR + "road_t.png"
	var tex := ArtAssetLoader.load_texture_from_disk(path)
	if tex == null:
		tex = ArtAssetLoader.load_texture(path)
	if tex == null:
		return null
	var keyed := ArtAssetLoader.apply_road_background_key(tex)
	if ArtAssetLoader.texture_has_visible_pixels(keyed):
		return keyed
	var black_keyed := ArtAssetLoader.apply_black_alpha_key(tex)
	if ArtAssetLoader.texture_has_visible_pixels(black_keyed):
		return black_keyed
	return tex


static func _has_road_textures() -> bool:
	_ensure_road_textures()
	return _tex_road_ns != null and _tex_road_ew != null


static func _ensure_interior_textures() -> void:
	if _interior_textures_ready:
		return
	_interior_textures_ready = true
	_tex_interior_floor = ArtAssetLoader.load_texture(INTERIOR_TILE_DIR + "floor.png")
	_tex_interior_obstacle = ArtAssetLoader.load_texture_alpha_key(INTERIOR_TILE_DIR + "obstacle.png")


static func reload_interior_textures() -> void:
	_interior_textures_ready = false
	_tex_interior_floor = null
	_tex_interior_obstacle = null
	_ensure_interior_textures()


static func draw_interior_floor(canvas: CanvasItem, panel_rect: Rect2) -> void:
	_ensure_interior_textures()
	if _tex_interior_floor != null:
		canvas.draw_texture_rect(_tex_interior_floor, panel_rect, false)
		return
	canvas.draw_rect(panel_rect, Color("#052a42"), true)


static func draw_interior_floor_grid(
	canvas: CanvasItem,
	panel_rect: Rect2,
	cols: int,
	rows: int,
) -> void:
	_ensure_interior_textures()
	var tile_w := panel_rect.size.x / float(maxi(cols, 1))
	var tile_h := panel_rect.size.y / float(maxi(rows, 1))
	for gy in range(rows):
		for gx in range(cols):
			var tile_rect := Rect2(
				panel_rect.position + Vector2(float(gx) * tile_w, float(gy) * tile_h),
				Vector2(tile_w, tile_h),
			)
			if _tex_interior_floor != null:
				canvas.draw_texture_rect(_tex_interior_floor, tile_rect, false)
			else:
				canvas.draw_rect(tile_rect, Color("#052a42"), true)


static func _segment_scale(texture: Texture2D, is_ns: bool) -> float:
	var tex_size := texture.get_size()
	var cross := tex_size.x if is_ns else tex_size.y
	return road_width() / cross


static func _cross_scale() -> float:
	return road_width() / _settings.cross_arm_tex_width * _settings.junction_scale_inset


static func _junction_scale(texture: Texture2D) -> float:
	# 与十字相同：统一以 _cross_scale 为基准，拐角/三岔仅乘各自倍率
	if texture == null or texture == _tex_road_cross:
		return _cross_scale()
	if texture == _tex_road_corner:
		return _cross_scale() * _settings.corner_scale_inset
	if texture == _tex_road_t:
		return _cross_scale() * _settings.t_junction_scale_inset
	return _cross_scale()


static func cross_trim_world() -> float:
	return _settings.cross_arm_tex_half_length * _cross_scale() * _settings.cross_trim_inset


static func junction_trim_world(dirs: Array) -> float:
	var base := cross_trim_world()
	if dirs.size() == 2 and not dirs_are_straight(dirs):
		return base * _settings.corner_scale_inset / maxf(_settings.corner_trim_extra, 0.5)
	if dirs.size() == 3:
		return base * _settings.t_junction_scale_inset * _settings.t_junction_trim_extra
	return base


static func _direction_vector(direction: String) -> Vector2:
	match direction:
		"up":
			return Vector2(0.0, -1.0)
		"down":
			return Vector2(0.0, 1.0)
		"left":
			return Vector2(-1.0, 0.0)
		"right":
			return Vector2(1.0, 0.0)
		_:
			return Vector2.ZERO


static func _opposite_direction(direction: String) -> String:
	match direction:
		"up":
			return "down"
		"down":
			return "up"
		"left":
			return "right"
		"right":
			return "left"
		_:
			return ""


## 按出口方向计算 trim；拐角用该朝向独立偏移，不再旋转共用一组。
static func junction_trim_for_exit(dirs: Array, exit_direction: String) -> float:
	if not needs_junction_cap(dirs) or exit_direction == "":
		return 0.0
	var mask := _road_dir_mask(dirs)
	if dirs.size() == 2 and not dirs_are_straight(dirs):
		var arm := cross_trim_world() * _settings.corner_scale_inset / maxf(_settings.corner_trim_extra, 0.5)
		var off := _corner_offset_for_mask(mask)
		var along := off.dot(_direction_vector(exit_direction))
		return clampf(arm + along, arm * 0.32, arm * 1.9)
	if dirs.size() == 3:
		var base := cross_trim_world()
		var off := Vector2(_settings.t_junction_offset_x, _settings.t_junction_offset_y).rotated(
			_t_junction_rotation(mask)
		)
		var along := off.dot(_direction_vector(exit_direction))
		var arm := base * _settings.t_junction_scale_inset * _settings.t_junction_trim_extra
		return clampf(arm + along, arm * 0.32, arm * 1.9)
	return cross_trim_world()


static func _road_dir_mask(dirs: Array) -> int:
	var mask := 0
	for raw in dirs:
		match str(raw):
			"up":
				mask |= 1
			"down":
				mask |= 2
			"left":
				mask |= 4
			"right":
				mask |= 8
	return mask


static func dirs_are_straight(dirs: Array) -> bool:
	if dirs.size() != 2:
		return false
	var a := str(dirs[0])
	var b := str(dirs[1])
	return (a == "up" and b == "down") or (a == "down" and b == "up") or (a == "left" and b == "right") or (a == "right" and b == "left")


static func needs_junction_cap(dirs: Array) -> bool:
	if dirs.size() >= 3:
		return true
	if dirs.size() == 2:
		return not dirs_are_straight(dirs)
	return false


static func _corner_rotation(mask: int) -> float:
	# 基准图：右 + 下（mask 10）
	match mask:
		10:
			return 0.0
		6:
			return PI * 0.5
		5:
			return PI
		9:
			return -PI * 0.5
		_:
			return 0.0


static func _t_junction_rotation(mask: int) -> float:
	# 基准图：左 + 右 + 下（缺上，mask 14）
	var missing := 15 - mask
	match missing:
		1:
			return 0.0
		2:
			return PI
		4:
			return -PI * 0.5
		8:
			return PI * 0.5
		_:
			return 0.0


static func _corner_offset_for_mask(mask: int) -> Vector2:
	# 10=右+下  6=下+左  5=左+上  9=上+右（与贴图旋转一致）
	match mask:
		10:
			return Vector2(_settings.corner_offset_rd_x, _settings.corner_offset_rd_y)
		6:
			return Vector2(_settings.corner_offset_dl_x, _settings.corner_offset_dl_y)
		5:
			return Vector2(_settings.corner_offset_lu_x, _settings.corner_offset_lu_y)
		9:
			return Vector2(_settings.corner_offset_ur_x, _settings.corner_offset_ur_y)
		_:
			return Vector2.ZERO


static func _junction_offset_world(texture: Texture2D, rotation: float, road_mask: int = 0) -> Vector2:
	if texture == _tex_road_corner:
		return _corner_offset_for_mask(road_mask)
	if texture == _tex_road_t:
		return Vector2(_settings.t_junction_offset_x, _settings.t_junction_offset_y).rotated(rotation)
	if texture == _tex_road_cross:
		return Vector2(_settings.cross_offset_x, _settings.cross_offset_y)
	return Vector2.ZERO


static func _draw_junction_texture(
	canvas: CanvasItem,
	center: Vector2,
	texture: Texture2D,
	rotation: float,
	modulate: Color,
	road_mask: int = 0,
) -> void:
	if texture == null:
		return
	var tex_size := texture.get_size()
	var scale := _junction_scale(texture)
	var draw_center := center + _junction_offset_world(texture, rotation, road_mask)
	canvas.draw_set_transform(draw_center, rotation, Vector2(scale, scale))
	canvas.draw_texture(texture, -tex_size * 0.5, modulate)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func draw_road_node_cap(canvas: CanvasItem, center: Vector2, cell_size: Vector2, explored: bool, dirs: Array = []) -> void:
	if dirs.is_empty() or (dirs.size() == 2 and dirs_are_straight(dirs)):
		return
	_ensure_road_textures()
	var count := dirs.size()
	var mask := _road_dir_mask(dirs)
	var modulate := _road_modulate(explored)
	if count == 2:
		if _tex_road_corner != null:
			_draw_junction_texture(canvas, center, _tex_road_corner, _corner_rotation(mask), modulate, mask)
			return
		_draw_corner_fallback_cap(canvas, center, cell_size, explored)
		return
	if count == 4 and mask == 15 and _tex_road_cross != null:
		_draw_junction_texture(canvas, center, _tex_road_cross, 0.0, modulate)
		return
	if count == 3 and _tex_road_t != null:
		_draw_junction_texture(canvas, center, _tex_road_t, _t_junction_rotation(mask), modulate)
		return
	if count >= 3:
		var half_w := _road_strip_half_width(cell_size)
		var radius := half_w * 1.35
		canvas.draw_circle(center, radius + 2.0, _road_edge_color(explored))
		canvas.draw_circle(center, radius, _road_surface_color(explored))
		if explored:
			canvas.draw_circle(center, radius * 0.35, Color("#d8c898", 0.5))


static func _draw_corner_fallback_cap(
	canvas: CanvasItem,
	center: Vector2,
	cell_size: Vector2,
	explored: bool,
) -> void:
	var half_w := _road_strip_half_width(cell_size)
	var radius := half_w * 1.15
	canvas.draw_circle(center, radius + 2.0, _road_edge_color(explored))
	canvas.draw_circle(center, radius, _road_surface_color(explored))


static func _road_surface_scale(texture: Texture2D, is_ns: bool) -> float:
	return _segment_scale(texture, is_ns)


static func _segment_metrics(texture: Texture2D, is_ns: bool) -> Vector3:
	var tex_size := texture.get_size()
	var cross := tex_size.x if is_ns else tex_size.y
	var along := tex_size.y if is_ns else tex_size.x
	var scale := _road_surface_scale(texture, is_ns)
	return Vector3(along * scale, scale, cross)


static func _draw_segment_piece(
	canvas: CanvasItem,
	texture: Texture2D,
	origin: Vector2,
	dir: Vector2,
	seg_len: float,
	full_step: float,
	is_ns: bool,
	modulate: Color,
	scale: float = -1.0,
) -> void:
	if texture == null or seg_len <= 0.01:
		return
	if scale < 0.0:
		scale = _segment_scale(texture, is_ns)
	var tex_size := texture.get_size()
	var rotation := atan2(-dir.x, dir.y) if is_ns else dir.angle()
	var center := origin + dir * (seg_len * 0.5)
	var frac := clampf(seg_len / full_step, 0.01, 1.0)
	var region_len := (tex_size.y if is_ns else tex_size.x) * frac
	var region := Rect2(
		0.0,
		0.0,
		tex_size.x if is_ns else region_len,
		region_len if is_ns else tex_size.y,
	)
	var dest := Rect2(
		-tex_size.x * 0.5 if is_ns else -region_len * 0.5,
		-region_len * 0.5 if is_ns else -tex_size.y * 0.5,
		region.size.x,
		region.size.y,
	)
	canvas.draw_set_transform(center, rotation, Vector2(scale, scale))
	canvas.draw_texture_rect_region(texture, dest, region, modulate)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _draw_tiled_road_strip(
	canvas: CanvasItem,
	from_pos: Vector2,
	to_pos: Vector2,
	explored: bool,
	trim_from: float = 0.0,
	trim_to: float = 0.0,
) -> void:
	var delta := to_pos - from_pos
	var length := delta.length()
	if length <= 0.01:
		return
	var dir := delta / length
	var is_ns := absf(dir.y) >= absf(dir.x)
	var texture := _tex_road_ns if is_ns else _tex_road_ew
	if texture == null:
		return
	var trim_start := clampf(trim_from, 0.0, length * _settings.segment_trim_max_frac)
	var trim_end := clampf(trim_to, 0.0, length * _settings.segment_trim_max_frac)
	var draw_start := from_pos + dir * trim_start
	var draw_end := to_pos - dir * trim_end
	var draw_len := draw_start.distance_to(draw_end)
	if draw_len <= 0.01:
		return
	var metrics := _segment_metrics(texture, is_ns)
	var tile_step: float = metrics.x
	var scale: float = metrics.y
	var modulate := _road_modulate(explored)
	var overlap := TILE_OVERLAP_WORLD
	var tile_count := maxi(1, int(ceil((draw_len + overlap) / tile_step)))
	for i in range(tile_count):
		var start_dist := float(i) * tile_step
		if i > 0:
			start_dist -= overlap
		if start_dist >= draw_len:
			break
		var seg_len := minf(tile_step + (overlap if i > 0 else 0.0), draw_len - start_dist)
		var origin := draw_start + dir * start_dist
		_draw_segment_piece(canvas, texture, origin, dir, seg_len, tile_step, is_ns, modulate, scale)


static func draw_road_connector(
	canvas: CanvasItem,
	from_pos: Vector2,
	to_pos: Vector2,
	cell_size: Vector2,
	explored: bool,
	trim_from: float = 0.0,
	trim_to: float = 0.0,
) -> void:
	if _has_road_textures():
		_draw_tiled_road_strip(canvas, from_pos, to_pos, explored, trim_from, trim_to)
		return
	var half_w := _road_strip_half_width(cell_size)
	var dir := to_pos - from_pos
	if dir.length_squared() < 0.01:
		return
	dir = dir.normalized()
	var perp := Vector2(-dir.y, dir.x) * half_w
	var surface := _road_surface_color(explored)
	var pts := PackedVector2Array([from_pos + perp, from_pos - perp, to_pos - perp, to_pos + perp])
	canvas.draw_colored_polygon(pts, surface)
	canvas.draw_polyline(pts + PackedVector2Array([pts[0]]), _road_edge_color(explored), 1.5)
	var mid := from_pos.lerp(to_pos, 0.5)
	var dash_len := half_w * 0.85
	var dash_color := Color("#d8c898", 0.45) if explored else Color("#6a6258", 0.25)
	if absf(dir.x) > absf(dir.y):
		canvas.draw_rect(Rect2(mid - Vector2(dash_len, 1.5), Vector2(dash_len * 2.0, 3.0)), dash_color, true)
	else:
		canvas.draw_rect(Rect2(mid - Vector2(1.5, dash_len), Vector2(3.0, dash_len * 2.0)), dash_color, true)


static func draw_road_line(
	canvas: CanvasItem,
	from_pos: Vector2,
	to_pos: Vector2,
	cell_size: Vector2,
	explored: bool,
	trim_from: float = 0.0,
	trim_to: float = 0.0,
) -> void:
	draw_road_connector(canvas, from_pos, to_pos, cell_size, explored, trim_from, trim_to)


## 先画各格路口贴图，再沿每个方向从路口 trim 点接到邻格路口（直路只接在路口之间）。
static func draw_road_network(
	canvas: CanvasItem,
	map: WorldMapData,
	view_rect: Rect2,
	should_draw_link: Callable,
	link_explored: Callable,
) -> void:
	# 先直路、后路口：直路可伸入拐角直臂下方，拐角贴图盖在上面消除接缝
	for index in range(map.cells.size()):
		if not map.is_drive_node(index):
			continue
		var center := map.cell_center(index)
		var from_dirs := map.get_road_directions(index)
		for direction in from_dirs:
			var other := map.get_neighbor_index(index, direction)
			if other < 0 or other < index:
				continue
			if not map.is_road_link(index, other):
				continue
			var other_center := map.cell_center(other)
			if not should_draw_link.call(index, other, center, other_center):
				continue
			var explored: bool = link_explored.call(index, other, center, other_center)
			var to_dirs := map.get_road_directions(other)
			var trim_from := junction_trim_for_exit(from_dirs, direction) if needs_junction_cap(from_dirs) else 0.0
			var trim_to := (
				junction_trim_for_exit(to_dirs, _opposite_direction(direction))
				if needs_junction_cap(to_dirs)
				else 0.0
			)
			draw_road_line(canvas, center, other_center, map.cell_size, explored, trim_from, trim_to)

	for index in range(map.cells.size()):
		if not map.is_drive_node(index):
			continue
		var center := map.cell_center(index)
		var node_in_view := view_rect.grow(road_width()).has_point(center)
		if not node_in_view:
			continue
		var road_dirs := map.get_road_directions(index)
		if not needs_junction_cap(road_dirs):
			continue
		var explored: bool = link_explored.call(index, index, center, center)
		draw_road_node_cap(canvas, center, map.cell_size, explored, road_dirs)


# 路面格只铺草地/废墟底图，窄路由连接带绘制
static func draw_road_terrain_cell(canvas: CanvasItem, rect: Rect2, explored: bool, seed: int) -> void:
	draw_ruin_cell(canvas, rect, "trail", explored, seed)


static func _ensure_vehicle_sprite() -> void:
	if _vehicle_sprite_ready:
		return
	_vehicle_sprite_ready = true
	var raw := ArtAssetLoader.load_texture(
		VEHICLE_TOPDOWN_SPRITE,
		"res://assets/dummy/vehicle_dummy.png",
	)
	if raw == null:
		raw = ArtAssetLoader.load_texture("res://assets/dummy/vehicle_dummy.png", "res://assets/dummy/vehicle_dummy.svg")
	if raw != null:
		var keyed := ArtAssetLoader.apply_road_background_key(raw)
		if ArtAssetLoader.texture_has_visible_pixels(keyed):
			_tex_vehicle = keyed
			return
		keyed = ArtAssetLoader.apply_black_alpha_key(raw, 0.12)
		if ArtAssetLoader.texture_has_visible_pixels(keyed):
			_tex_vehicle = keyed
			return
	_tex_vehicle = raw


static func vehicle_texture() -> Texture2D:
	_ensure_vehicle_sprite()
	return _tex_vehicle


static func _vehicle_draw_rotation(facing: Vector2, travel_axis: String) -> float:
	var dir := facing
	if dir.length_squared() < 0.01:
		match travel_axis:
			"right":
				dir = Vector2.RIGHT
			"left":
				dir = Vector2.LEFT
			"up":
				dir = Vector2.UP
			"down":
				dir = Vector2.DOWN
	if dir.length_squared() < 0.01:
		return 0.0
	return dir.angle() - VEHICLE_SPRITE_FORWARD.angle()


static func draw_vehicle_marker(
	canvas: CanvasItem,
	center: Vector2,
	unit_scale: float = 1.0,
	travel_axis: String = "",
	facing: Vector2 = Vector2.ZERO,
) -> void:
	var s := clampf(unit_scale, 0.55, 1.5)
	_ensure_vehicle_sprite()
	if _tex_vehicle != null:
		var tex_size := _tex_vehicle.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			var display := vehicle_display_width() * s * VEHICLE_DISPLAY_SCALE
			var base_scale := display / maxf(float(tex_size.x), float(tex_size.y))
			var rotation := _vehicle_draw_rotation(facing, travel_axis)
			canvas.draw_circle(center + Vector2(0.0, 4.0 * s), display * 0.3, Color(0.0, 0.0, 0.0, 0.36))
			var half := Vector2(tex_size) * 0.5
			canvas.draw_set_transform(center, rotation, Vector2(base_scale, base_scale))
			canvas.draw_texture(_tex_vehicle, -half)
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
	draw_pixel_vehicle(canvas, center, travel_axis)


static func draw_pixel_vehicle(canvas: CanvasItem, center: Vector2, travel_axis: String = "") -> void:
	var px := 3.0
	var body := Rect2(center - Vector2(7 * px, 5 * px), Vector2(14 * px, 10 * px))
	canvas.draw_rect(body, Color("#1a120c"), true)
	canvas.draw_rect(body.grow_individual(-px, -px, -px, -px), Color("#c87830"), true)
	if travel_axis == "ew":
		canvas.draw_rect(Rect2(center.x - 2 * px, center.y - 7 * px, 4 * px, 3 * px), Color("#8a5030"), true)
	elif travel_axis == "ns":
		canvas.draw_rect(Rect2(center.x - 7 * px, center.y - 2 * px, 3 * px, 4 * px), Color("#8a5030"), true)
	canvas.draw_rect(Rect2(center.x - 8 * px, center.y + 3 * px, 3 * px, 3 * px), Color("#101010"), true)
	canvas.draw_rect(Rect2(center.x + 5 * px, center.y + 3 * px, 3 * px, 3 * px), Color("#101010"), true)


static func draw_road_cell(canvas: CanvasItem, rect: Rect2, explored: bool, seed: int = 0) -> void:
	draw_road_terrain_cell(canvas, rect, explored, seed)


static func _building_colors(building_type: String) -> Dictionary:
	var wall_fill := Color("#5c4a38")
	var roof_fill := Color("#3d3028")
	match building_type:
		"elevator":
			wall_fill = Color("#6a5a42")
			roof_fill = Color("#4a3c2c")
		"archive":
			wall_fill = Color("#4a4560")
			roof_fill = Color("#353045")
		"warehouse":
			wall_fill = Color("#4f5a48")
			roof_fill = Color("#384030")
		"garage":
			wall_fill = Color("#4a5560")
			roof_fill = Color("#333c44")
		"barracks":
			wall_fill = Color("#5a4a40")
			roof_fill = Color("#3a3028")
		"market":
			wall_fill = Color("#6a5540")
			roof_fill = Color("#4a3c2c")
	return {"wall": wall_fill, "roof": roof_fill}


static func district_building_sign_rect(district_rect: Rect2, toward_road: Vector2) -> Rect2:
	var unit := minf(district_rect.size.x, district_rect.size.y)
	var center := district_rect.position + district_rect.size * 0.5
	if toward_road.length_squared() > 0.01:
		center += toward_road.normalized() * unit * 0.16
	var body_size := unit * 0.42
	var body := Rect2(center - Vector2(body_size, body_size) * 0.5, Vector2(body_size, body_size))
	return Rect2(body.position + Vector2(body_size * 0.5 - 36.0, -10.0), Vector2(72, 14))


static func draw_district_building(
	canvas: CanvasItem,
	district_rect: Rect2,
	building_type: String,
	label: String,
	toward_road: Vector2,
	highlight_entrance: bool = false,
	show_label: bool = true,
) -> void:
	var unit := minf(district_rect.size.x, district_rect.size.y)
	var center := district_rect.position + district_rect.size * 0.5
	if toward_road.length_squared() > 0.01:
		center += toward_road.normalized() * unit * 0.16
	var colors := _building_colors(building_type)
	var body_size := unit * 0.42
	var body := Rect2(center - Vector2(body_size, body_size) * 0.5, Vector2(body_size, body_size))
	canvas.draw_rect(body, colors["wall"], true)
	canvas.draw_rect(body, Color("#1a1410"), false, 2.0)
	var roof := body.grow(-body_size * 0.12)
	roof.size.y = body_size * 0.22
	roof.position.y = body.position.y + body_size * 0.06
	canvas.draw_rect(roof, colors["roof"], true)
	if highlight_entrance:
		canvas.draw_rect(body.grow(4.0), Color("#f0c168", 0.35), false, 2.0)
	if not show_label or label.is_empty():
		return
	var sign_rect := district_building_sign_rect(district_rect, toward_road)
	canvas.draw_rect(sign_rect, Color("#2a2218", 0.9), true)
	canvas.draw_string(
		ThemeDB.fallback_font,
		sign_rect.position + Vector2(4, 10),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		10,
		Color("#f8ecd8"),
	)


static func draw_roadside_entrance(
	canvas: CanvasItem,
	road_rect: Rect2,
	side_dir: Vector2,
	highlight_entrance: bool = false,
) -> Vector2:
	var road_center := road_rect.position + road_rect.size * 0.5
	var unit := minf(road_rect.size.x, road_rect.size.y)
	var edge := road_center + side_dir.normalized() * (unit * 0.36)
	var door_w := unit * 0.07
	var door_h := unit * 0.06
	var door_rect := Rect2(edge - Vector2(door_w * 0.5, door_h * 0.5), Vector2(door_w, door_h))
	canvas.draw_rect(door_rect, Color("#1a1410"), true)
	var door_color := Color("#4a9ed8")
	if highlight_entrance:
		door_color = Color("#9ef0ff")
		canvas.draw_rect(door_rect.grow(4.0), Color("#f0c168", 0.55), true)
	canvas.draw_rect(door_rect.grow(-1.5), door_color, true)
	canvas.draw_string(ThemeDB.fallback_font, edge - Vector2(6, 4), "门", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#f8ecd8"))
	return edge


static func roadside_facade_entrance(road_rect: Rect2, side_dir: Vector2) -> Vector2:
	var road_center := road_rect.position + road_rect.size * 0.5
	var unit := minf(road_rect.size.x, road_rect.size.y)
	return road_center + side_dir.normalized() * (unit * 0.36)


static func draw_hotkey_badge(
	canvas: CanvasItem,
	anchor: Vector2,
	hotkey: String,
	selected: bool = false,
) -> void:
	if hotkey.is_empty():
		return
	var badge := 16.0
	var rect := Rect2(anchor + Vector2(6.0, -badge - 8.0), Vector2(badge, badge))
	var bg := Color("#121820", 0.94) if not selected else Color("#3a2a10", 0.96)
	var border := Color("#7a9cb0", 0.85) if not selected else Color("#f0c168", 0.95)
	canvas.draw_rect(rect, bg, true)
	canvas.draw_rect(rect, border, false, 1.5)
	HudTheme.draw_string(
		canvas,
		rect.position + Vector2(4.0, 12.0),
		hotkey,
		11,
		Color("#eef8ff") if not selected else Color("#fff0c8"),
	)


static func draw_roadside_facade(
	canvas: CanvasItem,
	road_rect: Rect2,
	side_dir: Vector2,
	building_type: String,
	label: String,
	highlight_entrance: bool = false,
	district_rect: Rect2 = Rect2(),
	show_label: bool = true,
) -> Vector2:
	if district_rect.size != Vector2.ZERO:
		draw_district_building(
			canvas,
			district_rect,
			building_type,
			label,
			-side_dir,
			highlight_entrance,
			show_label,
		)
	return draw_roadside_entrance(canvas, road_rect, side_dir, highlight_entrance)


static func draw_world_building(
	canvas: CanvasItem,
	road_rect: Rect2,
	district_rect: Rect2,
	building_type: String,
	label: String,
	highlight_entrance: bool = false,
) -> Vector2:
	var road_center := road_rect.position + road_rect.size * 0.5
	var district_center := district_rect.position + district_rect.size * 0.5
	var side := district_center - road_center
	if side.length_squared() < 1.0:
		side = Vector2(0.0, -1.0)
	return draw_roadside_facade(
		canvas,
		road_rect,
		side.normalized(),
		building_type,
		label,
		highlight_entrance,
		district_rect,
	)


static func draw_roadside_building(canvas: CanvasItem, road_rect: Rect2, district_rect: Rect2, building_type: String, label: String) -> void:
	draw_world_building(canvas, road_rect, district_rect, building_type, label, false)


static func draw_loot_pickup(
	canvas: CanvasItem,
	center: Vector2,
	item_id: String,
	radius: float,
	show_label: bool = false,
	label_override: String = "",
) -> void:
	var icon_px := maxi(20, int(round(radius * 2.4)))
	var draw_id := ItemIconFactory.loot_draw_id(item_id)
	var tex: Texture2D = null
	var icon_size := Vector2(float(icon_px), float(icon_px))
	if draw_id == "quest_battery":
		tex = ItemIconFactory.get_quest_battery_texture(icon_px)
		icon_size = ItemIconFactory.quest_battery_draw_size(icon_px)
	else:
		tex = ItemIconFactory.get_texture(draw_id, icon_px)
	if tex != null:
		var icon_rect := Rect2(center - icon_size * 0.5, icon_size)
		canvas.draw_circle(center, maxf(radius * 0.55, icon_size.x * 0.55), Color(0.0, 0.0, 0.0, 0.35))
		canvas.draw_texture_rect(tex, icon_rect, false)
	else:
		var def := ItemDefs.get_def(item_id)
		var color: Color = def.get("color", Color("#8ddf8a"))
		if typeof(color) == TYPE_STRING:
			color = Color(str(color))
		canvas.draw_circle(center, radius + 3.0, Color(0.0, 0.0, 0.0, 0.45))
		canvas.draw_circle(center, radius, color)
	if not show_label:
		return
	var name := ItemIconFactory.loot_display_name(item_id, label_override)
	var label_pos := center + Vector2(-20.0, -radius - 10.0)
	var bubble := Rect2(label_pos + Vector2(-4.0, -12.0), Vector2(maxf(40.0, float(name.length()) * 7.0 + 8.0), 14.0))
	canvas.draw_rect(bubble, Color(0.04, 0.07, 0.10, 0.72), true)
	HudTheme.draw_string(canvas, label_pos, name, 10, Color("#e8f0f8"))


static func draw_building_icon(canvas: CanvasItem, center: Vector2, building_type: String) -> void:
	var door := Color("#6eb5e8")
	match building_type:
		"elevator":
			door = Color("#f0c168")
		"archive":
			door = Color("#b88cff")
		"warehouse":
			door = Color("#8fd4a0")
		"garage":
			door = Color("#9ec9ff")
		"barracks":
			door = Color("#c8a080")
		"market":
			door = Color("#e8a86e")
	canvas.draw_rect(Rect2(center - Vector2(10, 12), Vector2(20, 16)), Color("#2a2f34"), true)
	canvas.draw_rect(Rect2(center - Vector2(4, 2), Vector2(8, 10)), door, true)


static func draw_interior_tile(canvas: CanvasItem, tile_rect: Rect2, blocked: bool) -> void:
	if not blocked:
		return
	_ensure_interior_textures()
	if _tex_interior_obstacle != null:
		canvas.draw_texture_rect(_tex_interior_obstacle, tile_rect, false)
		return
	canvas.draw_rect(tile_rect, Color("#2a4a32"), true)
	canvas.draw_rect(tile_rect.grow_individual(-2, -2, -2, -2), Color("#39463a"), true)


static func draw_interior_door(canvas: CanvasItem, tile_rect: Rect2, emphasized: bool = true) -> void:
	var pad := minf(tile_rect.size.x, tile_rect.size.y) * 0.08
	var inner := tile_rect.grow(-pad)
	canvas.draw_rect(tile_rect, Color("#f0c168", 0.25 if emphasized else 0.12), true)
	canvas.draw_rect(inner, Color("#5a4638"), true)
	var frame := inner.grow_individual(-inner.size.x * 0.22, -inner.size.y * 0.12, -inner.size.x * 0.22, -inner.size.y * 0.28)
	canvas.draw_rect(frame, Color("#0e1824"), true)
	var door_fill := Color("#6eb8ff") if emphasized else Color("#3a7aaa")
	canvas.draw_rect(frame.grow(-3.0), door_fill, true)
	var label_pos := tile_rect.position + Vector2(tile_rect.size.x * 0.5 - 14.0, tile_rect.size.y * 0.5 - 6.0)
	canvas.draw_string(ThemeDB.fallback_font, label_pos, "出口", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#f8f0d8"))
	var arrow_y := tile_rect.position.y + tile_rect.size.y - pad - 6.0
	var cx := tile_rect.position.x + tile_rect.size.x * 0.5
	canvas.draw_colored_polygon(
		PackedVector2Array([Vector2(cx, arrow_y), Vector2(cx - 8.0, arrow_y - 10.0), Vector2(cx + 8.0, arrow_y - 10.0)]),
		Color("#f0c168", 0.9 if emphasized else 0.5),
	)


static func draw_elevator_console(
	canvas: CanvasItem,
	tile_rect: Rect2,
	highlighted: bool = false,
	progress: float = 0.0,
) -> void:
	var icon_px := int(minf(tile_rect.size.x, tile_rect.size.y) * 0.82)
	var tex := ItemIconFactory.get_elevator_console_texture(icon_px)
	var center := tile_rect.position + tile_rect.size * 0.5
	if highlighted:
		canvas.draw_circle(center, float(icon_px) * 0.56, Color("#f0c168", 0.20))
	if tex != null:
		var half := float(icon_px) * 0.5
		canvas.draw_texture_rect(
			tex,
			Rect2(center - Vector2(half, half), Vector2(icon_px, icon_px)),
			false,
		)
	if progress <= 0.0:
		return
	var bar_w := tile_rect.size.x * 0.62
	var bar_h := 3.0
	var bar_pos := Vector2(
		center.x - bar_w * 0.5,
		tile_rect.end.y - bar_h - 2.0,
	)
	canvas.draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.06, 0.09, 0.12, 0.55), true)
	canvas.draw_rect(
		Rect2(bar_pos, Vector2(bar_w * clampf(progress, 0.0, 1.0), bar_h)),
		Color("#52a872", 0.88),
		true,
	)


static func reload_player_sprite() -> void:
	_player_sprite_ready = false
	_tex_player_foot = null


static func _ensure_player_foot_sprite() -> void:
	if _player_sprite_ready:
		return
	_player_sprite_ready = true
	_tex_player_foot = ArtAssetLoader.load_texture_sprite_alpha_key(
		PLAYER_FOOT_WALK_SHEET,
		0.12,
		PLAYER_FOOT_WALK_UP,
	)


static func _foot_cardinal_direction(move_dir: Vector2) -> String:
	if move_dir.length_squared() < 0.01:
		return "up"
	if absf(move_dir.x) > absf(move_dir.y):
		return "right" if move_dir.x > 0.0 else "left"
	return "down" if move_dir.y > 0.0 else "up"


static func _foot_walk_flip(cardinal: String) -> Vector2:
	if cardinal == "left":
		return Vector2(-1.0, 1.0)
	return Vector2(1.0, 1.0)


static func _foot_walk_frame_list(cardinal: String) -> Array:
	match cardinal:
		"down":
			return PLAYER_WALK_FRAMES_DOWN
		"right", "left":
			return PLAYER_WALK_FRAMES_SIDE
		_:
			return PLAYER_WALK_FRAMES_UP


static func _foot_walk_sheet_frame_count(tex_size: Vector2i) -> int:
	if tex_size.x <= 0 or tex_size.y <= 0:
		return 1
	# 8 帧表：单帧宽约等于半高（如 128×254）；4 帧表：单帧近方形
	var fw8 := float(tex_size.x) / float(PLAYER_WALK_SHEET_FRAMES)
	if absf(fw8 / float(tex_size.y) - 0.5) < 0.18:
		return PLAYER_WALK_SHEET_FRAMES
	var fw4 := float(tex_size.x) / 4.0
	if absf(fw4 / float(tex_size.y) - 1.0) < 0.28:
		return 4
	return maxi(1, int(round(float(tex_size.x) / float(tex_size.y))))


static func _foot_walk_frame_index(walk_phase: float, is_walking: bool, cardinal: String) -> int:
	var frames: Array = _foot_walk_frame_list(cardinal)
	if frames.is_empty():
		return 0
	if not is_walking:
		return int(frames[mini(1, frames.size() - 1)])
	var step := int(floor(walk_phase * 2.0 / PI)) % frames.size()
	return int(frames[step])


static func draw_player_marker(
	canvas: CanvasItem,
	center: Vector2,
	unit_scale: float = 1.0,
	move_dir: Vector2 = Vector2.ZERO,
	walk_phase: float = 0.0,
	is_walking: bool = false,
) -> void:
	var s := clampf(unit_scale, 0.55, 1.15)
	_ensure_player_foot_sprite()
	if _tex_player_foot != null:
		var tex_size := _tex_player_foot.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			var sheet_frames := _foot_walk_sheet_frame_count(tex_size)
			var frame_w := float(tex_size.x) / float(sheet_frames)
			var frame_h := float(tex_size.y)
			var cardinal := _foot_cardinal_direction(move_dir)
			var frame := _foot_walk_frame_index(walk_phase, is_walking, cardinal)
			frame = clampi(frame, 0, sheet_frames - 1)
			var bob := 0.0
			var sway := 0.0
			if is_walking:
				bob = sin(walk_phase) * 3.0 * s
				sway = sin(walk_phase * 2.0) * 1.5 * s
			var draw_center := center + Vector2(sway, -bob)
			var flip := _foot_walk_flip(cardinal)
			var display_h := 52.0 * s
			var display_w := display_h * (frame_w / maxf(frame_h, 1.0))
			var shadow_center := center + Vector2(sway * 0.35, 3.0 * s)
			canvas.draw_circle(shadow_center, display_h * 0.28, Color(0.0, 0.0, 0.0, 0.38))
			var src := Rect2(frame * frame_w, 0.0, frame_w, frame_h)
			var dest := Rect2(-display_w * 0.5, -display_h * 0.5, display_w, display_h)
			canvas.draw_set_transform(draw_center, 0.0, flip)
			canvas.draw_texture_rect_region(_tex_player_foot, dest, src)
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
	var fallback_s := s
	canvas.draw_rect(Rect2(center - Vector2(4, 4) * fallback_s, Vector2(8, 8) * fallback_s), Color("#4a9eff"), true)
	canvas.draw_rect(Rect2(center - Vector2(2.5, 6) * fallback_s, Vector2(5, 3) * fallback_s), Color("#2a5a9a"), true)
