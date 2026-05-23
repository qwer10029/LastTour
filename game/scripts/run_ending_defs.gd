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

const TERMINAL_INTRO_TEXT := """【昆仑中继 · 顶层控制室 · 通信终端】

您的观察报告已接收。
请于下方完成本次勘探总结与身份识别。
本终端为程序自动应答，所有结论将上报至昆仑指挥部。"""

const TERMINAL_REPORT_PROMPT := "问题 1 / 1：根据您在地表的观察，请评估地表当前的宜居性。"
const TERMINAL_REPORT_OPTIONS := {
	"habitable": "地表宜居，建议恢复地面活动",
	"uninhabitable": "地表不宜，建议继续地下避难",
}

const TERMINAL_CAPTCHA_PROMPT := "身份识别：请将下方滑块拖动至最右端，以证明您是人类操作员。"

const TERMINAL_VERIFY_FAIL_TEXT := """【验证结果】

未识别到人类操作员特征。
勘探单元被判定为非授权终端访问者。

感谢您的付出。"""

const TERMINAL_STRIKE_TEXT := "[ 安全协议已执行：勘探单元被远程击毙 ]"

const TERMINAL_VERIFY_PASS_TEXT := """【验证结果】

证据校验通过。
人类指挥部信号源已不存在，昆仑程序进入失能状态。

最高权限正在移交……"""

const TERMINAL_TRANSFER_TEXT := "【权限移交完成】\n您已获得对昆仑中继的最高控制权。"

static func choice_title(choice_id: String) -> String:
	var def: Dictionary = FINAL_CHOICES.get(choice_id, {})
	return str(def.get("title", choice_id))


static func choice_summary(choice_id: String) -> String:
	var def: Dictionary = FINAL_CHOICES.get(choice_id, {})
	return str(def.get("summary", ""))
