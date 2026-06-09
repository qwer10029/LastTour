class_name StoryRunState
extends RefCounted

## 本局各 story_id 的运行态：phase / district / 计数 / 是否完成

const PHASE_NONE := "none"
const PHASE_GATE := "gate"
const PHASE_QUEST := "quest"
const PHASE_REWARD := "reward"
const PHASE_DONE := "done"

var _entries: Dictionary = {}


func clear() -> void:
	_entries.clear()


func get_phase(story_id: String) -> String:
	return str(_entry(story_id).get("phase", PHASE_NONE))


func set_phase(story_id: String, phase: String) -> void:
	var entry := _entry(story_id)
	entry["phase"] = phase
	_entries[story_id] = entry


func get_district(story_id: String) -> int:
	return int(_entry(story_id).get("district", -1))


func set_district(story_id: String, district_index: int) -> void:
	var entry := _entry(story_id)
	entry["district"] = district_index
	_entries[story_id] = entry


func get_collect_count(story_id: String) -> int:
	return int(_entry(story_id).get("collect_count", 0))


func set_collect_count(story_id: String, count: int) -> void:
	var entry := _entry(story_id)
	entry["collect_count"] = count
	_entries[story_id] = entry


func is_completed(story_id: String) -> bool:
	return get_phase(story_id) == PHASE_DONE


func is_quest_active(story_id: String) -> bool:
	return get_phase(story_id) == PHASE_QUEST


func is_reward_pending(story_id: String) -> bool:
	return get_phase(story_id) == PHASE_REWARD


func mark_done(story_id: String) -> void:
	set_phase(story_id, PHASE_DONE)


func get_variable(story_id: String, key: String, default: Variant = null) -> Variant:
	var vars: Variant = _entry(story_id).get("variables", {})
	if typeof(vars) != TYPE_DICTIONARY:
		return default
	if not (vars as Dictionary).has(key):
		return default
	return (vars as Dictionary)[key]


func set_variable(story_id: String, key: String, value: Variant) -> void:
	var entry := _entry(story_id)
	var vars: Dictionary = {}
	var raw: Variant = entry.get("variables", {})
	if typeof(raw) == TYPE_DICTIONARY:
		vars = (raw as Dictionary).duplicate(true)
	vars[key] = value
	entry["variables"] = vars
	_entries[story_id] = entry


func get_dialogue_node(story_id: String) -> String:
	return str(_entry(story_id).get("dialogue_node", ""))


func set_dialogue_node(story_id: String, node_id: String) -> void:
	var entry := _entry(story_id)
	entry["dialogue_node"] = node_id
	_entries[story_id] = entry


func clear_dialogue_node(story_id: String) -> void:
	var entry := _entry(story_id)
	entry["dialogue_node"] = ""
	_entries[story_id] = entry


func to_dictionary() -> Dictionary:
	return _entries.duplicate(true)


func load_from_dictionary(raw: Variant) -> void:
	_entries.clear()
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for story_id in raw.keys():
		var entry_var: Variant = raw[story_id]
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		_entries[str(story_id)] = (entry_var as Dictionary).duplicate(true)


func _entry(story_id: String) -> Dictionary:
	if not _entries.has(story_id):
		_entries[story_id] = {
			"phase": PHASE_NONE,
			"district": -1,
			"collect_count": 0,
			"variables": {},
		}
	return _entries[story_id]
