extends Node

const LEGACY_PATH := "res://data/journal_encounters.json"

var _entries: Dictionary = {}
var _required_ids: Array[String] = []


func _ready() -> void:
	_load_legacy_file()


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


func required_encounter_ids() -> Array[String]:
	return _required_ids.duplicate()


func all_encounter_ids() -> Array[String]:
	var out: Array[String] = []
	for k in _entries.keys():
		out.append(str(k))
	out.sort()
	return out
