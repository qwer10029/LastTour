extends CharacterBody2D
class_name PlayerCharacter

signal moved

@export var move_speed: float = 240.0
@export var world_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(1280, 720))

var _hud_callback: Callable = Callable()
var _blocked_checker: Callable = Callable()
var _active := false

@onready var camera: Camera2D = $Camera2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("player")
	set_active(false)
	_load_texture()

func _load_texture() -> void:
	if is_instance_valid(sprite):
		var tex: Texture2D = ArtAssetLoader.load_texture("res://assets/dummy/player_dummy.png", "res://assets/dummy/player_dummy.svg")
		sprite.texture = tex
		# Auto-scale large PNG/SVG so player icon fits expected size on screen
		if tex != null:
			var desired_px := 48.0
			var sz: Vector2i = tex.get_size()
			if sz.x > 0 and sz.y > 0:
				var factor: float = minf(minf(desired_px / float(sz.x), desired_px / float(sz.y)), 1.0)
				sprite.scale = Vector2(factor, factor)

func set_active(active: bool) -> void:
	_active = active
	visible = active
	set_physics_process(active)
	set_process(active)
	if is_instance_valid(camera):
		if active:
			camera.make_current()

func set_hud_callback(callback: Callable) -> void:
	_hud_callback = callback


func set_blocked_checker(callback: Callable) -> void:
	_blocked_checker = callback


func _physics_process(delta: float) -> void:
	var prev_pos := global_position
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_vector * move_speed
	move_and_slide()
	clamp_to_world()
	if _blocked_checker.is_valid() and bool(_blocked_checker.call(global_position)):
		global_position = prev_pos
		velocity = Vector2.ZERO
	if input_vector != Vector2.ZERO:
		emit_signal("moved")
		if _hud_callback.is_valid():
			_hud_callback.call()

func clamp_to_world() -> void:
	global_position.x = clamp(global_position.x, world_bounds.position.x + 16.0, world_bounds.position.x + world_bounds.size.x - 16.0)
	global_position.y = clamp(global_position.y, world_bounds.position.y + 16.0, world_bounds.position.y + world_bounds.size.y - 16.0)
