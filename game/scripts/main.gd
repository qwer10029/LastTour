extends Node2D

enum TravelMode { DRIVE, JUNCTION, FOOT }

@export var vehicle_scene: PackedScene
@export var player_scene: PackedScene
@export var resource_scene: PackedScene
@export var map_columns: int = 8
@export var map_rows: int = 6
@export var cell_size: Vector2i = Vector2i(240, 240)
@export var fuel_max: float = 999.0
@export var fuel_per_pixel: float = 0.01
@export var drive_speed: float = 160.0

var _map: WorldMapData = WorldMapData.new()
var _mode: int = TravelMode.DRIVE
var _vehicle: VehicleUnit
var _player: PlayerCharacter
var _resource_nodes: Array[Area2D] = []
var _fuel: float = 0.0
var _inventory: int = 0
var _current_node_index: int = -1
var _previous_node_index: int = -1
var _segment_target_index: int = -1
var _segment_progress: float = 0.0
var _segment_length: float = 1.0
var _drive_travel_distance: float = 0.0
var _current_district_index: int = -1
var _junction_options: Dictionary = {}
var _drive_offset: Vector2 = Vector2.ZERO

@onready var mode_label: Label = $HUD/InfoPanel/MarginContainer/VBoxContainer/ModeLabel
@onready var fuel_label: Label = $HUD/InfoPanel/MarginContainer/VBoxContainer/FuelLabel
@onready var inventory_label: Label = $HUD/InfoPanel/MarginContainer/VBoxContainer/InventoryLabel
@onready var status_label: Label = $HUD/InfoPanel/MarginContainer/VBoxContainer/StatusLabel
@onready var minimap_view: MinimapView = $HUD/MapPanel/MarginContainer/VBoxContainer/MinimapView
@onready var map_info_label: Label = $HUD/MapPanel/MarginContainer/VBoxContainer/MapInfoLabel
@onready var prompt_label: Label = $HUD/ActionPanel/MarginContainer/VBoxContainer/PromptLabel
@onready var disembark_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/ActionButtons/DisembarkButton
@onready var return_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/ActionButtons/ReturnButton
@onready var up_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/JunctionButtons/UpButton
@onready var down_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/JunctionButtons/DownButton
@onready var left_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/JunctionButtons/LeftButton
@onready var right_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/JunctionButtons/RightButton

func _ready() -> void:
	_ensure_input_actions()
	_connect_buttons()
	_map.generate(map_columns, map_rows, cell_size)
	_fuel = fuel_max
	_spawn_vehicle()
	_spawn_player()
	_spawn_resources()
	if is_instance_valid(minimap_view):
		minimap_view.set_world_map(_map)
	if _map.start_node_index >= 0:
		_begin_drive_from(_map.start_node_index)
	_refresh_ui()
	queue_redraw()

func _ensure_input_actions() -> void:
	for action_name in ["move_up", "move_down", "move_left", "move_right", "interact"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
	_register_key_action("move_up", KEY_W)
	_register_key_action("move_up", KEY_UP)
	_register_key_action("move_down", KEY_S)
	_register_key_action("move_down", KEY_DOWN)
	_register_key_action("move_left", KEY_A)
	_register_key_action("move_left", KEY_LEFT)
	_register_key_action("move_right", KEY_D)
	_register_key_action("move_right", KEY_RIGHT)
	_register_key_action("interact", KEY_E)
	_register_key_action("interact", KEY_SPACE)

func _register_key_action(action_name: String, keycode: Key) -> void:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)

func _connect_buttons() -> void:
	disembark_button.pressed.connect(_on_disembark_pressed)
	return_button.pressed.connect(_on_return_pressed)
	up_button.pressed.connect(func(): _on_direction_pressed("up"))
	down_button.pressed.connect(func(): _on_direction_pressed("down"))
	left_button.pressed.connect(func(): _on_direction_pressed("left"))
	right_button.pressed.connect(func(): _on_direction_pressed("right"))

func _spawn_vehicle() -> void:
	if vehicle_scene == null:
		vehicle_scene = load("res://scenes/vehicle.tscn")
	_vehicle = vehicle_scene.instantiate()
	add_child(_vehicle)

func _spawn_player() -> void:
	if player_scene == null:
		player_scene = load("res://scenes/player.tscn")
	_player = player_scene.instantiate()
	add_child(_player)
	_player.set_hud_callback(Callable(self, "_refresh_focus"))

