class_name ArtAssetLoader
extends RefCounted

static var _alpha_key_cache: Dictionary = {}


static func load_texture(preferred_path: String, fallback_path: String = "") -> Texture2D:
	var tex := _try_load_texture_path(preferred_path)
	if tex != null:
		return tex
	return _try_load_texture_path(fallback_path)


static func _try_load_texture_path(path: String) -> Texture2D:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res
	return load_texture_from_disk(path)


static func load_texture_from_disk(path: String) -> Texture2D:
	var global_path := ProjectSettings.globalize_path(path)
	if global_path == "" or not FileAccess.file_exists(global_path):
		return null
	var img := Image.load_from_file(global_path)
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


static func _image_has_visible_pixels(img: Image, min_alpha: float = 0.02) -> bool:
	if img == null or img.is_empty():
		return false
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > min_alpha:
				return true
	return false


static func texture_has_visible_pixels(tex: Texture2D, min_alpha: float = 0.02) -> bool:
	if tex == null:
		return false
	var img := tex.get_image()
	return _image_has_visible_pixels(img, min_alpha)


static func _pixel_should_key_road_background(c: Color) -> bool:
	if c.a <= 0.0:
		return false
	# 只去亮底/棋盘格，不抠深色（弹坑、阴影、沥青裂缝等会误伤）
	if c.r >= 0.92 and c.g >= 0.92 and c.b >= 0.92:
		return true
	var max_c := maxf(c.r, maxf(c.g, c.b))
	var min_c := minf(c.r, minf(c.g, c.b))
	var luminance := (c.r + c.g + c.b) / 3.0
	var saturation := max_c - min_c
	var neutral := absf(c.r - c.g) <= 0.035 and absf(c.g - c.b) <= 0.035
	# 去掉棋盘格/灰底（含深灰格），保留带色相的沥青路面
	if neutral and saturation <= 0.06 and luminance >= 0.32:
		return true
	return false


