extends Control

@onready var title_label: Label = %TitleLabel
@onready var hint_label: Label = %HintLabel
@onready var difficulty_label: Label = %DifficultyLabel
@onready var scavenger_button: Button = %ScavengerButton
@onready var logistics_button: Button = %LogisticsButton
@onready var back_button: Button = %BackButton

func _ready() -> void:
	_play_music_cue("menu_select", 0.8)
	MenuStyles.style_title(title_label, 36)
	MenuStyles.style_subtitle(hint_label)
	MenuStyles.style_subtitle(difficulty_label)
	difficulty_label.text = "当前难度：%s" % GameManager.get_difficulty_name()
	for button in [scavenger_button, logistics_button, back_button]:
		MenuStyles.style_menu_button(button)

	scavenger_button.pressed.connect(func(): _select_squad("scavenger"))
	logistics_button.pressed.connect(func(): _select_squad("logistics"))
	back_button.pressed.connect(_on_back_pressed)


func _play_music_cue(cue_id: String, fade_sec: float = -1.0) -> void:
	var music := get_tree().root.get_node_or_null("MusicManager") if get_tree() != null else null
	if music != null and music.has_method("play_cue"):
		music.play_cue(cue_id, fade_sec)


func _select_squad(id: String) -> void:
	GameManager.squad_id = id
	GameManager.start_run()


func _on_back_pressed() -> void:
	_play_music_cue("menu_select", 0.6)
	get_tree().change_scene_to_file(GameManager.SCENE_DIFFICULTY)
