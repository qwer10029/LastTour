extends Control
class_name SquadSelect
## 分队选择 — 与难度页同背景 + 高阶选项卡交互（SquadCard / LogisticsCard 规范）

const SquadCardScene := preload("res://scenes/menu/squad_card.tscn")
const BACKGROUND_PATH := "res://assets/menu/difficulty/background.png"
const BACKGROUND_BRIGHTNESS := Color(1.18, 1.18, 1.14, 1.0)
const COLOR_MASK := Color(0.102, 0.118, 0.149, 120.0 / 255.0)
const CARD_SIZE := Vector2(560, 148)
const CARD_MIN_WIDTH := 420.0

const CARD_TEXTURES := {
	"scavenger": "res://assets/menu/squad/card_scavenger.png",
	"logistics": "res://assets/menu/squad/card_logistics.png",
}

const CARD_GLOW := {
	"scavenger": Color(0.45, 0.82, 1.0, 0.55),
	"logistics": Color(0.35, 0.95, 0.55, 0.58),
}

static var _texture_cache: Dictionary = {}


static func clear_texture_cache() -> void:
	_texture_cache.clear()


static func preload_assets() -> void:
	var paths: Array[String] = [BACKGROUND_PATH]
	for key in CARD_TEXTURES.keys():
		paths.append(CARD_TEXTURES[key])
	for path in paths:
		if _texture_cache.has(path):
			continue
		var tex := MenuStyles.load_menu_texture(path)
		if tex != null:
			_texture_cache[path] = tex


@onready var background_texture: TextureRect = %BackgroundTexture
@onready var color_mask: ColorRect = %ColorMask
@onready var title_label: Label = %TitleLabel
@onready var difficulty_label: Label = %DifficultyLabel
@onready var hint_label: Label = %HintLabel
@onready var cards_container: VBoxContainer = %CardsContainer
@onready var back_button: Button = %BackButton

var _scavenger_card: SquadCard
var _logistics_card: SquadCard


func _ready() -> void:
	SquadSelect.clear_texture_cache()
	preload_assets()
	_play_music_cue("menu_select", 0.8)
	_setup_background()
	_setup_header()
	_setup_cards()
	_style_back_button()
	back_button.pressed.connect(_on_back_pressed)


func _play_music_cue(cue_id: String, fade_sec: float = -1.0) -> void:
	var music := get_tree().root.get_node_or_null("MusicManager") if get_tree() != null else null
	if music != null and music.has_method("play_cue"):
		music.play_cue(cue_id, fade_sec)


func _setup_background() -> void:
	if is_instance_valid(background_texture):
		background_texture.modulate = BACKGROUND_BRIGHTNESS
		background_texture.texture = _load_texture(BACKGROUND_PATH)
	if is_instance_valid(color_mask):
		color_mask.color = COLOR_MASK


func _setup_header() -> void:
	MenuStyles.style_title(title_label, 40)
	MenuStyles.style_subtitle(hint_label)
	MenuStyles.style_subtitle(difficulty_label)
	difficulty_label.text = "当前难度：%s" % GameManager.get_difficulty_name()


func _setup_cards() -> void:
	_scavenger_card = _spawn_card("scavenger")
	_logistics_card = _spawn_card("logistics")
	cards_container.add_child(_scavenger_card)
	cards_container.add_child(_logistics_card)
	_configure_card(_scavenger_card, "scavenger")
	_configure_card(_logistics_card, "logistics")
	_scavenger_card.pressed.connect(func() -> void: _select_squad("scavenger"))
	_logistics_card.pressed.connect(func() -> void: _select_squad("logistics"))
	_scavenger_card.play_intro_animation(0.05)
	_logistics_card.play_intro_animation(0.22)


func _configure_card(card: SquadCard, squad_id: String) -> void:
	var tex := _load_texture(CARD_TEXTURES.get(squad_id, ""))
	if tex == null:
		push_warning("分队卡片贴图加载失败: %s" % CARD_TEXTURES.get(squad_id, ""))
	card.configure(tex, CARD_GLOW.get(squad_id, Color.WHITE), _card_display_size())


func _card_display_size() -> Vector2:
	var vp_w := get_viewport_rect().size.x
	if vp_w <= 0.0:
		return CARD_SIZE
	# 宽横幅卡片：按视口宽度缩放，避免容器分配不到尺寸。
	var max_w := minf(CARD_SIZE.x, maxf(CARD_MIN_WIDTH, vp_w - 96.0))
	var scale := max_w / CARD_SIZE.x
	return Vector2(max_w, CARD_SIZE.y * scale)


func _spawn_card(_squad_id: String) -> SquadCard:
	return SquadCardScene.instantiate() as SquadCard


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	var tex := MenuStyles.load_menu_texture(path)
	if tex == null:
		tex = ArtAssetLoader.load_texture_from_disk(path)
	if tex != null:
		_texture_cache[path] = tex
	else:
		push_warning("分队卡片贴图加载失败: %s" % path)
	return tex


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


func _select_squad(id: String) -> void:
	GameManager.squad_id = id
	GameManager.start_run()


func _on_back_pressed() -> void:
	_play_music_cue("menu_select", 0.6)
	get_tree().change_scene_to_file(GameManager.SCENE_DIFFICULTY)
