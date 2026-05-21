extends Control

@onready var title_label: Label = %TitleLabel
@onready var hint_label: Label = %HintLabel
@onready var easy_button: Button = %EasyButton
@onready var normal_button: Button = %NormalButton
@onready var hard_button: Button = %HardButton
@onready var back_button: Button = %BackButton

func _ready() -> void:
	MenuStyles.style_title(title_label, 36)
	MenuStyles.style_subtitle(hint_label)
	for button in [easy_button, normal_button, hard_button, back_button]:
		MenuStyles.style_menu_button(button)

	easy_button.pressed.connect(func(): _select_difficulty(GameManager.Difficulty.EASY))
	normal_button.pressed.connect(func(): _select_difficulty(GameManager.Difficulty.NORMAL))
	hard_button.pressed.connect(func(): _select_difficulty(GameManager.Difficulty.HARD))
	back_button.pressed.connect(_on_back_pressed)


func _select_difficulty(value: int) -> void:
	GameManager.difficulty = value
	GameManager.go_to_squad_select()


func _on_back_pressed() -> void:
	GameManager.go_to_main_menu()
