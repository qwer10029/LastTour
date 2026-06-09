extends Control

const MAIN_MENU_BACKGROUND_PATH := "res://assets/menu/main_menu_bg.png"

@onready var background_texture: TextureRect = $Background
@onready var title_label: Label = %TitleLabel
@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var achievements_button: Button = %AchievementsButton
@onready var settings_button: Button = %SettingsButton
@onready var placeholder_dialog: AcceptDialog = %PlaceholderDialog

var _message_wall_popup: Window = null
var _msg_read_content: RichTextLabel
var _msg_custom_input: LineEdit
var _msg_status_label: Label


func _ready() -> void:
	_ensure_background_texture()
	if is_instance_valid(title_label):
		title_label.visible = false
	_apply_menu_button_styles()

	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	achievements_button.pressed.connect(_on_message_wall_pressed)
	settings_button.pressed.connect(_on_placeholder_pressed)

	_refresh_continue_button()
	achievements_button.text = "  📝   写下留言"
	achievements_button.disabled = false
	settings_button.disabled = false

	_build_message_wall_popup()


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
	MenuStyles.style_message_button(achievements_button)
	MenuStyles.style_settings_button(settings_button)
	_refresh_continue_button()


func _build_message_wall_popup() -> void:
	_message_wall_popup = Window.new()
	_message_wall_popup.title = "昆仑终端 · 已上传日志"
	_message_wall_popup.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	_message_wall_popup.size = Vector2i(560, 520)
	_message_wall_popup.unresizable = true
	_message_wall_popup.close_requested.connect(_message_wall_popup.hide)
	_message_wall_popup.visible = false
	add_child(_message_wall_popup)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	_message_wall_popup.add_child(root)

	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 8)
	root.add_child(margin)

	var inner := VBoxContainer.new()
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 10)
	margin.add_child(inner)

	var write_title := Label.new()
	write_title.text = "—— 写下留言（保存后下局可见）——"
	write_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(write_title)

	var read_hint := Label.new()
	read_hint.text = "前代留言（仅写留言时可见）"
	read_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(read_hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 120)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.add_child(scroll)

	_msg_read_content = RichTextLabel.new()
	_msg_read_content.name = "Content"
	_msg_read_content.bbcode_enabled = true
	_msg_read_content.fit_content = true
	_msg_read_content.scroll_active = false
	_msg_read_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_msg_read_content)

	var sep := HSeparator.new()
	inner.add_child(sep)

	var preset_box := VBoxContainer.new()
	preset_box.add_theme_constant_override("separation", 6)
	inner.add_child(preset_box)
	for preset in RunEndingDefs.MESSAGE_PRESETS:
		var preset_id: String = str(preset.get("id", ""))
		var btn := Button.new()
		btn.text = str(preset.get("text", ""))
		btn.custom_minimum_size = Vector2(0, 36)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_menu_preset_pressed.bind(preset_id, str(preset.get("text", ""))))
		preset_box.add_child(btn)

	_msg_custom_input = LineEdit.new()
	_msg_custom_input.placeholder_text = "或在此输入自定义留言（最多80字）…"
	_msg_custom_input.max_length = 80
	inner.add_child(_msg_custom_input)

	var submit_row := HBoxContainer.new()
	submit_row.alignment = BoxContainer.ALIGNMENT_CENTER
	submit_row.add_theme_constant_override("separation", 12)
	var submit_btn := Button.new()
	submit_btn.text = "提交自定义留言"
	submit_btn.custom_minimum_size = Vector2(180, 40)
	submit_btn.pressed.connect(_on_menu_submit_custom)
	submit_row.add_child(submit_btn)
	inner.add_child(submit_row)

	_msg_status_label = Label.new()
	_msg_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg_status_label.add_theme_color_override("font_color", Color("#8fd49a"))
	inner.add_child(_msg_status_label)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(120, 40)
	close_btn.pressed.connect(_message_wall_popup.hide)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(close_btn)


func _refresh_message_wall_read() -> void:
	if not is_instance_valid(_msg_read_content):
		return
	_msg_read_content.text = MetaManager.format_uploaded_logs_preview(8)


func _submit_menu_message(_text: String) -> void:
	_set_msg_status("日志仅在顶层通信终端上传与阅读。", false)


func _set_msg_status(text: String, ok: bool) -> void:
	if not is_instance_valid(_msg_status_label):
		return
	_msg_status_label.text = text
	_msg_status_label.add_theme_color_override("font_color", Color("#8fd49a") if ok else Color("#e8a060"))


func _on_menu_preset_pressed(preset_id: String, preset_text: String) -> void:
	if preset_id == "custom":
		_msg_custom_input.grab_focus()
		_set_msg_status("请在输入框填写后点「提交自定义留言」。", true)
		return
	_submit_menu_message(preset_text)


func _on_menu_submit_custom() -> void:
	_submit_menu_message(_msg_custom_input.text)


func _on_message_wall_pressed() -> void:
	_refresh_message_wall_read()
	_set_msg_status("", true)
	if _message_wall_popup:
		_message_wall_popup.popup_centered()
		_message_wall_popup.show()


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


func _on_placeholder_pressed() -> void:
	if placeholder_dialog:
		placeholder_dialog.popup_centered()
