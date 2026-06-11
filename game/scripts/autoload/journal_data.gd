extends Node

const LEGACY_PATH := "res://data/journal_encounters.json"

var _entries: Dictionary = {}
var _required_ids: Array[String] = []
var _required_story_ids: Array[String] = []


func _ready() -> void:
	_load_legacy_file()


func configure_truth_stories(story_ids: Array) -> void:
	_required_story_ids.clear()
	for raw_id in story_ids:
		var id := str(raw_id)
		if id != "" and not _required_story_ids.has(id):
			_required_story_ids.append(id)


func truth_story_ids() -> Array[String]:
	return _required_story_ids.duplicate()


func rebuild_from_stories(stories: Dictionary, required: Array[String]) -> void:
	for raw_id in required:
		var id := str(raw_id)
		if id != "" and not _required_ids.has(id):
			_required_ids.append(id)
	for story_id in stories.keys():
		var story: Dictionary = stories[story_id]
		var base_title := str(story.get("title", story_id))
		var npc_id := str(story.get("npc_id", ""))
		var reward: Dictionary = story.get("reward", {})
		for choice_var in reward.get("choices", []):
			if typeof(choice_var) != TYPE_DICTIONARY:
				continue
			var choice: Dictionary = choice_var
			var encounter_id := str(choice.get("encounter_id", ""))
			if encounter_id == "":
				continue
			_entries[encounter_id] = {
				"encounter_id": encounter_id,
				"title": base_title,
				"journal_body": str(choice.get("journal_body", "")),
				"npc_id": npc_id,
				"story_id": story_id,
				"choice_id": str(choice.get("choice_id", "")),
			}


func ensure_legacy_loaded() -> void:
	_load_legacy_file()


func _load_legacy_file() -> void:
	if not FileAccess.file_exists(LEGACY_PATH):
		return
	var file := FileAccess.open(LEGACY_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	for raw_id in data.get("required_stories_for_truth", []):
		var story_id := str(raw_id)
		if story_id != "" and not _required_story_ids.has(story_id):
			_required_story_ids.append(story_id)
	for raw_id in data.get("required_for_truth", []):
		var id := str(raw_id)
		if id != "" and not _required_ids.has(id):
			_required_ids.append(id)
	for entry_var in data.get("encounters", []):
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var
		var encounter_id := str(entry.get("encounter_id", ""))
		if encounter_id == "":
			continue
		_entries[encounter_id] = entry


func has_entry(id: String) -> bool:
	return _entries.has(id)


func get_entry(id: String) -> Dictionary:
	return _entries.get(id, {})


func title_of(id: String) -> String:
	return str(_entries.get(id, {}).get("title", id))


func body_of(id: String) -> String:
	return str(_entries.get(id, {}).get("journal_body", ""))


func npc_id_of(id: String) -> String:
	return str(_entries.get(id, {}).get("npc_id", ""))


func story_id_of_encounter(encounter_id: String) -> String:
	if encounter_id == "":
		return ""
	var from_story := StoryData.story_id_for_encounter(encounter_id)
	if from_story != "":
		return from_story
	var npc := npc_id_of(encounter_id)
	if npc == "":
		return ""
	for story_id in StoryData.all_story_ids():
		if str(StoryData.get_story(story_id).get("npc_id", "")) == npc:
			return story_id
	return ""


func story_has_log(story_id: String, unlocked_encounter_ids: Array) -> bool:
	if story_id == "":
		return false
	for encounter_id in unlocked_encounter_ids:
		if story_id_of_encounter(str(encounter_id)) == story_id:
			return true
	return false


func collected_required_truth_count(unlocked_encounter_ids: Array) -> int:
	var count := 0
	for req_id in _required_ids:
		if unlocked_encounter_ids.has(str(req_id)):
			count += 1
	return count


func collected_truth_story_count(unlocked_encounter_ids: Array) -> int:
	if not _required_ids.is_empty():
		return collected_required_truth_count(unlocked_encounter_ids)
	if _required_story_ids.is_empty():
		return collected_story_count(unlocked_encounter_ids)
	var count := 0
	for story_id in _required_story_ids:
		if story_has_log(story_id, unlocked_encounter_ids):
			count += 1
	return count


func collected_story_count(unlocked_encounter_ids: Array) -> int:
	var count := 0
	for story_id in StoryData.all_story_ids():
		if story_has_log(story_id, unlocked_encounter_ids):
			count += 1
	return count


func required_story_count() -> int:
	if not _required_ids.is_empty():
		return _required_ids.size()
	if not _required_story_ids.is_empty():
		return _required_story_ids.size()
	return StoryData.all_story_ids().size()


func has_all_story_logs(unlocked_encounter_ids: Array) -> bool:
	if not _required_ids.is_empty():
		return collected_required_truth_count(unlocked_encounter_ids) >= _required_ids.size()
	if _required_story_ids.is_empty():
		return collected_story_count(unlocked_encounter_ids) >= required_story_count()
	return collected_truth_story_count(unlocked_encounter_ids) >= _required_story_ids.size()


func required_encounter_ids() -> Array[String]:
	return _required_ids.duplicate()


func all_encounter_ids() -> Array[String]:
	var out: Array[String] = []
	for k in _entries.keys():
		out.append(str(k))
	out.sort()
	return out
