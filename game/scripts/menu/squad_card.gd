extends Control
class_name SquadCard

## 分队选项卡：与难度页相同 TextureButton 方案，保证贴图可见。

signal pressed

const HOVER_SCALE := Vector2(1.02, 1.02)
const HOVER_DURATION := 0.15
const INTRO_SWEEP_SEC := 0.55
const INTRO_PULSE_SEC := 0.35
const ICON_WIDTH_RATIO := 0.24

@export var card_display_size: Vector2 = Vector2(560, 148)
@export var glow_color: Color = Color(0.35, 0.95, 0.55, 0.58)

@onready var _glow: Panel = $GlowPanel
@onready var _card: TextureButton = $CardButton
@onready var _icon_region: Control = $IconRegion
@onready var _sweep: ColorRect = $IconRegion/SweepGlare
@onready var _icon_flash: ColorRect = $IconRegion/IconFlashOverlay

var _scale_tween: Tween
var _glow_tween: Tween
var _flash_tween: Tween
var _intro_done := false


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_card_size()
	_setup_card_button()
	_apply_glow_style()
	_glow.modulate.a = 0.0
	_setup_sweep_layers()
	_card.mouse_entered.connect(_on_hover_enter)
	_card.mouse_exited.connect(_on_hover_exit)
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)
	_card.pressed.connect(func() -> void: pressed.emit())


func configure(texture: Texture2D, glow: Color = glow_color, display_size: Vector2 = Vector2.ZERO) -> void:
	glow_color = glow
	if display_size != Vector2.ZERO:
		card_display_size = display_size
	if not is_node_ready():
		call_deferred("_apply_configure", texture)
		return
	_apply_configure(texture)


func _apply_configure(texture: Texture2D) -> void:
	_apply_card_size()
	_setup_card_button()
	if is_instance_valid(_card):
		_card.texture_normal = texture
		_card.modulate = Color.WHITE
	if is_instance_valid(_glow):
		_glow.modulate.a = 0.45 if texture == null else 0.0
	_apply_glow_style()
	_layout_icon_region()


func _apply_card_size() -> void:
	custom_minimum_size = card_display_size
	if is_instance_valid(_card):
		_card.custom_minimum_size = card_display_size
		_card.pivot_offset = card_display_size * 0.5
		_card.scale = Vector2.ONE


func _setup_card_button() -> void:
	if not is_instance_valid(_card):
		return
	_card.ignore_texture_size = true
	_card.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
	_card.focus_mode = Control.FOCUS_NONE
	_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	_card.add_theme_stylebox_override("normal", empty)
	_card.add_theme_stylebox_override("hover", empty)
	_card.add_theme_stylebox_override("pressed", empty)
	_card.add_theme_stylebox_override("disabled", empty)
	_card.add_theme_stylebox_override("focus", empty)


func _setup_sweep_layers() -> void:
	_layout_icon_region()
	if is_instance_valid(_sweep):
		_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sweep.color = Color(0.72, 0.98, 1.0, 0.0)
	if is_instance_valid(_icon_flash):
		_icon_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_flash.color = Color(0.55, 0.95, 0.82, 0.0)


func _layout_icon_region() -> void:
	if not is_instance_valid(_icon_region):
		return
	var icon_w := card_display_size.x * ICON_WIDTH_RATIO
	_icon_region.position = Vector2.ZERO
	_icon_region.size = Vector2(icon_w, card_display_size.y)
	if is_instance_valid(_sweep):
		_sweep.size = Vector2(icon_w * 0.35, card_display_size.y)
		_sweep.position = Vector2(-icon_w * 0.35, 0.0)
	if is_instance_valid(_icon_flash):
		_icon_flash.set_anchors_preset(Control.PRESET_FULL_RECT)


func play_intro_animation(delay_sec: float = 0.0) -> void:
	if delay_sec > 0.0:
		await get_tree().create_timer(delay_sec).timeout
	if not is_instance_valid(self):
		return
	_play_icon_sweep()
	await get_tree().create_timer(INTRO_SWEEP_SEC * 0.85).timeout
	if not is_instance_valid(self):
		return
	_play_card_pulse()
	_intro_done = true


func _apply_glow_style() -> void:
	if not is_instance_valid(_glow):
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.78)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = glow_color
	style.shadow_size = 22
	style.expand_margin_left = 10
	style.expand_margin_top = 10
	style.expand_margin_right = 10
	style.expand_margin_bottom = 10
	_glow.add_theme_stylebox_override("panel", style)


func _play_icon_sweep() -> void:
	if not is_instance_valid(_sweep):
		return
	var icon_w := _icon_region.size.x
	_sweep.position.x = -_sweep.size.x
	_sweep.color = Color(0.75, 1.0, 0.95, 0.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_sweep, "position:x", icon_w, INTRO_SWEEP_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		func(a: float) -> void:
			var c := _sweep.color
			c.a = a
			_sweep.color = c,
		0.0,
		0.85,
		INTRO_SWEEP_SEC * 0.45,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_method(
		func(a: float) -> void:
			var c := _sweep.color
			c.a = a
			_sweep.color = c,
		0.85,
		0.0,
		INTRO_SWEEP_SEC * 0.4,
	)


func _play_card_pulse() -> void:
	if not is_instance_valid(_card):
		return
	_card.modulate = Color(0.88, 0.92, 0.96, 1.0)
	var tween := create_tween()
	tween.tween_property(_card, "modulate", Color(1.08, 1.1, 1.05, 1.0), INTRO_PULSE_SEC * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "modulate", Color.WHITE, INTRO_PULSE_SEC * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _on_hover_enter() -> void:
	_tween_scale(HOVER_SCALE)
	_tween_glow(1.0)
	_tween_icon_flash(1.0)


func _on_hover_exit() -> void:
	_tween_scale(Vector2.ONE)
	_tween_glow(0.0)
	_tween_icon_flash(0.0)


func _tween_scale(target: Vector2) -> void:
	if not is_instance_valid(_card):
		return
	_kill_tween(_scale_tween)
	_scale_tween = create_tween()
	_scale_tween.set_trans(Tween.TRANS_CUBIC)
	_scale_tween.set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(_card, "scale", target, HOVER_DURATION)


func _tween_glow(alpha: float) -> void:
	_kill_tween(_glow_tween)
	_glow_tween = create_tween()
	_glow_tween.set_trans(Tween.TRANS_CUBIC)
	_glow_tween.set_ease(Tween.EASE_OUT)
	_glow_tween.tween_property(_glow, "modulate:a", alpha, HOVER_DURATION)


func _tween_icon_flash(alpha: float) -> void:
	_kill_tween(_flash_tween)
	_flash_tween = create_tween()
	_flash_tween.set_trans(Tween.TRANS_CUBIC)
	_flash_tween.set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(_icon_flash, "color:a", alpha * 0.42, HOVER_DURATION)


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
