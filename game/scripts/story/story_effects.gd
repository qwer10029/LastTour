class_name StoryEffects
extends RefCounted

## 故事选项的地图/背包效果。由 StoryController 调用。


static func apply(host: Node, district_index: int, effects: Array) -> void:
	if host == null or not host.has_method("_story_apply_effect"):
		return
	for effect_var in effects:
		if typeof(effect_var) != TYPE_DICTIONARY:
			continue
		host.call("_story_apply_effect", district_index, effect_var)
