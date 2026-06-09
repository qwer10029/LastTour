extends PanelContainer

@onready var title_label: Label = %TitleLabel
@onready var body_label: Label = %BodyLabel

var _visible_timer: float = 0.0
var _message_mode := false
var _message_timer: SceneTreeTimer


func _ready() -> void:
	visible = false
	modulate.a = 0.0


func _process(delta: float) -> void:
	if not visible or _message_mode:
		return
	_visible_timer += delta
	var pulse := 0.85 + 0.15 * sin(_visible_timer * 4.0)
	modulate = Color(1.0, pulse, pulse * 0.6, 1.0)


func show_message(title: String, body: String, duration_sec: float = 5.0) -> void:
	_message_mode = true
	visible = true
	modulate = Color.WHITE
	_visible_timer = 0.0
	if is_instance_valid(_message_timer):
		_message_timer.timeout.disconnect(_on_message_timeout)
	_message_timer = get_tree().create_timer(maxf(duration_sec, 1.0))
	_message_timer.timeout.connect(_on_message_timeout, CONNECT_ONE_SHOT)
	if is_instance_valid(title_label):
		title_label.text = title
	if is_instance_valid(body_label):
		body_label.text = body


func _on_message_timeout() -> void:
	hide_notice()


func show_evening_warning(remaining_sec: float) -> void:
	_message_mode = false
	visible = true
	modulate.a = 1.0
	_visible_timer = 0.0
	if is_instance_valid(title_label):
		title_label.text = "傍晚 · 即将入夜"
	if is_instance_valid(body_label):
		body_label.text = "探索阶段即将结束。请尽快返回车辆，按 F 进入布防模式。（剩余约 %.0f 秒）" % remaining_sec


func show_night_setup() -> void:
	_message_mode = false
	visible = true
	modulate.a = 1.0
	_visible_timer = 0.0
	if is_instance_valid(title_label):
		title_label.text = "入夜 · 开始设防"
	if is_instance_valid(body_label):
		body_label.text = "白天探索已结束。进入俯视角塔防：用背包资源布防，再抵御敌袭。"


func hide_notice() -> void:
	_message_mode = false
	visible = false
	modulate.a = 0.0
