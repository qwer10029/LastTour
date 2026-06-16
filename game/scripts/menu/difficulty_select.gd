extends Control
class_name DifficultySelect

const HOVER_SCALE := Vector2(1.05, 1.05)
const HOVER_DURATION := 0.15
const CARD_DISPLAY_SIZE := Vector2(300, 400)

enum CardKind { EASY, NORMAL, HARD }

const GLOW_COLORS := {
	CardKind.EASY: Color(0.35, 0.95, 0.45, 0.55),
	CardKind.NORMAL: Color(0.35, 0.75, 1.0, 0.55),
	CardKind.HARD: Color(1.0, 0.25, 0.2, 0.6),
}

const CARD_TEXTURE_PATHS := {
	CardKind.EASY: "res://assets/menu/difficulty/card_easy.png",
	CardKind.NORMAL: "res://assets/menu/difficulty/card_normal.png",
	CardKind.HARD: "res://assets/menu/difficulty/card_hard.png",
}

const BACKGROUND_PATH := "res://assets/menu/difficulty/background.png"
const BACKGROUND_BRIGHTNESS := Color(1.18, 1.18, 1.14, 1.0)
const OVERLAY_COLOR := Color(0.0, 0.0, 0.0, 0.16)

static var _texture_cache: Dictionary = {}


static func preload_assets() -> void:
	var paths: Array[String] = [
		BACKGROUND_PATH,
		CARD_TEXTURE_PATHS[CardKind.EASY],
		CARD_TEXTURE_PATHS[CardKind.NORMAL],
		CARD_TEXTURE_PATHS[CardKind.HARD],
	]
	for path in paths:
		if _texture_cache.has(path):
			continue
		var tex := MenuStyles.load_menu_texture(path)
		if tex != null:
			_texture_cache[path] = tex

@onready var background_texture: TextureRect = %BackgroundTexture
@onready var dark_overlay: ColorRect = $BackgroundLayer/DarkOverlay
@onready var title_label: Label = %TitleLabel
@onready var card_easy: TextureButton = %CardEasy
@onready var card_normal: TextureButton = %CardNormal
@onready var card_hard: TextureButton = %CardHard
@onready var glow_easy: Panel = %GlowEasy
@onready var glow_normal: Panel = %GlowNormal
@onready var glow_hard: Panel = %GlowHard
@onready var back_button: Button = %BackButton

var _scale_tweens: Dictionary = {}
var _glow_tweens: Dictionary = {}


func _ready() -> void:
	preload_assets()
	_play_music_cue("day_exploration", 0.8)
	_ensure_background_texture()
	MenuStyles.style_title(title_label, 42)
	_style_back_button()

	_setup_card(card_easy, glow_easy, CardKind.EASY, GameManager.Difficulty.EASY)
	_setup_card(card_normal, glow_normal, CardKind.NORMAL, GameManager.Difficulty.NORMAL)
	_setup_card(card_hard, glow_hard, CardKind.HARD, GameManager.Difficulty.HARD)

	back_button.pressed.connect(_on_back_pressed)


func _play_music_cue(cue_id: String, fade_sec: float = -1.0) -> void:
	var music := get_tree().root.get_node_or_null("MusicManager") if get_tree() != null else null
	if music != null and music.has_method("play_cue"):
		music.play_cue(cue_id, fade_sec)


func _ensure_background_texture() -> void:
	if is_instance_valid(background_texture):
		background_texture.modulate = BACKGROUND_BRIGHTNESS
	if is_instance_valid(dark_overlay):
		dark_overlay.color = OVERLAY_COLOR
	if not is_instance_valid(background_texture):
		return
	var tex := _load_texture(BACKGROUND_PATH)
	if tex != null:
		background_texture.texture = tex
	else:
		push_warning("难度背景加载失败: %s" % BACKGROUND_PATH)


func _load_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	var tex := MenuStyles.load_menu_texture(path)
	if tex != null:
		_texture_cache[path] = tex
	return tex


func _load_card_texture(kind: CardKind) -> Texture2D:
	return _load_texture(CARD_TEXTURE_PATHS[kind])


