class_name DayTopdownRender
extends RefCounted

const PIXEL := 16
const VEHICLE_PIXEL := 3.0
const VEHICLE_BODY_UNITS := 14.0
const ROAD_TILE_DIR := "res://assets/tiles/road/"

static var _road_textures_ready := false
static var _tex_road_ns: Texture2D
static var _tex_road_ew: Texture2D
static var _tex_road_cross: Texture2D

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


static func _ensure_road_textures() -> void:
	if _road_textures_ready:
		return
	_road_textures_ready = true
	_tex_road_ns = ArtAssetLoader.load_texture(ROAD_TILE_DIR + "road_ns_segment.png")
	_tex_road_ew = ArtAssetLoader.load_texture(ROAD_TILE_DIR + "road_ew_segment.png")
	_tex_road_cross = ArtAssetLoader.load_texture(ROAD_TILE_DIR + "road_cross.png")


static func _has_road_textures() -> bool:
	_ensure_road_textures()
	return _tex_road_ns != null and _tex_road_ew != null


static func _road_surface_scale(texture: Texture2D, is_ns: bool) -> float:
	var tex_size := texture.get_size()
	var cross := tex_size.x if is_ns else tex_size.y
	return road_width() / cross


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
) -> void:
	if texture == null or seg_len <= 0.01:
		return
	var tex_size := texture.get_size()
	var metrics := _segment_metrics(texture, is_ns)
	var scale: float = metrics.y
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
	var metrics := _segment_metrics(texture, is_ns)
	var tile_step: float = metrics.x
	var modulate := _road_modulate(explored)
	var tile_count := maxi(1, int(ceil(length / tile_step)))
	for i in range(tile_count):
		var start_dist := float(i) * tile_step
		if start_dist >= length:
			break
		var seg_len := minf(tile_step, length - start_dist)
		var origin := from_pos + dir * start_dist
		_draw_segment_piece(canvas, texture, origin, dir, seg_len, tile_step, is_ns, modulate)


static func draw_road_connector(canvas: CanvasItem, from_pos: Vector2, to_pos: Vector2, cell_size: Vector2, explored: bool) -> void:
	if _has_road_textures():
		_draw_tiled_road_strip(canvas, from_pos, to_pos, explored)
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


static func draw_road_line(canvas: CanvasItem, from_pos: Vector2, to_pos: Vector2, cell_size: Vector2, explored: bool) -> void:
	draw_road_connector(canvas, from_pos, to_pos, cell_size, explored)


static func draw_road_node_cap(canvas: CanvasItem, center: Vector2, cell_size: Vector2, explored: bool, hub: bool = false) -> void:
	if hub and _has_road_textures() and _tex_road_cross != null:
		var tex_size := _tex_road_cross.get_size()
		# 与直路一致：贴图里实际路面宽约 247px，对应同一 world road_width
		const CROSS_ROAD_TEX_WIDTH := 247.0
		var scale := road_width() / CROSS_ROAD_TEX_WIDTH
		var modulate := _road_modulate(explored)
		canvas.draw_set_transform(center, 0.0, Vector2(scale, scale))
		canvas.draw_texture(_tex_road_cross, -tex_size * 0.5, modulate)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if not hub:
		return
	var half_w := _road_strip_half_width(cell_size)
	var radius := half_w * 1.35
	canvas.draw_circle(center, radius + 2.0, _road_edge_color(explored))
	canvas.draw_circle(center, radius, _road_surface_color(explored))
	if explored:
		canvas.draw_circle(center, radius * 0.35, Color("#d8c898", 0.5))


# 路面格只铺草地/废墟底图，窄路由连接带绘制
static func draw_road_terrain_cell(canvas: CanvasItem, rect: Rect2, explored: bool, seed: int) -> void:
	draw_ruin_cell(canvas, rect, "trail", explored, seed)


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


static func draw_vehicle_marker(canvas: CanvasItem, center: Vector2, _unit_scale: float = 1.0) -> void:
	draw_pixel_vehicle(canvas, center)


static func draw_road_cell(canvas: CanvasItem, rect: Rect2, explored: bool, seed: int = 0) -> void:
	draw_road_terrain_cell(canvas, rect, explored, seed)


