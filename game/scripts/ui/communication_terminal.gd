extends CanvasLayer

const SciFiFramePanelScript = preload("res://scripts/ui/sci_fi_frame_panel.gd")

signal strike_completed
signal transfer_completed

enum Phase { HIDDEN, INTRO, UPLOAD, READ, REPORT, CAPTCHA, EVIDENCE_AUDIT, RESULT_FAIL, RESULT_PASS }

const COLOR_ALERT := Color("#ff3d4a")
const REQUIRED_EVIDENCE_IDS := [
	"backdoor_info",
	"clone_identity",
	"faction_conflict",
	"human_extinction_proof",
]

var _phase: int = Phase.HIDDEN
var _report_choice: String = ""
var _run_layer: int = 3
var _day_index: int = 1
var _run_journal_entries: Array = []
var _backpack_snapshot: Dictionary = {}
var _upload_done: bool = false
var _audit_passed: bool = false

var _dim: ColorRect
var _frame: SciFiFramePanel
var _title_label: Label
var _header_label: Label
var _body_label: Label
var _log_section: Label
var _log_history: RichTextLabel
var _options_box: VBoxContainer
var _captcha_box: VBoxContainer
var _captcha_slider: HSlider
var _captcha_hint: Label
var _captcha_close_btn: Button
var _primary_btn: Button
var _option_buttons: Array[Button] = []


func _ready() -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.01, 0.03, 0.06, 0.9)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_frame = SciFiFramePanelScript.new()
	_frame.custom_minimum_size = Vector2(800, 560)
	center.add_child(_frame)

	_captcha_close_btn = Button.new()
	_captcha_close_btn.name = "CaptchaAuditClose"
	_captcha_close_btn.text = "X"
	_captcha_close_btn.visible = false
	_captcha_close_btn.focus_mode = Control.FOCUS_NONE
	_captcha_close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_captcha_close_btn.z_index = 20
	_captcha_close_btn.custom_minimum_size = Vector2(30, 26)
	_captcha_close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_captcha_close_btn.offset_left = -42.0
	_captcha_close_btn.offset_top = 14.0
	_captcha_close_btn.offset_right = -12.0
	_captcha_close_btn.offset_bottom = 40.0
	HudTheme.apply_sci_fi_terminal_button(_captcha_close_btn, Color("#e87840"))
	_captcha_close_btn.pressed.connect(_on_captcha_close_pressed)
	_frame.add_child(_captcha_close_btn)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	_frame.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	HudTheme.apply_terminal_title(_title_label)
	root.add_child(_title_label)

	_header_label = Label.new()
	_header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header_label.visible = false
	HudTheme.apply_terminal_section(_header_label)
	root.add_child(_header_label)

	var prompt_header := _make_section_label("◈ 终端提示")
	root.add_child(prompt_header)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.custom_minimum_size = Vector2(720, 96)
	HudTheme.apply_terminal_log_label(_body_label)
	root.add_child(_body_label)

	_log_section = _make_section_label("◈ 终端存档")
	_log_section.visible = false
	root.add_child(_log_section)

	_log_history = RichTextLabel.new()
	_log_history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_history.custom_minimum_size = Vector2(720, 180)
	_log_history.scroll_active = true
	_log_history.visible = false
	HudTheme.apply_terminal_log_rich(_log_history)
	root.add_child(_log_history)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 8)
	_options_box.visible = false
	root.add_child(_options_box)

	_captcha_box = VBoxContainer.new()
	_captcha_box.add_theme_constant_override("separation", 8)
	_captcha_box.visible = false
	root.add_child(_captcha_box)

	_captcha_hint = Label.new()
	_captcha_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HudTheme.apply_terminal_section(_captcha_hint)
	_captcha_box.add_child(_captcha_hint)

	_captcha_slider = HSlider.new()
	_captcha_slider.min_value = 0.0
	_captcha_slider.max_value = 100.0
	_captcha_slider.step = 1.0
	_captcha_slider.value = 0.0
	_captcha_slider.custom_minimum_size = Vector2(560, 36)
	_captcha_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_captcha_slider_theme()
	_captcha_slider.value_changed.connect(_on_captcha_value_changed)
	_captcha_box.add_child(_captcha_slider)

	_primary_btn = Button.new()
	_primary_btn.text = "继续"
	_primary_btn.custom_minimum_size = Vector2(300, 46)
	_primary_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	HudTheme.apply_sci_fi_terminal_button(_primary_btn)
	_primary_btn.pressed.connect(_on_primary_pressed)
	root.add_child(_primary_btn)
	_frame.move_child(_captcha_close_btn, _frame.get_child_count() - 1)


