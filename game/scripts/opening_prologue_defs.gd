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
			"地表是否还能居住、资源是否还能利用——这些问题，仍等待回答。",
		],
	},
	{
		"image": "res://assets/prologue/startpicture2.png",
		"lines": [
			"地下指挥部启动了「昆仑」地表勘探计划。",
			"这座城共分多层；勘探者从底层出发，逐层向上推进。",
			"每一层都要记录环境、修复受损的电梯，并把观察结果回报给地下。",
		],
	},
	{
		"image": "res://assets/prologue/startpicture3.png",
		"lines": [
			"你报名加入了昆仑计划。",
			"听说地表依然存在希望，而你想亲眼去看看。",
		],
	},
	{
		"image": "res://assets/prologue/startpicture4.png",
		"lines": [
			"向上，记录，回报。",
			"直到有人告诉我们，这个世界是否还值得活下去。",
		],
	},
]

static func slide_count() -> int:
	return SLIDES.size()


static func slide(index: int) -> Dictionary:
	if index < 0 or index >= SLIDES.size():
		return {}
	return SLIDES[index]
