class_name ItemIconFactory
extends RefCounted

const ICON_SIZE := 32
const LOOT_SPRITE_DIR := "res://assets/sprites/loot/"
const QUEST_BATTERY_SPRITE_PATH := "res://assets/sprites/loot/quest_battery.png"
const BACKPACK_SPRITE_PATH := "res://assets/sprites/ui/backpack.png"
const ELEVATOR_CONSOLE_SPRITE_PATH := "res://assets/sprites/ui/elevator_console.png"

static var _cache: Dictionary = {}
static var _file_cache: Dictionary = {}


static func get_backpack_texture(size: int = ICON_SIZE) -> Texture2D:
	var key := "backpack_%d" % size
	if _cache.has(key):
		return _cache[key]
	var file_tex := _load_backpack_sprite()
	if file_tex != null:
		var scaled := _scale_texture(file_tex, size)
		_cache[key] = scaled
		return scaled
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var body := Color("#5a7890")
	var dark := Color("#2a3848")
	var light := Color("#9ec8e8")
	var pack := Rect2i(7, 11, size - 14, size - 15)
	_fill_round_rect(img, pack, body, dark)
	_fill_rect(img, Rect2i(9, 8, size - 18, 5), light)
	_fill_rect(img, Rect2i(11, 6, 3, 7), dark)
	_fill_rect(img, Rect2i(size - 14, 6, 3, 7), dark)
	_fill_rect(img, Rect2i(pack.position.x + 4, pack.position.y + 6, pack.size.x - 8, 2), dark)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _load_backpack_sprite() -> Texture2D:
	if _file_cache.has("backpack"):
		return _file_cache["backpack"]
	var tex := ArtAssetLoader.load_texture_icon_alpha_key(BACKPACK_SPRITE_PATH)
	_file_cache["backpack"] = tex
	return tex


static func get_elevator_console_texture(size: int = ICON_SIZE) -> Texture2D:
	var key := "elevator_console_%d" % size
	if _cache.has(key):
		return _cache[key]
	var file_tex := _load_elevator_console_sprite()
	if file_tex != null:
		var scaled := _scale_texture(file_tex, size)
		_cache[key] = scaled
		return scaled
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var frame := Color("#2a3848")
	var panel := Color("#1a2838")
	var screen := Color("#3a5870")
	var accent := Color("#f0c168")
	var light := Color("#9ec8e8")
	var body := Rect2i(4, 5, size - 8, size - 8)
	_fill_round_rect(img, body, panel, frame)
	var screen_rect := Rect2i(body.position.x + 3, body.position.y + 3, body.size.x - 6, body.size.y - 10)
	_fill_rect(img, screen_rect, screen)
	_fill_rect(img, Rect2i(screen_rect.position.x + 2, screen_rect.position.y + 2, screen_rect.size.x - 4, 3), light)
	_fill_rect(img, Rect2i(body.position.x + 5, body.end.y - 5, 5, 3), accent)
	_fill_rect(img, Rect2i(body.end.x - 10, body.end.y - 5, 5, 3), accent)
	_fill_rect(img, Rect2i(body.position.x + body.size.x / 2 - 2, body.end.y - 5, 4, 3), Color("#6a9a72"))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _load_elevator_console_sprite() -> Texture2D:
	if _file_cache.has("elevator_console"):
		return _file_cache["elevator_console"]
	var tex := ArtAssetLoader.load_texture_icon_alpha_key(ELEVATOR_CONSOLE_SPRITE_PATH)
	_file_cache["elevator_console"] = tex
	return tex


static func get_texture(item_id: String, size: int = ICON_SIZE) -> Texture2D:
	if item_id == "quest_battery" or item_id.begins_with("quest:sentinel_battery"):
		return get_quest_battery_texture(size)
	if item_id.begins_with("evidence:") or item_id == "evidence":
		return _fallback_evidence_texture(size)
	if item_id.begins_with("quest:"):
		return get_quest_item_texture(item_id, size)
	var key := "loot_v3_%s_%d" % [item_id, size]
	if _cache.has(key):
		return _cache[key]
	var normalized := ItemDefs.normalize_item_id(item_id)
	var file_tex := _load_loot_sprite(normalized)
	if file_tex != null:
		var scaled := _scale_loot_texture(file_tex, size, normalized)
		_cache[key] = scaled
		return scaled
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_draw_item_icon(img, item_id, size)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func get_quest_battery_texture(size: int = ICON_SIZE) -> Texture2D:
	var key := "quest_battery_%d" % size
	if _cache.has(key):
		return _cache[key]
	var file_tex := _load_quest_battery_sprite()
	if file_tex != null:
		var scaled := _scale_texture_fit_max(file_tex, size)
		_cache[key] = scaled
		return scaled
	var tex := _fallback_quest_battery_texture(size)
	_cache[key] = tex
	return tex


