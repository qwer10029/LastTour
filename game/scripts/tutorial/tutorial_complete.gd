extends Control

const RunBootstrapScript := preload("res://scripts/menu/run_bootstrap.gd")


func _ready() -> void:
	_play_music_cue("menu_main", 1.0)
	var meta := get_node_or_null("/root/MetaManager")
	if meta != null and meta.has_method("mark_tutorial_completed"):
		meta.mark_tutorial_completed()
	_build_ui()


func _play_music_cue(cue_id: String, fade_sec: float = -1.0) -> void:
	var music := get_tree().root.get_node_or_null("MusicManager") if get_tree() != null else null
	if music != null and music.has_method("play_cue"):
		music.play_cue(cue_id, fade_sec)


func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.04, 0.08, 0.88)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_stylebox_override("panel", HudTheme.panel_style(0.94))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "教学完成"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#f4f0e8"))
	HudTheme.apply_label(title)
	vbox.add_child(title)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = (
		"电梯每推进一步，就离上一层更近一步。\n"
		+ "本游戏共有 %d 层，修满电梯、逐层向上，最终抵达顶层昆仑即为通关目标。"
	) % RunBootstrapScript.TOTAL_LAYERS
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color("#c8d4e0"))
	HudTheme.apply_label(body)
	vbox.add_child(body)

	var menu_btn := Button.new()
	menu_btn.text = "返回主菜单"
	menu_btn.custom_minimum_size = Vector2(0, 48)
	MenuStyles.style_menu_button(menu_btn)
	menu_btn.pressed.connect(_on_menu_pressed)
	vbox.add_child(menu_btn)

	var new_game_btn := Button.new()
	new_game_btn.text = "开始新游戏"
	new_game_btn.custom_minimum_size = Vector2(0, 48)
	MenuStyles.style_journal_button(new_game_btn)
	new_game_btn.pressed.connect(_on_new_game_pressed)
	vbox.add_child(new_game_btn)


func _on_menu_pressed() -> void:
	GameManager.finish_tutorial_and_return_menu()


func _on_new_game_pressed() -> void:
	GameManager.is_tutorial_run = false
	GameManager.begin_new_game_flow()
