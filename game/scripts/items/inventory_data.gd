class_name InventoryData
extends RefCounted

var items: Dictionary = {}  # item_id -> int


func clear() -> void:
	items.clear()


func add(item_id: String, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	var def: Dictionary = ItemDefs.get_def(item_id)
	if def.is_empty():
		return 0
	var max_stack := int(def.get("stack_max", 99))
	var current := int(items.get(item_id, 0))
	var room := max_stack - current
	var added := mini(amount, room)
	if added > 0:
		items[item_id] = current + added
	return added


func remove(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return true
	var current := int(items.get(item_id, 0))
	if current < amount:
		return false
	current -= amount
	if current <= 0:
		items.erase(item_id)
	else:
		items[item_id] = current
	return true


func count(item_id: String) -> int:
	return int(items.get(item_id, 0))


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
		for key in data.keys():
			var qty := int(data[key])
			if qty > 0:
				items[str(key)] = qty


func apply_starting_items(starting: Dictionary) -> void:
	for item_id in starting.keys():
		add(str(item_id), int(starting[item_id]))
