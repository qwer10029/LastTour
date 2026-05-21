extends Control

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var achievements_button: Button = %AchievementsButton
@onready var settings_button: Button = %SettingsButton
@onready var placeholder_dialog: AcceptDialog = %PlaceholderDialog

func _ready() -> void:
	MenuStyles.style_title(title_label, 48)
	MenuStyles.style_subtitle(subtitle_label)
	for button in [new_game_button, continue_button, achievements_button, settings_button]:
		MenuStyles.style_menu_button(button)

	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	achievements_button.pressed.connect(_on_placeholder_pressed)
	settings_button.pressed.connect(_on_placeholder_pressed)

	_refresh_continue_button()
	achievements_button.disabled = true
	settings_button.disabled = true


func _refresh_continue_button() -> void:
	if not is_instance_valid(continue_button):
		return
	if SaveManager.has_save():
		var summary := SaveManager.get_save_summary()
		continue_button.disabled = false
		continue_button.text = "  ▶   继续游戏（第 %d 天 · %s · %s）" % [
			int(summary.get("day_index", 1)),
			str(summary.get("difficulty_name", "")),
			str(summary.get("squad_name", "")),
		]
	else:
		continue_button.disabled = true
		continue_button.text = "  ▶   继续游戏（无存档）"


func _on_continue_pressed() -> void:
	if SaveManager.has_save():
		GameManager.continue_from_save()


func _on_new_game_pressed() -> void:
	GameManager.begin_new_game_flow()


func _on_placeholder_pressed() -> void:
	if placeholder_dialog:
		placeholder_dialog.popup_centered()
