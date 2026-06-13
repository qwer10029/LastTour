class_name TutorialDirector
extends CanvasLayer

signal step_changed(step_id: String)

const DAY_STEPS := [
	"drive",
	"enter",
	"loot",
	"craft",
	"return",
	"evening",
]

const NIGHT_STEPS := [
	"place_tower",
	"withdraw_tower",
	"build_more",
	"survive",
]

const ELEVATOR_STEPS := [
	"go_elevator",
	"repair_elevator",
]

## 各步骤默认底部提示（craft 等步骤打开背包时也会显示这里的内容）
const OBJECTIVES := {
	"drive": "从十字路口出发，用 WASD 向北开往仓库",
	"enter": "按 E 下车进入仓库",
	"loot": "用 WASD 在室内移动，收集废料与燃料",
	"craft": "点击高亮的「合成零件」按钮，合成 1 个零件",
	"return": "按 E 上车；若背包仍打开，先按 B 关闭",
	"evening": "在车上按 F 进入布防",
	"place_tower": "左键地图格子放置一座炮塔",
	"withdraw_tower": "右键炮塔所在格子撤销（资源全额退还）",
	"build_more": "至少放置两座炮塔；准备好后点「开始接敌」，接敌后按提示逐步实操",
	"survive": "守住车辆直到波次清空",
	"go_elevator": "WASD驾驶车辆，前往东侧电梯枢纽，按 E 进入电梯房",
	"repair_elevator": "在电梯控制台按 F；零件、废料、木材+废料三选一，均可推进修复",
}

const PHASE_TITLES := {
	"day": "教学 · 白天探索",
	"night": "教学 · 守夜",
	"elevator": "教学 · 修复电梯",
}

## 动态覆盖提示（按 B 关闭、走到门口等），改文案主要改这里
const OVERRIDE_HINTS := {
	"open_backpack": "按 B 打开背包",
	"close_backpack": "按 B 关闭背包",
	"foot_move": "用 WASD 在室内移动",
	"foot_loot": "用 WASD 移动，收集地上的废料与燃料",
	"foot_return_near_door": "按 E 上车返回车辆",
	"foot_return_go_door": "走到门口按 E 上车",
	"foot_door_enter": "E 上车",
	"foot_door_go": "走到门口按 E 上车",
	"foot_close_backpack": "B 关闭背包",
}

var current_step: String = "drive"
var completed_steps: Array[String] = []
var phase: String = "day"
var _objective_override: String = ""

var _dialog_panel: PanelContainer
var _phase_label: Label
var _objective_label: Label


func _ready() -> void:
	layer = 115
	_build_objective_ui()


func set_phase(new_phase: String, first_step: String = "") -> void:
	phase = new_phase
	completed_steps.clear()
	if first_step != "":
		current_step = first_step
	else:
		match phase:
			"night":
				current_step = NIGHT_STEPS[0]
			"elevator":
				current_step = ELEVATOR_STEPS[0]
			_:
				current_step = DAY_STEPS[0]
	_refresh_objective_ui()
	step_changed.emit(current_step)


func get_objective_text() -> String:
	if _objective_override != "":
		return _objective_override
	return OBJECTIVES.get(current_step, "")


func set_objective_override(text: String) -> void:
	_objective_override = text
	_refresh_objective_ui()


func override_hint(key: String) -> String:
	return OVERRIDE_HINTS.get(key, "")


func advance_to(step_id: String) -> void:
	if current_step != "" and not completed_steps.has(current_step):
		completed_steps.append(current_step)
	current_step = step_id
	_refresh_objective_ui()
	step_changed.emit(current_step)


func advance_if(condition: bool, next_step: String) -> void:
	if condition and current_step != next_step:
		advance_to(next_step)


func is_action_allowed(action: String) -> bool:
	match current_step:
		"evening":
			return action == "enter_defense"
		"craft":
			if action == "enter_defense":
				return false
		"loot", "enter":
			if action == "enter_defense":
				return false
		"drive", "go_elevator":
			if action == "enter_defense":
				return false
		"return":
			if action == "enter_defense":
				return false
		"repair_elevator":
			return action in ["repair", "interact"]
	return true


func should_highlight_craft() -> bool:
	return phase == "day" and current_step == "craft"


func _build_objective_ui() -> void:
	var root := Control.new()
	root.name = "TutorialObjectiveRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var bottom_anchor := Control.new()
	bottom_anchor.name = "BottomAnchor"
	bottom_anchor.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_anchor.offset_bottom = 0.0
	bottom_anchor.offset_top = -148.0
	bottom_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom_anchor)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_anchor.add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.custom_minimum_size = Vector2(560, 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)

	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(name_row)

	var name_panel := PanelContainer.new()
	name_panel.add_theme_stylebox_override("panel", DialogueUiTheme.name_tag_style())
	name_row.add_child(name_panel)

	_phase_label = Label.new()
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.add_theme_font_size_override("font_size", 13)
	_phase_label.add_theme_color_override("font_color", Color("#8ec8e8"))
	HudTheme.apply_compact_label(_phase_label)
	name_panel.add_child(_phase_label)

	_dialog_panel = PanelContainer.new()
	_dialog_panel.custom_minimum_size = Vector2(520, 72)
	_dialog_panel.add_theme_stylebox_override("panel", DialogueUiTheme.dialog_panel_style())
	column.add_child(_dialog_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_dialog_panel.add_child(margin)

	_objective_label = Label.new()
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.add_theme_font_size_override("font_size", 16)
	_objective_label.add_theme_color_override("font_color", Color("#e8eef4"))
	HudTheme.apply_label(_objective_label)
	margin.add_child(_objective_label)

	_refresh_objective_ui()


func _refresh_objective_ui() -> void:
	if not is_instance_valid(_objective_label):
		return
	_objective_label.text = get_objective_text()
	if is_instance_valid(_phase_label):
		_phase_label.text = PHASE_TITLES.get(phase, "教学关卡")
