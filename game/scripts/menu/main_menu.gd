extends Control

const MAIN_MENU_BACKGROUND_PATH := "res://assets/menu/main_menu_bg.png"
const JournalArchiveOverlayScript = preload("res://scripts/ui/journal_archive_overlay.gd")

@onready var background_texture: TextureRect = $Background
@onready var title_label: Label = %TitleLabel
@onready var new_game_button: Button = %NewGameButton
@onready var tutorial_button: Button = %TutorialButton
@onready var continue_button: Button = %ContinueButton
@onready var journal_button: Button = %JournalButton
@onready var settings_button: Button = %SettingsButton
@onready var placeholder_dialog: AcceptDialog = %PlaceholderDialog

var _journal_overlay: CanvasLayer
var _settings_overlay: SettingsOverlay


func _ready() -> void:
	_play_music_cue("menu_main", 1.0)
	_ensure_background_texture()
	if is_instance_valid(title_label):
		title_label.visible = false
	_apply_menu_button_styles()

	new_game_button.pressed.connect(_on_new_game_pressed)
	if is_instance_valid(tutorial_button):
		tutorial_button.pressed.connect(_on_tutorial_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	journal_button.pressed.connect(_on_journal_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

	journal_button.text = "  ◈   查看日志"
	journal_button.disabled = false
	settings_button.disabled = false

	_journal_overlay = JournalArchiveOverlayScript.new()
	add_child(_journal_overlay)

	_settings_overlay = SettingsOverlay.new()
	add_child(_settings_overlay)
	_settings_overlay.replay_tutorial_requested.connect(_on_replay_tutorial_requested)
	if _settings_overlay.has_signal("replay_tutorial_run_requested"):
		_settings_overlay.replay_tutorial_run_requested.connect(_on_replay_tutorial_run_requested)

	_refresh_continue_button()


func _play_music_cue(cue_id: String, fade_sec: float = -1.0) -> void:
	var music := get_tree().root.get_node_or_null("MusicManager") if get_tree() != null else null
	if music != null and music.has_method("play_cue"):
		music.play_cue(cue_id, fade_sec)


func _ensure_background_texture() -> void:
	if not is_instance_valid(background_texture):
		return
	var tex := _load_texture(MAIN_MENU_BACKGROUND_PATH)
	if tex != null:
		background_texture.texture = tex


func _load_texture(path: String) -> Texture2D:
	return MenuStyles.load_menu_texture(path)


func _apply_menu_button_styles() -> void:
	MenuStyles.style_new_game_button(new_game_button)
	if is_instance_valid(tutorial_button):
		MenuStyles.style_journal_button(tutorial_button)
	MenuStyles.style_journal_button(journal_button)
	MenuStyles.style_settings_button(settings_button)
	_refresh_continue_button()


func _on_journal_pressed() -> void:
	if is_instance_valid(_journal_overlay):
		_journal_overlay.show_archive()


func _refresh_continue_button() -> void:
	if not is_instance_valid(continue_button):
		return
	var has_save := SaveManager.has_save()
	MenuStyles.style_continue_button(continue_button, has_save)
	if has_save:
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


func _on_tutorial_pressed() -> void:
	GameManager.begin_tutorial_flow()


func _on_settings_pressed() -> void:
	if is_instance_valid(_settings_overlay):
		_settings_overlay.show_settings()
	elif placeholder_dialog:
		placeholder_dialog.popup_centered()


## 在设置里点"重看夜晚教程"：清除已看标记，下次进入夜晚时会再次弹出。
func _on_replay_tutorial_requested() -> void:
	var meta := get_node_or_null("/root/MetaManager")
	if meta != null and meta.has_method("reset_night_tutorial"):
		meta.reset_night_tutorial()
	if placeholder_dialog:
		placeholder_dialog.dialog_text = "夜晚教程将在下次进入夜晚布防时重新显示。"
		placeholder_dialog.popup_centered()


func _on_replay_tutorial_run_requested() -> void:
	var meta := get_node_or_null("/root/MetaManager")
	if meta != null and meta.has_method("reset_tutorial"):
		meta.reset_tutorial()
	if placeholder_dialog:
		placeholder_dialog.dialog_text = "教学关卡完成标记已清除，可随时从主菜单重新进入。"
		placeholder_dialog.popup_centered()
