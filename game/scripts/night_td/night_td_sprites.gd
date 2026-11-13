class_name NightTdSprites
extends RefCounted

const TOWER_DIR := "res://assets/sprites/night_td/towers/"
const ENEMY_DIR := "res://assets/sprites/night_td/enemies/"
const THUNDER_LEITING_ENEMY_PATH := "res://assets/sprites/npc/npc_thunder_leiting.png"
## 预烘焙的抠图结果（tools/bake_night_td_sprites.gd 生成，与运行时抠图逐像素一致）。
## 存在时直接加载，跳过运行时逐像素 GDScript 抠图（每张 1024² 图 1.5–3.5 秒）。
const BAKED_DIR := "res://assets/sprites/night_td/baked/"

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


const PRELOAD_TOWER_IDS: Array[String] = [
	"jammer", "barrier", "trap", "cryo_beacon", "hacker", "sniper", "splash",
]


static func preload_all_towers() -> void:
	for type_id in PRELOAD_TOWER_IDS:
		tower_texture(type_id)


static func is_tower_texture_cached(type_id: String) -> bool:
	return _cache.has("tower|%s" % type_id)


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
	var file_name := "tower_%s.png" % _tower_file_id(type_id)
	var tex := _load_baked(file_name)
	if tex == null:
		tex = ArtAssetLoader.load_texture_loot_alpha_key(TOWER_DIR + file_name)
	_cache[cache_key] = tex
	return tex


static func enemy_texture(type_id: String) -> Texture2D:
	var cache_key := "enemy|%s" % type_id
	if _cache.has(cache_key):
		return _cache[cache_key]
	var path := ENEMY_DIR + "enemy_%s.png" % type_id
	var tex: Texture2D = null
	if type_id == "thunder_leiting":
		path = THUNDER_LEITING_ENEMY_PATH
	else:
		tex = _load_baked("enemy_%s.png" % type_id)
	if tex == null:
		tex = ArtAssetLoader.load_texture_loot_alpha_key(path)
	_cache[cache_key] = tex
	return tex


static func _load_baked(file_name: String) -> Texture2D:
	var path := BAKED_DIR + file_name
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	return res as Texture2D


## 供烘焙工具使用：源图 → 烘焙图。thunder_leiting 源图自带透明，运行时本就不抠图，无需烘焙。
static func bake_sources() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for dir_path in [TOWER_DIR, ENEMY_DIR]:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for file_name in dir.get_files():
			if not file_name.ends_with(".png"):
				continue
			result.append({"source": dir_path + file_name, "baked": BAKED_DIR + file_name})
	return result


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
