class_name NightTdSprites
extends RefCounted

const TOWER_DIR := "res://assets/sprites/night_td/towers/"
const ENEMY_DIR := "res://assets/sprites/night_td/enemies/"

const DEFAULT_ENEMY_ART_FACE := Vector2.RIGHT
const DEFAULT_TOWER_ART_FACE := Vector2.UP

const ENEMY_ART_FACE: Dictionary = {
	"drone": Vector2.DOWN,
	"scout": Vector2.RIGHT,
	"saboteur": Vector2.RIGHT,
	"sprinter": Vector2.RIGHT,
	"repair_mender": Vector2.RIGHT,
	"shepherd": Vector2.RIGHT,
	"armored": Vector2.UP,
	"heavy": Vector2.UP,
	"tank": Vector2.UP,
	"terminal_overseer": Vector2.RIGHT,
}

const TOWER_ART_FACE: Dictionary = {
	"sniper": Vector2.UP,
	"jammer": Vector2.UP,
	"splash": Vector2.UP,
	"cryo_beacon": Vector2.UP,
	"hacker": Vector2.UP,
	"barrier": Vector2.UP,
	"trap": Vector2.UP,
}

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()
	ArtAssetLoader.clear_alpha_cache()


static func _tower_file_id(type_id: String) -> String:
	if type_id == "sniper":
		return "cannon"
	return type_id


static func enemy_art_face_dir(type_id: String) -> Vector2:
	var raw: Variant = ENEMY_ART_FACE.get(type_id, DEFAULT_ENEMY_ART_FACE)
	if raw is Vector2:
		return raw as Vector2
	return DEFAULT_ENEMY_ART_FACE


static func tower_art_face_dir(type_id: String) -> Vector2:
	var raw: Variant = TOWER_ART_FACE.get(type_id, DEFAULT_TOWER_ART_FACE)
	if raw is Vector2:
		return raw as Vector2
	return DEFAULT_TOWER_ART_FACE


static func rotation_for_face(face_dir: Vector2, art_face_dir: Vector2) -> float:
	if face_dir.length_squared() < 0.0001:
		return 0.0
	return face_dir.normalized().angle() - art_face_dir.angle()


static func tower_texture(type_id: String) -> Texture2D:
	var cache_key := "tower|%s" % type_id
	if _cache.has(cache_key):
		return _cache[cache_key]
	var path := TOWER_DIR + "tower_%s.png" % _tower_file_id(type_id)
	var tex := ArtAssetLoader.load_texture_loot_alpha_key(path)
	_cache[cache_key] = tex
	return tex


static func enemy_texture(type_id: String) -> Texture2D:
	var cache_key := "enemy|%s" % type_id
	if _cache.has(cache_key):
		return _cache[cache_key]
	var path := ENEMY_DIR + "enemy_%s.png" % type_id
	var tex := ArtAssetLoader.load_texture_loot_alpha_key(path)
	_cache[cache_key] = tex
	return tex


static func draw_entity_sprite(
	canvas: CanvasItem,
	center: Vector2,
	tex: Texture2D,
	target_diameter: float,
	modulate: Color = Color.WHITE,
	face_dir: Vector2 = Vector2.ZERO,
	art_face_dir: Vector2 = Vector2.RIGHT,
) -> bool:
	if tex == null:
		return false
	var img_size := tex.get_size()
	if img_size.x <= 0.0 or img_size.y <= 0.0:
		return false
	var scale := target_diameter / float(maxi(img_size.x, img_size.y))
	var w := img_size.x * scale
	var h := img_size.y * scale
	var angle := rotation_for_face(face_dir, art_face_dir)
	canvas.draw_set_transform(center, angle, Vector2.ONE)
	canvas.draw_texture_rect(tex, Rect2(-w * 0.5, -h * 0.5, w, h), false, modulate)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true
