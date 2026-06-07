class_name SentinelEncounterDefs
extends RefCounted

## 游戏内军营门口对话（短句，气泡展示）。完整文学版见 journal_encounters.json / 剧情/哨兵.md

const GATE_LINES: Array[Dictionary] = [
	{"speaker": "npc", "text": "请停步。我并无敌意，能请您帮个忙吗？"},
	{"speaker": "npc", "text": "我是 10032 军营哨兵，编号 S-09。"},
	{"speaker": "npc", "text": "能源快耗尽了。我不能离开门口。"},
	{"speaker": "npc", "text": "东侧仓库有能量电池。取来就给您报酬。"},
	{"speaker": "player", "text": "仓库在哪？"},
	{"speaker": "npc", "text": "第二通道备件柜。门已替您解锁。"},
]

const GATE_CHOICE_NPC := "能帮我吗？"
const GATE_ACCEPT_NPC := "我会在这里等您。"
const GATE_ACCEPT_PLAYER := "好。"
const GATE_DECLINE_NPC := "……明白了。营门仍由我守着。"

const REWARD_NPC := "谢谢。按协议，报酬任选一项。"
const QUEST_HINT := "进入军营，拾取能量电池（2 块）。"

const REWARD_OPTIONS: Array[Dictionary] = [
	{
		"id": "parts",
		"encounter_id": "sentinel_s09_parts",
		"label": "1 · 二十份零件",
		"short_label": "零件",
		"summary": "仓库西侧未登记的维修备件。",
		"parts": 20,
	},
	{
		"id": "blueprint",
		"encounter_id": "sentinel_s09_blueprint",
		"label": "2 · 强化防御塔蓝图",
		"short_label": "蓝图",
		"summary": "10032 军营夜间布防方案第 7 修订版。",
		"parts": 5,
	},
	{
		"id": "branch",
		"encounter_id": "sentinel_s09_branch",
		"label": "3 · 变异植物的枝条",
		"short_label": "枝条",
		"summary": "从花盆取走一截枝条。",
		"parts": 0,
	},
]
