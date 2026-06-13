class_name NightTdHintText
extends RefCounted

## 夜战 HUD 顶栏与夜晚教程共用的布防/接敌提示文案。改字主要改这里。

const PLACE_BACKPACK := (
	"俯视图：青色箭头为敌群涌动方向。左键放置设施、右键撤销（资源全额退还）。\n"
	+ "用背包里的零件/废料建造设施；幸存设施夜末回收，被毁则折成少量废料。"
)

const PLACE_DEPLOY_BUDGET := (
	"俯视图：青色箭头为敌群涌动方向。左键放置设施、右键撤销。\n"
	+ "右侧列出每种设施消耗的部署点与效果，选中后点地图格子放置。"
)

const COMBAT_NO_PLACE := "没有进入布防模式，敌人将直接来袭。"
const COMBAT_ACTIVE := "接敌中：敌人头顶箭头为当前前进方向，设施自动开火/阻挡。"
const TUTORIAL_PLACE := "先点左侧「炮塔」卡片（高亮项），再左键地图格子放置；勿选「物理路障」。"
const TUTORIAL_AFTER_PLACE := "已放置炮塔。右键撤销后，将开放热力图、电力调度与应急供能。"

## 教学关接敌：逐步实操，完成当前步骤后才进入下一步
const TUTORIAL_COMBAT_STEP_ORDER: Array[String] = [
	"power_control",
	"click_select",
	"box_select",
	"commander_overlay",
	"emergency_fuel",
]

const TUTORIAL_COMBAT_OBJECTIVES: Dictionary = {
	"power_control": "【请操作】左侧「电力调度」点 +/-，调节一座塔的功率",
	"click_select": "【请操作】单击地图上的防御塔，高亮电力面板对应行",
	"box_select": "【请操作】按住左键拖拽，框选一座或多座防御塔",
	"commander_overlay": "【请操作】点开右上「热力图」，查看敌人指挥官集结与突击",
	"emergency_fuel": "【请操作】点击「应急供能」，临时提升反应堆产能",
	"survive": "守住车辆直到波次清空",
}

const TUTORIAL_COMBAT_STEP_DONE: Dictionary = {
	"power_control": "已学会调节塔功率",
	"click_select": "已学会单击挑选防御塔",
	"box_select": "已学会框选防御塔",
	"commander_overlay": "已学会查看敌人指挥官",
	"emergency_fuel": "已学会应急供能",
}

# HUD 底部简略提示（长说明留给教程 overlay）
const PLACE_BACKPACK_SHORT := "左键放置 · 右键撤销（资源全额退还）"
const PLACE_DEPLOY_BUDGET_SHORT := "左键放置 · 右键撤销"
const COMBAT_NO_PLACE_SHORT := "敌人来袭"
const COMBAT_ACTIVE_SHORT := "接敌中 · 设施自动开火/阻挡"
const TUTORIAL_PLACE_SHORT := "先选「炮塔」卡片，再左键地图格子放置"
const TUTORIAL_AFTER_PLACE_SHORT := "撤销炮塔后开放热力图 · 电力 · 应急供能"