static func draw_roadside_facade(
	canvas: CanvasItem,
	road_rect: Rect2,
	side_dir: Vector2,
	building_type: String,
	label: String,
	highlight_entrance: bool = false,
) -> Vector2:
	var road_center := road_rect.position + road_rect.size * 0.5
	var unit := minf(road_rect.size.x, road_rect.size.y)
	var tangent := Vector2(-side_dir.y, side_dir.x)
	var facade_depth := unit * 0.14
	var facade_width := unit * 0.22
	var edge := road_center + side_dir * (unit * 0.32)
	var base := edge + side_dir * (facade_depth * 0.35)
	var half_w := tangent * (facade_width * 0.5)
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
		"market":
			wall_fill = Color("#6a5540")
			roof_fill = Color("#4a3c2c")
	var front_l := base - half_w
	var front_r := base + half_w
	var back_l := front_l + side_dir * facade_depth
	var back_r := front_r + side_dir * facade_depth
	var wall_pts := PackedVector2Array([front_l, front_r, back_r, back_l])
	canvas.draw_colored_polygon(wall_pts, wall_fill)
	canvas.draw_polyline(wall_pts + PackedVector2Array([front_l]), Color("#1a1410"), 2.0)
	var roof_l := front_l - tangent * 10.0 + side_dir * 6.0
	var roof_r := front_r + tangent * 10.0 + side_dir * 6.0
	var roof_back := (back_l + back_r) * 0.5 + side_dir * 4.0
	canvas.draw_colored_polygon(PackedVector2Array([roof_l, roof_r, roof_back]), roof_fill)
	var door_center := edge + side_dir * (facade_depth * 0.42)
	var door_w := facade_width * 0.28
	var door_h := facade_depth * 0.85
	var door_rect := Rect2(door_center - Vector2(door_w * 0.5, door_h * 0.5), Vector2(door_w, door_h))
	var mat_rect := Rect2(road_center + side_dir * (unit * 0.08) - Vector2(door_w * 0.55, door_h * 0.35), Vector2(door_w * 1.1, door_h * 0.7))
	canvas.draw_rect(mat_rect, Color("#3a3428", 0.85), true)
	canvas.draw_rect(door_rect, Color("#1a1410"), true)
	var door_color := Color("#4a9ed8")
	if highlight_entrance:
		door_color = Color("#9ef0ff")
		canvas.draw_rect(door_rect.grow(5.0), Color("#f0c168", 0.55), true)
		canvas.draw_rect(mat_rect.grow(3.0), Color("#f0c168", 0.35), true)
	canvas.draw_rect(door_rect.grow(-2.0), door_color, true)
	canvas.draw_string(ThemeDB.fallback_font, door_center - Vector2(8, 5), "门", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#f8ecd8"))
	var sign_pos := door_center + tangent * (facade_width * 0.38) + side_dir * (facade_depth * 0.2)
	canvas.draw_rect(Rect2(sign_pos - Vector2(36, 8), Vector2(72, 14)), Color("#2a2218", 0.9), true)
	canvas.draw_string(ThemeDB.fallback_font, sign_pos - Vector2(32, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#f8ecd8"))
	return door_center


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
	return draw_roadside_facade(canvas, road_rect, side.normalized(), building_type, label, highlight_entrance)


static func draw_roadside_building(canvas: CanvasItem, road_rect: Rect2, district_rect: Rect2, building_type: String, label: String) -> void:
	draw_world_building(canvas, road_rect, district_rect, building_type, label, false)


static func draw_loot_pickup(canvas: CanvasItem, center: Vector2, item_id: String, radius: float) -> void:
	var def := ItemDefs.get_def(item_id)
	var color: Color = def.get("color", Color("#8ddf8a"))
	if typeof(color) == TYPE_STRING:
		color = Color(str(color))
	canvas.draw_circle(center, radius + 3.0, Color(0.0, 0.0, 0.0, 0.45))
	canvas.draw_circle(center, radius, color)
	canvas.draw_rect(Rect2(center - Vector2(radius * 0.55, radius * 0.55), Vector2(radius * 1.1, radius * 1.1)), Color("#ffffff", 0.35), false, 2.0)
	var name := ItemDefs.get_item_name(item_id)
	canvas.draw_string(ThemeDB.fallback_font, center + Vector2(-radius * 1.6, radius + 14.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#f0f4f8"))


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
		"market":
			door = Color("#e8a86e")
	canvas.draw_rect(Rect2(center - Vector2(10, 12), Vector2(20, 16)), Color("#2a2f34"), true)
	canvas.draw_rect(Rect2(center - Vector2(4, 2), Vector2(8, 10)), door, true)


static func draw_interior_tile(canvas: CanvasItem, tile_rect: Rect2, blocked: bool, gx: int, gy: int) -> void:
	if blocked:
		canvas.draw_rect(tile_rect, Color("#2a4a32"), true)
		canvas.draw_rect(tile_rect.grow_individual(-2, -2, -2, -2), Color("#39463a"), true)
		return
	var shade := Color("#062a45") if ((gx + gy) % 2 == 0) else Color("#042238")
	canvas.draw_rect(tile_rect, shade, true)
	if hash_cell(gx * 17 + gy, gx, gy) > 0.93:
		canvas.draw_rect(tile_rect.grow_individual(-5, -5, -5, -5), Color("#0a3550", 0.6), true)


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


static func draw_player_marker(canvas: CanvasItem, center: Vector2, unit_scale: float = 1.0) -> void:
	var s := clampf(unit_scale, 0.55, 1.15)
	canvas.draw_rect(Rect2(center - Vector2(4, 4) * s, Vector2(8, 8) * s), Color("#4a9eff"), true)
	canvas.draw_rect(Rect2(center - Vector2(2.5, 6) * s, Vector2(5, 3) * s), Color("#2a5a9a"), true)
