extends Area2D

signal collected

var _is_collected := false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_load_texture()

func _load_texture() -> void:
	if is_instance_valid(sprite):
		sprite.texture = ArtAssetLoader.load_texture("res://assets/dummy/resource_dummy.png", "res://assets/dummy/resource_dummy.svg")

func _on_body_entered(body: Node) -> void:
	if _is_collected:
		return
	if body.is_in_group("player"):
		_is_collected = true
		emit_signal("collected")
		queue_free()
