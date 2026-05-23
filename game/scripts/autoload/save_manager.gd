extends Node

const SAVE_PATH := "user://run_save.json"
const SAVE_VERSION := 2

signal save_completed(success: bool)
signal load_failed(reason: String)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func get_save_summary() -> Dictionary:
	if not has_save():
		return {}
	var data := _read_file()
	if data.is_empty():
		return {}
	return {
		"day_index": int(data.get("time", {}).get("day_index", 1)),
		"layer": int(data.get("layer", {}).get("current_layer", 1)),
		"difficulty_name": _difficulty_label(int(data.get("difficulty", 1))),
		"squad_name": GameManager.get_squad_name(str(data.get("squad_id", "scavenger"))),
		"saved_at": int(data.get("saved_at", 0)),
	}


func save_game(data: Dictionary) -> bool:
	var payload := data.duplicate(true)
	payload["version"] = SAVE_VERSION
	payload["saved_at"] = int(Time.get_unix_time_from_system())
	var json_text := JSON.stringify(payload, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		save_completed.emit(false)
		return false
	file.store_string(json_text)
	file.close()
	save_completed.emit(true)
	return true


func load_game() -> Dictionary:
	if not has_save():
		load_failed.emit("没有找到存档")
		return {}
	var data := _read_file()
	if data.is_empty():
		load_failed.emit("存档损坏或无法读取")
		return {}
	if int(data.get("version", 0)) != SAVE_VERSION:
		load_failed.emit("存档版本不兼容")
		return {}
	return data


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


func _read_file() -> Dictionary:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _difficulty_label(value: int) -> String:
	return GameManager.get_difficulty_name(value)