static func apply_road_background_key(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.is_empty():
		return tex
	if img.get_format() != Image.FORMAT_RGBA8:
		img = img.duplicate()
		img.convert(Image.FORMAT_RGBA8)
	else:
		img = img.duplicate()
	var changed := false
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			if not _pixel_should_key_road_background(c):
				continue
			c.a = 0.0
			img.set_pixel(x, y, c)
			changed = true
	if not changed:
		return tex
	return ImageTexture.create_from_image(img)


static func apply_black_alpha_key(tex: Texture2D, threshold: float = 0.12) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.is_empty():
		return tex
	if img.get_format() != Image.FORMAT_RGBA8:
		img = img.duplicate()
		img.convert(Image.FORMAT_RGBA8)
	else:
		img = img.duplicate()
	var changed := false
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			if c.r <= threshold and c.g <= threshold and c.b <= threshold:
				c.a = 0.0
				img.set_pixel(x, y, c)
				changed = true
	if not changed:
		return tex
	return ImageTexture.create_from_image(img)


static func _color_near(a: Color, b: Color, tolerance: float) -> bool:
	return absf(a.r - b.r) <= tolerance and absf(a.g - b.g) <= tolerance and absf(a.b - b.b) <= tolerance


## 用左上角背景色去底（精灵表灰底）；容差宜小，避免误抠头盔灰。
static func apply_sampled_background_key(tex: Texture2D, tolerance: float = 0.055) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.is_empty():
		return tex
	if img.get_format() != Image.FORMAT_RGBA8:
		img = img.duplicate()
		img.convert(Image.FORMAT_RGBA8)
	else:
		img = img.duplicate()
	var bg := img.get_pixel(0, 0)
	var changed := false
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			if _color_near(c, bg, tolerance):
				c.a = 0.0
				img.set_pixel(x, y, c)
				changed = true
	if not changed:
		return tex
	return ImageTexture.create_from_image(img)


static func apply_flood_background_key(tex: Texture2D, tolerance: float = 0.055) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.is_empty():
		return tex
	if img.get_format() != Image.FORMAT_RGBA8:
		img = img.duplicate()
		img.convert(Image.FORMAT_RGBA8)
	else:
		img = img.duplicate()
	var bg := img.get_pixel(0, 0)
	var w := img.get_width()
	var h := img.get_height()
	var visited := PackedByteArray()
	visited.resize(w * h)
	var queue: Array[Vector2i] = []

	var try_seed := func(pos: Vector2i) -> void:
		if pos.x < 0 or pos.y < 0 or pos.x >= w or pos.y >= h:
			return
		var idx := pos.y * w + pos.x
		if visited[idx] != 0:
			return
		var c := img.get_pixel(pos.x, pos.y)
		if c.a <= 0.0 or not _color_near(c, bg, tolerance):
			return
		visited[idx] = 1
		queue.append(pos)

	for x in range(w):
		try_seed.call(Vector2i(x, 0))
		try_seed.call(Vector2i(x, h - 1))
	for y in range(h):
		try_seed.call(Vector2i(0, y))
		try_seed.call(Vector2i(w - 1, y))

	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		var c := img.get_pixel(pos.x, pos.y)
		c.a = 0.0
		img.set_pixel(pos.x, pos.y, c)
		for dir in dirs:
			try_seed.call(pos + dir)

	return ImageTexture.create_from_image(img)


static func load_texture_icon_alpha_key(
	preferred_path: String,
	tolerance: float = 0.055,
	fallback_path: String = "",
) -> Texture2D:
	var cache_key := "icon|%s|%.3f|%s" % [preferred_path, tolerance, fallback_path]
	if _alpha_key_cache.has(cache_key):
		return _alpha_key_cache[cache_key]
	var tex := load_texture(preferred_path, fallback_path)
	if tex == null:
		_alpha_key_cache[cache_key] = null
		return null
	tex = apply_flood_background_key(tex, tolerance)
	_alpha_key_cache[cache_key] = tex
	return tex


## 角色精灵：仅从边缘洪泛去除采样背景色，不抠深色像素。
static func load_texture_sprite_alpha_key(
	preferred_path: String,
	_threshold: float = 0.12,
	fallback_path: String = "",
) -> Texture2D:
	var cache_key := "sprite_v2|%s|%s" % [preferred_path, fallback_path]
	if _alpha_key_cache.has(cache_key):
		return _alpha_key_cache[cache_key]
	var tex := load_texture(preferred_path, fallback_path)
	if tex == null:
		_alpha_key_cache[cache_key] = null
		return null
	var keyed := apply_flood_background_key(tex)
	if not texture_has_visible_pixels(keyed):
		keyed = apply_sampled_background_key(tex)
	if not texture_has_visible_pixels(keyed):
		keyed = tex
	_alpha_key_cache[cache_key] = keyed
	return keyed


static func load_texture_alpha_key(
	preferred_path: String,
	_threshold: float = 0.12,
	fallback_path: String = "",
) -> Texture2D:
	# 素材 PNG 应已带透明通道；不再对深色像素做 alpha key
	return load_texture(preferred_path, fallback_path)


static func load_texture_road_alpha_key(preferred_path: String, fallback_path: String = "") -> Texture2D:
	var cache_key := "road_v3|%s|%s" % [preferred_path, fallback_path]
	if _alpha_key_cache.has(cache_key):
		return _alpha_key_cache[cache_key]
	var tex := load_texture(preferred_path, fallback_path)
	if tex == null:
		_alpha_key_cache[cache_key] = null
		return null
	var keyed := apply_road_background_key(tex)
	if not texture_has_visible_pixels(keyed):
		keyed = tex
	_alpha_key_cache[cache_key] = keyed
	return keyed


static func clear_road_alpha_cache() -> void:
	for key in _alpha_key_cache.keys():
		if str(key).begins_with("road"):
			_alpha_key_cache.erase(key)


static func clear_alpha_cache() -> void:
	_alpha_key_cache.clear()
