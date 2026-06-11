extends Control
class_name ContinuePrompt

const TRI_COLOR := Color("#507896")
const BLINK_MIN := 0.25
const BLINK_MAX := 1.0
const BLINK_HALF_SEC := 0.55

var _alpha := BLINK_MAX
var _tween: Tween


func _ready() -> void:
	custom_minimum_size = Vector2(36, 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_blink()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if visible:
			_start_blink()
		else:
			_stop_blink()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var pts := PackedVector2Array([
		Vector2(w * 0.15, h * 0.2),
		Vector2(w * 0.85, h * 0.5),
		Vector2(w * 0.15, h * 0.8),
	])
	var col := TRI_COLOR
	col.a = _alpha
	draw_colored_polygon(pts, col)


func _start_blink() -> void:
	_stop_blink()
	_alpha = BLINK_MAX
	_tween = create_tween()
	_tween.set_loops()
	_tween.tween_method(_set_alpha, BLINK_MAX, BLINK_MIN, BLINK_HALF_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_set_alpha, BLINK_MIN, BLINK_MAX, BLINK_HALF_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_blink() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _set_alpha(v: float) -> void:
	_alpha = v
	queue_redraw()
