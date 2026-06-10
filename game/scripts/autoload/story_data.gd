extends Node

const DATA_PATH := "res://data/stories.json"

var _stories: Dictionary = {}
var _required_truth: Array[String] = []


func _ready() -> void:
	_load()


func _load() -> void:
	_stories.clear()
	_required_truth.clear()
	if not FileAccess.file_exists(DATA_PATH):
		return
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	for raw_id in data.get("required_for_truth", []):
		var id := str(raw_id)
		if id != "":
			_required_truth.append(id)
	for raw_story in data.get("stories", []):
		if typeof(raw_story) != TYPE_DICTIONARY:
			continue
		var story: Dictionary = raw_story
		var story_id := str(story.get("story_id", ""))
		if story_id == "":
			continue
		_stories[story_id] = story
	_rebuild_journal_index()


func _rebuild_journal_index() -> void:
	if JournalData.has_method("rebuild_from_stories"):
		JournalData.rebuild_from_stories(_stories, _required_truth)
	if JournalData.has_method("ensure_legacy_loaded"):
		JournalData.ensure_legacy_loaded()


func all_story_ids() -> Array[String]:
	var out: Array[String] = []
	for k in _stories.keys():
		out.append(str(k))
	out.sort()
	return out


func has_story(story_id: String) -> bool:
	return _stories.has(story_id)


func get_story(story_id: String) -> Dictionary:
	return _stories.get(story_id, {})


func story_id_for_district_tag(tag: String) -> String:
	for story_id in _stories.keys():
		var story: Dictionary = _stories[story_id]
		if str(story.get("district_tag", "")) == tag:
			return str(story_id)
	return ""


func district_tag_of(story_id: String) -> String:
	return str(get_story(story_id).get("district_tag", ""))


func title_of(story_id: String) -> String:
	return str(get_story(story_id).get("title", story_id))


func prompt_disembark(story_id: String) -> String:
	var custom := str(get_story(story_id).get("prompt_disembark", ""))
	if custom != "":
		return custom
	return "交谈 (E)"


func prompt_return(story_id: String) -> String:
	var custom := str(get_story(story_id).get("prompt_return", ""))
	if custom != "":
		return custom
	return "%s · E 交还任务物品" % title_of(story_id)


func prompt_reward(story_id: String) -> String:
	var custom := str(get_story(story_id).get("prompt_reward", ""))
	if custom != "":
		return custom
	return "%s · E 领取报酬" % title_of(story_id)


func any_story_spawns_near_start() -> bool:
	for story_id in _stories.keys():
		if bool(get_story(story_id).get("spawn_near_start", false)):
			return true
	return false


func dialogue_path(story_id: String) -> String:
	return str(get_story(story_id).get("dialogue_path", ""))


func reward_loot_def(story_id: String, loot_key: String) -> Dictionary:
	var reward_loot: Variant = get_story(story_id).get("reward_loot", {})
	if typeof(reward_loot) != TYPE_DICTIONARY:
		return {}
	var bucket: Variant = (reward_loot as Dictionary).get(loot_key, {})
	if typeof(bucket) != TYPE_DICTIONARY:
		return {}
	return (bucket as Dictionary).duplicate(true)


func interior_ambient_loot_pickups(story_id: String) -> Array:
	var raw: Variant = get_story(story_id).get("interior_ambient_loot", [])
	if typeof(raw) != TYPE_ARRAY:
		return []
	return (raw as Array).duplicate(true)


func tactical_hidden_sites(story_id: String) -> Array:
	var raw: Variant = get_story(story_id).get("tactical_hidden_sites", [])
	if typeof(raw) != TYPE_ARRAY:
		return []
	return (raw as Array).duplicate(true)


func setup_tactical_hidden_sites(map: WorldMapData, layer: int) -> void:
	for story_id in _stories.keys():
		var story: Dictionary = _stories[story_id]
		if int(story.get("spawn_layer", 1)) != layer:
			continue
		var sites := tactical_hidden_sites(story_id)
		if sites.is_empty():
			continue
		map.prepare_tactical_hidden_sites(sites, story_id)


func gate_lines(story_id: String) -> Array:
	var gate: Dictionary = get_story(story_id).get("gate", {})
	var raw: Variant = gate.get("lines", [])
	if typeof(raw) != TYPE_ARRAY:
		return []
	return raw.duplicate(true)


func gate_field(story_id: String, key: String, default: String = "") -> String:
	var gate: Dictionary = get_story(story_id).get("gate", {})
	return str(gate.get(key, default))


func quest_def(story_id: String) -> Dictionary:
	return get_story(story_id).get("quest", {})


func reward_gate_npc(story_id: String) -> String:
	var reward: Dictionary = get_story(story_id).get("reward", {})
	return str(reward.get("gate_npc", ""))


func reward_choices(story_id: String) -> Array:
	var reward: Dictionary = get_story(story_id).get("reward", {})
	var raw: Variant = reward.get("choices", [])
	if typeof(raw) != TYPE_ARRAY:
		return []
	return raw.duplicate(true)


func reward_choice_count(story_id: String) -> int:
	return reward_choices(story_id).size()


