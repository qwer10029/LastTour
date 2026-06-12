extends CanvasLayer
class_name SettingsOverlay

signal replay_tutorial_requested
signal replay_tutorial_run_requested

const COLOR_TITLE := Color("#6eb8ff")
const COLOR_TEXT := Color("#e4eef8")
const COLOR_SECTION := Color("#5a8aaa")
const COLOR_PANEL_BG := Color(0.04, 0.07, 0.11, 0.95)
const COLOR_PANEL_BORDER := Color("#5ec8ff")

var _master_slider: HSlider
var _master_percent_label: Label
var _music_slider: HSlider
var _music_percent_label: Label
var _fullscreen_check: CheckButton
var _syncing := false


func _ready() -> void:
	layer = 140
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func show_settings() -> void:
	_sync_from_settings_manager()
	visible = true


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 360)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var title := Label.new()
	title.text = "设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", COLOR_TITLE)
	HudTheme.apply_label(title)
	root.add_child(title)

	root.add_child(_make_section_label("◈ 音频"))

	var master_row := _make_slider_row("主音量")
	_master_slider = master_row["slider"] as HSlider
	_master_percent_label = master_row["percent_label"] as Label
	_master_slider.value_changed.connect(_on_master_volume_changed)
	var master_root := master_row["root"] as Control
	root.add_child(master_root)

	var music_row := _make_slider_row("音乐音量")
	_music_slider = music_row["slider"] as HSlider
	_music_percent_label = music_row["percent_label"] as Label
	_music_slider.value_changed.connect(_on_music_volume_changed)
	var music_root := music_row["root"] as Control
	root.add_child(music_root)

	root.add_child(_make_section_label("◈ 显示"))

	_fullscreen_check = CheckButton.new()
	_fullscreen_check.text = "全屏"
	_fullscreen_check.add_theme_font_size_override("font_size", 14)
	_fullscreen_check.add_theme_color_override("font_color", COLOR_TEXT)
	_fullscreen_check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	HudTheme.apply_button(_fullscreen_check)
	root.add_child(_fullscreen_check)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	root.add_child(spacer)

	var tutorial_btn := Button.new()
	tutorial_btn.text = "重看夜晚教程"
	tutorial_btn.custom_minimum_size = Vector2(300, 44)
	tutorial_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	HudTheme.apply_sci_fi_terminal_button(tutorial_btn, Color("#8ec8e8"))
	tutorial_btn.pressed.connect(_on_replay_tutorial_pressed)
	root.add_child(tutorial_btn)

	var tutorial_run_btn := Button.new()
	tutorial_run_btn.text = "重玩教学关卡"
	tutorial_run_btn.custom_minimum_size = Vector2(300, 44)
	tutorial_run_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	HudTheme.apply_sci_fi_terminal_button(tutorial_run_btn, Color("#8ec8e8"))
	tutorial_run_btn.pressed.connect(_on_replay_tutorial_run_pressed)
	root.add_child(tutorial_run_btn)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(300, 44)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	HudTheme.apply_sci_fi_terminal_button(close_btn)
	close_btn.pressed.connect(_hide_settings)
	root.add_child(close_btn)


func _make_panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_PANEL_BG
	box.border_color = Color(COLOR_PANEL_BORDER.r, COLOR_PANEL_BORDER.g, COLOR_PANEL_BORDER.b, 0.82)
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.shadow_color = Color(0, 0, 0, 0.36)
	box.shadow_size = 8
	return box


func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", COLOR_SECTION)
	return label


func _make_slider_row(label_text: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(82, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	HudTheme.apply_label(label)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(220, 0)
	row.add_child(slider)

	var percent_label := Label.new()
	percent_label.text = "100%"
	percent_label.custom_minimum_size = Vector2(48, 0)
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	percent_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	percent_label.add_theme_font_size_override("font_size", 14)
	percent_label.add_theme_color_override("font_color", COLOR_TEXT)
	HudTheme.apply_label(percent_label)
	row.add_child(percent_label)

	return {
		"root": row,
		"slider": slider,
		"percent_label": percent_label
	}


func _sync_from_settings_manager() -> void:
	var settings := _settings_manager()
	_syncing = true
	if settings != null:
		_master_slider.value = clampf(float(settings.get("master_volume")), 0.0, 1.0)
		_music_slider.value = clampf(float(settings.get("music_volume")), 0.0, 1.0)
		_fullscreen_check.button_pressed = bool(settings.get("fullscreen"))
	_update_percent_label(_master_percent_label, float(_master_slider.value))
	_update_percent_label(_music_percent_label, float(_music_slider.value))
	_syncing = false


func _settings_manager() -> Node:
	return get_node_or_null("/root/SettingsManager")


func _update_percent_label(label: Label, value: float) -> void:
	if label == null:
		return
	label.text = "%d%%" % int(roundf(clampf(value, 0.0, 1.0) * 100.0))


func _on_master_volume_changed(value: float) -> void:
	_update_percent_label(_master_percent_label, value)
	if _syncing:
		return
	var settings := _settings_manager()
	if settings != null and settings.has_method("set_master_volume"):
		settings.call("set_master_volume", value)


func _on_music_volume_changed(value: float) -> void:
	_update_percent_label(_music_percent_label, value)
	if _syncing:
		return
	var settings := _settings_manager()
	if settings != null and settings.has_method("set_music_volume"):
		settings.call("set_music_volume", value)


func _on_fullscreen_toggled(pressed: bool) -> void:
	if _syncing:
		return
	var settings := _settings_manager()
	if settings != null and settings.has_method("set_fullscreen"):
		settings.call("set_fullscreen", pressed)


func _on_replay_tutorial_pressed() -> void:
	replay_tutorial_requested.emit()


func _on_replay_tutorial_run_pressed() -> void:
	replay_tutorial_run_requested.emit()
	_hide_settings()


func _hide_settings() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_hide_settings()
		get_viewport().set_input_as_handled()
