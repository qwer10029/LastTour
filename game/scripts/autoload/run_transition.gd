extends CanvasLayer
## 跨场景持久入场遮罩：在场景切换与主场景初始化期间盖住视口，避免露出灰色空帧。

const BACKGROUND_PATH := "res://assets/menu/difficulty/background.png"
const BACKGROUND_BRIGHTNESS := Color(1.18, 1.18, 1.14, 1.0)
const COLOR_MASK := Color(0.102, 0.118, 0.149, 120.0 / 255.0)
const FALLBACK_FILL := Color(0.043, 0.063, 0.094, 1.0)

var _root: Control
var _fallback: ColorRect
var _background: TextureRect
var _mask: ColorRect
var _covering := false
var _cached_texture: Texture2D


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_nodes()
	hide_cover()


func preload_background() -> void:
	_ensure_texture()


func show_cover() -> void:
	_ensure_texture()
	_covering = true
	visible = true
	if is_instance_valid(_root):
		_root.visible = true
		_root.modulate = Color.WHITE


func is_covering() -> bool:
	return _covering and visible


func fade_out_cover(duration: float = 0.45) -> void:
	if not _covering:
		return
	if not is_instance_valid(_root):
		hide_cover()
		return
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	hide_cover()


func hide_cover() -> void:
	_covering = false
	visible = false
	if is_instance_valid(_root):
		_root.modulate = Color.WHITE


func _build_nodes() -> void:
	_root = Control.new()
	_root.name = "CoverRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_fallback = ColorRect.new()
	_fallback.name = "FallbackFill"
	_fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fallback.color = FALLBACK_FILL
	_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fallback)

	_background = TextureRect.new()
	_background.name = "BackgroundTexture"
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.modulate = BACKGROUND_BRIGHTNESS
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_background)

	_mask = ColorRect.new()
	_mask.name = "ColorMask"
	_mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mask.color = COLOR_MASK
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_mask)


func _ensure_texture() -> void:
	if _cached_texture != null:
		_background.texture = _cached_texture
		return
	_cached_texture = MenuStyles.load_menu_texture(BACKGROUND_PATH)
	if _cached_texture == null:
		_cached_texture = ArtAssetLoader.load_texture_from_disk(BACKGROUND_PATH)
	if _cached_texture != null:
		_background.texture = _cached_texture
