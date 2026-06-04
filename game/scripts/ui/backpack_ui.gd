extends Control
class_name BackpackUI

signal item_use_requested(item_id: String)
signal item_discard_requested(item_id: String)
signal craft_parts_requested
signal closed

@export var panel_size: Vector2 = Vector2(540, 440)

var _root: Control
var _panel: PanelContainer
var _item_list: ItemList
var _detail_label: Label
var _use_btn: Button
var _discard_btn: Button
var _craft_hint_label: Label
var _craft_btn: Button
var _selected_id: String = ""
var _inventory: InventoryData
var _tab_bar: TabBar
var _items_view: Control
var _archive_view: Control
var _archive_list: ItemList
var _archive_detail: Label


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

	_tab_bar = TabBar.new()
	_tab_bar.add_tab("物品")
	_tab_bar.add_tab("档案库")
	_tab_bar.tab_changed.connect(_on_tab_changed)
	outer.add_child(_tab_bar)

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

	# --- 合成区（无需选中物品，独立于使用/丢弃）---
	var sep := HSeparator.new()
	side.add_child(sep)

	_craft_hint_label = Label.new()
	_craft_hint_label.text = "合成配方：3 废料 + 1 燃料 → 1 零件"
	_craft_hint_label.add_theme_font_size_override("font_size", 13)
	_craft_hint_label.add_theme_color_override("font_color", Color("#bcc8d8"))
	_craft_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(_craft_hint_label)

	_craft_btn = Button.new()
	_craft_btn.text = "合成零件"
	_craft_btn.pressed.connect(func(): craft_parts_requested.emit())
	side.add_child(_craft_btn)

	var close_btn := Button.new()
	close_btn.text = "关闭 (B / Esc)"
	close_btn.pressed.connect(func(): hide_backpack())
	side.add_child(close_btn)

	_items_view = body

	_archive_view = HBoxContainer.new()
	_archive_view.add_theme_constant_override("separation", 14)
	_archive_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_archive_view.visible = false
	outer.add_child(_archive_view)

	_archive_list = ItemList.new()
	_archive_list.custom_minimum_size = Vector2(280, 320)
	_archive_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_archive_list.item_selected.connect(_on_archive_selected)
	_archive_view.add_child(_archive_list)

	var archive_side := VBoxContainer.new()
	archive_side.custom_minimum_size = Vector2(240, 320)
	archive_side.add_theme_constant_override("separation", 10)
	_archive_view.add_child(archive_side)

	_archive_detail = Label.new()
	_archive_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_archive_detail.custom_minimum_size = Vector2(228, 180)
	_archive_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_archive_detail.text = "← 选择左侧档案"
	_archive_detail.add_theme_color_override("font_color", Color("#d8e4f0"))
	archive_side.add_child(_archive_detail)

	var archive_close_btn := Button.new()
	archive_close_btn.text = "关闭 (B / Esc)"
	archive_close_btn.pressed.connect(func(): hide_backpack())
	archive_side.add_child(archive_close_btn)


func show_backpack(inventory: InventoryData) -> void:
	_inventory = inventory
	_refresh_list(inventory)
	_refresh_archive_list()
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

func _refresh_archive_list() -> void:
	_archive_list.clear()
	var ids := EvidenceData.all_ids()
	ids.sort_custom(func(a, b): return EvidenceData.layer_of(a) < EvidenceData.layer_of(b))
	for ev_id in ids:
		var collected := MetaManager.evidence_collected.has(ev_id)
		var label_text: String
		if collected:
			label_text = "✓ %s（第%d层）" % [EvidenceData.title_of(ev_id), EvidenceData.layer_of(ev_id)]
		else:
			label_text = "○ ??? （第%d层）" % EvidenceData.layer_of(ev_id)
		var idx := _archive_list.add_item(label_text)
		_archive_list.set_item_metadata(idx, ev_id)
		if not collected:
			_archive_list.set_item_custom_fg_color(idx, Color(0.55, 0.6, 0.7))

func _on_archive_selected(index: int) -> void:
	if index < 0:
		_archive_detail.text = ""
		return
	var ev_id := str(_archive_list.get_item_metadata(index))
	if MetaManager.evidence_collected.has(ev_id):
		_archive_detail.text = "%s\n\n%s" % [
			EvidenceData.title_of(ev_id),
			EvidenceData.content_of(ev_id),
		]
	else:
		_archive_detail.text = "（尚未收集此档案。）"

func _on_tab_changed(tab: int) -> void:
	_items_view.visible = (tab == 0)
	_archive_view.visible = (tab == 1)
