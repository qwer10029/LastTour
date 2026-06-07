class_name PdaHudPanel
extends Control

signal backpack_pressed
signal item_use_requested(item_id: String)

const ICON_SLOT_SIZE := 40
const ICON_TEX_SIZE := 28
const MAX_ICON_SLOTS := 5

var _icon_row: HBoxContainer
var _backpack_button: Button
var _icon_slots: Array[Button] = []


func _ready() -> void:
	custom_minimum_size = Vector2(268, HudTheme.TOP_BAR_CONTENT_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_ui()


func _build_ui() -> void:
	_icon_row = HBoxContainer.new()
	_icon_row.add_theme_constant_override("separation", 4)
	add_child(_icon_row)

	_backpack_button = _make_backpack_button()
	_icon_row.add_child(_backpack_button)

	for i in MAX_ICON_SLOTS:
		var slot := _make_icon_slot()
		slot.name = "IconSlot%d" % i
		slot.pressed.connect(_on_icon_slot_pressed.bind(slot))
		_icon_row.add_child(slot)
		_icon_slots.append(slot)


func _make_backpack_button() -> Button:
	var btn := Button.new()
	btn.name = "BackpackButton"
	btn.custom_minimum_size = Vector2(ICON_SLOT_SIZE, ICON_SLOT_SIZE)
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = "打开背包 (B)"
	btn.pressed.connect(func() -> void: backpack_pressed.emit())
	_apply_slot_style(btn, Color("#6a8ca8", 0.78))

	var body := Control.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(body)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(ICON_TEX_SIZE, ICON_TEX_SIZE)
	icon.size = Vector2(ICON_TEX_SIZE, ICON_TEX_SIZE)
	icon.position = Vector2(
		(ICON_SLOT_SIZE - ICON_TEX_SIZE) * 0.5,
		(ICON_SLOT_SIZE - ICON_TEX_SIZE) * 0.5 - 1.0,
	)
	icon.texture = ItemIconFactory.get_backpack_texture(ICON_TEX_SIZE)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(icon)

	var key_hint := Label.new()
	key_hint.name = "KeyHint"
	key_hint.text = "B"
	key_hint.add_theme_font_size_override("font_size", 9)
	key_hint.add_theme_color_override("font_color", Color("#eef8ff"))
	HudTheme.apply_label(key_hint)
	key_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	key_hint.offset_left = 3.0
	key_hint.offset_top = -13.0
	key_hint.offset_right = 14.0
	key_hint.offset_bottom = -1.0
	body.add_child(key_hint)

	return btn


func _make_icon_slot() -> Button:
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(ICON_SLOT_SIZE, ICON_SLOT_SIZE)
	slot.focus_mode = Control.FOCUS_NONE
	_apply_slot_style(slot, Color(0.28, 0.40, 0.50, 0.55))

	var body := Control.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(body)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(ICON_TEX_SIZE, ICON_TEX_SIZE)
	icon.size = Vector2(ICON_TEX_SIZE, ICON_TEX_SIZE)
	icon.position = Vector2(
		(ICON_SLOT_SIZE - ICON_TEX_SIZE) * 0.5,
		(ICON_SLOT_SIZE - ICON_TEX_SIZE) * 0.5 - 2.0,
	)
	icon.visible = false
	body.add_child(icon)

	var count := Label.new()
	count.name = "Count"
	count.add_theme_font_size_override("font_size", 10)
	count.add_theme_color_override("font_color", Color("#eef8ff"))
	HudTheme.apply_label(count)
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.offset_left = -22.0
	count.offset_top = -14.0
	count.offset_right = -2.0
	count.offset_bottom = -1.0
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.visible = false
	body.add_child(count)

	return slot


func _apply_slot_style(slot: Button, border: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.10, 0.14, 0.92)
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	box.content_margin_left = 0
	box.content_margin_top = 0
	box.content_margin_right = 0
	box.content_margin_bottom = 0
	slot.add_theme_stylebox_override("normal", box)
	slot.add_theme_stylebox_override("hover", _slot_style(box, true))
	slot.add_theme_stylebox_override("pressed", _slot_style(box, true))
	slot.add_theme_stylebox_override("disabled", _slot_style(box, false, 0.45))
	slot.set_meta("slot_border", border)


func _slot_style(base: StyleBoxFlat, hover: bool, alpha: float = 1.0) -> StyleBoxFlat:
	var box := base.duplicate() as StyleBoxFlat
	box.bg_color.a *= alpha
	if hover:
		box.border_color = Color("#8ec8e8", 0.85)
	return box


func refresh(data: Dictionary) -> void:
	var entries: Array = data.get("entries", [])

	var shown := mini(entries.size(), MAX_ICON_SLOTS)
	for i in MAX_ICON_SLOTS:
		_set_icon_slot(_icon_slots[i], "", 0)
	for i in shown:
		var entry: Dictionary = entries[i]
		_set_icon_slot(_icon_slots[i], str(entry.get("id", "")), int(entry.get("count", 0)))

	if not is_instance_valid(_backpack_button):
		return
	var open := bool(data.get("backpack_open", false))
	var enabled := bool(data.get("backpack_enabled", true))
	_backpack_button.visible = enabled
	_backpack_button.disabled = not enabled
	_backpack_button.tooltip_text = "关闭背包 (B)" if open else "打开背包 (B)"
	var border := Color("#f0c168", 0.92) if open else Color("#6a8ca8", 0.78)
	_apply_slot_style(_backpack_button, border)


func _set_icon_slot(slot: Button, item_id: String, count: int) -> void:
	slot.set_meta("item_id", item_id)
	var body := slot.get_child(0) as Control
	if body == null:
		return
	var icon := body.get_node_or_null("Icon") as TextureRect
	var count_lbl := body.get_node_or_null("Count") as Label
	if item_id.is_empty() or count <= 0:
		slot.visible = false
		slot.disabled = true
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_instance_valid(icon):
			icon.texture = null
			icon.visible = false
		if is_instance_valid(count_lbl):
			count_lbl.visible = false
		return

	slot.visible = true
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	var usable := ItemDefs.is_usable(item_id)
	slot.disabled = not usable
	slot.tooltip_text = ItemDefs.get_item_name(item_id)
	if usable:
		slot.tooltip_text += "\n点击使用"
	var border := Color("#6a9a72", 0.72) if usable else Color(0.28, 0.40, 0.50, 0.55)
	_apply_slot_style(slot, border)

	if is_instance_valid(icon):
		icon.texture = ItemIconFactory.get_texture(item_id, ICON_TEX_SIZE)
		icon.visible = true
	if is_instance_valid(count_lbl):
		count_lbl.text = str(count)
		count_lbl.visible = true


func _on_icon_slot_pressed(slot: Button) -> void:
	var item_id := str(slot.get_meta("item_id", ""))
	if item_id.is_empty() or not ItemDefs.is_usable(item_id):
		return
	item_use_requested.emit(item_id)