func _spawn_resources() -> void:
	if resource_scene == null:
		resource_scene = load("res://scenes/resource_pickup.tscn")
	_resource_nodes.clear()
	for district_index in _map.district_indices:
		var cell := _map.get_cell(district_index)
		for spawn_position in cell.get("resource_spawns", []):
			var pickup := resource_scene.instantiate()
			add_child(pickup)
			pickup.visible = false
			pickup.position = _map.cell_rect(district_index).position + spawn_position
			pickup.set_meta("district_index", district_index)
			pickup.collected.connect(_on_resource_collected.bind(pickup))
			_resource_nodes.append(pickup)

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		if _mode == TravelMode.DRIVE and _can_disembark():
			_begin_foot_mode()
		elif _mode == TravelMode.FOOT:
			_return_to_vehicle()

	match _mode:
		TravelMode.DRIVE:
			_process_drive(delta)
		TravelMode.FOOT:
			_process_foot(delta)
		TravelMode.JUNCTION:
			_process_junction()

	_refresh_focus()
	_refresh_ui()
	queue_redraw()

func _process_drive(delta: float) -> void:
	if _segment_target_index < 0 or not _map.is_valid_index(_segment_target_index):
		_update_vehicle_transform()
		return

	var axis := 0.0
	if Input.is_action_pressed("move_left"):
		axis -= 1.0
	if Input.is_action_pressed("move_right"):
		axis += 1.0
	if axis == 0.0:
		_update_vehicle_transform()
		return
	_segment_progress = clampf(_segment_progress + axis * drive_speed * delta / maxf(_segment_length, 1.0), 0.0, 1.0)
	_update_vehicle_transform()
	_fuel = maxf(_fuel - abs(axis) * drive_speed * delta * fuel_per_pixel, 0.0)

	if _segment_progress >= 1.0:
		_arrive_at_node(_segment_target_index)

func _process_foot(_delta: float) -> void:
	if is_instance_valid(_player):
		_player.global_position = _clamp_to_cell(_player.global_position, _current_district_index)

func _process_junction() -> void:
	# Allow both keyboard and UI buttons to choose the next branch.
	if Input.is_action_just_pressed("move_up"):
		_on_direction_pressed("up")
	elif Input.is_action_just_pressed("move_down"):
		_on_direction_pressed("down")
	elif Input.is_action_just_pressed("move_left"):
		_on_direction_pressed("left")
	elif Input.is_action_just_pressed("move_right"):
		_on_direction_pressed("right")

func _arrive_at_node(node_index: int) -> void:
	if _segment_target_index >= 0:
		_drive_travel_distance += _segment_length
	var source_node := _current_node_index
	_current_node_index = node_index
	_previous_node_index = source_node if _map.is_valid_index(source_node) else _previous_node_index
	_map.mark_explored(node_index)
	var degree := _map.connected_count(node_index)
	# Record current district for possible disembark options, but do not force stop driving.
	if _map.is_district(node_index):
		_current_district_index = node_index
	if degree >= 3:
		_mode = TravelMode.JUNCTION
		_segment_target_index = -1
		_junction_options = _build_junction_options(node_index)
		return
	if degree == 2:
		var next_index := _pick_auto_next(node_index)
		if next_index >= 0:
			_begin_drive_segment(node_index, next_index)
			return
	_mode = TravelMode.DRIVE
	_segment_target_index = -1

func _pick_auto_next(node_index: int) -> int:
	var connections := _map.get_connected_indices(node_index)
	for connected in connections:
		if connected != _previous_node_index:
			return connected
	return -1

func _build_junction_options(node_index: int) -> Dictionary:
	var options: Dictionary = {}
	for direction in _map.get_available_directions(node_index):
		var neighbor := _map.get_neighbor_index(node_index, direction)
		if neighbor >= 0:
			options[direction] = neighbor
	return options

func _begin_drive_from(start_index: int) -> void:
	var next_index := _pick_auto_next(start_index)
	if next_index < 0:
		next_index = start_index
	_current_node_index = start_index
	_previous_node_index = start_index
	_begin_drive_segment(start_index, next_index)

func _begin_drive_segment(from_index: int, to_index: int) -> void:
	if not _map.is_valid_index(from_index) or not _map.is_valid_index(to_index):
		return
	_mode = TravelMode.DRIVE
	_current_node_index = from_index
	_previous_node_index = from_index
	_segment_target_index = to_index
	_segment_progress = 0.0
	_segment_length = maxf(_map.cell_center(from_index).distance_to(_map.cell_center(to_index)), 1.0)
	if is_instance_valid(_vehicle):
		_vehicle.set_active(true)
		_vehicle.global_position = _map.cell_center(from_index)
	for node in _resource_nodes:
		if is_instance_valid(node):
			node.visible = false

