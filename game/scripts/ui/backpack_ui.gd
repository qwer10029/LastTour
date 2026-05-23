extends Control
class_name BackpackUI

signal item_use_requested(item_id: String)
signal item_discard_requested(item_id: String)
signal closed

@export var panel_size: Vector2 = Vector2(540, 440)

var _root: Control
var _panel: PanelContainer
var _item_list: ItemList
var _detail_label: Label
var _use_btn: Button
var _discard_btn: Button
var _selected_id: String = ""
var _inventory: InventoryData


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	hide_backpack(false)


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.05, 0.1, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = panel_size
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -panel_size.x * 0.5
	_panel.offset_top = -panel_size.y * 0.5
	_panel.offset_right = panel_size.x * 0.5
	_panel.offset_bottom = panel_size.y * 0.5
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.16, 0.22, 0.96)
	panel_style.border_color = Color(0.55, 0.72, 0.88, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", panel_style)
	_root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)

	var title := Label.new()
	title.text = "背包 — 点击物品，再选择使用或丢弃（B 关闭）"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#eef8ff"))
	outer.add_child(title)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)

	_item_list = ItemList.new()
	_item_list.custom_minimum_size = Vector2(280, 320)
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.item_selected.connect(_on_item_selected)
	_item_list.item_activated.connect(_on_item_activated)
	body.add_child(_item_list)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(240, 320)
	side.add_theme_constant_override("separation", 10)
	body.add_child(side)

	_detail_label = Label.new()
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.custom_minimum_size = Vector2(228, 180)
	_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_label.text = "← 选择左侧物品"
	_detail_label.add_theme_color_override("font_color", Color("#d8e4f0"))
	side.add_child(_detail_label)

	_use_btn = Button.new()
	_use_btn.text = "使用"
	_use_btn.disabled = true
	_use_btn.pressed.connect(_on_use_pressed)
	side.add_child(_use_btn)

	_discard_btn = Button.new()
	_discard_btn.text = "丢弃 1 个"
	_discard_btn.disabled = true
	_discard_btn.pressed.connect(_on_discard_pressed)
	side.add_child(_discard_btn)

	var close_btn := Button.new()
	close_btn.text = "关闭 (B / Esc)"
	close_btn.pressed.connect(func(): hide_backpack())
	side.add_child(close_btn)


func show_backpack(inventory: InventoryData) -> void:
	_inventory = inventory
	_refresh_list(inventory)
	_root.visible = true
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	_selected_id = ""
	_update_detail()
	_update_action_buttons()


func hide_backpack(emit_closed_signal: bool = true) -> void:
	if is_instance_valid(_root):
		_root.visible = false
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_selected_id = ""
	if emit_closed_signal:
		closed.emit()


func is_open() -> bool:
	return visible and is_instance_valid(_root) and _root.visible


func _refresh_list(inventory: InventoryData) -> void:
	_item_list.clear()
	if inventory == null:
		_item_list.add_item("（背包为空）")
		return
	var entries := inventory.get_sorted_entries()
	if entries.is_empty():
		_item_list.add_item("（背包为空）")
		return
	for entry in entries:
		var item_id := str(entry["id"])
		var qty := int(entry["count"])
		var def: Dictionary = ItemDefs.get_def(item_id)
		var name := str(def.get("name", item_id))
		var color: Color = def.get("color", Color.WHITE)
		var idx := _item_list.add_item("%s  ×%d" % [name, qty])
		_item_list.set_item_metadata(idx, item_id)
		_item_list.set_item_custom_fg_color(idx, color)
		_item_list.set_item_icon(idx, ItemIconFactory.get_texture(item_id))


func _on_item_selected(index: int) -> void:
	if index < 0:
		return
	var meta: Variant = _item_list.get_item_metadata(index)
	if meta == null or str(meta) == "":
		_selected_id = ""
	else:
		_selected_id = str(meta)
	_update_detail()
	_update_action_buttons()


func _on_item_activated(index: int) -> void:
	_on_item_selected(index)
	if ItemDefs.is_usable(_selected_id):
		_on_use_pressed()


func _update_detail() -> void:
	if _selected_id == "":
		_detail_label.text = "← 选择左侧物品"
		return
	var def: Dictionary = ItemDefs.get_def(_selected_id)
	if def.is_empty():
		_detail_label.text = _selected_id
		return
	_detail_label.text = ItemDefs.get_detail_text(_selected_id, _inventory)


func _update_action_buttons() -> void:
	var has_sel := _selected_id != ""
	_use_btn.disabled = not has_sel or not ItemDefs.is_usable(_selected_id)
	_discard_btn.disabled = not has_sel


func _on_use_pressed() -> void:
	if _selected_id == "":
		return
	item_use_requested.emit(_selected_id)


func _on_discard_pressed() -> void:
	if _selected_id == "":
		return
	item_discard_requested.emit(_selected_id)
