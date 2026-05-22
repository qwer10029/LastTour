class_name RunEndingDefs
extends RefCounted

const TRUTH_REVEAL_TEXT := """【昆仑中继 · 顶层控制室】

五层残存档案在此拼合成同一结论：

大战之后，地下最后的人类躲入深处，启动了「昆仑」勘探计划。
计划启动不久，地下据点因内讧而空无一人——
但培育克隆人、派遣克隆人的程序从未停止。

从未有勘探者从顶层返回，也从未有人发出真正的「终止信号」。
程序把每一次失败当作理由，把新的你送上来。

你不是第一个到达这里的人。
控制室的终端仍在等待最后一个指令。"""

const FINAL_CHOICES := {
	"stop_signal": {
		"title": "发送真实终止信号",
		"summary": "向昆仑程序发送停机指令，结束克隆循环。",
	},
	"message_only": {
		"title": "只留言，不发停机",
		"summary": "留下勘探记录，让程序继续运转。",
	},
	"fake_success": {
		"title": "伪造「勘探成功」",
		"summary": "篡改中继回报，以讽刺的方式令循环停摆。",
	},
}

static func choice_title(choice_id: String) -> String:
	var def: Dictionary = FINAL_CHOICES.get(choice_id, {})
	return str(def.get("title", choice_id))


static func choice_summary(choice_id: String) -> String:
	var def: Dictionary = FINAL_CHOICES.get(choice_id, {})
	return str(def.get("summary", ""))
