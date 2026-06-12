extends CanvasLayer
class_name StoryDialogueUI

signal choice_pressed(index: int)
signal advance_requested

const MAX_CHARS_PER_PAGE := 88
const MAX_VISIBLE_LINES := 3
const ADVANCE_DEBOUNCE_SEC := 0.12

@onready var _bottom: VBoxContainer = $Root/BottomAnchor
@onready var _name_panel: PanelContainer = $Root/BottomAnchor/NameTagRow/NameTagPanel
@onready var _name_label: Label = $Root/BottomAnchor/NameTagRow/NameTagPanel/NameLabel
@onready var _dialog_panel: PanelContainer = $Root/BottomAnchor/DialogPanel
@onready var _body_label: Label = \
	$Root/BottomAnchor/DialogPanel/DialogMargin/DialogVBox/BodyLabel
@onready var _choice_hint: Label = \
	$Root/BottomAnchor/DialogPanel/DialogMargin/DialogVBox/ChoiceHint
@onready var _continue: ContinuePrompt = \
	$Root/BottomAnchor/DialogPanel/DialogMargin/DialogVBox/FooterRow/ContinuePrompt
@onready var _choice_column: VBoxContainer = $Root/BottomAnchor/ChoiceColumn

var _choice_buttons: Array[StoryChoiceButton] = []
var _pages: PackedStringArray = []
var _page_index := 0
var _show_continue_on_last_page := true
var _choice_mode := false
var _next_advance_time_msec := 0


func _ready() -> void:
	layer = 120
	visible = false
	_apply_static_styles()
	_choice_hint.visible = false
	_dialog_panel.gui_input.connect(_on_dialog_gui_input)


func _apply_static_styles() -> void:
	_dialog_panel.add_theme_stylebox_override("panel", DialogueUiTheme.dialog_panel_style())
	_name_panel.add_theme_stylebox_override("panel", DialogueUiTheme.name_tag_style())
	HudTheme.apply_label(_body_label)
	HudTheme.apply_compact_label(_name_label)
	HudTheme.apply_compact_label(_choice_hint)
	_name_label.add_theme_color_override("font_color", Color("#8ec8e8"))
	_choice_hint.add_theme_color_override("font_color", Color("#9eb4c8"))
	_dialog_panel.mouse_filter = Control.MOUSE_FILTER_STOP


func hide_dialogue() -> void:
	visible = false
	_choice_mode = false
	_pages.clear()
	_page_index = 0
	_clear_choices()


func is_choice_mode() -> bool:
	return _choice_mode


func get_choice_count() -> int:
	return _choice_buttons.size()


func try_advance_page() -> bool:
	if _choice_mode or not visible:
		return false
	if not _can_advance_now():
		return true
	if _page_index < _pages.size() - 1:
		_mark_advanced()
		_page_index += 1
		_apply_page()
		return true
	return false


func show_narrative(body: String, speaker: String = "", show_continue: bool = true) -> void:
	_clear_choices()
	_choice_mode = false
	_show_continue_on_last_page = show_continue
	_pages = _split_pages(body.strip_edges())
	_page_index = 0
	_mark_advanced()
	_set_speaker(speaker)
	_choice_hint.visible = false
	_apply_page()
	visible = true


func show_choices(
	body: String,
	options: Array,
	speaker: String = "",
	hint: String = "",
) -> void:
	show_narrative(body, speaker, false)
	_choice_mode = true
	_continue.visible = false
	_choice_hint.text = hint
	_choice_hint.visible = hint.strip_edges() != ""
	_build_choice_buttons(options)
	visible = true


func _set_speaker(speaker_name: String) -> void:
	var trimmed := speaker_name.strip_edges()
	_name_label.text = trimmed
	_name_panel.visible = trimmed != ""


func _apply_page() -> void:
	if _pages.is_empty():
		_body_label.text = ""
		_continue.visible = false
		_reflow_body()
		return
	_body_label.text = _pages[_page_index]
	var on_last := _page_index >= _pages.size() - 1
	_continue.visible = not _choice_mode and (not on_last or _show_continue_on_last_page)
	_reflow_body()


func _split_pages(text: String) -> PackedStringArray:
	if text.is_empty():
		return PackedStringArray()
	var paragraphs: PackedStringArray = []
	for block in text.split("\n"):
		var trimmed := str(block).strip_edges()
		if trimmed != "":
			paragraphs.append(trimmed)
	if paragraphs.is_empty():
		return PackedStringArray([text])
	var pages: PackedStringArray = []
	var current := ""
	for para in paragraphs:
		if current.is_empty():
			current = para
		elif current.length() + 1 + para.length() <= MAX_CHARS_PER_PAGE:
			current = "%s\n%s" % [current, para]
		else:
			pages.append(current)
			current = para
		while current.length() > MAX_CHARS_PER_PAGE:
			var cut := _soft_cut(current, MAX_CHARS_PER_PAGE)
			pages.append(cut)
			current = current.substr(cut.length()).strip_edges()
	if not current.is_empty():
		pages.append(current)
	return pages


func _soft_cut(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	var slice := text.substr(0, max_len)
	for sep in ["。", "！", "？", "……", "，", " ", "\n"]:
		var pos := slice.rfind(sep)
		if pos > int(max_len * 0.45):
			return slice.substr(0, pos + sep.length()).strip_edges()
	return slice.strip_edges()


func _clear_choices() -> void:
	for child in _choice_column.get_children():
		child.queue_free()
	_choice_buttons.clear()


func _build_choice_buttons(options: Array) -> void:
	_clear_choices()
	var labels: Array[String] = []
	for opt in options:
		var t := str(opt).strip_edges()
		if t != "":
			labels.append(t)
	if labels.is_empty():
		return

	for i in range(labels.size()):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.custom_minimum_size = Vector2(0, 44)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_choice_column.add_child(row)

		var shift_wrap := MarginContainer.new()
		shift_wrap.add_theme_constant_override("margin_left", 0)
		row.add_child(shift_wrap)

		var btn := StoryChoiceButton.new()
		btn.text = "%d · %s" % [i + 1, labels[i]]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.bind_hover_shift(shift_wrap)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_choice.bind(i))
		shift_wrap.add_child(btn)
		_choice_buttons.append(btn)


func _on_choice(index: int) -> void:
	call_deferred("_emit_choice", index)


func _emit_choice(index: int) -> void:
	choice_pressed.emit(index)
	hide_dialogue()


func _on_dialog_gui_input(event: InputEvent) -> void:
	if _choice_mode:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if not _can_advance_now():
				return
			if try_advance_page():
				return
			advance_requested.emit()


func _can_advance_now() -> bool:
	return Time.get_ticks_msec() >= _next_advance_time_msec


func _mark_advanced() -> void:
	_next_advance_time_msec = Time.get_ticks_msec() + int(ADVANCE_DEBOUNCE_SEC * 1000.0)


func _reflow_body() -> void:
	call_deferred("_sync_body_layout")


func _sync_body_layout() -> void:
	if not is_instance_valid(_body_label) or not is_instance_valid(_dialog_panel):
		return
	var width := maxf(_bottom.size.x - 32.0, 280.0)
	_body_label.custom_minimum_size = Vector2(width, 0.0)
	var line_h := maxf(_body_label.get_theme_font_size("font_size"), 14) + 6
	var lines := maxi(_body_label.get_line_count(), 1)
	lines = mini(lines, MAX_VISIBLE_LINES)
	var body_h := float(lines) * line_h + 8.0
	_body_label.custom_minimum_size.y = body_h
	_dialog_panel.custom_minimum_size.y = body_h + 72.0