func _begin_foot_mode() -> void:
	if _current_district_index < 0:
		return
	_mode = TravelMode.FOOT
	_segment_target_index = -1
	if is_instance_valid(_vehicle):
		_vehicle.set_active(false)
	if is_instance_valid(_player):
		_player.set_active(true)
		_player.world_bounds = _map.cell_rect(_current_district_index)
		_player.global_position = _map.cell_rect(_current_district_index).position + _map.cell_rect(_current_district_index).size * 0.5
	for node in _resource_nodes:
		if is_instance_valid(node):
			node.visible = int(node.get_meta("district_index", -1)) == _current_district_index

func _return_to_vehicle() -> void:
	_mode = TravelMode.DRIVE
	if is_instance_valid(_player):
		_player.set_active(false)
	if is_instance_valid(_vehicle):
		_vehicle.set_active(true)
		_vehicle.global_position = _map.cell_center(maxi(_current_district_index, 0))
	for node in _resource_nodes:
		if is_instance_valid(node):
			node.visible = false
	if _current_district_index >= 0:
		var next_index := _pick_auto_next(_current_district_index)
		if next_index >= 0:
			_begin_drive_segment(_current_district_index, next_index)

func _on_disembark_pressed() -> void:
	if _mode == TravelMode.DRIVE and _can_disembark():
		_begin_foot_mode()

func _on_return_pressed() -> void:
	if _mode == TravelMode.FOOT:
		_return_to_vehicle()

func _on_direction_pressed(direction: String) -> void:
	if _mode != TravelMode.JUNCTION:
		return
	if _junction_options.has(direction):
		_begin_drive_segment(_current_node_index, int(_junction_options[direction]))

func _can_disembark() -> bool:
	return _current_district_index >= 0 and _map.is_district(_current_district_index)

func _on_resource_collected(pickup: Node) -> void:
	if not is_instance_valid(pickup):
		return
	if not pickup.has_meta("district_index"):
		return
	var district_index := int(pickup.get_meta("district_index"))
	if _map.collect_resource(district_index):
		_inventory += 1
		_refresh_ui()

func _current_focus_position() -> Vector2:
	if _mode == TravelMode.FOOT and is_instance_valid(_player):
		return _player.global_position
	if is_instance_valid(_vehicle):
		return _vehicle.global_position
	if _current_node_index >= 0:
		return _map.cell_center(_current_node_index)
	return Vector2.ZERO

func _refresh_focus() -> void:
	_map.mark_position_explored(_current_focus_position())
	if is_instance_valid(minimap_view):
		minimap_view.set_focus_position(_current_focus_position())

func _refresh_ui() -> void:
	if is_instance_valid(mode_label):
		mode_label.text = "状态: %s" % ["驾驶车辆" if _mode != TravelMode.FOOT else "步行探索"]
	if is_instance_valid(fuel_label):
		fuel_label.text = "燃料: %.1f / %.1f" % [_fuel, fuel_max]
	if is_instance_valid(inventory_label):
		inventory_label.text = "已搬运资源: %d" % _inventory

	var district_text := ""
	if _current_district_index >= 0 and _map.is_valid_index(_current_district_index):
		district_text = " | %s" % _map.building_label(_current_district_index)
	if is_instance_valid(status_label):
		status_label.text = "探索: %d / %d | 剩余资源: %d%s" % [_map.explored_count(), _map.cells.size(), _map.total_resources_remaining(), district_text]
	if is_instance_valid(map_info_label):
		map_info_label.text = "迷你地图：亮起为已探索，黑色为未探索，红点为当前位置"

	if is_instance_valid(prompt_label):
		_update_prompts()

func _update_prompts() -> void:
	var can_stop := _can_disembark()
	var in_junction := _mode == TravelMode.JUNCTION
	var in_foot := _mode == TravelMode.FOOT
	prompt_label.text = ""
	disembark_button.visible = false
	return_button.visible = false
	up_button.visible = false
	down_button.visible = false
	left_button.visible = false
	right_button.visible = false

	if in_junction:
		prompt_label.text = "十字路口：↑北 ↓南 ←西 →东，车的位置表示来向"
		up_button.visible = _junction_options.has("up")
		down_button.visible = _junction_options.has("down")
		left_button.visible = _junction_options.has("left")
		right_button.visible = _junction_options.has("right")
	elif in_foot:
		prompt_label.text = "步行探索：收集资源后按返回车辆"
		return_button.visible = true
	elif can_stop:
		prompt_label.text = "建筑群：可以下车探索"
		disembark_button.visible = true
	else:
		prompt_label.text = "沿道路驾驶，遇到十字路口会切换到俯视选择"

