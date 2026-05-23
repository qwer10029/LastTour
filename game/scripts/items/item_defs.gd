class_name ItemDefs
extends RefCounted

const REPAIR_PARTS_EACH := 1
const REPAIR_SCRAP_EACH := 2
const REPAIR_WOOD_EACH := 2
const REPAIR_SCRAP_ALT_EACH := 1

const ITEMS := {
	"water": {
		"name": "净水",
		"desc": "饮用后恢复口渴度。",
		"stack_max": 20,
		"color": Color("#6ec8ff"),
		"usable": true,
		"restore_thirst": 40.0,
	},
	"food": {
		"name": "干粮",
		"desc": "食用后恢复饥饿度。",
		"stack_max": 20,
		"color": Color("#e8b86a"),
		"usable": true,
		"restore_hunger": 35.0,
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
	"medkit": {
		"name": "急救包",
		"desc": "包扎伤口，恢复生命值。",
		"stack_max": 10,
		"color": Color("#ff6b7a"),
		"usable": true,
		"restore_hp": 45.0,
	},
}

const LOOT_BY_BUILDING := {
	"warehouse": ["wood", "parts", "scrap", "food", "water"],
	"market": ["food", "water", "scrap"],
	"garage": ["parts", "scrap", "wood"],
	"archive": ["scrap", "medkit", "water"],
	"elevator": ["parts", "scrap"],
	"hub": ["food", "water", "scrap"],
	"default": ["wood", "parts", "food", "water"],
}


static func get_def(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})


static func get_item_name(item_id: String) -> String:
	return str(get_def(item_id).get("name", item_id))


static func is_usable(item_id: String) -> bool:
	return bool(get_def(item_id).get("usable", false))


static func get_detail_text(item_id: String, inventory: InventoryData = null) -> String:
	var def: Dictionary = get_def(item_id)
	if def.is_empty():
		return item_id
	var lines: PackedStringArray = []
	lines.append(str(def.get("name", item_id)))
	lines.append(str(def.get("desc", "")))
	lines.append("")
	match item_id:
		"water":
			var amt := float(def.get("restore_thirst", 40.0))
			lines.append("【使用效果】口渴 +%.0f（上限 100）" % amt)
			lines.append("适合口渴低于 20 时使用。")
		"food":
			var amt_f := float(def.get("restore_hunger", 35.0))
			lines.append("【使用效果】饥饿 +%.0f（上限 100）" % amt_f)
			lines.append("适合饥饿低于 20 时使用。")
		"medkit":
			var amt_h := float(def.get("restore_hp", 45.0))
			lines.append("【使用效果】生命 +%.0f（上限 100）" % amt_h)
		"parts":
			lines.append("【用途】修复电梯：每次进度消耗 零件×%d（优先）。" % REPAIR_PARTS_EACH)
		"scrap":
			lines.append("【用途】应急修电梯：没有零件时，每次进度消耗 废料×%d。" % REPAIR_SCRAP_EACH)
			lines.append("（或 木材×%d + 废料×%d 的组合修补）" % [REPAIR_WOOD_EACH, REPAIR_SCRAP_ALT_EACH])
		"wood":
			lines.append("【用途】与废料组合修电梯：木材×%d + 废料×%d = 1 次进度。" % [REPAIR_WOOD_EACH, REPAIR_SCRAP_ALT_EACH])
			lines.append("有零件时请优先用零件，不必消耗木材。")
	if inventory != null:
		var have := inventory.count(item_id)
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
	var pool: Array = LOOT_BY_BUILDING.get(building_type, LOOT_BY_BUILDING["default"])
	if pool.is_empty():
		pool = LOOT_BY_BUILDING["default"]
	return str(pool[rng.randi_range(0, pool.size() - 1)])
