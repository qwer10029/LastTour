extends Control

@onready var _texture_rect: TextureRect = %BackgroundImage
@onready var _narration_label: Label = %NarrationLabel
@onready var _page_label: Label = %PageLabel
@onready var _next_button: Button = %NextButton
@onready var _skip_button: Button = %SkipButton
@onready var _narration_bar: PanelContainer = $NarrationBar

var _slide_index := 0


func _ready() -> void:
	_style_narration_bar()
	MenuStyles.style_menu_button(_next_button)
	MenuStyles.style_menu_button(_skip_button)
	_style_narration_text(_narration_label, 22)
	_style_narration_text(_page_label, 16)
	_next_button.pressed.connect(_on_next_pressed)
	_skip_button.pressed.connect(_on_skip_pressed)
	_show_slide(0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()


func _style_narration_bar() -> void:
	var style := StyleBoxEmpty.new()
	_narration_bar.add_theme_stylebox_override("panel", style)


func _style_narration_text(label: Label, font_size: int) -> void:
	label.add_theme_color_override("font_color", MenuStyles.TITLE_COLOR)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.95))
	label.add_theme_constant_override("font_outline_size", 4)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))


func _show_slide(index: int) -> void:
	_slide_index = clampi(index, 0, OpeningPrologueDefs.slide_count() - 1)
	var data := OpeningPrologueDefs.slide(_slide_index)
	var image_path := str(data.get("image", ""))
	if image_path != "" and ResourceLoader.exists(image_path):
		var tex := load(image_path) as Texture2D
		_texture_rect.texture = tex
	var lines: Array = data.get("lines", [])
	_narration_label.text = "\n".join(lines)
	var total := OpeningPrologueDefs.slide_count()
	_page_label.text = "%d / %d" % [_slide_index + 1, total]
	var is_last := _slide_index >= total - 1
	_next_button.text = "开始游戏" if is_last else "下一段  ▶"


func _advance() -> void:
	if _slide_index >= OpeningPrologueDefs.slide_count() - 1:
		_finish()
	else:
		_show_slide(_slide_index + 1)


func _on_next_pressed() -> void:
	_advance()


func _on_skip_pressed() -> void:
	_finish()


func _finish() -> void:
	GameManager.go_to_difficulty_select()
