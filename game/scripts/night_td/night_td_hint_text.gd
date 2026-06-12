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
const TUTORIAL_AFTER_PLACE := "已放置炮塔。右上可切换热力图查看敌潮；左侧可管理供电。"

# HUD 底部简略提示（长说明留给教程 overlay）
const PLACE_BACKPACK_SHORT := "左键放置 · 右键撤销（资源全额退还）"
const PLACE_DEPLOY_BUDGET_SHORT := "左键放置 · 右键撤销"
const COMBAT_NO_PLACE_SHORT := "敌人来袭"
const COMBAT_ACTIVE_SHORT := "接敌中 · 设施自动开火/阻挡"
const TUTORIAL_PLACE_SHORT := "先选「炮塔」卡片，再左键地图格子放置"
const TUTORIAL_AFTER_PLACE_SHORT := "可开热力图查看敌潮 · 侧栏管理供电"
