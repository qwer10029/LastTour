class_name BlueprintCatalog
extends RefCounted

const CATALOG_PATH := "res://data/night_td/blueprint_catalog.json"
const ITEM_PREFIX := "blueprint:"
const GENERIC_PICKUP_ID := "blueprint:armory"

const COMBAT_TOWER_IDS: Array[String] = ["jammer", "sniper", "splash", "trap"]
const POWERED_TOWER_IDS: Array[String] = ["jammer", "cryo_beacon", "hacker", "sniper", "splash"]
const GLOBAL_SCOPES: Array[String] = ["all_towers", "all_combat_towers", "all_powered_towers"]

static var _cache: Dictionary = {}


static func _config() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	if not FileAccess.file_exists(CATALOG_PATH):
		return {}
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_cache = parsed
	return _cache


static func default_run_state() -> Dictionary:
	var starters: Array = _config().get("starter_unlocked_towers", ["jammer", "barrier"])
	return {
		"unlocked_towers": (starters as Array).duplicate(),
		"global": {},
		"tower": {},
		"reactor": {
			"starting_add": 0.0,
			"capacity_add": 0.0,
			"capacity_mult": 1.0,
			"production_add": 0.0,
			"production_mult": 1.0,
		},
		"salvage_mult": 1.0,
	}


static func sanitize_run_state(raw: Variant) -> Dictionary:
	var state := default_run_state()
	if typeof(raw) != TYPE_DICTIONARY:
		return state
	var src: Dictionary = raw
	var unlocked: Variant = src.get("unlocked_towers", [])
	if unlocked is Array:
		state["unlocked_towers"] = []
		for entry in unlocked:
			var tid := str(entry)
			if tid != "" and not (state["unlocked_towers"] as Array).has(tid):
				(state["unlocked_towers"] as Array).append(tid)
	for starter in _config().get("starter_unlocked_towers", []):
		var starter_id := str(starter)
		if starter_id != "" and not (state["unlocked_towers"] as Array).has(starter_id):
			(state["unlocked_towers"] as Array).append(starter_id)
	var global_src: Variant = src.get("global")
	if global_src is Dictionary:
		state["global"] = (global_src as Dictionary).duplicate(true)
	var tower_src: Variant = src.get("tower")
	if tower_src is Dictionary:
		state["tower"] = (tower_src as Dictionary).duplicate(true)
	var reactor_src: Variant = src.get("reactor")
	if reactor_src is Dictionary:
		var reactor: Dictionary = state["reactor"]
		for stat_key in (reactor_src as Dictionary).keys():
			var stat := str(stat_key)
			if reactor.has(stat):
				reactor[stat] = float((reactor_src as Dictionary).get(stat_key, reactor[stat]))
	state["salvage_mult"] = maxf(float(src.get("salvage_mult", state["salvage_mult"])), 0.0)
	return state


static func is_blueprint_item(item_id: String) -> bool:
	return item_id.begins_with(ITEM_PREFIX)


static func is_generic_pickup(item_id: String) -> bool:
	return item_id == GENERIC_PICKUP_ID or item_id.begins_with("armory_blueprint_roll_")


static func is_resolved_blueprint(item_id: String) -> bool:
	if not is_blueprint_item(item_id):
		return false
	return blueprint_id_from_item(item_id) != "armory"


static func item_id_for(blueprint_id: String) -> String:
	return ITEM_PREFIX + blueprint_id


static func blueprint_id_from_item(item_id: String) -> String:
	if not item_id.begins_with(ITEM_PREFIX):
		return ""
	return item_id.substr(ITEM_PREFIX.length())


static func get_entry(blueprint_id: String) -> Dictionary:
	for entry_var in _config().get("blueprints", []):
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var
		if str(entry.get("id", "")) == blueprint_id:
			return entry
	return {}


