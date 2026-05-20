class_name ArtAssetLoader
extends RefCounted

static func load_texture(preferred_path: String, fallback_path: String = "") -> Texture2D:
	if preferred_path != "" and ResourceLoader.exists(preferred_path):
		return load(preferred_path)
	if fallback_path != "" and ResourceLoader.exists(fallback_path):
		return load(fallback_path)
	return null
