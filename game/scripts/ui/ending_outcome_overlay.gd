extends CanvasLayer

const SciFiFramePanelScript = preload("res://scripts/ui/sci_fi_frame_panel.gd")

signal closed

enum Mode { CREDITS, FAKE_SUCCESS, ARCHIVE_ONLY_EPILOGUE }

var _mode: int = Mode.CREDITS
var _dim: ColorRect
var _frame: SciFiFramePanel
var _title: Label
var _section_label: Label
var _body: RichTextLabel
var _credits_scroll: ScrollContainer
var _primary_btn: Button
var _credits_scroll_speed: float = 36.0

const CREDITS_FONT_SIZE := 17
const CREDITS_TITLE_FONT_SIZE := 20


func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _process(delta: float) -> void:
	if not visible or _mode != Mode.CREDITS:
		return
	if not is_instance_valid(_credits_scroll):
		return
	var bar := _credits_scroll.get_v_scroll_bar()
	if bar == null:
		return
	bar.value = minf(bar.value + _credits_scroll_speed * delta, bar.max_value)


func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.04, 0.08, 0.92)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_frame = SciFiFramePanelScript.new()
	_frame.custom_minimum_size = Vector2(760, 520)
	center.add_child(_frame)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	_frame.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	HudTheme.apply_terminal_title(_title)
	root.add_child(_title)

	_section_label = Label.new()
	_section_label.text = "◈ 系统日志"
	_section_label.visible = false
	HudTheme.apply_terminal_section(_section_label)
	root.add_child(_section_label)

	_body = RichTextLabel.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.custom_minimum_size = Vector2(660, 200)
	_body.scroll_active = false
	_body.fit_content = true
	_body.visible = false
	HudTheme.apply_terminal_log_rich(_body)
	root.add_child(_body)

	_credits_scroll = ScrollContainer.new()
	_credits_scroll.custom_minimum_size = Vector2(680, 220)
	_credits_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_credits_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_credits_scroll.visible = false
	root.add_child(_credits_scroll)

	var credits_body := RichTextLabel.new()
	credits_body.name = "CreditsBody"
	credits_body.bbcode_enabled = true
	credits_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits_body.custom_minimum_size = Vector2(660, 480)
	credits_body.scroll_active = false
	credits_body.fit_content = true
	credits_body.add_theme_font_size_override("normal_font_size", CREDITS_FONT_SIZE)
	credits_body.add_theme_color_override("default_color", Color("#c8dce8"))
	credits_body.add_theme_constant_override("line_separation", 14)
	_credits_scroll.add_child(credits_body)

	_primary_btn = Button.new()
	_primary_btn.custom_minimum_size = Vector2(300, 46)
	_primary_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	HudTheme.apply_sci_fi_terminal_button(_primary_btn)
	_primary_btn.pressed.connect(_on_primary_pressed)
	root.add_child(_primary_btn)


func show_outcome(choice_id: String, _run_layer: int, _day_index: int = 1) -> void:
	visible = true
	if choice_id == "stop_signal":
		_play_music_cue("truth_reveal", 0.9)
	else:
		_play_music_cue("final_choice", 0.9)
	match choice_id:
		"stop_signal":
			_enter_credits()
		"message_only":
			_enter_archive_only_epilogue()
		"fake_success":
			_enter_fake_success()
		_:
			_enter_credits()


func hide_overlay() -> void:
	visible = false


func _play_music_cue(cue_id: String, fade_sec: float = -1.0) -> void:
	var music := get_tree().root.get_node_or_null("MusicManager") if get_tree() != null else null
	if music != null and music.has_method("play_cue"):
		music.play_cue(cue_id, fade_sec)


func _enter_credits() -> void:
	_mode = Mode.CREDITS
	_title.text = "克隆循环 · 终止"
	_section_label.text = "◈ 制作名单"
	_section_label.visible = true
	_body.visible = false
	_credits_scroll.visible = true
	var credits_body := _credits_scroll.get_node_or_null("CreditsBody") as RichTextLabel
	if credits_body != null:
		credits_body.add_theme_font_size_override("normal_font_size", CREDITS_FONT_SIZE)
		var blocks: PackedStringArray = []
		for line in RunEndingDefs.CREDITS_LINES:
			var trimmed := str(line).strip_edges()
			if trimmed.is_empty():
				blocks.append("")
				continue
			if trimmed.begins_with("——") or trimmed.begins_with("【"):
				blocks.append(
					"[center][font_size=%d][color=#8ec8e8]%s[/color][/font_size][/center]"
					% [CREDITS_TITLE_FONT_SIZE, trimmed]
				)
			elif trimmed.begins_with("感谢游玩"):
				blocks.append(
					"[center][font_size=%d][color=#6eb8ff]%s[/color][/font_size][/center]"
					% [CREDITS_TITLE_FONT_SIZE + 2, trimmed]
				)
			elif trimmed.begins_with("克隆程序") or trimmed.begins_with("地表的风"):
				blocks.append("[center][font_size=%d]%s[/font_size][/center]" % [CREDITS_FONT_SIZE, trimmed])
			else:
				blocks.append("[center]%s[/center]" % trimmed)
		var gap := "\n".repeat(3)
		credits_body.text = gap.join(blocks)
	call_deferred("_reset_credits_scroll")
	_primary_btn.text = "返回主菜单"


func _reset_credits_scroll() -> void:
	if not is_instance_valid(_credits_scroll):
		return
	var bar := _credits_scroll.get_v_scroll_bar()
	if bar != null:
		bar.value = 0.0


func _enter_fake_success() -> void:
	_mode = Mode.FAKE_SUCCESS
	_title.text = "勘探成功 · 伪造"
	_section_label.visible = true
	_credits_scroll.visible = false
	_body.visible = true
	_body.text = HudTheme.format_terminal_log(
		"""昆仑中继收到一条伪造的「勘探成功」信号。
程序不会追问真伪。
它只是需要一个理由停下来。
循环以讽刺的方式停摆了。
也许这就是人类能给出的最后答案。"""
	)
	_primary_btn.text = "返回主菜单"


func _enter_archive_only_epilogue() -> void:
	_mode = Mode.ARCHIVE_ONLY_EPILOGUE
	_title.text = "仅归档 · 循环继续"
	_section_label.visible = true
	_credits_scroll.visible = false
	_body.visible = true
	_body.text = HudTheme.format_terminal_log(
		"""你没有发送终止信号。
本局勘探日记已上传至昆仑终端。
程序将把新的克隆体送上来——循环继续。"""
	)
	_primary_btn.text = "返回主菜单"


func _on_primary_pressed() -> void:
	closed.emit()
