class_name ItemDefs
extends RefCounted

const DATA_PATH := "res://data/item_defs.json"
const EVIDENCE_DATA_PATH := "res://data/evidence.json"

static var REPAIR_PARTS_EACH := 1
static var REPAIR_SCRAP_EACH := 2
static var REPAIR_WOOD_EACH := 2
static var REPAIR_SCRAP_ALT_EACH := 1
static var VEHICLE_REPAIR_PARTS_EACH := 1
static var VEHICLE_REPAIR_WOOD_EACH := 2
static var VEHICLE_REPAIR_HEAL_AMOUNT := 25.0
static var LOOT_FALLBACK_ITEM := "scrap"

# 背包内合成：废料 + 燃料 → 零件（缓解前期造塔资源短缺）
static var CRAFT_PARTS_SCRAP_COST := 3
static var CRAFT_PARTS_FUEL_COST := 1
static var CRAFT_PARTS_OUT := 1

static var _items: Dictionary = {}
static var _loot_by_building: Dictionary = {}
static var _evidence_entries: Dictionary = {}
static var _evidence_loaded := false


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
		"kunlun_control": ["parts", "scrap", "supplies"],
		"hub": ["supplies", "fuel", "scrap"],
		"default": ["wood", "parts", "supplies", "fuel"],
	}

	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		printerr("[ItemDefs] Failed to open item defs: %s" % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
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

	var craft: Dictionary = data.get("craft_parts", {})
	CRAFT_PARTS_SCRAP_COST = maxi(int(craft.get("scrap_cost", CRAFT_PARTS_SCRAP_COST)), 1)
	CRAFT_PARTS_FUEL_COST = maxi(int(craft.get("fuel_cost", CRAFT_PARTS_FUEL_COST)), 0)
	CRAFT_PARTS_OUT = maxi(int(craft.get("parts_out", CRAFT_PARTS_OUT)), 1)

	var vehicle_repair: Dictionary = data.get("vehicle_repair", {})
	VEHICLE_REPAIR_PARTS_EACH = maxi(int(vehicle_repair.get("parts_each", VEHICLE_REPAIR_PARTS_EACH)), 1)
	VEHICLE_REPAIR_WOOD_EACH = maxi(int(vehicle_repair.get("wood_each", VEHICLE_REPAIR_WOOD_EACH)), 1)
	VEHICLE_REPAIR_HEAL_AMOUNT = maxf(float(vehicle_repair.get("heal_amount", VEHICLE_REPAIR_HEAL_AMOUNT)), 1.0)

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
	if item_id.begins_with("evidence:"):
		var evidence_id := item_id.substr("evidence:".length())
		if evidence_id != "" and _evidence_has_entry(evidence_id):
			return "evidence:%s" % evidence_id
		return ""
	if item_id.begins_with("blueprint:"):
		return item_id
	match item_id:
		"food", "water":
			return "supplies"
		"medkit":
			return "supplies"
		_:
			return item_id


static func get_def(item_id: String) -> Dictionary:
	var normalized := normalize_item_id(item_id)
	if normalized.begins_with("blueprint:"):
		var blueprint_def := BlueprintCatalog.get_item_def(BlueprintCatalog.blueprint_id_from_item(normalized))
		if not blueprint_def.is_empty():
			return blueprint_def
	if normalized.begins_with("evidence:"):
		var evidence_id := normalized.substr("evidence:".length())
		if not _evidence_has_entry(evidence_id):
			return {}
		return {
			"name": evidence_title_of(evidence_id),
			"desc": evidence_content_of(evidence_id),
			"stack_max": 1,
			"color": Color("#ffd966"),
			"usable": false,
			"is_evidence": true,
			"evidence_id": evidence_id,
		}
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
	if normalized.begins_with("evidence:"):
		lines.append("【证据】可在顶层通信终端提交审计。")
		lines.append("夜间突破不会拖走证据，且不能用于建造。")
		if inventory != null:
			lines.append("")
			lines.append("背包持有：%d 个" % inventory.count(normalized))
		return "\n".join(lines)
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
	if normalized.begins_with("blueprint:") and bool(def.get("usable", false)):
		lines.append("【使用效果】写入夜间防御系统，本局永久生效。")
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
			lines.append("✓ 材料足够，可按 F 或按钮修复")
		else:
			lines.append("✗ 材料不足，请继续探索收集")
	return "\n".join(lines)


static func evidence_title_of(evidence_id: String) -> String:
	var node := _evidence_node()
	if node != null and node.has_method("title_of"):
		return str(node.call("title_of", evidence_id))
	_ensure_evidence_loaded()
	return str(_evidence_entries.get(evidence_id, {}).get("title", evidence_id))


static func evidence_content_of(evidence_id: String) -> String:
	var node := _evidence_node()
	if node != null and node.has_method("content_of"):
		return str(node.call("content_of", evidence_id))
	_ensure_evidence_loaded()
	return str(_evidence_entries.get(evidence_id, {}).get("content", ""))


static func _evidence_has_entry(evidence_id: String) -> bool:
	var node := _evidence_node()
	if node != null and node.has_method("has_entry"):
		return bool(node.call("has_entry", evidence_id))
	_ensure_evidence_loaded()
	return _evidence_entries.has(evidence_id)


static func _evidence_node() -> Node:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).root.get_node_or_null("EvidenceData")
	return null


