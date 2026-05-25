extends Control

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var achievements_button: Button = %AchievementsButton
@onready var settings_button: Button = %SettingsButton
@onready var placeholder_dialog: AcceptDialog = %PlaceholderDialog

var _message_wall_popup: Window = null

func _ready() -> void:
	MenuStyles.style_title(title_label, 48)
	MenuStyles.style_subtitle(subtitle_label)
	for button in [new_game_button, continue_button, achievements_button, settings_button]:
		MenuStyles.style_menu_button(button)

	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	achievements_button.pressed.connect(_on_message_wall_pressed)
	settings_button.pressed.connect(_on_placeholder_pressed)

	_refresh_continue_button()
	achievements_button.text = "  📝   前代勘探者留言墙"
	achievements_button.disabled = false
	settings_button.disabled = true

	_build_message_wall_popup()


func _build_message_wall_popup() -> void:
	_message_wall_popup = Window.new()
	_message_wall_popup.title = "前代勘探者留言墙"
	_message_wall_popup.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	_message_wall_popup.size = Vector2i(520, 420)
	_message_wall_popup.unresizable = true
	_message_wall_popup.close_requested.connect(_message_wall_popup.hide)
	_message_wall_popup.visible = false
	add_child(_message_wall_popup)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	_message_wall_popup.add_child(vbox)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	vbox.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var content := RichTextLabel.new()
	content.name = "Content"
	content.bbcode_enabled = true
	content.fit_content = true
	content.scroll_active = false
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(120, 40)
	close_btn.pressed.connect(_message_wall_popup.hide)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(close_btn)


func _refresh_message_wall_popup() -> void:
	if _message_wall_popup == null:
		return
	var content := _message_wall_popup.get_node("VBoxContainer/MarginContainer/ScrollContainer/Content")
	if not is_instance_valid(content):
		return
	var messages: Array = MetaManager.message_wall
	if messages.is_empty():
		content.text = "[center][color=#6a8aaa]还没有留言。\n完成一次勘探并选择留言后，这里会显示前代勘探者的痕迹。[/color][/center]"
		return
	var lines: PackedStringArray = []
	for i in range(messages.size() - 1, -1, -1):
		var entry: Dictionary = messages[i]
		var text := str(entry.get("text", ""))
		var layer := int(entry.get("layer", 0))
		var run_id := str(entry.get("run_id", ""))
		lines.append("[color=#b8c7d8]第%d层[/color]  [color=#e8d090]%s[/color]" % [layer, text])
		if i > 0:
			lines.append("[color=#3a4a5a]──────────────────────────[/color]")
	content.text = "\n".join(lines)


func _on_message_wall_pressed() -> void:
	_refresh_message_wall_popup()
	if _message_wall_popup:
		_message_wall_popup.show()


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
