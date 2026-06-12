class_name ArmorySiteData
extends RefCounted

const DATA_PATH := "res://data/armory_sites.json"

static var _cache: Dictionary = {}


static func _config() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	if not FileAccess.file_exists(DATA_PATH):
		return {}
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_cache = parsed
	return _cache


static func place_on_map(map: WorldMapData, layer: int) -> void:
	var config := _config()
	var sites: Array = config.get("sites", [])
	if sites.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(layer * 7919 + map.columns * 104729 + map.rows * 9176)
	var count_range := _layer_count_range(layer, config)
	var pick_count := rng.randi_range(count_range[0], count_range[1])
	pick_count = mini(pick_count, sites.size())
	var pool: Array = sites.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var selected: Array = []
	for i in range(pick_count):
		if typeof(pool[i]) != TYPE_DICTIONARY:
			continue
		selected.append((pool[i] as Dictionary).duplicate(true))
	if selected.is_empty():
		return
	var roll_pool := _blueprint_roll_pool(config)
	map.place_blueprint_armories(selected, rng, roll_pool)


static func _blueprint_roll_pool(config: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for entry in config.get("blueprint_roll_pool", []):
		var item_id := str(entry)
		if item_id != "":
			result.append(item_id)
	return result


static func _layer_count_range(layer: int, config: Dictionary) -> Array:
	var raw: Variant = config.get("layer_count_range", {})
	if raw is Dictionary:
		var entry: Variant = (raw as Dictionary).get(str(layer), null)
		if entry is Array and (entry as Array).size() >= 2:
			return [int(entry[0]), int(entry[1])]
	return [1, 2]