static func _ensure_evidence_loaded() -> void:
	if _evidence_loaded:
		return
	_evidence_loaded = true
	_evidence_entries.clear()
	var file := FileAccess.open(EVIDENCE_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var raw: Variant = (parsed as Dictionary).get("evidences", [])
	if typeof(raw) != TYPE_ARRAY:
		return
	for entry_var in raw:
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var
		var id := str(entry.get("evidence_id", ""))
		if id != "":
			_evidence_entries[id] = entry


static func can_repair_with_inventory(inventory: InventoryData) -> bool:
	if inventory == null:
		return false
	if inventory.has("parts", REPAIR_PARTS_EACH):
		return true
	if inventory.has("scrap", REPAIR_SCRAP_EACH):
		return true
	return inventory.has("wood", REPAIR_WOOD_EACH) and inventory.has("scrap", REPAIR_SCRAP_ALT_EACH)


static func can_repair_vehicle_with_inventory(inventory: InventoryData) -> bool:
	if inventory == null:
		return false
	return inventory.has("parts", VEHICLE_REPAIR_PARTS_EACH) and inventory.has("wood", VEHICLE_REPAIR_WOOD_EACH)


static func get_vehicle_repair_requirement_text(inventory: InventoryData) -> String:
	var lines: PackedStringArray = []
	lines.append("车辆修复：零件 ×%d + 木材 ×%d" % [VEHICLE_REPAIR_PARTS_EACH, VEHICLE_REPAIR_WOOD_EACH])
	lines.append("修复效果：车辆耐久 +%.0f" % VEHICLE_REPAIR_HEAL_AMOUNT)
	if inventory != null:
		lines.append("当前持有：零件 %d | 木材 %d" % [
			inventory.count("parts"),
			inventory.count("wood"),
		])
		if can_repair_vehicle_with_inventory(inventory):
			lines.append("✓ 可在白天从背包中修复车辆")
		else:
			lines.append("✗ 材料不足或已到夜晚")
	return "\n".join(lines)


static func pick_loot_for_building(building_type: String, rng: RandomNumberGenerator) -> String:
	var default_pool: Array = _loot_by_building.get("default", [])
	var pool: Array = _loot_by_building.get(building_type, default_pool)
	if pool.is_empty():
		pool = default_pool
	if pool.is_empty():
		return LOOT_FALLBACK_ITEM
	return str(pool[rng.randi_range(0, pool.size() - 1)])
