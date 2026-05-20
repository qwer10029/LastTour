extends CharacterBody2D
class_name VehicleUnit

@export var road_y: float = 448.0

@onready var camera: Camera2D = $Camera2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("vehicle")
	set_active(false)
	_load_texture()

func _load_texture() -> void:
	if is_instance_valid(sprite):
		var tex: Texture2D = ArtAssetLoader.load_texture("res://assets/dummy/vehicle_dummy.png", "res://assets/dummy/vehicle_dummy.svg")
		sprite.texture = tex
		if tex != null:
			var desired_px := 64.0
			var sz: Vector2i = tex.get_size()
			if sz.x > 0 and sz.y > 0:
				var factor: float = minf(minf(desired_px / float(sz.x), desired_px / float(sz.y)), 1.0)
				sprite.scale = Vector2(factor, factor)

func set_active(active: bool) -> void:
	set_physics_process(active)
	set_process(active)
	if is_instance_valid(sprite):
		sprite.visible = false
	if is_instance_valid(camera):
		if active:
			camera.make_current()
