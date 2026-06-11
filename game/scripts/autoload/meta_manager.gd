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
	# 旧版 message_wall / messages 字段已废弃，读取时忽略。
	for upload_var in data.get("journal_uploads", []):
		if typeof(upload_var) != TYPE_DICTIONARY:
			continue
		journal_uploads.append(_normalize_upload(upload_var))
	var loaded_count := journal_uploads.size()
	_prune_invalid_uploads()
	if journal_uploads.size() != loaded_count:
		call_deferred("save_meta")
	_rebuild_encounters_from_uploads()
	for legacy_id in data.get("evidence_collected", []):
		var legacy := str(legacy_id)
		if legacy.begins_with("placeholder_run_"):
			continue
	management_rights_transferred = bool(data.get("management_rights_transferred", false))
	for e in data.get("endings_seen", []):
		endings_seen.append(str(e))


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
	return JournalData.collected_truth_story_count(encounters_unlocked)


func required_encounter_count() -> int:
	return JournalData.required_story_count()


func has_all_truth_encounters() -> bool:
	return JournalData.has_all_story_logs(encounters_unlocked)


func upload_run_journal(entries: Array, layer: int, day_index: int) -> bool:
	if entries.is_empty():
		return false
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
	if normalized_entries.is_empty():
		return false
	journal_uploads.append({
		"run_id": "%d" % Time.get_unix_time_from_system(),
		"layer": layer,
		"day_index": day_index,
		"reached_top": true,
		"entries": normalized_entries,
	})
	while get_archived_uploads().size() > 12:
		_remove_oldest_archived_upload()
	return true


func get_archived_uploads() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for upload in journal_uploads:
		if _is_valid_archive_upload(upload):
			out.append(upload)
	return out


func journal_upload_count() -> int:
	return get_archived_uploads().size()


func archive_status_label() -> String:
	if has_all_truth_encounters():
		return "真相已拼合 · 隐藏结局已解锁"
	var collected := encounters_unlocked_count()
	var required := required_encounter_count()
	if collected > 0:
		return "关键情报 %d / %d" % [collected, required]
	return "尚无情报"


func get_archived_entry(upload_index: int, entry_index: int) -> Dictionary:
	var uploads := get_archived_uploads()
	if upload_index < 0 or upload_index >= uploads.size():
		return {}
	var upload_entries: Variant = uploads[upload_index].get("entries", [])
	if typeof(upload_entries) != TYPE_ARRAY:
		return {}
	if entry_index < 0 or entry_index >= upload_entries.size():
		return {}
	var entry_var: Variant = upload_entries[entry_index]
	if typeof(entry_var) != TYPE_DICTIONARY:
		return {}
	return (entry_var as Dictionary).duplicate(true)


func format_uploaded_logs_preview(max_uploads: int = 4) -> String:
	var uploads := get_archived_uploads()
	if uploads.is_empty():
		return "（尚无上传记录。只有抵达顶层并完成上传的勘探日记会归档于此。）"
	var lines: PackedStringArray = []
	var start := maxi(0, uploads.size() - max_uploads)
	for i in range(start, uploads.size()):
		var upload: Dictionary = uploads[i]
		var layer := int(upload.get("layer", 0))
		var day := int(upload.get("day_index", 0))
		lines.append("—— 上传 #%d · 第%d层·第%d天 ——" % [i + 1, layer, day])
		var upload_entries: Variant = upload.get("entries", [])
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


func _is_valid_archive_upload(upload: Dictionary) -> bool:
	if upload.is_empty():
		return false
	var upload_entries: Variant = upload.get("entries", [])
	if typeof(upload_entries) != TYPE_ARRAY or upload_entries.is_empty():
		return false
	if upload.has("reached_top") and not bool(upload.get("reached_top", false)):
		return false
	return true


func _prune_invalid_uploads() -> void:
	var valid: Array[Dictionary] = []
	for upload in journal_uploads:
		if _is_valid_archive_upload(upload):
			valid.append(upload)
	journal_uploads = valid


func _rebuild_encounters_from_uploads() -> void:
	encounters_unlocked.clear()
	for upload in get_archived_uploads():
		for entry_var in upload.get("entries", []):
			if typeof(entry_var) != TYPE_DICTIONARY:
				continue
			unlock_encounter(str((entry_var as Dictionary).get("encounter_id", "")))


func _remove_oldest_archived_upload() -> void:
	for i in range(journal_uploads.size()):
		if _is_valid_archive_upload(journal_uploads[i]):
			journal_uploads.remove_at(i)
			return


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
		"reached_top": bool(raw.get("reached_top", not entries_out.is_empty())),
		"entries": entries_out,
	}
