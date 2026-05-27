class_name ItemDefs
extends RefCounted

const DATA_PATH := "res://data/item_defs.json"

static var REPAIR_PARTS_EACH := 1
static var REPAIR_SCRAP_EACH := 2
static var REPAIR_WOOD_EACH := 2
static var REPAIR_SCRAP_ALT_EACH := 1
static var LOOT_FALLBACK_ITEM := "scrap"

static var _items: Dictionary = {}
static var _loot_by_building: Dictionary = {}


static func _static_init() -> void:
	_load_data()


static func _load_data() -> void:
	_items = {
		"supplies": {
			"name": "补给",
			"desc": "可补充体力的综合补给包。",
			"stack_max": 40,
			"color": Color("#8ddf8a"),
			"usable": true,
			"restore_stamina": 45.0,
		},
		"fuel": {
			"name": "燃料桶",
			"desc": "为车辆补充燃料。",
			"stack_max": 20,
			"color": Color("#f4d03f"),
			"usable": true,
			"restore_fuel": 140.0,
		},
		"wood": {
			"name": "木材",
			"desc": "基础建材，可用于应急修补电梯。",
			"stack_max": 30,
			"color": Color("#a67c52"),
			"usable": false,
		},
		"parts": {
			"name": "零件",
			"desc": "机械零件，修电梯的首选材料。",
			"stack_max": 20,
			"color": Color("#b0b8c8"),
			"usable": false,
		},
		"scrap": {
			"name": "废料",
			"desc": "回收金属碎料，可应急代替零件修电梯。",
			"stack_max": 40,
			"color": Color("#8a9aa8"),
			"usable": false,
		},
	}
	_loot_by_building = {
		"warehouse": ["wood", "parts", "scrap", "supplies", "fuel"],
		"market": ["supplies", "fuel", "scrap"],
		"garage": ["parts", "scrap", "wood", "fuel"],
		"archive": ["scrap", "supplies", "fuel"],
		"elevator": ["parts", "scrap"],
		"hub": ["supplies", "fuel", "scrap"],
		"default": ["wood", "parts", "supplies", "fuel"],
	}

	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		printerr("[ItemDefs] Failed to open item defs: %s" % DATA_PATH)
		return
	var parsed := JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		printerr("[ItemDefs] Invalid item defs JSON, using defaults: %s" % DATA_PATH)
		return
	var data: Dictionary = parsed
	var repair_costs: Dictionary = data.get("repair_costs", {})
	REPAIR_PARTS_EACH = maxi(int(repair_costs.get("parts_each", REPAIR_PARTS_EACH)), 1)
	REPAIR_SCRAP_EACH = maxi(int(repair_costs.get("scrap_each", REPAIR_SCRAP_EACH)), 1)
	REPAIR_WOOD_EACH = maxi(int(repair_costs.get("wood_each", REPAIR_WOOD_EACH)), 1)
	REPAIR_SCRAP_ALT_EACH = maxi(int(repair_costs.get("scrap_alt_each", REPAIR_SCRAP_ALT_EACH)), 1)
	LOOT_FALLBACK_ITEM = normalize_item_id(str(data.get("loot_fallback_item", LOOT_FALLBACK_ITEM)))
	if LOOT_FALLBACK_ITEM == "" or get_def(LOOT_FALLBACK_ITEM).is_empty():
		LOOT_FALLBACK_ITEM = "scrap"

	var loaded_items: Dictionary = data.get("items", {})
	if not loaded_items.is_empty():
		_items.clear()
		for item_id in loaded_items.keys():
			var raw: Variant = loaded_items[item_id]
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var normalized: Dictionary = raw.duplicate()
			if normalized.has("color"):
				normalized["color"] = Color(str(normalized.get("color", "#ffffff")))
			_items[str(item_id)] = normalized

	var loaded_loot: Dictionary = data.get("loot_by_building", {})
	if not loaded_loot.is_empty():
		_loot_by_building.clear()
		for building_type in loaded_loot.keys():
			var pool_raw: Variant = loaded_loot[building_type]
			if typeof(pool_raw) != TYPE_ARRAY:
				continue
			var pool: Array[String] = []
			for item in pool_raw:
				pool.append(str(item))
			_loot_by_building[str(building_type)] = pool


