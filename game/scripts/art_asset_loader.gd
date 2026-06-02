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
	var global_path := ProjectSettings.globalize_path(path)
	if global_path != "" and FileAccess.file_exists(global_path):
		var img := Image.load_from_file(global_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


static func load_texture_alpha_key(
	preferred_path: String,
	threshold: float = 0.12,
	fallback_path: String = "",
) -> Texture2D:
	var cache_key := "%s|%.3f|%s" % [preferred_path, threshold, fallback_path]
	if _alpha_key_cache.has(cache_key):
		return _alpha_key_cache[cache_key]
	var tex := load_texture(preferred_path, fallback_path)
	if tex == null:
		_alpha_key_cache[cache_key] = null
		return null
	var img := tex.get_image()
	if img == null or img.is_empty():
		_alpha_key_cache[cache_key] = tex
		return tex
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
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
	if changed:
		tex = ImageTexture.create_from_image(img)
	_alpha_key_cache[cache_key] = tex
	return tex
