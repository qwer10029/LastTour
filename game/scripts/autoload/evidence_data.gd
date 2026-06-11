extends Node

const DATA_PATH := "res://data/evidence.json"

var _entries: Dictionary = {}
var _loaded := false

func _ready() -> void:
	_load_entries()

func _load_entries() -> void:
	_entries.clear()
	_loaded = true
	if not ResourceLoader.exists(DATA_PATH) and not FileAccess.file_exists(DATA_PATH):
		return
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var raw: Variant = parsed.get("evidences", [])
	if typeof(raw) != TYPE_ARRAY:
		return
	for entry_var in raw:
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var
		var id := str(entry.get("evidence_id", ""))
		if id == "":
			continue
		_entries[id] = entry

func _ensure_loaded() -> void:
	if not _loaded:
		_load_entries()

func has_entry(id: String) -> bool:
	_ensure_loaded()
	return _entries.has(id)

func get_entry(id: String) -> Dictionary:
	_ensure_loaded()
	return _entries.get(id, {})

func all_ids() -> Array[String]:
	_ensure_loaded()
	var out: Array[String] = []
	for k in _entries.keys():
		out.append(str(k))
	out.sort()
	return out

func ids_for_layer(layer: int) -> Array[String]:
	_ensure_loaded()
	var out: Array[String] = []
	for k in _entries.keys():
		var entry: Dictionary = _entries[k]
		if int(entry.get("unlock_layer", 0)) == layer:
			out.append(str(k))
	out.sort()
	return out

func terminal_required_ids() -> Array[String]:
	_ensure_loaded()
	var out: Array[String] = []
	for k in _entries.keys():
		var id := str(k)
		if id != "":
			out.append(id)
	out.sort()
	return out

func title_of(id: String) -> String:
	_ensure_loaded()
	return str(_entries.get(id, {}).get("title", id))

func content_of(id: String) -> String:
	_ensure_loaded()
	return str(_entries.get(id, {}).get("content", ""))

func layer_of(id: String) -> int:
	_ensure_loaded()
	return int(_entries.get(id, {}).get("unlock_layer", 0))
