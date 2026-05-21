extends Control

@onready var title_label: Label = %TitleLabel
@onready var hint_label: Label = %HintLabel
@onready var difficulty_label: Label = %DifficultyLabel
@onready var scavenger_button: Button = %ScavengerButton
@onready var logistics_button: Button = %LogisticsButton
@onready var back_button: Button = %BackButton

func _ready() -> void:
	MenuStyles.style_title(title_label, 36)
	MenuStyles.style_subtitle(hint_label)
	MenuStyles.style_subtitle(difficulty_label)
	difficulty_label.text = "当前难度：%s" % GameManager.get_difficulty_name()
	for button in [scavenger_button, logistics_button, back_button]:
		MenuStyles.style_menu_button(button)

	scavenger_button.pressed.connect(func(): _select_squad("scavenger"))
	logistics_button.pressed.connect(func(): _select_squad("logistics"))
	back_button.pressed.connect(_on_back_pressed)


func _select_squad(id: String) -> void:
	GameManager.squad_id = id
	GameManager.start_run()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(GameManager.SCENE_DIFFICULTY)
