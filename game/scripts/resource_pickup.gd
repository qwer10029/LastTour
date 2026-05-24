extends Area2D

signal collected(item_id: String)

var item_id: String = "scrap"
var _is_collected := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label


func _ready() -> void:
	if has_meta("item_id"):
		item_id = str(get_meta("item_id"))
	body_entered.connect(_on_body_entered)
	_load_texture()
	_refresh_label()


func setup_loot(id: String) -> void:
	item_id = id
	set_meta("item_id", id)
	_load_texture()
	_refresh_label()


func _load_texture() -> void:
	if not is_instance_valid(sprite):
		return
	if _is_evidence():
		sprite.texture = ItemIconFactory.get_texture("scrap", 28)
		sprite.modulate = Color("#ffd966")
		if sprite.texture != null:
			var tex_size := sprite.texture.get_size()
			if tex_size.x > 0.0:
				var scale_factor := 28.0 / maxf(tex_size.x, tex_size.y)
				sprite.scale = Vector2(scale_factor, scale_factor)
		return
	sprite.texture = ItemIconFactory.get_texture(item_id, 28)
	sprite.modulate = Color.WHITE
	if sprite.texture != null:
		var tex_size := sprite.texture.get_size()
		if tex_size.x > 0.0:
			var scale_factor := 28.0 / maxf(tex_size.x, tex_size.y)
			sprite.scale = Vector2(scale_factor, scale_factor)


func _refresh_label() -> void:
	if not is_instance_valid(label):
		return
	if _is_evidence():
		label.text = EvidenceData.title_of(_evidence_id())
		label.add_theme_color_override("font_color", Color("#ffe28a"))
		return
	label.text = ItemDefs.get_item_name(item_id)
	label.add_theme_color_override("font_color", ItemDefs.get_def(item_id).get("color", Color("#eef8ff")))


func _on_body_entered(body: Node) -> void:
	if _is_collected:
		return
	if body.is_in_group("player"):
		_is_collected = true
		collected.emit(item_id)
		queue_free()

func _is_evidence() -> bool:
	return item_id.begins_with("evidence:")

func _evidence_id() -> String:
	return item_id.substr("evidence:".length())
