extends Node

const META_PATH := "user://meta.json"
const META_VERSION := 1
const EVIDENCE_THRESHOLD_FOR_TRANSFER := 3

var evidence_collected: Array[String] = []
var management_rights_transferred: bool = false
var endings_seen: Array[String] = []
var message_wall: Array[Dictionary] = []


func _ready() -> void:
	load_meta()


func load_meta() -> void:
	evidence_collected = []
	management_rights_transferred = false
	endings_seen = []
	message_wall = []
	if not FileAccess.file_exists(META_PATH):
		return
	var file := FileAccess.open(META_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != META_VERSION:
		return
	for id in data.get("evidence_collected", []):
		var id_str := str(id)
		if id_str.begins_with("placeholder_run_"):
			continue
		evidence_collected.append(id_str)
	management_rights_transferred = bool(data.get("management_rights_transferred", false))
	for e in data.get("endings_seen", []):
		endings_seen.append(str(e))
	for m in data.get("message_wall", []):
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = m
		message_wall.append({
			"text": str(entry.get("text", "")),
			"layer": int(entry.get("layer", 0)),
			"run_id": str(entry.get("run_id", "")),
		})


func save_meta() -> void:
	var payload := {
		"version": META_VERSION,
		"evidence_collected": evidence_collected,
		"management_rights_transferred": management_rights_transferred,
		"endings_seen": endings_seen,
		"message_wall": message_wall,
		"saved_at": int(Time.get_unix_time_from_system()),
	}
	var file := FileAccess.open(META_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


func add_evidence(id: String) -> bool:
	if id == "" or evidence_collected.has(id):
		return false
	evidence_collected.append(id)
	return true


func evidence_count() -> int:
	return evidence_collected.size()


func has_enough_evidence() -> bool:
	return evidence_collected.size() >= EVIDENCE_THRESHOLD_FOR_TRANSFER


func record_ending(choice_id: String) -> void:
	if choice_id == "" or endings_seen.has(choice_id):
		return
	endings_seen.append(choice_id)

func append_message(text: String, layer: int) -> void:
	if text.strip_edges() == "":
		return
	message_wall.append({
		"text": text.strip_edges().substr(0, 80),
		"layer": layer,
		"run_id": "%d" % Time.get_unix_time_from_system(),
	})