func choice_by_index(story_id: String, index: int) -> Dictionary:
	var choices := reward_choices(story_id)
	if index < 0 or index >= choices.size():
		return {}
	if typeof(choices[index]) != TYPE_DICTIONARY:
		return {}
	return (choices[index] as Dictionary).duplicate(true)


func choice_by_encounter_id(encounter_id: String) -> Dictionary:
	for story_id in _stories.keys():
		for choice_var in reward_choices(story_id):
			if typeof(choice_var) != TYPE_DICTIONARY:
				continue
			var choice: Dictionary = choice_var
			if str(choice.get("encounter_id", "")) == encounter_id:
				return choice.duplicate(true)
	return {}


func story_id_for_encounter(encounter_id: String) -> String:
	for story_id in _stories.keys():
		for choice_var in reward_choices(story_id):
			if typeof(choice_var) != TYPE_DICTIONARY:
				continue
			if str((choice_var as Dictionary).get("encounter_id", "")) == encounter_id:
				return story_id
	return ""


func journal_for_encounter(encounter_id: String) -> Dictionary:
	var choice := choice_by_encounter_id(encounter_id)
	if choice.is_empty():
		return {}
	var story_id := story_id_for_encounter(encounter_id)
	return {
		"encounter_id": encounter_id,
		"title": title_of(story_id) if story_id != "" else encounter_id,
		"journal_body": str(choice.get("journal_body", "")),
		"npc_id": str(get_story(story_id).get("npc_id", "")),
	}


func required_truth_ids() -> Array[String]:
	return _required_truth.duplicate()


func _clear_district_map_loot(cell: Dictionary) -> void:
	cell["resource_total"] = 0
	cell["resource_remaining"] = 0
	cell["resource_spawns"] = []


func is_interior_encounter(story_id: String) -> bool:
	return bool(get_story(story_id).get("interior_encounter", false))


func locks_exit_until_resolved(story_id: String) -> bool:
	return bool(get_story(story_id).get("lock_exit_until_resolved", false))


func ensure_story_districts(map: WorldMapData, layer: int = 1) -> void:
	for story_id in _stories.keys():
		var story: Dictionary = _stories[story_id]
		var required_layer := int(story.get("spawn_layer", 1))
		if layer != required_layer:
			continue
		var building_type := str(story.get("building_type", ""))
		if building_type == "":
			continue
		var tag := str(story.get("district_tag", story_id))
		var already := false
		for district_index in map.district_indices:
			var cell := map.get_cell(district_index)
			if str(cell.get("story_id", "")) == story_id:
				_clear_district_map_loot(cell)
				already = true
				break
			if str(cell.get("special_encounter", "")) == tag:
				cell["story_id"] = story_id
				cell["building_type"] = building_type
				_clear_district_map_loot(cell)
				already = true
				break
		if already:
			continue
		var candidates: Array[int] = []
		for district_index in map.district_indices:
			var pick_cell := map.get_cell(district_index)
			if bool(pick_cell.get("has_elevator", false)) or bool(pick_cell.get("has_kunlun_control", false)):
				continue
			if str(pick_cell.get("story_id", "")) != "" or str(pick_cell.get("special_encounter", "")) != "":
				continue
			candidates.append(district_index)
		if candidates.is_empty():
			continue
		var pick := -1
		if bool(story.get("spawn_near_start", false)):
			pick = _pick_district_near_start(map, candidates)
		if pick < 0:
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			pick = candidates[rng.randi_range(0, candidates.size() - 1)]
		var cell_pick := map.get_cell(pick)
		cell_pick["building_type"] = building_type
		cell_pick["story_id"] = story_id
		cell_pick["district_tag"] = tag
		cell_pick["special_encounter"] = tag
		_clear_district_map_loot(cell_pick)


func _pick_district_near_start(map: WorldMapData, candidates: Array[int]) -> int:
	var start_road := map.start_node_index
	if not map.is_valid_index(start_road):
		return -1
	for district_index in map.get_roadside_districts(start_road):
		if district_index in candidates:
			return district_index
	for district_index in map.get_roadside_districts(start_road):
		if not map.is_district(district_index):
			continue
		if (
			bool(map.get_cell(district_index).get("has_elevator", false))
			or bool(map.get_cell(district_index).get("has_kunlun_control", false))
		):
			map.relocate_special_building_from(district_index)
		return district_index
	for district_index in candidates:
		if int(map.get_cell(district_index).get("approach_road_index", -1)) == start_road:
			return district_index
	var neighbor_roads: Dictionary = {}
	for direction in map.get_passable_directions(start_road):
		var neighbor := map.get_neighbor_index(start_road, direction)
		if neighbor >= 0:
			neighbor_roads[neighbor] = true
	for district_index in candidates:
		var approach := int(map.get_cell(district_index).get("approach_road_index", -1))
		if neighbor_roads.has(approach):
			return district_index
	return -1


func set_debug_start_near_story(map: WorldMapData) -> void:
	for story_id in _stories.keys():
		if not bool(get_story(story_id).get("spawn_near_start", false)):
			continue
		for district_index in map.district_indices:
			var cell := map.get_cell(district_index)
			if str(cell.get("story_id", "")) != story_id:
				continue
			var approach := int(cell.get("approach_road_index", -1))
			if map.is_valid_index(approach) and map.is_drive_node(approach):
				map.start_node_index = approach
				return