func start_flow(run_journal_entries: Array, run_layer: int = 3, day_index: int = 1, backpack_snapshot: Dictionary = {}) -> void:
	_run_journal_entries = run_journal_entries.duplicate(true)
	_backpack_snapshot = backpack_snapshot.duplicate(true)
	_report_choice = ""
	_run_layer = run_layer
	_day_index = day_index
	_upload_done = false
	_audit_passed = false
	visible = true
	_play_music_cue("terminal", 0.9)
	_enter_phase(Phase.INTRO)


func hide_terminal() -> void:
	_phase = Phase.HIDDEN
	visible = false


func _play_music_cue(cue_id: String, fade_sec: float = -1.0) -> void:
	var music := get_tree().root.get_node_or_null("MusicManager") if get_tree() != null else null
	if music != null and music.has_method("play_cue"):
		music.play_cue(cue_id, fade_sec)


func _enter_phase(phase: int) -> void:
	_phase = phase
	_clear_option_buttons()
	_options_box.visible = false
	_captcha_box.visible = false
	_captcha_close_btn.visible = false
	_log_section.visible = false
	_log_history.visible = false
	_body_label.visible = true
	_primary_btn.visible = true
	HudTheme.apply_terminal_title(_title_label)
	HudTheme.apply_terminal_log_label(_body_label)
	match phase:
		Phase.INTRO:
			_title_label.text = "通信终端 · 接入"
			_set_terminal_body(RunEndingDefs.TERMINAL_INTRO_TEXT)
			_primary_btn.text = "继续"
		Phase.UPLOAD:
			_title_label.text = "通信终端 · 日志上传"
			_header_label.visible = false
			_body_label.text = HudTheme.format_terminal_log(
				"正在将本局勘探日记同步至昆仑中继……\n上传完成后，前代勘探者的记录将与此处合并存档。"
			)
			_primary_btn.text = "开始上传"
		Phase.READ:
			_title_label.text = "通信终端 · 勘探日志"
			_header_label.visible = false
			_body_label.text = "> 已上传本局日记。下方为终端存档（含前代上传与本局记录）。"
			_log_section.visible = true
			_log_history.visible = true
			_refresh_log_history()
			_primary_btn.text = "继续汇报"
		Phase.REPORT:
			_title_label.text = "通信终端 · 勘探汇报"
			_header_label.visible = false
			_body_label.text = "> %s" % RunEndingDefs.TERMINAL_REPORT_PROMPT
			_options_box.visible = true
			_primary_btn.visible = false
			_build_report_options()
		Phase.CAPTCHA:
			_title_label.text = "通信终端 · 身份识别"
			_header_label.visible = false
			_body_label.text = "> %s" % RunEndingDefs.TERMINAL_CAPTCHA_PROMPT
			_captcha_box.visible = true
			_captcha_close_btn.visible = true
			_captcha_slider.value = 0.0
			_captcha_hint.text = "滑块进度：0 / 100"
			_primary_btn.text = "提交验证"
			_primary_btn.disabled = true
		Phase.EVIDENCE_AUDIT:
			_title_label.text = "通信终端 · 证据审计"
			_header_label.visible = false
			var audit := _evidence_audit_report()
			_audit_passed = bool(audit.get("passed", false))
			_body_label.text = str(audit.get("text", ""))
			_primary_btn.text = "提交证据包" if _audit_passed else "提交中断记录"
			_primary_btn.disabled = false
		Phase.RESULT_FAIL:
			_title_label.text = "通信终端 · 验证失败"
			_title_label.add_theme_color_override("font_color", COLOR_ALERT)
			_header_label.visible = false
			_body_label.text = "%s\n\n%s" % [
				HudTheme.format_terminal_log(RunEndingDefs.TERMINAL_VERIFY_FAIL_TEXT, false),
				RunEndingDefs.TERMINAL_STRIKE_TEXT,
			]
			_body_label.add_theme_color_override("font_color", COLOR_ALERT)
			_primary_btn.text = "接受结算"
			_primary_btn.disabled = false
		Phase.RESULT_PASS:
			_title_label.text = "通信终端 · 权限移交"
			HudTheme.apply_terminal_title(_title_label)
			_header_label.visible = false
			_body_label.text = "%s\n\n%s" % [
				HudTheme.format_terminal_log(_pass_text(), false),
				HudTheme.format_terminal_log(RunEndingDefs.TERMINAL_TRANSFER_TEXT, false),
			]
			_primary_btn.text = "接管控制台"
			_primary_btn.disabled = false


func _set_terminal_body(raw: String) -> void:
	var header := HudTheme.extract_terminal_header(raw)
	_header_label.text = header
	_header_label.visible = not header.is_empty()
	_body_label.text = HudTheme.format_terminal_log(raw)


func _refresh_log_history() -> void:
	if not is_instance_valid(_log_history):
		return
	var intel := "> 情报收集：%d / %d" % [
		MetaManager.encounters_unlocked_count(),
		MetaManager.required_encounter_count(),
	]
	_log_history.text = "%s\n\n%s\n\n%s" % [
		intel,
		MetaManager.format_current_run_preview(_run_journal_entries, 8),
		MetaManager.format_uploaded_logs_preview(4),
	]


