class_name ItemIconFactory
extends RefCounted

const ICON_SIZE := 32
const LOOT_SPRITE_DIR := "res://assets/sprites/loot/"

static var _cache: Dictionary = {}
static var _file_cache: Dictionary = {}


static func get_backpack_texture(size: int = ICON_SIZE) -> Texture2D:
	var key := "backpack_%d" % size
	if _cache.has(key):
		return _cache[key]
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


static func get_texture(item_id: String, size: int = ICON_SIZE) -> Texture2D:
	var key := "%s_%d" % [item_id, size]
	if _cache.has(key):
		return _cache[key]
	var normalized := ItemDefs.normalize_item_id(item_id)
	var file_tex := _load_loot_sprite(normalized)
	if file_tex != null:
		var scaled := _scale_texture(file_tex, size)
		_cache[key] = scaled
		return scaled
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_draw_item_icon(img, item_id, size)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _load_loot_sprite(item_id: String) -> Texture2D:
	if _file_cache.has(item_id):
		return _file_cache[item_id]
	var path := LOOT_SPRITE_DIR + item_id + ".png"
	var tex := ArtAssetLoader.load_texture_alpha_key(path)
	_file_cache[item_id] = tex
	return tex


static func _scale_texture(tex: Texture2D, size: int) -> Texture2D:
	var img := tex.get_image()
	if img == null or img.is_empty():
		return tex
	if img.get_width() == size and img.get_height() == size:
		return tex
	img = img.duplicate()
	img.resize(size, size, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


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