static func get_item_def(blueprint_id: String) -> Dictionary:
	if blueprint_id == "armory":
		return {
			"name": "军用防御蓝图",
			"desc": "战前兵工厂封印的防御塔改良图。拾取后解析为一种夜间强化方案。",
			"stack_max": 1,
			"color": Color("#9ec0e8"),
			"usable": false,
		}
	var entry := get_entry(blueprint_id)
	if entry.is_empty():
		return {}
	return {
		"name": str(entry.get("display_name", "军用防御蓝图")),
		"desc": str(entry.get("effect_summary", "战前兵工厂封印的防御塔改良图。")),
		"stack_max": 1,
		"color": Color("#9ec0e8"),
		"usable": true,
		"blueprint_id": blueprint_id,
	}


static func pending_unlock_towers(inventory: InventoryData) -> Array[String]:
	var result: Array[String] = []
	if inventory == null:
		return result
	for entry_var in inventory.get_sorted_entries():
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var item_id := str((entry_var as Dictionary).get("id", ""))
		if not is_resolved_blueprint(item_id):
			continue
		var bp_entry := get_entry(blueprint_id_from_item(item_id))
		if str(bp_entry.get("category", "")) != "unlock":
			continue
		var tower := str(bp_entry.get("unlocks_tower", ""))
		if tower != "" and not result.has(tower):
			result.append(tower)
	return result


static func can_roll_entry(entry: Dictionary, unlocked: Array, pending_unlocks: Array = []) -> bool:
	if str(entry.get("category", "")) == "unlock":
		var tower := str(entry.get("unlocks_tower", ""))
		return tower != "" and not unlocked.has(tower) and not pending_unlocks.has(tower)
	return true


static func _roll_weight(entry: Dictionary) -> int:
	var cat := str(entry.get("category", ""))
	var weights: Dictionary = _config().get("roll_pool_suggestion", {}).get("weights", {})
	var base := maxi(int(weights.get(cat, 10)), 1)
	if cat == "global_buff":
		var target := str(entry.get("target", ""))
		if target in GLOBAL_SCOPES:
			base = int(round(float(base) * 1.8))
	return base


static func roll_blueprint_id(
	rng: RandomNumberGenerator,
	run_state: Dictionary,
	pending_unlocks: Array = [],
) -> String:
	var unlocked: Array = run_state.get("unlocked_towers", [])
	var candidates: Array[Dictionary] = []
	var total_weight := 0
	for entry_var in _config().get("blueprints", []):
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var
		if not can_roll_entry(entry, unlocked, pending_unlocks):
			continue
		var weight := _roll_weight(entry)
		candidates.append({"id": str(entry.get("id", "")), "weight": weight})
		total_weight += weight
	if candidates.is_empty() or total_weight <= 0:
		return ""
	var roll := rng.randi_range(1, total_weight)
	var acc := 0
	for candidate in candidates:
		acc += int(candidate.get("weight", 0))
		if roll <= acc:
			return str(candidate.get("id", ""))
	return str(candidates.back().get("id", ""))


static func _reactor_stat_key(effect_key: String) -> String:
	if effect_key.begins_with("reactor_"):
		return effect_key.substr("reactor_".length())
	return effect_key


static func _merge_mult_bucket(bucket: Dictionary, stat: String, value: float) -> void:
	if absf(value) <= 0.0001:
		return
	if stat.ends_with("_add"):
		bucket[stat] = float(bucket.get(stat, 0.0)) + value
	else:
		bucket[stat] = float(bucket.get(stat, 1.0)) * value