func _update_vehicle_transform() -> void:
	if not is_instance_valid(_vehicle):
		return
	if _segment_target_index < 0:
		_drive_offset = Vector2(_drive_travel_distance, 0.0)
		_vehicle.global_position = _map.cell_center(maxi(_current_node_index, 0))
		return
	# keep the vehicle visually fixed while the background scrolls across the current segment
	_drive_offset = Vector2(_drive_travel_distance + _segment_progress * _segment_length, 0.0)
	_vehicle.global_position = _map.cell_center(maxi(_current_node_index, 0))

func _clamp_to_cell(position: Vector2, district_index: int) -> Vector2:
	if not _map.is_valid_index(district_index):
		return position
	var rect := _map.cell_rect(district_index)
	return Vector2(clampf(position.x, rect.position.x + 18.0, rect.end.x - 18.0), clampf(position.y, rect.position.y + 18.0, rect.end.y - 18.0))

func _draw() -> void:
	match _mode:
		TravelMode.DRIVE:
			_draw_drive_background()
		TravelMode.JUNCTION:
			_draw_junction_background()
		TravelMode.FOOT:
			_draw_foot_background()

func _draw_drive_background() -> void:
	var view_size := get_viewport_rect().size
	if view_size == Vector2.ZERO:
		view_size = Vector2(1280.0, 720.0)
	var anchor := _drive_view_anchor()
	var left := anchor.x - view_size.x * 0.5
	var top := anchor.y - view_size.y * 0.5
	var scroll := _drive_offset.x

	draw_rect(Rect2(Vector2(left, top), view_size), Color("#0b1624"), true)
	draw_rect(Rect2(left, top, view_size.x, view_size.y * 0.54), Color("#102133"), true)

	var sun_x := left + view_size.x * 0.78
	var sun_y := top + view_size.y * 0.18
	draw_circle(Vector2(sun_x, sun_y), 42.0, Color("#f0c168"))

	var mountain_spacing := 240.0
	var mountain_shift := fposmod(scroll * 0.16, mountain_spacing)
	for i in range(-2, int(view_size.x / mountain_spacing) + 5):
		var mountain_x := left + float(i) * mountain_spacing - mountain_shift
		draw_circle(Vector2(mountain_x, top + view_size.y * 0.50), 120.0, Color("#1a2d42"))
		draw_rect(Rect2(mountain_x - 120.0, top + view_size.y * 0.50, 240.0, 90.0), Color("#1a2d42"), true)

	var block_spacing := 160.0
	var block_shift := fposmod(scroll * 0.34, block_spacing)
	for i in range(-3, int(view_size.x / block_spacing) + 6):
		var block_x := left + float(i) * block_spacing - block_shift
		var block_height := 72.0 + float(i % 4) * 20.0
		draw_rect(Rect2(block_x - 42.0, top + view_size.y * 0.58 - block_height, 84.0, block_height), Color("#223246"), true)
		draw_rect(Rect2(block_x - 50.0, top + view_size.y * 0.58 - block_height - 10.0, 100.0, 10.0), Color("#31455c"), true)
		if i % 2 == 0:
			draw_rect(Rect2(block_x - 10.0, top + view_size.y * 0.58 - block_height - 26.0, 20.0, 16.0), Color("#3b5169"), true)

	var tree_spacing := 132.0
	var tree_shift := fposmod(scroll * 0.58, tree_spacing)
	for i in range(-3, int(view_size.x / tree_spacing) + 6):
		var tree_x := left + float(i) * tree_spacing - tree_shift
		var trunk_top := top + view_size.y * 0.72
		draw_rect(Rect2(tree_x - 3.0, trunk_top - 26.0, 6.0, 32.0), Color("#5b4430"), true)
		draw_circle(Vector2(tree_x, trunk_top - 34.0), 18.0, Color("#3e6c53"))
		draw_circle(Vector2(tree_x - 12.0, trunk_top - 28.0), 12.0, Color("#345d48"))

	var road_top := top + view_size.y * 0.76
	draw_rect(Rect2(left - 120.0, road_top, view_size.x + 240.0, view_size.y - (road_top - top)), Color("#2a2f36"), true)
	draw_rect(Rect2(left - 120.0, road_top + 12.0, view_size.x + 240.0, 6.0), Color("#4d535c"), true)

	var stripe_spacing := 78.0
	var stripe_shift := fposmod(scroll * 0.92, stripe_spacing)
	for i in range(-2, int((view_size.x + 240.0) / stripe_spacing) + 5):
		var stripe_x := left - 120.0 + float(i) * stripe_spacing - stripe_shift
		draw_rect(Rect2(stripe_x, road_top + 58.0, 34.0, 6.0), Color("#d6c779"), true)

	if is_instance_valid(_vehicle):
		var vpos := _vehicle.global_position
		draw_rect(Rect2(vpos.x - 8.0, road_top + 34.0, 16.0, 12.0), Color("#1a1a1a"), true)
		draw_rect(Rect2(vpos.x - 30.0, road_top + 18.0, 60.0, 20.0), Color("#d89246"), true)
		draw_rect(Rect2(vpos.x - 34.0, road_top + 34.0, 68.0, 12.0), Color("#6b3f17"), true)

