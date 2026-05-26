class_name OpeningPrologueDefs
extends RefCounted

## 开场前情提要：4 张 CG + 旁白（官方叙事，不剧透克隆/人类灭绝）

const SLIDES: Array[Dictionary] = [
	{
		"image": "res://assets/prologue/startpicture1.png",
		"lines": [
			"一场大战几乎摧毁了地表文明。",
			"城市化为废墟，道路断裂，天空常年阴沉。",
			"幸存的人类退入地下最后的据点，却始终没有放弃重返地表。",
			"地表是否还能居住、资源是否还能利用——这些问题，仍等待着答案。",
		],
	},
	{
		"image": "res://assets/prologue/startpicture2.png",
		"lines": [
			"地下指挥部启动了「昆仑」地表勘探计划。",
			"这座城共分多层；勘探者从底层出发，逐层向上推进。",
			"每一层都要记录环境、搜集样本、修复受损的电梯，并把观察结果回报给地下。",
			"指挥厅的屏幕仍在闪烁，工作人员在值班，等待来自地表的消息。",
		],
	},
	{
		"image": "res://assets/prologue/startpicture3.png",
		"lines": [
			"你自愿加入了昆仑计划，成为地表勘探志愿者。",
			"指挥部为你准备了勘探服、身份标识与一辆可移动、可栖居的勘探车。",
			"穿过这道舱门，你将踏上第一层废土——任务，从此刻开始。",
		],
	},
	{
		"image": "res://assets/prologue/startpicture4.png",
		"lines": [
			"第一层：工业废墟带。",
			"白天驾车探索、搜集食物与零件；天黑前回到车里布防，撑过夜晚。",
			"修好本层的电梯，才能进入上一层；如此反复，直至抵达城市最顶端。",
			"你的职责，是把所见所闻如实记录，汇报给仍在地下等待的人类指挥部。",
			"向上，记录，回报——为了某一天，地表能再次响起人类的脚步声。",
		],
	},
]

static func slide_count() -> int:
	return SLIDES.size()


static func slide(index: int) -> Dictionary:
	if index < 0 or index >= SLIDES.size():
		return {}
	return SLIDES[index]
