extends Button
class_name StoryChoiceButton

const HOVER_SHIFT := 8.0
const TWEEN_SEC := 0.18

var _normal_style: StyleBoxFlat
var _rest_border: Color
var _hover_border: Color = DialogueUiTheme.BORDER_HOVER
var _shift_tween: Tween
var _border_tween: Tween
var _shift_host: MarginContainer
var _is_hovered := false


func bind_hover_shift(host: MarginContainer) -> void:
	_shift_host = host


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = Vector2(300, 0)

	_normal_style = DialogueUiTheme.choice_button_normal_style()
	_rest_border = _normal_style.border_color
	add_theme_stylebox_override("normal", _normal_style)
	add_theme_stylebox_override("focus", _normal_style)
	add_theme_stylebox_override("pressed", _normal_style)
	add_theme_stylebox_override("hover", _normal_style)

	HudTheme.apply_button(self)
	add_theme_color_override("font_color", Color("#dce8f0"))

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	if _is_hovered:
		return
	_is_hovered = true
	_tween_shift(HOVER_SHIFT)
	_tween_border(_hover_border, 2)


func _on_mouse_exited() -> void:
	if not _is_hovered:
		return
	_is_hovered = false
	_tween_shift(0)
	_tween_border(_rest_border, 1)


func _tween_shift(target_margin: float) -> void:
	if _shift_host == null:
		return
	if _shift_tween != null and _shift_tween.is_valid():
		_shift_tween.kill()
	_shift_tween = create_tween()
	_shift_tween.tween_method(
		func(v: float) -> void:
			_shift_host.add_theme_constant_override("margin_left", int(v)),
		float(_shift_host.get_theme_constant("margin_left")),
		target_margin,
		TWEEN_SEC,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _tween_border(target: Color, width: int) -> void:
	if _border_tween != null and _border_tween.is_valid():
		_border_tween.kill()
	var style := _normal_style
	_border_tween = create_tween()
	_border_tween.tween_method(
		func(c: Color) -> void:
			style.border_color = c,
		style.border_color,
		target,
		TWEEN_SEC,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_border_tween.parallel().tween_method(
		func(w: float) -> void:
			style.border_width_left = int(w)
			style.border_width_top = int(w)
			style.border_width_right = int(w)
			style.border_width_bottom = int(w),
		float(style.border_width_left),
		float(width),
		TWEEN_SEC,
	)