static func apply_blueprint(run_state: Dictionary, blueprint_id: String) -> Dictionary:
	var entry := get_entry(blueprint_id)
	if entry.is_empty():
		return run_state
	var category := str(entry.get("category", ""))
	match category:
		"unlock":
			var tower := str(entry.get("unlocks_tower", ""))
			if tower != "" and not (run_state["unlocked_towers"] as Array).has(tower):
				(run_state["unlocked_towers"] as Array).append(tower)
		"global_buff", "tower_buff":
			var target := str(entry.get("target", ""))
			var effects: Dictionary = entry.get("effects", {})
			if target == "reactor":
				var reactor: Dictionary = run_state.get("reactor", {})
				if typeof(reactor) != TYPE_DICTIONARY:
					reactor = default_run_state()["reactor"]
					run_state["reactor"] = reactor
				for stat in effects.keys():
					_merge_mult_bucket(reactor, _reactor_stat_key(str(stat)), float(effects[stat]))
			elif category == "tower_buff":
				var tower_root: Dictionary = run_state.get("tower", {})
				if typeof(tower_root) != TYPE_DICTIONARY:
					tower_root = {}
					run_state["tower"] = tower_root
				var tower_bucket: Dictionary = tower_root.get(target, {})
				if typeof(tower_bucket) != TYPE_DICTIONARY:
					tower_bucket = {}
				for stat in effects.keys():
					_merge_mult_bucket(tower_bucket, str(stat), float(effects[stat]))
				tower_root[target] = tower_bucket
			else:
				var global_root: Dictionary = run_state.get("global", {})
				if typeof(global_root) != TYPE_DICTIONARY:
					global_root = {}
					run_state["global"] = global_root
				var scope_bucket: Dictionary = global_root.get(target, {})
				if typeof(scope_bucket) != TYPE_DICTIONARY:
					scope_bucket = {}
				for stat in effects.keys():
					var stat_name := str(stat)
					var value := float(effects[stat])
					_merge_mult_bucket(scope_bucket, stat_name, value)
					if stat_name == "salvage_mult":
						run_state["salvage_mult"] = float(run_state.get("salvage_mult", 1.0)) * value
				global_root[target] = scope_bucket
		"power_capacity", "power_generation", "power_bundle":
			var reactor: Dictionary = run_state.get("reactor", {})
			if typeof(reactor) != TYPE_DICTIONARY:
				reactor = default_run_state()["reactor"]
				run_state["reactor"] = reactor
			var effects: Dictionary = entry.get("effects", {})
			for stat in effects.keys():
				_merge_mult_bucket(reactor, _reactor_stat_key(str(stat)), float(effects[stat]))
	return run_state


static func scope_applies(scope: String, tower_type: String) -> bool:
	match scope:
		"all_towers":
			return true
		"all_combat_towers":
			return tower_type in COMBAT_TOWER_IDS
		"all_powered_towers":
			return tower_type in POWERED_TOWER_IDS
		_:
			return false


static func mult_for_tower(run_state: Dictionary, tower_type: String, stat: String) -> float:
	var result := 1.0
	var global_buckets: Dictionary = run_state.get("global", {})
	for scope in GLOBAL_SCOPES:
		if not scope_applies(scope, tower_type):
			continue
		var bucket: Variant = global_buckets.get(scope, {})
		if typeof(bucket) == TYPE_DICTIONARY:
			result *= float((bucket as Dictionary).get(stat, 1.0))
	var tower_bucket: Variant = run_state.get("tower", {}).get(tower_type, {})
	if typeof(tower_bucket) == TYPE_DICTIONARY:
		result *= float((tower_bucket as Dictionary).get(stat, 1.0))
	return result


static func apply_reactor_mods(energy: NightTdEnergy, run_state: Dictionary) -> void:
	if energy == null:
		return
	var reactor: Dictionary = run_state.get("reactor", {})
	var base_cap := energy.capacity
	var base_prod := energy.production_rate
	var base_start := energy.current
	energy.capacity = (base_cap + float(reactor.get("capacity_add", 0.0))) * float(reactor.get("capacity_mult", 1.0))
	energy.production_rate = (base_prod + float(reactor.get("production_add", 0.0))) * float(reactor.get("production_mult", 1.0))
	energy.current = clampf(base_start + float(reactor.get("starting_add", 0.0)), 0.0, energy.capacity)


static func effect_summary(blueprint_id: String) -> String:
	return str(get_entry(blueprint_id).get("effect_summary", ""))