static func get_quest_item_texture(item_id: String, size: int = ICON_SIZE) -> Texture2D:
	var key := "quest_item_%s_%d" % [item_id, size]
	if _cache.has(key):
		return _cache[key]
	var file_tex := _load_quest_item_sprite(item_id)
	if file_tex != null:
		var scaled := _scale_texture_fit_max(file_tex, size)
		_cache[key] = scaled
		return scaled
	var fallback_id := item_id.replace("quest:", "")
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_draw_item_icon(img, fallback_id, size)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _quest_sprite_path(item_id: String) -> String:
	var slug := item_id.replace("quest:", "quest_")
	return LOOT_SPRITE_DIR + slug + ".png"


static func _load_quest_item_sprite(item_id: String) -> Texture2D:
	if _file_cache.has(item_id):
		return _file_cache[item_id]
	var path := _quest_sprite_path(item_id)
	var tex := ArtAssetLoader.load_texture_loot_alpha_key(path)
	_file_cache[item_id] = tex
	return tex


static func _load_quest_battery_sprite() -> Texture2D:
	if _file_cache.has("quest_battery"):
		return _file_cache["quest_battery"]
	var tex := ArtAssetLoader.load_texture_icon_alpha_key(QUEST_BATTERY_SPRITE_PATH)
	_file_cache["quest_battery"] = tex
	return tex


static func _fallback_quest_battery_texture(size: int) -> Texture2D:
	var w := maxi(8, int(round(float(size) * 0.72)))
	var h := maxi(18, int(round(float(size) * 0.92)))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var shell := Color("#3a5870")
	var body := Color("#58b8dc")
	var dark := Color("#2a5870")
	var light := Color("#c8ecff")
	var cap := Color("#d8f4ff")
	var mid_x := w >> 1
	_fill_rect(img, Rect2i(mid_x - 2, 0, 4, 2), cap)
	_fill_rect(img, Rect2i(mid_x - 1, 2, 2, 1), shell)
	var body_rect := Rect2i(1, 3, w - 2, h - 5)
	_fill_round_rect(img, body_rect, body, shell)
	_fill_rect(img, Rect2i(body_rect.position.x + 1, body_rect.position.y + 2, body_rect.size.x - 2, body_rect.size.y - 4), dark.lightened(0.08))
	_fill_rect(img, Rect2i(body_rect.position.x + 2, body_rect.position.y + 3, 2, body_rect.size.y - 8), light)
	_fill_rect(img, Rect2i(1, h - 2, w - 2, 2), shell.darkened(0.15))
	return ImageTexture.create_from_image(img)


static func _fallback_evidence_texture(size: int) -> Texture2D:
	var key := "evidence_%d" % size
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var paper := Color("#ffd966")
	var dark := Color("#6f5430")
	var line := Color("#b68d3c")
	var fold := Color("#fff0a8")
	var rect := Rect2i(7, 4, size - 14, size - 8)
	_fill_rect(img, rect, paper)
	_fill_rect(img, Rect2i(rect.position.x, rect.position.y, rect.size.x, 2), dark)
	_fill_rect(img, Rect2i(rect.position.x, rect.end.y - 2, rect.size.x, 2), dark)
	_fill_rect(img, Rect2i(rect.position.x, rect.position.y, 2, rect.size.y), dark)
	_fill_rect(img, Rect2i(rect.end.x - 2, rect.position.y, 2, rect.size.y), dark)
	_fill_rect(img, Rect2i(rect.end.x - 8, rect.position.y + 2, 6, 6), fold)
	_fill_rect(img, Rect2i(rect.position.x + 4, rect.position.y + 9, rect.size.x - 8, 2), line)
	_fill_rect(img, Rect2i(rect.position.x + 4, rect.position.y + 14, rect.size.x - 10, 2), line)
	_fill_rect(img, Rect2i(rect.position.x + 4, rect.position.y + 19, rect.size.x - 12, 2), line)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func quest_battery_draw_size(base_size: int) -> Vector2:
	var tex := get_quest_battery_texture(base_size)
	if tex == null:
		return Vector2(float(base_size) * 0.72, float(base_size) * 0.92)
	return Vector2(float(tex.get_width()), float(tex.get_height()))


