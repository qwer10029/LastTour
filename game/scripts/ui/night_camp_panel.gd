extends PanelContainer

signal confirm_pressed

@onready var title_label: Label = %NightTitleLabel
@onready var hint_label: Label = %NightHintLabel
@onready var jammer_button: Button = %JammerButton
@onready var barrier_button: Button = %BarrierButton
@onready var summary_label: Label = %DefenseSummaryLabel
@onready var confirm_button: Button = %ConfirmDefenseButton
@onready var result_label: Label = %NightResultLabel

var _defense_system: NightDefenseSystem


func _ready() -> void:
	visible = false
	if is_instance_valid(jammer_button):
		jammer_button.pressed.connect(func(): _toggle("jammer"))
	if is_instance_valid(barrier_button):
		barrier_button.pressed.connect(func(): _toggle("barrier"))
	if is_instance_valid(confirm_button):
		confirm_button.pressed.connect(_on_confirm_pressed)


func bind_defense_system(defense_system: NightDefenseSystem) -> void:
	_defense_system = defense_system
	if _defense_system != null and not _defense_system.defense_changed.is_connected(_refresh_buttons):
		_defense_system.defense_changed.connect(_refresh_buttons)


func show_camp() -> void:
	visible = true
	if is_instance_valid(result_label):
		result_label.text = ""
	if is_instance_valid(confirm_button):
		confirm_button.visible = true
		confirm_button.disabled = false
	_refresh_buttons()


func hide_camp() -> void:
	visible = false


func show_resolve_result(result: Dictionary) -> void:
	visible = true
	if is_instance_valid(confirm_button):
		confirm_button.visible = false
	if is_instance_valid(result_label):
		var outcome := str(result.get("outcome", ""))
		var outcome_text := "成功"
		match outcome:
			"partial":
				outcome_text = "部分损失"
			"fail":
				outcome_text = "失守"
		result_label.text = "%s\n威胁 %d · 防御 %d\n%s" % [
			outcome_text,
			int(result.get("threat_power", 0)),
			int(result.get("defense_power", 0)),
			str(result.get("message", "")),
		]
	_refresh_buttons()


func _toggle(defense_id: String) -> void:
	if _defense_system == null:
		return
	_defense_system.toggle_defense(defense_id)


func _refresh_buttons() -> void:
	if _defense_system == null:
		return
	var jammer_def: Dictionary = NightDefenseSystem.DEFENSE_OPTIONS.get("jammer", {})
	var barrier_def: Dictionary = NightDefenseSystem.DEFENSE_OPTIONS.get("barrier", {})
	if is_instance_valid(jammer_button):
		var on := _defense_system.is_defense_active("jammer")
		jammer_button.text = ("[已部署] " if on else "[  ] ") + str(jammer_def.get("name", "干扰信标")) + "\n" + str(jammer_def.get("description", ""))
	if is_instance_valid(barrier_button):
		var on_b := _defense_system.is_defense_active("barrier")
		barrier_button.text = ("[已部署] " if on_b else "[  ] ") + str(barrier_def.get("name", "物理路障")) + "\n" + str(barrier_def.get("description", ""))
	if is_instance_valid(summary_label):
		var names := _defense_system.get_active_defense_names()
		if names.is_empty():
			summary_label.text = "当前防御力: %d（未部署任何手段）" % _defense_system.get_total_defense_power()
		else:
			summary_label.text = "当前防御力: %d · 已部署: %s" % [_defense_system.get_total_defense_power(), ", ".join(names)]


func _on_confirm_pressed() -> void:
	confirm_pressed.emit()