func _perform_upload() -> void:
	if _upload_done:
		return
	MetaManager.upload_run_journal(_run_journal_entries, _run_layer, _day_index)
	MetaManager.save_meta()
	_upload_done = true


func _build_report_options() -> void:
	for key in RunEndingDefs.TERMINAL_REPORT_OPTIONS.keys():
		var label: String = RunEndingDefs.TERMINAL_REPORT_OPTIONS[key]
		var btn := Button.new()
		btn.text = label
		btn.custom_minimum_size = Vector2(0, 42)
		HudTheme.apply_sci_fi_terminal_button(btn, Color("#8ec8e8"))
		btn.pressed.connect(_on_report_chosen.bind(str(key)))
		_options_box.add_child(btn)
		_option_buttons.append(btn)


func _clear_option_buttons() -> void:
	for btn in _option_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_option_buttons.clear()


func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	HudTheme.apply_terminal_section(label)
	return label


func _apply_captcha_slider_theme() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.10, 0.14, 0.88)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#3a8ab0")
	fill.set_corner_radius_all(4)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color("#6eb8ff")
	grabber.set_corner_radius_all(3)
	grabber.content_margin_top = 4
	grabber.content_margin_bottom = 4
	_captcha_slider.add_theme_stylebox_override("slider", bg)
	_captcha_slider.add_theme_stylebox_override("grabber_area", fill)
	_captcha_slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	_captcha_slider.add_theme_stylebox_override("grabber", grabber)
	_captcha_slider.add_theme_stylebox_override("grabber_highlight", grabber)


func _on_report_chosen(choice_id: String) -> void:
	_report_choice = choice_id
	_enter_phase(Phase.CAPTCHA)


func _on_captcha_value_changed(value: float) -> void:
	_captcha_hint.text = "滑块进度：%d / 100" % int(value)
	_primary_btn.disabled = value < 100.0


func _on_captcha_close_pressed() -> void:
	if _phase != Phase.CAPTCHA:
		return
	_enter_phase(Phase.EVIDENCE_AUDIT)


func _required_evidence_ids() -> Array[String]:
	var ids: Array[String] = []
	var configured := EvidenceData.terminal_required_ids()
	if not configured.is_empty():
		for id in configured:
			ids.append(str(id))
		return ids
	for id in REQUIRED_EVIDENCE_IDS:
		ids.append(str(id))
	return ids


func _has_evidence_item(evidence_id: String) -> bool:
	return int(_backpack_snapshot.get("evidence:%s" % evidence_id, 0)) > 0


func _evidence_audit_report() -> Dictionary:
	var missing: Array[String] = []
	var present: Array[String] = []
	for evidence_id in _required_evidence_ids():
		if _has_evidence_item(evidence_id):
			present.append(EvidenceData.title_of(evidence_id))
		else:
			missing.append(EvidenceData.title_of(evidence_id))
	var lines: PackedStringArray = []
	lines.append("> 操作者主动放弃 CAPTCHA。")
	lines.append("> 终端转入异常中断审计，扫描背包内实体证据。")
	lines.append("")
	if not present.is_empty():
		lines.append("> 已提交证据：%s" % "、".join(present))
	if missing.is_empty():
		lines.append("> 归档证明链完整。")
		lines.append("> 操作员 CAPTCHA 已放弃；物理证据包验证紧急移交后门。")
		return {"passed": true, "text": "\n".join(lines)}
	lines.append("> 缺失证据：%s" % "、".join(missing))
	lines.append("> 中断行为缺少授权依据。")
	return {"passed": false, "text": "\n".join(lines)}


func _pass_text() -> String:
	if _audit_passed:
		return RunEndingDefs.TERMINAL_AUDIT_PASS_TEXT
	return RunEndingDefs.TERMINAL_VERIFY_PASS_TEXT


func _on_primary_pressed() -> void:
	match _phase:
		Phase.INTRO:
			_enter_phase(Phase.UPLOAD)
		Phase.UPLOAD:
			_perform_upload()
			_enter_phase(Phase.READ)
		Phase.READ:
			_enter_phase(Phase.REPORT)
		Phase.CAPTCHA:
			if _captcha_slider.value < 100.0:
				return
			_enter_phase(Phase.RESULT_FAIL)
		Phase.EVIDENCE_AUDIT:
			if _audit_passed:
				_enter_phase(Phase.RESULT_PASS)
			else:
				_enter_phase(Phase.RESULT_FAIL)
		Phase.RESULT_FAIL:
			hide_terminal()
			strike_completed.emit()
		Phase.RESULT_PASS:
			hide_terminal()
			transfer_completed.emit()
