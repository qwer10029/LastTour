extends Control
class_name SquadSelect

const HOVER_SCALE := Vector2(1.05, 1.05)
const HOVER_DURATION := 0.15
const CARD_MAX_WIDTH := 560.0

enum CardKind { SCAVENGER, LOGISTICS }

const GLOW_COLORS := {
	CardKind.SCAVENGER: Color(0.82, 0.62, 0.35, 0.58),
	CardKind.LOGISTICS: Color(0.35, 0.78, 1.0, 0.58),
}

const CARD_TEXTURE_PATHS := {
	CardKind.SCAVENGER: "res://assets/menu/squad/card_scavenger.png",
	CardKind.LOGISTICS: "res://assets/menu/squad/card_logistics.png",
}

const SQUAD_IDS := {
	CardKind.SCAVENGER: "scavenger",
	CardKind.LOGISTICS: "logistics",
}

const BACKGROUND_PATH := "res://assets/menu/difficulty/background.png"
const BACKGROUND_BRIGHTNESS := Color(1.18, 1.18, 1.14, 1.0)
const OVERLAY_COLOR := Color(0.0, 0.0, 0.0, 0.16)

static var _texture_cache: Dictionary = {}


static func preload_assets() -> void:
	var paths: Array[String] = [
		BACKGROUND_PATH,
		CARD_TEXTURE_PATHS[CardKind.SCAVENGER],
		CARD_TEXTURE_PATHS[CardKind.LOGISTICS],
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
@onready var difficulty_label: Label = %DifficultyLabel
@onready var hint_label: Label = %HintLabel
@onready var card_scavenger: TextureRect = %CardScavenger
@onready var card_logistics: TextureRect = %CardLogistics
@onready var glow_scavenger: Panel = %GlowScavenger
@onready var glow_logistics: Panel = %GlowLogistics
@onready var back_button: Button = %BackButton

var _scale_tweens: Dictionary = {}
var _glow_tweens: Dictionary = {}


func _ready() -> void:
	preload_assets()
	_play_music_cue("menu_select", 0.8)
	_ensure_background_texture()
	MenuStyles.style_title(title_label, 40)
	MenuStyles.style_subtitle(difficulty_label)
	MenuStyles.style_subtitle(hint_label)
	difficulty_label.text = "当前难度：%s" % GameManager.get_difficulty_name()
	_style_back_button()

	_setup_card(card_scavenger, glow_scavenger, CardKind.SCAVENGER)
	_setup_card(card_logistics, glow_logistics, CardKind.LOGISTICS)

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
		push_warning("分队背景加载失败: %s" % BACKGROUND_PATH)


func _load_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	var tex := MenuStyles.load_menu_texture(path)
	if tex != null:
		_texture_cache[path] = tex
	return tex


func _load_card_texture(kind: CardKind) -> Texture2D:
	return _load_texture(CARD_TEXTURE_PATHS[kind])


func _card_display_size(tex: Texture2D) -> Vector2:
	var tex_size := tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return Vector2(CARD_MAX_WIDTH, CARD_MAX_WIDTH / 3.46)
	var width_scale := CARD_MAX_WIDTH / tex_size.x
	return Vector2(CARD_MAX_WIDTH, tex_size.y * width_scale)


func _setup_card(card: TextureRect, glow: Panel, kind: CardKind) -> void:
	var slot := card.get_parent() as Control
	var tex := _load_card_texture(kind)
	var display_size := Vector2(CARD_MAX_WIDTH, CARD_MAX_WIDTH / 3.46)
	if tex == null:
		push_warning("分队卡片加载失败: %s" % CARD_TEXTURE_PATHS[kind])
	else:
		card.texture = tex
		display_size = _card_display_size(tex)

	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.custom_minimum_size = display_size
	if slot:
		slot.custom_minimum_size = display_size
		slot.clip_contents = false

	card.pivot_offset = display_size * 0.5
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
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
	card.gui_input.connect(func(event: InputEvent) -> void:
		_on_card_gui_input(event, kind)
	)


func _on_card_gui_input(event: InputEvent, kind: CardKind) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_select_squad(SQUAD_IDS[kind])


func _apply_glow_style(glow: Panel, kind: CardKind) -> void:
	var color: Color = GLOW_COLORS[kind]
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(color.r, color.g, color.b, 0.72)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.shadow_size = 0
	glow.add_theme_stylebox_override("panel", style)


func _style_back_button() -> void:
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_button.custom_minimum_size = Vector2(220, 44)
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


func _on_card_hover_enter(card: TextureRect, glow: Panel, _kind: CardKind) -> void:
	_tween_scale(card, HOVER_SCALE)
	_tween_glow(glow, 1.0)


func _on_card_hover_exit(card: TextureRect, glow: Panel, _kind: CardKind) -> void:
	_tween_scale(card, Vector2.ONE)
	_tween_glow(glow, 0.0)


func _tween_scale(card: TextureRect, target: Vector2) -> void:
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


func _select_squad(id: String) -> void:
	var manager := _game_manager()
	if manager == null:
		return
	manager.squad_id = id
	manager.start_run()


func _on_back_pressed() -> void:
	_play_music_cue("menu_select", 0.6)
	var manager := _game_manager()
	if manager != null:
		get_tree().change_scene_to_file(GameManager.SCENE_DIFFICULTY)


func _game_manager() -> Node:
	return get_tree().root.get_node_or_null("GameManager") if get_tree() != null else null
