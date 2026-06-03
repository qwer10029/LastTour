extends CharacterBody2D
class_name VehicleUnit

const DayTopdownRender = preload("res://scripts/day_topdown_render.gd")

@export var road_y: float = 448.0

@onready var camera: Camera2D = $Camera2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("vehicle")
	set_active(false)
	_load_texture()

func _load_texture() -> void:
	if not is_instance_valid(sprite):
		return
	var tex: Texture2D = DayTopdownRender.vehicle_texture()
	sprite.texture = tex
	if tex == null:
		return
	var desired_px := DayTopdownRender.vehicle_display_width() * DayTopdownRender.VEHICLE_DISPLAY_SCALE
	var sz: Vector2i = tex.get_size()
	if sz.x > 0 and sz.y > 0:
		var factor: float = desired_px / maxf(float(sz.x), float(sz.y))
		sprite.scale = Vector2(factor, factor)

func set_active(active: bool) -> void:
	set_physics_process(active)
	set_process(active)
	if is_instance_valid(sprite):
		sprite.visible = false
	if is_instance_valid(camera):
		if active:
			camera.make_current()