func _setup_card(card: TextureButton, glow: Panel, kind: CardKind, difficulty: int) -> void:
	var slot := card.get_parent() as Control
	var tex := _load_card_texture(kind)
	if tex == null:
		push_warning("难度卡片加载失败: %s" % CARD_TEXTURE_PATHS[kind])
	else:
		card.texture_normal = tex

	card.ignore_texture_size = true
	# 统一填满 300×400，避免不同宽高比导致可见边长不一致
	card.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.custom_minimum_size = CARD_DISPLAY_SIZE
	_make_card_button_transparent(card)
	if slot:
		slot.custom_minimum_size = CARD_DISPLAY_SIZE

	card.pivot_offset = CARD_DISPLAY_SIZE * 0.5
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.scale = Vector2.ONE
	card.modulate = Color.WHITE

	_apply_glow_style(glow, kind)
	glow.modulate.a = 0.0
	glow.visible = true

	card.mouse_entered.connect(func() -> void:
		_on_card_hover_enter(card, glow, kind)
	)
	card.mouse_exited.connect(func() -> void:
		_on_card_hover_exit(card, glow, kind)
	)
	card.pressed.connect(func() -> void:
		_select_difficulty(difficulty)
	)


func _make_card_button_transparent(card: TextureButton) -> void:
	var empty := StyleBoxEmpty.new()
	card.add_theme_stylebox_override("normal", empty)
	card.add_theme_stylebox_override("hover", empty)
	card.add_theme_stylebox_override("pressed", empty)
	card.add_theme_stylebox_override("disabled", empty)
	card.add_theme_stylebox_override("focus", empty)


func _apply_glow_style(glow: Panel, kind: CardKind) -> void:
	var color: Color = GLOW_COLORS[kind]
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(color.r, color.g, color.b, 0.72)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.shadow_color = color
	style.shadow_size = 20
	style.expand_margin_left = 8
	style.expand_margin_top = 8
	style.expand_margin_right = 8
	style.expand_margin_bottom = 8
	glow.add_theme_stylebox_override("panel", style)


func _style_back_button() -> void:
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_button.custom_minimum_size = Vector2(200, 44)
	back_button.add_theme_font_size_override("font_size", 16)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.09, 0.13, 0.72)
	normal.border_color = Color(0.35, 0.45, 0.58, 0.45)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.10, 0.14, 0.20, 0.88)
	hover.border_color = Color(0.55, 0.68, 0.82, 0.65)

	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.05, 0.07, 0.10, 0.95)

	back_button.add_theme_stylebox_override("normal", normal)
	back_button.add_theme_stylebox_override("hover", hover)
	back_button.add_theme_stylebox_override("pressed", pressed)
	back_button.add_theme_stylebox_override("focus", hover)
	back_button.add_theme_color_override("font_color", Color("#b8c8d8"))
	back_button.add_theme_color_override("font_hover_color", Color("#e8f0f8"))


func _on_card_hover_enter(card: TextureButton, glow: Panel, _kind: CardKind) -> void:
	_tween_scale(card, HOVER_SCALE)
	_tween_glow(glow, 1.0)


func _on_card_hover_exit(card: TextureButton, glow: Panel, _kind: CardKind) -> void:
	_tween_scale(card, Vector2.ONE)
	_tween_glow(glow, 0.0)


func _tween_scale(card: TextureButton, target: Vector2) -> void:
	_kill_tween(_scale_tweens, card)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", target, HOVER_DURATION)
	_scale_tweens[card] = tween


func _tween_glow(glow: Panel, alpha: float) -> void:
	_kill_tween(_glow_tweens, glow)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(glow, "modulate:a", alpha, HOVER_DURATION)
	_glow_tweens[glow] = tween


func _kill_tween(store: Dictionary, key: Variant) -> void:
	if not store.has(key):
		return
	var tween: Tween = store[key]
	if tween != null and tween.is_valid():
		tween.kill()
	store.erase(key)


func _select_difficulty(value: int) -> void:
	var manager := _game_manager()
	if manager == null:
		return
	manager.difficulty = value
	manager.go_to_squad_select()


func _on_back_pressed() -> void:
	var manager := _game_manager()
	if manager != null:
		manager.go_to_main_menu()


func _game_manager() -> Node:
	return get_tree().root.get_node_or_null("GameManager") if get_tree() != null else null
