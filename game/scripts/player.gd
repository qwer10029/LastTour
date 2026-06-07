extends CharacterBody2D
class_name PlayerCharacter

signal moved

@export var move_speed: float = 96.0
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
		var tex: Texture2D = ArtAssetLoader.load_texture_sprite_alpha_key(
			"res://assets/sprites/player_foot_walk_all.png",
			0.12,
			"res://assets/sprites/player_foot_walk_up.png",
		)
		if tex == null:
			tex = ArtAssetLoader.load_texture("res://assets/dummy/player_dummy.svg")
		sprite.texture = tex
		sprite.hframes = 1
		sprite.frame = 0
		if tex != null:
			var desired_px := 52.0
			var sz: Vector2i = tex.get_size()
			if sz.x > 0 and sz.y > 0:
				var sheet_frames := 8 if float(sz.x) / float(sz.y) >= 3.5 and float(sz.x) / 8.0 / float(sz.y) < 0.68 else 1
				if sheet_frames > 1:
					sprite.hframes = sheet_frames
					sprite.frame = 1
				var frame_w := float(sz.x) / float(sprite.hframes)
				var factor: float = desired_px / maxf(frame_w, float(sz.y))
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
	if world_bounds.size == Vector2.ZERO:
		return
	global_position.x = clampf(global_position.x, world_bounds.position.x, world_bounds.end.x)
	global_position.y = clampf(global_position.y, world_bounds.position.y, world_bounds.end.y)
