extends Control
class_name NightTdDurabilityBar

## 车辆耐久分段条：使用 bar_durability_segments.png，数值变化时 Tween 平滑过渡。

@export var tween_duration: float = 0.35

var _ratio: float = 1.0
var _tween: Tween
var _bar_tex: Texture2D
var _fill_rect: ColorRect
var _track: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(320, 28)
	_bar_tex = NightTdUiTheme.load_texture(NightTdUiTheme.BAR_DURABILITY_SEGMENTS)

	_track = TextureRect.new()
	_track.name = "Track"
	_track.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_track.stretch_mode = TextureRect.STRETCH_SCALE
	_track.set_anchors_preset(Control.PRESET_FULL_RECT)
	if _bar_tex != null:
		_track.texture = _bar_tex
	else:
		_track.modulate = Color("#1a2533")
	add_child(_track)

	_fill_rect = ColorRect.new()
	_fill_rect.name = "Fill"
	_fill_rect.color = Color("#d89246", 0.85)
	_fill_rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_fill_rect.offset_left = 4.0
	_fill_rect.offset_top = 4.0
	_fill_rect.offset_bottom = -4.0
	add_child(_fill_rect)

	_apply_ratio_visual(_ratio, false)


func set_ratio(target: float, animate: bool = true) -> void:
	var clamped := clampf(target, 0.0, 1.0)
	if not animate:
		_ratio = clamped
		_apply_ratio_visual(_ratio, false)
		return
	if is_equal_approx(clamped, _ratio):
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_apply_ratio_visual, _ratio, clamped, tween_duration)
	_ratio = clamped


func _apply_ratio_visual(value: float, _unused: Variant = null) -> void:
	if not is_instance_valid(_fill_rect):
		return
	var inner_w := maxf(size.x - 8.0, 1.0)
	_fill_rect.offset_right = 4.0 + inner_w * clampf(value, 0.0, 1.0)
