extends PanelContainer

@onready var title_label: Label = %TitleLabel
@onready var body_label: Label = %BodyLabel

var _visible_timer: float = 0.0
var _active: bool = false


func _ready() -> void:
	visible = false
	modulate.a = 0.0


func _process(delta: float) -> void:
	if not _active or not visible:
		return
	_visible_timer += delta
	# Strong red pulse: oscillates between deep red and bright red
	var pulse := 0.7 + 0.3 * sin(_visible_timer * 5.0)
	modulate = Color(1.0, pulse * 0.35, pulse * 0.25, 1.0)


func show_warning() -> void:
	_active = true
	visible = true
	modulate.a = 1.0
	_visible_timer = 0.0
	if is_instance_valid(title_label):
		title_label.text = "⚠ 体力不足"
	if is_instance_valid(body_label):
		body_label.text = "体力已低于 20，请及时使用补给（按 B 打开背包）恢复体力"


func hide_warning() -> void:
	_active = false
	visible = false
	modulate.a = 0.0