func _drive_view_anchor() -> Vector2:
	if is_instance_valid(_vehicle):
		return _vehicle.global_position
	if _current_node_index >= 0:
		return _map.cell_center(_current_node_index)
	return Vector2.ZERO

func _draw_junction_background() -> void:
	var center := Vector2(640.0, 360.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color("#0e141b"), true)
	draw_rect(Rect2(center.x - 180.0, center.y - 24.0, 360.0, 48.0), Color("#313943"), true)
	draw_rect(Rect2(center.x - 24.0, center.y - 180.0, 48.0, 360.0), Color("#313943"), true)
	for direction in _junction_options.keys():
		match str(direction):
			"up":
				draw_rect(Rect2(center.x - 18.0, center.y - 220.0, 36.0, 120.0), Color("#4e6a7f"), true)
			"down":
				draw_rect(Rect2(center.x - 18.0, center.y + 100.0, 36.0, 120.0), Color("#4e6a7f"), true)
			"left":
				draw_rect(Rect2(center.x - 220.0, center.y - 18.0, 120.0, 36.0), Color("#4e6a7f"), true)
			"right":
				draw_rect(Rect2(center.x + 100.0, center.y - 18.0, 120.0, 36.0), Color("#4e6a7f"), true)
	draw_circle(center, 20.0, Color("#ff5f57"))
	if is_instance_valid(_vehicle):
		var entry_offset := _junction_entry_offset()
		draw_rect(Rect2(center.x + entry_offset.x - 16.0, center.y + entry_offset.y - 10.0, 32.0, 16.0), Color("#d89246"), true)

func _junction_entry_offset() -> Vector2:
	if _current_node_index < 0 or _previous_node_index < 0:
		return Vector2.ZERO
	var current_coord := _map.coord_from_index(_current_node_index)
	var previous_coord := _map.coord_from_index(_previous_node_index)
	var delta := current_coord - previous_coord
	if delta == Vector2i(0, -1):
		return Vector2(0.0, -126.0)
	if delta == Vector2i(0, 1):
		return Vector2(0.0, 126.0)
	if delta == Vector2i(-1, 0):
		return Vector2(-126.0, 0.0)
	if delta == Vector2i(1, 0):
		return Vector2(126.0, 0.0)
	return Vector2.ZERO

func _draw_foot_background() -> void:
	if _current_district_index < 0:
		return
	# Expand foot view to a larger interior area and draw a dark-blue tiled grid background.
	var rect := _map.cell_rect(_current_district_index)
	var interior_margin := Vector2(80.0, 80.0)
	var interior_size := rect.size + interior_margin * 2.0
	var interior_origin := rect.position - interior_margin
	var interior_rect := Rect2(interior_origin, interior_size)
	draw_rect(interior_rect, Color("#031026"), true)
	# draw grid tiles
	var tile_size := 48.0
	for gx in range(0, int(interior_size.x / tile_size) + 1):
		for gy in range(0, int(interior_size.y / tile_size) + 1):
			var px := interior_origin.x + gx * tile_size
			var py := interior_origin.y + gy * tile_size
			var shade := Color("#05223a") if ((gx + gy) % 2 == 0) else Color("#022033")
			draw_rect(Rect2(px, py, tile_size, tile_size), shade, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_map.get_cell(_current_district_index)["seed"])
	for detail in range(5):
		var detail_width := rng.randf_range(40.0, 110.0)
		var detail_height := rng.randf_range(28.0, 80.0)
		var detail_x := rng.randf_range(rect.position.x + 20.0, rect.end.x - detail_width - 20.0)
		var detail_y := rng.randf_range(rect.position.y + 20.0, rect.end.y - detail_height - 20.0)
		draw_rect(Rect2(detail_x, detail_y, detail_width, detail_height), Color("#39463a"), true)