static func normalize_item_id(item_id: String) -> String:
	if item_id.is_empty():
		return ""
	match item_id:
		"food", "water":
			return "supplies"
		"medkit":
			return "supplies"
		_:
			return item_id


static func get_def(item_id: String) -> Dictionary:
	var normalized := normalize_item_id(item_id)
	return _items.get(normalized, {})


static func get_item_name(item_id: String) -> String:
	return str(get_def(item_id).get("name", item_id))


static func is_usable(item_id: String) -> bool:
	return bool(get_def(item_id).get("usable", false))


static func get_detail_text(item_id: String, inventory: InventoryData = null) -> String:
	var def: Dictionary = get_def(item_id)
	if def.is_empty():
		return item_id
	var normalized := normalize_item_id(item_id)
	var lines: PackedStringArray = []
	lines.append(str(def.get("name", normalized)))
	lines.append(str(def.get("desc", "")))
	lines.append("")
	match normalized:
		"supplies":
			var amt := float(def.get("restore_stamina", 45.0))
			lines.append("【使用效果】体力 +%.0f（上限 100）" % amt)
		"fuel":
			var fuel_amt := float(def.get("restore_fuel", 140.0))
			lines.append("【使用效果】车辆燃料 +%.0f" % fuel_amt)
		"parts":
			lines.append("【用途】修复电梯：每次进度消耗 零件×%d（优先）。" % REPAIR_PARTS_EACH)
		"scrap":
			lines.append("【用途】应急修电梯：没有零件时，每次进度消耗 废料×%d。" % REPAIR_SCRAP_EACH)
			lines.append("（或 木材×%d + 废料×%d 的组合修补）" % [REPAIR_WOOD_EACH, REPAIR_SCRAP_ALT_EACH])
		"wood":
			lines.append("【用途】与废料组合修电梯：木材×%d + 废料×%d = 1 次进度。" % [REPAIR_WOOD_EACH, REPAIR_SCRAP_ALT_EACH])
			lines.append("有零件时请优先用零件，不必消耗木材。")
	if inventory != null:
		var have := inventory.count(normalized)
		lines.append("")
		lines.append("背包持有：%d 个" % have)
	return "\n".join(lines)


static func get_repair_requirement_text(inventory: InventoryData) -> String:
	var lines: PackedStringArray = []
	lines.append("修电梯 · 每推进 1 步进度需要：")
	lines.append("  ① 零件 ×%d（优先）" % REPAIR_PARTS_EACH)
	lines.append("  ② 或 废料 ×%d（应急）" % REPAIR_SCRAP_EACH)
	lines.append("  ③ 或 木材×%d + 废料×%d" % [REPAIR_WOOD_EACH, REPAIR_SCRAP_ALT_EACH])
	if inventory != null:
		lines.append("当前持有：零件 %d | 废料 %d | 木材 %d" % [
			inventory.count("parts"),
			inventory.count("scrap"),
			inventory.count("wood"),
		])
		if can_repair_with_inventory(inventory):
			lines.append("✓ 材料足够，可按 R 或按钮修复")
		else:
			lines.append("✗ 材料不足，请继续探索收集")
	return "\n".join(lines)


static func can_repair_with_inventory(inventory: InventoryData) -> bool:
	if inventory == null:
		return false
	if inventory.has("parts", REPAIR_PARTS_EACH):
		return true
	if inventory.has("scrap", REPAIR_SCRAP_EACH):
		return true
	return inventory.has("wood", REPAIR_WOOD_EACH) and inventory.has("scrap", REPAIR_SCRAP_ALT_EACH)


static func pick_loot_for_building(building_type: String, rng: RandomNumberGenerator) -> String:
	var default_pool: Array = _loot_by_building.get("default", [])
	var pool: Array = _loot_by_building.get(building_type, default_pool)
	if pool.is_empty():
		pool = default_pool
	if pool.is_empty():
		return LOOT_FALLBACK_ITEM
	return str(pool[rng.randi_range(0, pool.size() - 1)])
