extends Node2D
class_name NightTdDefenceCoreVisual

const DayTopdownRender = preload("res://scripts/day_topdown_render.gd")

## 战场中央基地标识：车辆俯视图 + effect_energy_shield 护盾激活动画。

var _field: NightTdField
var _core_tex: Texture2D
var _shield_tex: Texture2D
var _shield_sprite: Sprite2D
var _core_sprite: Sprite2D
var _scale_base := Vector2.ONE
var _intro_played := false


func bind_field(field: NightTdField) -> void:
	_field = field


func _ready() -> void:
	_core_tex = DayTopdownRender.vehicle_texture()
	if _core_tex == null:
		_core_tex = NightTdUiTheme.load_texture(NightTdUiTheme.UNIT_DEFENCE_CORE)
	_shield_tex = NightTdUiTheme.load_texture(NightTdUiTheme.EFFECT_ENERGY_SHIELD)

	_core_sprite = Sprite2D.new()
	_core_sprite.name = "CoreSprite"
	_core_sprite.texture = _core_tex
	_core_sprite.centered = true
	add_child(_core_sprite)

	_shield_sprite = Sprite2D.new()
	_shield_sprite.name = "ShieldSprite"
	_shield_sprite.texture = _shield_tex
	_shield_sprite.centered = true
	_shield_sprite.modulate = Color(1, 1, 1, 0)
	add_child(_shield_sprite)

	_sync_scale()
	set_process(true)


func play_shield_activate() -> void:
	if _intro_played:
		return
	_intro_played = true
	_shield_sprite.modulate.a = 0.0
	_shield_sprite.scale = _scale_base * 0.92
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_shield_sprite, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_shield_sprite, "scale", _scale_base * 1.06, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(_shield_sprite, "scale", _scale_base, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	if _field == null or not is_instance_valid(_field):
		return
	global_position = _field.get_vehicle_center_world()
	var tile := _field.get_layout_tile_size()
	var target_diameter := tile * 2.28
	if _core_tex != null:
		var max_side := maxf(float(_core_tex.get_width()), float(_core_tex.get_height()))
		if max_side > 0.0:
			var s := target_diameter / max_side
			_scale_base = Vector2(s, s)
			if _core_sprite != null:
				_core_sprite.scale = _scale_base
			if _shield_sprite != null and not _intro_played:
				_shield_sprite.scale = _scale_base * 0.92


func _sync_scale() -> void:
	if _core_tex == null and _field != null:
		visible = false
