class_name InventoryData
extends RefCounted

var items: Dictionary = {}  # item_id -> int


func clear() -> void:
	items.clear()


func add(item_id: String, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	var normalized := ItemDefs.normalize_item_id(item_id)
	if normalized == "":
		return 0
	if ItemDefs.get_def(normalized).is_empty():
		return 0
	var current := int(items.get(normalized, 0))
	items[normalized] = current + amount
	return amount


func remove(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return true
	var normalized := ItemDefs.normalize_item_id(item_id)
	var current := int(items.get(normalized, 0))
	if current < amount:
		return false
	current -= amount
	if current <= 0:
		items.erase(normalized)
	else:
		items[normalized] = current
	return true


func count(item_id: String) -> int:
	var normalized := ItemDefs.normalize_item_id(item_id)
	return int(items.get(normalized, 0))


func has(item_id: String, amount: int = 1) -> bool:
	return count(item_id) >= amount


func total_count() -> int:
	var total := 0
	for key in items.keys():
		total += int(items[key])
	return total


func get_sorted_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for item_id in items.keys():
		var qty := int(items[item_id])
		if qty > 0:
			entries.append({"id": str(item_id), "count": qty})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return ItemDefs.get_item_name(str(a["id"])) < ItemDefs.get_item_name(str(b["id"]))
	)
	return entries


func to_dictionary() -> Dictionary:
	return items.duplicate()


func load_from_dictionary(data: Variant) -> void:
	items.clear()
	if data is Dictionary:
		var normalized_totals: Dictionary = {}
		var converted_legacy_count := 0
		for key in data.keys():
			var qty := int(data[key])
			if qty <= 0:
				continue
			var source_id := str(key)
			var normalized := ItemDefs.normalize_item_id(source_id)
			if normalized == "":
				continue
			if ItemDefs.get_def(normalized).is_empty():
				continue
			if normalized != source_id:
				converted_legacy_count += qty
			normalized_totals[normalized] = int(normalized_totals.get(normalized, 0)) + qty
		for item_id in normalized_totals.keys():
			items[str(item_id)] = int(normalized_totals[item_id])
		if converted_legacy_count > 0:
			print("[InventoryData] Converted %d legacy items into current item IDs while loading save." % converted_legacy_count)


func apply_starting_items(starting: Dictionary) -> void:
	for item_id in starting.keys():
		add(str(item_id), int(starting[item_id]))
