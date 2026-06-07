extends Node

const META_PATH := "user://meta.json"
const META_VERSION := 1

var encounters_unlocked: Array[String] = []
var management_rights_transferred: bool = false
var endings_seen: Array[String] = []
var journal_uploads: Array[Dictionary] = []


func _ready() -> void:
	load_meta()


func load_meta() -> void:
	encounters_unlocked = []
	management_rights_transferred = false
	endings_seen = []
	journal_uploads = []
	if not FileAccess.file_exists(META_PATH):
		return
	var file := FileAccess.open(META_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != META_VERSION:
		return
	for id in data.get("encounters_unlocked", []):
		var id_str := str(id)
		if id_str != "" and not encounters_unlocked.has(id_str):
			encounters_unlocked.append(id_str)
	for legacy_id in data.get("evidence_collected", []):
		var legacy := str(legacy_id)
		if legacy.begins_with("placeholder_run_"):
			continue
	management_rights_transferred = bool(data.get("management_rights_transferred", false))
	for e in data.get("endings_seen", []):
		endings_seen.append(str(e))
	for upload_var in data.get("journal_uploads", []):
		if typeof(upload_var) != TYPE_DICTIONARY:
			continue
		journal_uploads.append(_normalize_upload(upload_var))


func save_meta() -> void:
	var payload := {
		"version": META_VERSION,
		"encounters_unlocked": encounters_unlocked,
		"management_rights_transferred": management_rights_transferred,
		"endings_seen": endings_seen,
		"journal_uploads": journal_uploads,
		"saved_at": int(Time.get_unix_time_from_system()),
	}
	var file := FileAccess.open(META_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


func unlock_encounter(encounter_id: String) -> bool:
	if encounter_id == "" or encounters_unlocked.has(encounter_id):
		return false
	encounters_unlocked.append(encounter_id)
	return true


func encounters_unlocked_count() -> int:
	return encounters_unlocked.size()


func required_encounter_count() -> int:
	return JournalData.required_encounter_ids().size()


func has_all_truth_encounters() -> bool:
	for encounter_id in JournalData.required_encounter_ids():
		if not encounters_unlocked.has(encounter_id):
			return false
	return true


func upload_run_journal(entries: Array, layer: int, day_index: int) -> void:
	var normalized_entries: Array[Dictionary] = []
	for entry_var in entries:
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var
		var encounter_id := str(entry.get("encounter_id", ""))
		if encounter_id == "":
			continue
		normalized_entries.append({
			"encounter_id": encounter_id,
			"title": str(entry.get("title", JournalData.title_of(encounter_id))),
			"body": str(entry.get("body", JournalData.body_of(encounter_id))),
			"layer": int(entry.get("layer", layer)),
			"day_index": int(entry.get("day_index", day_index)),
		})
		unlock_encounter(encounter_id)
	journal_uploads.append({
		"run_id": "%d" % Time.get_unix_time_from_system(),
		"layer": layer,
		"day_index": day_index,
		"entries": normalized_entries,
	})
	while journal_uploads.size() > 12:
		journal_uploads.pop_front()


func format_uploaded_logs_preview(max_uploads: int = 4) -> String:
	if journal_uploads.is_empty():
		return "（尚无上传记录。前代勘探者的日记会在到顶上传后出现在此处。）"
	var lines: PackedStringArray = []
	var start := maxi(0, journal_uploads.size() - max_uploads)
	for i in range(start, journal_uploads.size()):
		var upload: Dictionary = journal_uploads[i]
		var layer := int(upload.get("layer", 0))
		var day := int(upload.get("day_index", 0))
		lines.append("—— 上传 #%d · 第%d层·第%d天 ——" % [i + 1, layer, day])
		var upload_entries: Variant = upload.get("entries", [])
		if typeof(upload_entries) != TYPE_ARRAY or upload_entries.is_empty():
			lines.append("（本局未记录遭遇。）")
			continue
		for entry_var in upload_entries:
			if typeof(entry_var) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_var
			lines.append("· %s" % str(entry.get("title", entry.get("encounter_id", "未命名"))))
			var body := str(entry.get("body", ""))
			if body != "":
				var snippet := body.substr(0, mini(120, body.length()))
				if body.length() > 120:
					snippet += "…"
				lines.append("  %s" % snippet)
		lines.append("")
	return "\n".join(lines)


func format_current_run_preview(entries: Array, max_entries: int = 6) -> String:
	if entries.is_empty():
		return "（本局尚未写入勘探日记。）"
	var lines: PackedStringArray = ["—— 本局日记 ——"]
	var count := 0
	for entry_var in entries:
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		if count >= max_entries:
			break
		var entry: Dictionary = entry_var
		lines.append("· %s" % str(entry.get("title", entry.get("encounter_id", "未命名"))))
		count += 1
	if entries.size() > max_entries:
		lines.append("… 共 %d 篇" % entries.size())
	return "\n".join(lines)


func record_ending(choice_id: String) -> void:
	if choice_id == "" or endings_seen.has(choice_id):
		return
	endings_seen.append(choice_id)


func _normalize_upload(raw: Dictionary) -> Dictionary:
	var entries_out: Array[Dictionary] = []
	for entry_var in raw.get("entries", []):
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var
		entries_out.append({
			"encounter_id": str(entry.get("encounter_id", "")),
			"title": str(entry.get("title", "")),
			"body": str(entry.get("body", "")),
			"layer": int(entry.get("layer", 0)),
			"day_index": int(entry.get("day_index", 0)),
		})
	return {
		"run_id": str(raw.get("run_id", "")),
		"layer": int(raw.get("layer", 0)),
		"day_index": int(raw.get("day_index", 0)),
		"entries": entries_out,
	}
