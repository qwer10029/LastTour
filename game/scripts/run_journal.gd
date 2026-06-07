class_name RunJournal
extends RefCounted

var entries: Array[Dictionary] = []


func clear() -> void:
	entries.clear()


func add_story_outcome(encounter_id: String, layer: int, day_index: int) -> bool:
	if encounter_id == "" or has_encounter(encounter_id):
		return false
	var body := JournalData.body_of(encounter_id)
	if body == "":
		return false
	entries.append({
		"encounter_id": encounter_id,
		"title": JournalData.title_of(encounter_id),
		"body": body,
		"layer": layer,
		"day_index": day_index,
		"recorded_at": int(Time.get_unix_time_from_system()),
	})
	return true


func add_encounter(encounter_id: String, layer: int, day_index: int) -> bool:
	return add_story_outcome(encounter_id, layer, day_index)


func has_encounter(encounter_id: String) -> bool:
	for entry in entries:
		if str(entry.get("encounter_id", "")) == encounter_id:
			return true
	return false


func get_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in entries:
		out.append(entry.duplicate(true))
	return out


func to_array() -> Array:
	var out: Array = []
	for entry in entries:
		out.append(entry.duplicate(true))
	return out


func load_from_array(raw: Variant) -> void:
	entries.clear()
	if typeof(raw) != TYPE_ARRAY:
		return
	for entry_var in raw:
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var
		var encounter_id := str(entry.get("encounter_id", ""))
		if encounter_id == "":
			continue
		entries.append({
			"encounter_id": encounter_id,
			"title": str(entry.get("title", JournalData.title_of(encounter_id))),
			"body": str(entry.get("body", JournalData.body_of(encounter_id))),
			"layer": int(entry.get("layer", 1)),
			"day_index": int(entry.get("day_index", 1)),
			"recorded_at": int(entry.get("recorded_at", 0)),
		})