static func _scale_texture_fit_max(tex: Texture2D, max_dim: int) -> Texture2D:
	var img := tex.get_image()
	if img == null or img.is_empty():
		return tex
	var w := img.get_width()
	var h := img.get_height()
	if w <= 0 or h <= 0:
		return tex
	var scale := float(max_dim) / float(maxi(w, h))
	var nw := maxi(1, int(round(float(w) * scale)))
	var nh := maxi(1, int(round(float(h) * scale)))
	if nw == w and nh == h:
		return tex
	img = img.duplicate()
	img.resize(nw, nh, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


static func loot_draw_id(item_id: String) -> String:
	if item_id.begins_with("quest:sentinel_battery") or item_id == "sentinel_battery":
		return "quest_battery"
	if item_id.begins_with("evidence:"):
		return "evidence"
	if item_id.begins_with("quest:"):
		return item_id
	return item_id


static func loot_display_name(item_id: String, fallback: String = "") -> String:
	if fallback != "":
		return fallback
	if item_id.begins_with("evidence:"):
		var evidence_id := item_id.substr("evidence:".length())
		return ItemDefs.evidence_title_of(evidence_id)
	if item_id.begins_with("quest:sentinel_battery") or item_id == "sentinel_battery":
		return "能量电池"
	if item_id.begins_with("quest:chronicler_memory"):
		return "存储模块"
	if item_id.begins_with("quest:"):
		return "任务物品"
	return ItemDefs.get_item_name(item_id)


static func _load_loot_sprite(item_id: String) -> Texture2D:
	var sprite_id := item_id
	if item_id.begins_with("blueprint:"):
		sprite_id = "blueprint_armory"
	if _file_cache.has(sprite_id):
		return _file_cache[sprite_id]
	var path := LOOT_SPRITE_DIR + sprite_id + ".png"
	var tex := ArtAssetLoader.load_texture_loot_alpha_key(path)
	_file_cache[sprite_id] = tex
	return tex


static func _loot_icon_fill_ratio(item_id: String) -> float:
	match item_id:
		"wood", "fuel":
			return 0.96
		_:
			return 0.90


static func _alpha_centroid(img: Image) -> Vector2:
	var w := img.get_width()
	var h := img.get_height()
	var sum_x := 0.0
	var sum_y := 0.0
	var weight_sum := 0.0
	for y in range(h):
		for x in range(w):
			var alpha := img.get_pixel(x, y).a
			if alpha <= 0.04:
				continue
			var weight := float(alpha)
			sum_x += float(x) * weight
			sum_y += float(y) * weight
			weight_sum += weight
	if weight_sum <= 0.0:
		return Vector2(float(w) * 0.5, float(h) * 0.5)
	return Vector2(sum_x / weight_sum, sum_y / weight_sum)


static func _scale_loot_texture(tex: Texture2D, size: int, item_id: String = "") -> Texture2D:
	var img := tex.get_image()
	if img == null or img.is_empty():
		return tex
	img = img.duplicate()
	var used := img.get_used_rect()
	if used.size != Vector2i.ZERO:
		img = img.get_region(used)
	var src_w := img.get_width()
	var src_h := img.get_height()
	if src_w <= 0 or src_h <= 0:
		return tex
	var fill := _loot_icon_fill_ratio(item_id)
	var target := maxi(1, int(round(float(size) * fill)))
	var scale := float(target) / float(maxi(src_w, src_h))
	var nw := maxi(1, int(round(float(src_w) * scale)))
	var nh := maxi(1, int(round(float(src_h) * scale)))
	if nw != src_w or nh != src_h:
		img.resize(nw, nh, Image.INTERPOLATE_NEAREST)
	var centroid := _alpha_centroid(img)
	var canvas := Image.create(size, size, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var dest := Vector2i(
		int(round(float(size) * 0.5 - centroid.x)),
		int(round(float(size) * 0.5 - centroid.y)),
	)
	canvas.blit_rect(img, Rect2i(0, 0, nw, nh), dest)
	return ImageTexture.create_from_image(canvas)


static func _scale_texture(tex: Texture2D, size: int) -> Texture2D:
	return _scale_loot_texture(tex, size)


static func _draw_item_icon(img: Image, item_id: String, size: int) -> void:
	var def: Dictionary = ItemDefs.get_def(item_id)
	var main_color: Color = def.get("color", Color.WHITE)
	var dark := main_color.darkened(0.35)
	var light := main_color.lightened(0.2)
	var half := size >> 1
	var normalized := ItemDefs.normalize_item_id(item_id)
	match normalized:
		"fuel":
			_fill_round_rect(img, Rect2i(7, 5, size - 14, size - 10), main_color, dark)
			_fill_rect(img, Rect2i(10, 9, size - 20, 4), light)
			_fill_rect(img, Rect2i(half - 2, 3, 4, 6), dark)
		"supplies":
			_fill_circle(img, half, half + 2, size / 3, main_color)
			_fill_rect(img, Rect2i(half - 3, 4, 6, size / 3), light)
		"wood":
			_fill_rect(img, Rect2i(5, 12, size - 10, 8), dark)
			_fill_rect(img, Rect2i(7, 8, size - 14, 10), main_color)
			_fill_rect(img, Rect2i(9, 6, size - 18, 6), light)
		"parts":
			_fill_circle(img, half, half, 9, dark)
			_fill_circle(img, half, half, 5, main_color)
			_fill_rect(img, Rect2i(half - 2, 4, 4, size - 8), light)
			_fill_rect(img, Rect2i(4, half - 2, size - 8, 4), light)
		"scrap":
			_fill_rect(img, Rect2i(7, 7, size - 14, size - 14), main_color)
			_fill_rect(img, Rect2i(9, 9, size - 18, 3), dark)
			_fill_rect(img, Rect2i(9, size - 12, size - 18, 3), dark)
			_fill_rect(img, Rect2i(half - 2, 5, 4, size - 10), light)
		_:
			_fill_circle(img, half, half, size / 3, main_color)


static func _fill_rect(img: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, color)


static func _fill_round_rect(img: Image, rect: Rect2i, fill: Color, border: Color) -> void:
	_fill_rect(img, rect, fill)
	_fill_rect(img, Rect2i(rect.position.x, rect.position.y, rect.size.x, 2), border)


static func _fill_circle(img: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	var r2 := radius * radius
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= r2 and x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, color)
