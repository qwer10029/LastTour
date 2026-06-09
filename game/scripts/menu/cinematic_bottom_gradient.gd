extends Control

@export var bottom_alpha: float = 0.78

var _gradient_tex: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_rebuild_gradient)
	_rebuild_gradient()


func _rebuild_gradient() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var grad := Gradient.new()
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	grad.add_point(0.0, Color(0.0, 0.0, 0.0, 0.0))
	grad.add_point(0.5, Color(0.0, 0.0, 0.0, 0.0))
	grad.add_point(0.72, Color(0.0, 0.0, 0.0, bottom_alpha * 0.45))
	grad.add_point(1.0, Color(0.0, 0.0, 0.0, bottom_alpha))
	_gradient_tex = GradientTexture2D.new()
	_gradient_tex.gradient = grad
	_gradient_tex.fill_from = Vector2(0.5, 0.0)
	_gradient_tex.fill_to = Vector2(0.5, 1.0)
	_gradient_tex.width = maxi(1, int(size.x))
	_gradient_tex.height = maxi(1, int(size.y))
	queue_redraw()


func _draw() -> void:
	if _gradient_tex == null:
		return
	draw_texture_rect(_gradient_tex, Rect2(Vector2.ZERO, size), false)
