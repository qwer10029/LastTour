extends PanelContainer

@onready var title_label: Label = %TitleLabel
@onready var body_label: Label = %BodyLabel

var _visible_timer: float = 0.0


func _ready() -> void:
	visible = false
	modulate.a = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_visible_timer += delta
	var pulse := 0.85 + 0.15 * sin(_visible_timer * 4.0)
	modulate = Color(1.0, pulse, pulse * 0.6, 1.0)


func show_evening_warning(remaining_sec: float) -> void:
	visible = true
	modulate.a = 1.0
	_visible_timer = 0.0
	if is_instance_valid(title_label):
		title_label.text = "傍晚 · 即将入夜"
	if is_instance_valid(body_label):
		body_label.text = "探索阶段即将结束。请尽快返回车辆，按 F 进入布防模式。（剩余约 %.0f 秒）" % remaining_sec


func show_night_setup() -> void:
	visible = true
	modulate.a = 1.0
	_visible_timer = 0.0
	if is_instance_valid(title_label):
		title_label.text = "入夜 · 开始设防"
	if is_instance_valid(body_label):
		body_label.text = "白天探索已结束。进入俯视角塔防：用背包资源布防，再抵御敌袭。"


func hide_notice() -> void:
	visible = false
	modulate.a = 0.0
