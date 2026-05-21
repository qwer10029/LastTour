extends Node2D

enum TravelMode { DRIVE, FOOT }

@export var vehicle_scene: PackedScene
@export var player_scene: PackedScene
@export var resource_scene: PackedScene
@export var map_columns: int = 8
@export var map_rows: int = 6
@export var cell_size: Vector2i = Vector2i(240, 240)
@export var fuel_max: float = 999.0
@export var fuel_per_pixel: float = 0.01
@export var drive_speed: float = 160.0
@export var total_layers: int = 3
@export var base_elevator_repair_cost: int = 3

var _map: WorldMapData = WorldMapData.new()
var _mode: int = TravelMode.DRIVE
var _vehicle: VehicleUnit
var _player: PlayerCharacter
var _resource_nodes: Array[Area2D] = []
var _fuel: float = 0.0
var _inventory: int = 0
var _current_node_index: int = -1
var _previous_node_index: int = -1
var _arrived_from_index: int = -1
var _segment_from_index: int = -1
var _segment_target_index: int = -1
var _segment_progress: float = 0.0
var _segment_length: float = 1.0
var _drive_travel_distance: float = 0.0
var _current_district_index: int = -1
var _exit_options: Dictionary = {}
var _drive_offset: Vector2 = Vector2.ZERO
var _current_layer: int = 1
var _elevator_repair_progress: int = 0
var _run_completed := false
var _base_fuel_max: float = 999.0
var _base_elevator_repair_cost: int = 3
var _run_difficulty_name: String = "普通"
var _run_squad_name: String = "拾荒者"
var _saved_travel_mode: int = TravelMode.DRIVE
var _evening_tint: float = 0.0
var _game_paused := false
var _pause_layer: CanvasLayer
var _pause_panel: PanelContainer
var _pause_confirm: ConfirmationDialog

@onready var time_system: TimeSystem = $Systems/TimeSystem
@onready var night_defense: NightDefenseSystem = $Systems/NightDefenseSystem
@onready var time_hud: Control = $HUD/TimePanel/MarginContainer/TimeHud
@onready var evening_notice: PanelContainer = $HUD/EveningNotice
@onready var night_td: NightTdController = $NightTd
@onready var mode_label: Label = $HUD/InfoPanel/MarginContainer/VBoxContainer/ModeLabel
@onready var fuel_label: Label = $HUD/InfoPanel/MarginContainer/VBoxContainer/FuelLabel
@onready var inventory_label: Label = $HUD/InfoPanel/MarginContainer/VBoxContainer/InventoryLabel
@onready var status_label: Label = $HUD/InfoPanel/MarginContainer/VBoxContainer/StatusLabel
@onready var minimap_view: MinimapView = $HUD/MapPanel/MarginContainer/VBoxContainer/MinimapView
@onready var map_info_label: Label = $HUD/MapPanel/MarginContainer/VBoxContainer/MapInfoLabel
@onready var prompt_label: Label = $HUD/ActionPanel/MarginContainer/VBoxContainer/PromptLabel
@onready var disembark_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/ActionButtons/DisembarkButton
@onready var return_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/ActionButtons/ReturnButton
@onready var repair_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/ActionButtons/RepairButton
@onready var up_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/JunctionButtons/UpButton
@onready var down_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/JunctionButtons/DownButton
@onready var left_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/JunctionButtons/LeftButton
@onready var right_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/JunctionButtons/RightButton
@onready var back_track_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/ActionButtons/BackTrackButton

func _ready() -> void:
	_base_fuel_max = fuel_max
	_base_elevator_repair_cost = base_elevator_repair_cost
	_apply_run_config_from_manager()
	_ensure_input_actions()
	_connect_buttons()
	_setup_pause_ui()
	_spawn_vehicle()
	_spawn_player()
	_setup_day_night()
	var junction_buttons := get_node_or_null("HUD/ActionPanel/MarginContainer/VBoxContainer/JunctionButtons")
	if junction_buttons != null:
		junction_buttons.visible = false
	if GameManager.consume_load_save_request():
		var save_data := SaveManager.load_game()
		if save_data.is_empty():
			_start_new_run()
		else:
			_apply_save_data(save_data)
	else:
		_start_new_run()
	_refresh_ui()
	queue_redraw()


func _start_new_run() -> void:
	_generate_layer_map()
	_fuel = fuel_max
	_spawn_resources()
	if is_instance_valid(minimap_view):
		minimap_view.set_world_map(_map)
	if _map.start_node_index >= 0:
		_enter_node(_map.start_node_index, true)
	if is_instance_valid(time_system):
		time_system.start_day(1)

func _ensure_input_actions() -> void:
	for action_name in ["move_up", "move_down", "move_left", "move_right", "interact", "repair", "pause"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
	# 步行：WASD；驾车/选路：方向键（↑北 ↓南 ←西 →东）
	_reset_action_keys("move_up")
	_reset_action_keys("move_down")
	_reset_action_keys("move_left")
	_reset_action_keys("move_right")
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
	_register_key_action("repair", KEY_R)
	_register_key_action("pause", KEY_ESCAPE)
	_register_key_action("pause", KEY_P)

func _reset_action_keys(action_name: String) -> void:
	for event in InputMap.action_get_events(action_name):
		InputMap.action_erase_event(action_name, event)

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
	repair_button.pressed.connect(_on_repair_pressed)
	if is_instance_valid(back_track_button):
		back_track_button.focus_mode = Control.FOCUS_NONE
		back_track_button.pressed.connect(_take_back_at_node)

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
	for node in _resource_nodes:
		if is_instance_valid(node):
			node.queue_free()
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
	if _game_paused:
		return
	_update_evening_tint(delta)
	if _is_night_phase():
		_refresh_ui()
		queue_redraw()
		return

	if not _is_exploration_allowed():
		_refresh_ui()
		queue_redraw()
		return

	if Input.is_action_just_pressed("interact"):
		if _mode == TravelMode.DRIVE and _segment_target_index < 0:
			_take_back_at_node()
		elif _mode == TravelMode.DRIVE and _can_disembark():
			_begin_foot_mode()
		elif _mode == TravelMode.FOOT:
			_return_to_vehicle()
	if Input.is_action_just_pressed("repair"):
		_attempt_repair_elevator()

	match _mode:
		TravelMode.DRIVE:
			_process_drive(delta)
		TravelMode.FOOT:
			_process_foot(delta)

	_refresh_focus()
	_refresh_ui()
	queue_redraw()

func _process_drive(delta: float) -> void:
	if _segment_target_index < 0 or not _map.is_valid_index(_segment_target_index):
		_update_vehicle_transform()
		return

	var axis := _get_segment_drive_axis()
	if axis == 0.0:
		_update_vehicle_transform()
		return
	_segment_progress += axis * drive_speed * delta / maxf(_segment_length, 1.0)
	_update_vehicle_transform()
	_fuel = maxf(_fuel - abs(axis) * drive_speed * delta * fuel_per_pixel, 0.0)

	if _segment_progress >= 1.0:
		_arrive_at_node(_segment_target_index)
	elif _segment_progress <= 0.0 and axis < 0.0:
		_segment_progress = 0.0
		_halt_at_node(_segment_from_index)

func _process_foot(_delta: float) -> void:
	if is_instance_valid(_player):
		_player.global_position = _clamp_to_cell(_player.global_position, _current_district_index)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if _game_paused:
		return
	if _mode != TravelMode.DRIVE:
		return
	if _is_night_phase() or not _is_exploration_allowed():
		return
	if _segment_target_index >= 0:
		return
	if not (event is InputEventKey and event.pressed and not event.is_echo()):
		return
	var direction := _direction_from_keycode(event.physical_keycode)
	if direction == "" or not _exit_options.has(direction):
		return
	_begin_drive_segment(_current_node_index, int(_exit_options[direction]))
	get_viewport().set_input_as_handled()

func _arrive_at_node(node_index: int) -> void:
	if _segment_target_index >= 0:
		_drive_travel_distance += _segment_length
	var source_node := _current_node_index
	_current_node_index = node_index
	if _map.is_valid_index(source_node):
		_arrived_from_index = source_node
		_previous_node_index = source_node
	_map.mark_explored(node_index)
	var degree := _map.connected_count(node_index)
	# Record current district for possible disembark options, but do not force stop driving.
	if _map.is_district(node_index):
		_current_district_index = node_index
	_halt_at_node(node_index)

func _pick_auto_next(node_index: int) -> int:
	var connections := _map.get_connected_indices(node_index)
	for connected in connections:
		if connected != _previous_node_index:
			return connected
	return -1

func _build_exit_options(node_index: int) -> Dictionary:
	var options: Dictionary = {}
	for direction in _map.get_available_directions(node_index):
		var neighbor := _map.get_neighbor_index(node_index, direction)
		if neighbor >= 0:
			options[direction] = neighbor
	return options


func _halt_at_node(node_index: int) -> void:
	if not _map.is_valid_index(node_index):
		return
	_mode = TravelMode.DRIVE
	_current_node_index = node_index
	_segment_target_index = -1
	_segment_from_index = -1
	_segment_progress = 0.0
	_exit_options = _build_exit_options(node_index)
	_ensure_back_exit_option()
	if is_instance_valid(_vehicle):
		_vehicle.set_active(true)
		_vehicle.global_position = _map.cell_center(node_index)
	if get_viewport() != null:
		get_viewport().gui_release_focus()
	_sync_minimap_navigation()


func _get_back_neighbor_index() -> int:
	if not _map.is_valid_index(_current_node_index) or not _map.is_valid_index(_arrived_from_index):
		return -1
	for neighbor in _map.get_connected_indices(_current_node_index):
		if neighbor == _arrived_from_index:
			return _arrived_from_index
	return -1


func _ensure_back_exit_option() -> void:
	var back_index := _get_back_neighbor_index()
	if back_index < 0:
		return
	var back_dir := _map.direction_between(_current_node_index, back_index)
	if back_dir != "":
		_exit_options[back_dir] = back_index


func _take_back_at_node() -> void:
	if _mode != TravelMode.DRIVE or _segment_target_index >= 0:
		return
	var back_index := _get_back_neighbor_index()
	if back_index >= 0:
		_begin_drive_segment(_current_node_index, back_index)


func _direction_from_keycode(keycode: Key) -> String:
	match keycode:
		KEY_UP:
			return "up"
		KEY_DOWN:
			return "down"
		KEY_LEFT:
			return "left"
		KEY_RIGHT:
			return "right"
		_:
			return ""


func _pressed_drive_direction() -> String:
	if Input.is_physical_key_pressed(KEY_UP):
		return "up"
	if Input.is_physical_key_pressed(KEY_DOWN):
		return "down"
	if Input.is_physical_key_pressed(KEY_LEFT):
		return "left"
	if Input.is_physical_key_pressed(KEY_RIGHT):
		return "right"
	return ""


func _get_segment_drive_axis() -> float:
	if _segment_target_index < 0 or not _map.is_valid_index(_segment_from_index):
		return 0.0
	var input_dir := _pressed_drive_direction()
	if input_dir == "":
		return 0.0
	var allowed := _map.allowed_input_directions_for_segment(_segment_from_index, _segment_target_index)
	if input_dir not in allowed:
		return 0.0
	var forward_dir := _map.direction_between(_segment_from_index, _segment_target_index)
	if input_dir == forward_dir:
		return 1.0
	if input_dir == _map.opposite_direction(forward_dir):
		return -1.0
	return 0.0


func _enter_node(node_index: int, is_run_start: bool = false) -> void:
	if not _map.is_valid_index(node_index):
		return
	_current_node_index = node_index
	if is_run_start:
		_arrived_from_index = -1
		_previous_node_index = -1
	_map.mark_explored(node_index)
	if _map.is_district(node_index):
		_current_district_index = node_index
	var degree := _map.connected_count(node_index)
	if degree >= 1:
		_halt_at_node(node_index)
	else:
		_mode = TravelMode.DRIVE
		_segment_target_index = -1
		if is_instance_valid(_vehicle):
			_vehicle.set_active(true)
			_vehicle.global_position = _map.cell_center(node_index)

func _begin_drive_segment(from_index: int, to_index: int) -> void:
	if not _map.is_valid_index(from_index) or not _map.is_valid_index(to_index):
		return
	_mode = TravelMode.DRIVE
	_current_node_index = from_index
	_segment_from_index = from_index
	_segment_target_index = to_index
	_segment_progress = 0.0
	_segment_length = maxf(_map.cell_center(from_index).distance_to(_map.cell_center(to_index)), 1.0)
	if is_instance_valid(_vehicle):
		_vehicle.set_active(true)
		_vehicle.global_position = _map.cell_center(from_index)
	for node in _resource_nodes:
		if is_instance_valid(node):
			node.visible = false
	_sync_minimap_navigation()

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
	if _current_node_index >= 0:
		_halt_at_node(_current_node_index)

func _on_disembark_pressed() -> void:
	if _mode == TravelMode.DRIVE and _can_disembark():
		_begin_foot_mode()

func _on_return_pressed() -> void:
	if _mode == TravelMode.FOOT:
		_return_to_vehicle()

func _on_repair_pressed() -> void:
	_attempt_repair_elevator()

func _can_disembark() -> bool:
	return _current_district_index >= 0 and _map.is_district(_current_district_index)

func _can_repair_elevator() -> bool:
	return _mode == TravelMode.FOOT and _current_district_index >= 0 and _map.district_has_elevator(_current_district_index) and not _run_completed

func apply_run_config(manager: Node) -> void:
	if manager == null:
		return
	if manager.has_method("get_fuel_max"):
		fuel_max = manager.get_fuel_max(_base_fuel_max)
	if manager.has_method("get_starting_inventory"):
		_inventory = manager.get_starting_inventory()
	if manager.has_method("get_difficulty_name"):
		_run_difficulty_name = manager.get_difficulty_name()
	if manager.has_method("get_squad_name"):
		_run_squad_name = manager.get_squad_name()


func _apply_run_config_from_manager() -> void:
	apply_run_config(GameManager)


func _current_repair_cost() -> int:
	return GameManager.get_elevator_repair_cost(_base_elevator_repair_cost) + maxi(_current_layer - 1, 0)

func _attempt_repair_elevator() -> void:
	if not _can_repair_elevator():
		return
	if _inventory <= 0:
		return
	var needed := _current_repair_cost() - _elevator_repair_progress
	if needed <= 0:
		return
	_inventory -= 1
	_elevator_repair_progress += 1
	if _elevator_repair_progress >= _current_repair_cost():
		_advance_layer()

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
	if _mode == TravelMode.DRIVE and _segment_target_index >= 0:
		return _vehicle_world_position()
	if _mode == TravelMode.DRIVE and _segment_target_index < 0 and _map.is_valid_index(_current_node_index):
		return _map.cell_center(_current_node_index)
	if is_instance_valid(_vehicle):
		return _vehicle.global_position
	if _current_node_index >= 0:
		return _map.cell_center(_current_node_index)
	return Vector2.ZERO

func _refresh_focus() -> void:
	_map.mark_position_explored(_current_focus_position())
	if is_instance_valid(minimap_view):
		minimap_view.set_focus_position(_current_focus_position())

func _setup_pause_ui() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 120
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_layer.add_child(dim)

	_pause_panel = PanelContainer.new()
	_pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	_pause_panel.offset_left = -190.0
	_pause_panel.offset_top = -150.0
	_pause_panel.offset_right = 190.0
	_pause_panel.offset_bottom = 150.0
	_pause_layer.add_child(_pause_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_pause_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := Label.new()
	title.text = "游戏暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var hint := Label.new()
	hint.text = "Esc / P 继续"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	var resume_btn := Button.new()
	resume_btn.text = "继续游戏"
	resume_btn.pressed.connect(_resume_from_pause)
	box.add_child(resume_btn)

	var save_btn := Button.new()
	save_btn.text = "保存并退出"
	save_btn.pressed.connect(_save_and_exit_to_menu)
	box.add_child(save_btn)

	var menu_btn := Button.new()
	menu_btn.text = "返回主菜单"
	menu_btn.pressed.connect(_confirm_return_to_menu)
	box.add_child(menu_btn)

	_pause_confirm = ConfirmationDialog.new()
	_pause_confirm.title = "返回主菜单"
	_pause_confirm.dialog_text = "未保存的进度将丢失，确定返回吗？"
	_pause_confirm.ok_button_text = "返回"
	_pause_confirm.cancel_button_text = "取消"
	_pause_confirm.confirmed.connect(_return_to_menu_without_save)
	_pause_layer.add_child(_pause_confirm)

	_pause_layer.visible = false


func _toggle_pause() -> void:
	if _pause_confirm != null and _pause_confirm.visible:
		return
	if _game_paused:
		_resume_from_pause()
	else:
		_pause_game()


func _pause_game() -> void:
	_game_paused = true
	if is_instance_valid(_pause_layer):
		_pause_layer.visible = true
	if is_instance_valid(time_system) and not time_system.is_paused():
		time_system.pause()


func _resume_from_pause() -> void:
	_game_paused = false
	if is_instance_valid(_pause_layer):
		_pause_layer.visible = false
	if is_instance_valid(time_system):
		if _is_night_phase():
			time_system.pause()
		else:
			time_system.resume()


func capture_save_data() -> Dictionary:
	var player_pos := Vector2.ZERO
	if is_instance_valid(_player):
		player_pos = _player.global_position
	return {
		"difficulty": GameManager.difficulty,
		"squad_id": GameManager.squad_id,
		"fuel_max": fuel_max,
		"base_elevator_repair_cost": _base_elevator_repair_cost,
		"map": _map.to_dictionary(),
		"travel": {
			"mode": _mode,
			"fuel": _fuel,
			"inventory": _inventory,
			"current_node_index": _current_node_index,
			"previous_node_index": _previous_node_index,
			"arrived_from_index": _arrived_from_index,
			"segment_from_index": _segment_from_index,
			"segment_target_index": _segment_target_index,
			"segment_progress": _segment_progress,
			"segment_length": _segment_length,
			"drive_travel_distance": _drive_travel_distance,
			"current_district_index": _current_district_index,
		},
		"layer": {
			"current_layer": _current_layer,
			"elevator_repair_progress": _elevator_repair_progress,
			"run_completed": _run_completed,
		},
		"time": time_system.to_dictionary() if is_instance_valid(time_system) else {},
		"foot": {
			"player_x": player_pos.x,
			"player_y": player_pos.y,
		},
	}


func _apply_save_data(data: Dictionary) -> void:
	GameManager.difficulty = int(data.get("difficulty", GameManager.Difficulty.NORMAL))
	GameManager.squad_id = str(data.get("squad_id", "scavenger"))
	fuel_max = float(data.get("fuel_max", _base_fuel_max))
	_base_elevator_repair_cost = int(data.get("base_elevator_repair_cost", base_elevator_repair_cost))
	_apply_run_config_from_manager()

	_map.load_from_dictionary(data.get("map", {}))
	var travel: Dictionary = data.get("travel", {})
	_mode = int(travel.get("mode", TravelMode.DRIVE))
	_fuel = float(travel.get("fuel", fuel_max))
	_inventory = int(travel.get("inventory", 0))
	_current_node_index = int(travel.get("current_node_index", -1))
	_previous_node_index = int(travel.get("previous_node_index", -1))
	_arrived_from_index = int(travel.get("arrived_from_index", -1))
	_segment_from_index = int(travel.get("segment_from_index", -1))
	_segment_target_index = int(travel.get("segment_target_index", -1))
	_segment_progress = float(travel.get("segment_progress", 0.0))
	_segment_length = float(travel.get("segment_length", 1.0))
	_drive_travel_distance = float(travel.get("drive_travel_distance", 0.0))
	_current_district_index = int(travel.get("current_district_index", -1))

	var layer: Dictionary = data.get("layer", {})
	_current_layer = int(layer.get("current_layer", 1))
	_elevator_repair_progress = int(layer.get("elevator_repair_progress", 0))
	_run_completed = bool(layer.get("run_completed", false))

	if is_instance_valid(time_system):
		time_system.load_from_dictionary(data.get("time", {}))

	_spawn_resources()
	_refresh_resource_pickups()
	if is_instance_valid(minimap_view):
		minimap_view.set_world_map(_map)

	if _mode == TravelMode.FOOT:
		_restore_foot_mode_from_save(data.get("foot", {}))
	else:
		if is_instance_valid(_player):
			_player.set_active(false)
		if is_instance_valid(_vehicle):
			_vehicle.set_active(true)
		_restore_drive_state_after_load()

	_restore_time_phase_after_load()
	_sync_minimap_navigation()
	_refresh_ui()
	queue_redraw()


func _restore_foot_mode_from_save(foot: Dictionary) -> void:
	if _current_district_index < 0:
		_mode = TravelMode.DRIVE
		_restore_drive_state_after_load()
		return
	if is_instance_valid(_vehicle):
		_vehicle.set_active(false)
	if is_instance_valid(_player):
		_player.set_active(true)
		_player.world_bounds = _map.cell_rect(_current_district_index)
		_player.global_position = Vector2(float(foot.get("player_x", 0.0)), float(foot.get("player_y", 0.0)))
		_player.global_position = _clamp_to_cell(_player.global_position, _current_district_index)
	for node in _resource_nodes:
		if is_instance_valid(node):
			node.visible = int(node.get_meta("district_index", -1)) == _current_district_index


func _restore_drive_state_after_load() -> void:
	if _segment_target_index >= 0 and _map.is_valid_index(_segment_from_index) and _map.is_valid_index(_segment_target_index):
		_mode = TravelMode.DRIVE
		_segment_length = maxf(
			_map.cell_center(_segment_from_index).distance_to(_map.cell_center(_segment_target_index)),
			1.0
		)
		if is_instance_valid(_vehicle):
			_vehicle.set_active(true)
			_update_vehicle_transform()
		for node in _resource_nodes:
			if is_instance_valid(node):
				node.visible = false
	elif _map.is_valid_index(_current_node_index):
		_halt_at_node(_current_node_index)
	else:
		_exit_options.clear()


func _restore_time_phase_after_load() -> void:
	if not is_instance_valid(time_system):
		return
	match time_system.phase:
		TimeSystem.Phase.NIGHT_SETUP:
			_force_return_to_vehicle_for_night()
			if is_instance_valid(night_defense):
				night_defense.start_td_session(_inventory, GameManager.difficulty, time_system.day_index)
			time_system.pause()
		TimeSystem.Phase.NIGHT_RESOLVE:
			time_system.finish_night_and_advance_day()
		TimeSystem.Phase.EVENING:
			time_system.resume()
			if is_instance_valid(evening_notice) and evening_notice.has_method("show_evening_warning"):
				evening_notice.show_evening_warning(time_system.get_day_remaining_sec())
		_:
			time_system.resume()
			if is_instance_valid(evening_notice):
				evening_notice.hide_notice()


func _refresh_resource_pickups() -> void:
	for node in _resource_nodes:
		if not is_instance_valid(node) or not node.has_meta("district_index"):
			continue
		var district_index := int(node.get_meta("district_index"))
		var remaining := _map.sector_resource_remaining(district_index)
		node.visible = _mode == TravelMode.FOOT and district_index == _current_district_index and remaining > 0


func _save_and_exit_to_menu() -> void:
	if SaveManager.save_game(capture_save_data()):
		_game_paused = false
		GameManager.go_to_main_menu()


func _confirm_return_to_menu() -> void:
	if _pause_confirm != null:
		_pause_confirm.popup_centered()
	else:
		_return_to_menu_without_save()


func _return_to_menu_without_save() -> void:
	_game_paused = false
	GameManager.go_to_main_menu()


func _setup_day_night() -> void:
	if is_instance_valid(time_hud) and time_hud.has_method("bind_time_system"):
		time_hud.bind_time_system(time_system)
	if is_instance_valid(night_td):
		night_defense.bind_td_controller(night_td)
	if is_instance_valid(night_defense):
		night_defense.session_finished.connect(_on_night_td_finished)
	if is_instance_valid(time_system):
		time_system.evening_warning_triggered.connect(_on_evening_warning)
		time_system.night_setup_started.connect(_on_night_setup_started)
		time_system.day_started.connect(_on_day_started)
		time_system.phase_changed.connect(_on_time_phase_changed)
	if is_instance_valid(evening_notice):
		evening_notice.hide_notice()


func is_user_paused() -> bool:
	return _game_paused


func _is_night_phase() -> bool:
	return is_instance_valid(time_system) and (
		time_system.phase == TimeSystem.Phase.NIGHT_SETUP
		or time_system.phase == TimeSystem.Phase.NIGHT_RESOLVE
	)


func _is_exploration_allowed() -> bool:
	return is_instance_valid(time_system) and time_system.is_exploration_allowed()


func _update_evening_tint(delta: float) -> void:
	if not is_instance_valid(time_system):
		_evening_tint = 0.0
		return
	var target := 0.0
	if time_system.phase == TimeSystem.Phase.EVENING:
		target = 0.45
	elif _is_night_phase():
		target = 0.72
	_evening_tint = move_toward(_evening_tint, target, delta * 0.8)


func _on_evening_warning(remaining_sec: float) -> void:
	if is_instance_valid(evening_notice) and evening_notice.has_method("show_evening_warning"):
		evening_notice.show_evening_warning(remaining_sec)


func _on_night_setup_started(day_index: int) -> void:
	_force_return_to_vehicle_for_night()
	if is_instance_valid(time_system):
		time_system.pause()
	if is_instance_valid(evening_notice) and evening_notice.has_method("hide_notice"):
		evening_notice.hide_notice()
	if is_instance_valid(night_defense):
		night_defense.start_td_session(_inventory, GameManager.difficulty, day_index)
	_refresh_ui()


func _on_night_td_finished(result: Dictionary) -> void:
	if is_instance_valid(night_defense):
		night_defense.hide_td_session()
	_apply_night_result(result)
	if is_instance_valid(time_system):
		# 塔防界面已展示结算，直接进下一天（避免 pause 导致 NIGHT_RESOLVE 永不结束）
		time_system.finish_night_and_advance_day()


func _apply_night_result(result: Dictionary) -> void:
	if result.has("inventory_remaining"):
		_inventory = int(result.get("inventory_remaining", _inventory))
	var loss := int(result.get("inventory_loss", 0))
	_inventory = maxi(_inventory - loss, 0)
	_fuel = maxf(_fuel - float(result.get("fuel_loss", 0.0)), 0.0)


func _on_day_started(_day_index: int) -> void:
	if is_instance_valid(evening_notice) and evening_notice.has_method("hide_notice"):
		evening_notice.hide_notice()
	if is_instance_valid(time_system):
		time_system.resume()
	if is_instance_valid(night_defense):
		night_defense.hide_td_session()
	_refresh_ui()


func _on_time_phase_changed(_old_phase: int, new_phase: int) -> void:
	if new_phase == TimeSystem.Phase.DAY and is_instance_valid(evening_notice):
		evening_notice.hide_notice()
	_refresh_ui()


func _force_return_to_vehicle_for_night() -> void:
	_saved_travel_mode = _mode
	if _mode == TravelMode.FOOT:
		_return_to_vehicle()
	_mode = TravelMode.DRIVE
	_segment_target_index = -1
	if is_instance_valid(_player):
		_player.set_active(false)
	if is_instance_valid(_vehicle):
		_vehicle.set_active(true)
		_vehicle.global_position = _map.cell_center(maxi(_current_district_index, maxi(_current_node_index, 0)))
	for node in _resource_nodes:
		if is_instance_valid(node):
			node.visible = false


func _refresh_ui() -> void:
	var in_td := is_instance_valid(night_td) and night_td.visible
	if has_node("HUD/InfoPanel"):
		$HUD/InfoPanel.visible = not in_td
	if has_node("HUD/MapPanel"):
		$HUD/MapPanel.visible = not in_td
	if has_node("HUD/ActionPanel"):
		$HUD/ActionPanel.visible = not in_td
	if has_node("HUD/TimePanel"):
		$HUD/TimePanel.visible = not in_td
	if is_instance_valid(mode_label):
		if _is_night_phase():
			mode_label.text = "状态: %s" % time_system.get_phase_name()
		else:
			var phase_hint := ""
			if is_instance_valid(time_system) and time_system.phase == TimeSystem.Phase.EVENING:
				phase_hint = "（傍晚·请回车设防）"
			mode_label.text = "状态: %s%s" % ["驾驶车辆" if _mode != TravelMode.FOOT else "步行探索", phase_hint]
	if is_instance_valid(fuel_label):
		fuel_label.text = "燃料: %.1f / %.1f" % [_fuel, fuel_max]
	if is_instance_valid(inventory_label):
		inventory_label.text = "已搬运资源: %d" % _inventory

	var district_text := ""
	if _current_district_index >= 0 and _map.is_valid_index(_current_district_index):
		district_text = " | %s" % _map.building_label(_current_district_index)
	if is_instance_valid(status_label):
		var layer_text := "第 %d / %d 层" % [_current_layer, total_layers]
		var elevator_text := "电梯进度: %d / %d" % [_elevator_repair_progress, _current_repair_cost()]
		var run_text := "%s · %s" % [_run_difficulty_name, _run_squad_name]
		var day_text := ""
		if is_instance_valid(time_system):
			day_text = " | %s 第%d天" % [time_system.get_phase_name(), time_system.day_index]
		status_label.text = "%s | %s | %s%s | 探索: %d / %d | 剩余资源: %d%s" % [run_text, layer_text, elevator_text, day_text, _map.explored_count(), _map.cells.size(), _map.total_resources_remaining(), district_text]
	if is_instance_valid(map_info_label):
		map_info_label.text = "地图：↑北 ↓南 ←西 →东 | 蓝=南北路 黄=东西路 | 绿箭头=可走"
	_sync_minimap_navigation()

	if is_instance_valid(prompt_label):
		_update_prompts()

func _update_prompts() -> void:
	var can_stop := _can_disembark()
	var in_foot := _mode == TravelMode.FOOT
	var waiting_turn := _mode == TravelMode.DRIVE and _segment_target_index < 0
	prompt_label.text = ""
	disembark_button.visible = false
	return_button.visible = false
	repair_button.visible = false
	if is_instance_valid(back_track_button):
		back_track_button.visible = false

	if _is_night_phase():
		if is_instance_valid(night_td) and night_td.visible:
			prompt_label.text = "夜晚塔防：俯视图布防 → 接敌交互 → 结算（白天探索已暂停）"
		else:
			prompt_label.text = "夜晚结算中…"
		return
	if is_instance_valid(time_system) and time_system.phase == TimeSystem.Phase.EVENING:
		prompt_label.text = "傍晚提醒：请尽快返回车辆，入夜后需布置防线"
		if can_stop and _mode == TravelMode.DRIVE:
			disembark_button.visible = true
		elif in_foot:
			return_button.visible = true
		return

	if waiting_turn:
		var hint := _halt_prompt_text()
		prompt_label.text = hint
		var back_index := _get_back_neighbor_index()
		if is_instance_valid(back_track_button) and back_index >= 0:
			var back_dir := _map.direction_between(_current_node_index, back_index)
			back_track_button.visible = true
			back_track_button.text = "原路返回 %s (E)" % _direction_label(back_dir)
	elif in_foot:
		if _run_completed:
			prompt_label.text = "已完成 %d 层试作流程，可继续探索或返回车辆" % total_layers
		elif _can_repair_elevator():
			prompt_label.text = "电梯楼：消耗资源修复电梯，进度满后进入上层"
			repair_button.visible = true
		else:
			prompt_label.text = "步行探索：收集资源后按返回车辆"
		return_button.visible = true
	elif can_stop:
		prompt_label.text = "建筑群：可以下车探索"
		disembark_button.visible = true
	else:
		if _segment_target_index >= 0:
			var axis := _map.get_segment_axis(_segment_from_index, _segment_target_index)
			if axis == "ns":
				prompt_label.text = "南北路段：↑ 前进  ↓ 后退（←→ 无效）"
			elif axis == "ew":
				prompt_label.text = "东西路段：→ 前进  ← 后退（↑↓ 无效）"
			else:
				prompt_label.text = "沿当前路段用方向键前进/后退"
		else:
			prompt_label.text = "查看地图，在岔口用方向键选路（↑北 ↓南 ←西 →东）"

func _halt_prompt_text() -> String:
	var parts: PackedStringArray = []
	for direction in ["up", "down", "left", "right"]:
		if _exit_options.has(direction):
			parts.append(_direction_label(direction))
	var exits := "、".join(parts) if not parts.is_empty() else "无"
	return "岔口选路（方向键，与地图一致）：%s" % exits

func _exit_directions_array() -> Array[String]:
	var result: Array[String] = []
	for direction in _exit_options.keys():
		result.append(str(direction))
	return result

func _sync_minimap_navigation() -> void:
	if not is_instance_valid(minimap_view):
		return
	var segment_axis := ""
	if _segment_target_index >= 0 and _map.is_valid_index(_segment_from_index):
		segment_axis = _map.get_segment_axis(_segment_from_index, _segment_target_index)
	var node_index := _current_node_index
	if _segment_target_index >= 0:
		node_index = _segment_from_index
	var hints: Array[String] = []
	if _segment_target_index < 0:
		hints = _exit_directions_array()
	minimap_view.set_navigation_hints(node_index, hints, segment_axis)

func _vehicle_world_position() -> Vector2:
	if _segment_target_index >= 0 and _map.is_valid_index(_segment_from_index) and _map.is_valid_index(_segment_target_index):
		var from_pos := _map.cell_center(_segment_from_index)
		var to_pos := _map.cell_center(_segment_target_index)
		return from_pos.lerp(to_pos, clampf(_segment_progress, 0.0, 1.0))
	if _current_node_index >= 0:
		return _map.cell_center(_current_node_index)
	return Vector2.ZERO

func _world_view_transform() -> Transform2D:
	var view_size := get_viewport_rect().size
	if view_size == Vector2.ZERO:
		view_size = Vector2(1280.0, 720.0)
	var world_size := _map.get_world_size()
	var focus := _vehicle_world_position()
	var padding := 0.88
	var scale := minf(view_size.x / maxf(world_size.x, 1.0), view_size.y / maxf(world_size.y, 1.0)) * padding
	var origin := view_size * 0.5 - focus * scale
	return Transform2D(Vector2(scale, 0.0), Vector2(0.0, scale), origin)

func _update_vehicle_transform() -> void:
	if not is_instance_valid(_vehicle):
		return
	if _segment_target_index < 0:
		_drive_offset = Vector2(_drive_travel_distance, 0.0)
		_vehicle.global_position = _map.cell_center(maxi(_current_node_index, 0))
		return
	_drive_offset = Vector2(_drive_travel_distance + _segment_progress * _segment_length, 0.0)
	_vehicle.global_position = _map.cell_center(maxi(_current_node_index, 0))

func _direction_label(direction: String) -> String:
	match direction:
		"up":
			return "↑北"
		"down":
			return "↓南"
		"left":
			return "←西"
		"right":
			return "→东"
		_:
			return direction


func _clamp_to_cell(position: Vector2, district_index: int) -> Vector2:
	if not _map.is_valid_index(district_index):
		return position
	var rect := _map.cell_rect(district_index)
	return Vector2(clampf(position.x, rect.position.x + 18.0, rect.end.x - 18.0), clampf(position.y, rect.position.y + 18.0, rect.end.y - 18.0))

func _draw() -> void:
	if _is_night_phase() and (not is_instance_valid(night_td) or not night_td.visible):
		_draw_night_camp_background()
		return
	if is_instance_valid(night_td) and night_td.visible:
		return
	match _mode:
		TravelMode.DRIVE:
			if _segment_target_index >= 0:
				_draw_drive_background()
			else:
				_draw_world_map_background()
		TravelMode.FOOT:
			_draw_foot_background()
	if _evening_tint > 0.001:
		var view_size := get_viewport_rect().size
		if view_size == Vector2.ZERO:
			view_size = Vector2(1280.0, 720.0)
		draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.05, 0.08, 0.18, _evening_tint), true)

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
	var sun_color := Color("#f0c168")
	if is_instance_valid(time_system) and time_system.phase == TimeSystem.Phase.EVENING:
		sun_color = Color("#e87840")
	draw_circle(Vector2(sun_x, sun_y), 42.0, sun_color)

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

	var axis := _map.get_segment_axis(_segment_from_index, _segment_target_index)
	if axis == "ns":
		draw_string(ThemeDB.fallback_font, Vector2(left + 16.0, top + 16.0), "南北路段：↑ 前进  ↓ 后退", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9ec9ff"))
	elif axis == "ew":
		draw_string(ThemeDB.fallback_font, Vector2(left + 16.0, top + 16.0), "东西路段：→ 前进  ← 后退", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f0d080"))

func _drive_view_anchor() -> Vector2:
	if is_instance_valid(_vehicle):
		return _vehicle.global_position
	if _current_node_index >= 0:
		return _map.cell_center(_current_node_index)
	return Vector2.ZERO

func _draw_world_map_background() -> void:
	var view_size := get_viewport_rect().size
	if view_size == Vector2.ZERO:
		view_size = Vector2(1280.0, 720.0)
	draw_rect(Rect2(Vector2.ZERO, view_size), Color("#060a10"), true)

	var xform := _world_view_transform()
	for index in range(_map.cells.size()):
		var cell := _map.get_cell(index)
		if str(cell["kind"]) == "empty":
			continue
		var rect := _map.cell_rect(index)
		var screen_rect := xform * rect
		var explored := bool(cell["explored"])
		var kind := str(cell["kind"])
		var fill := Color("#151b24")
		if explored:
			match kind:
				"district":
					fill = Color("#5f7a4c")
				"hub":
					fill = Color("#4f6472")
				"junction":
					fill = Color("#4a6278")
				_:
					fill = Color("#2f3a46")
		draw_rect(screen_rect, fill, true)
		draw_rect(screen_rect, Color("#3d5168") if explored else Color("#1e2834"), false, 2.0)

	for index in range(_map.cells.size()):
		if not bool(_map.get_cell(index)["explored"]):
			continue
		var center := xform * _map.cell_center(index)
		for direction in _map.get_available_directions(index):
			var other := _map.get_neighbor_index(index, direction)
			if other < 0 or other < index:
				continue
			var other_center := xform * _map.cell_center(other)
			var is_ns := direction == "up" or direction == "down"
			var road_color := Color("#6eb5e8") if is_ns else Color("#e8c66e")
			draw_line(center, other_center, road_color, 7.0 if is_ns else 5.0)

	if _map.is_valid_index(_current_node_index):
		var node_center := xform * _map.cell_center(_current_node_index)
		var node_rect := xform * _map.cell_rect(_current_node_index)
		draw_rect(node_rect, Color("#ff5f57", 0.15), true)
		draw_rect(node_rect, Color("#ff8b7a"), false, 3.0)
		for direction in _exit_options.keys():
			var tip := node_center
			var arm := minf(node_rect.size.x, node_rect.size.y) * 0.34
			match str(direction):
				"up":
					tip += Vector2(0.0, -arm)
				"down":
					tip += Vector2(0.0, arm)
				"left":
					tip += Vector2(-arm, 0.0)
				"right":
					tip += Vector2(arm, 0.0)
			draw_line(node_center, tip, Color("#7dffb2"), 5.0)
			draw_circle(tip, 5.0, Color("#ffffff"))
		draw_circle(node_center, 10.0, Color("#ff5f57"))
		draw_rect(Rect2(node_center.x - 14.0, node_center.y - 8.0, 28.0, 16.0), Color("#d89246"), true)

	var north_base := Vector2(view_size.x - 52.0, 28.0)
	draw_line(north_base, north_base + Vector2(0.0, 18.0), Color("#9ec9ff"), 3.0)
	draw_string(ThemeDB.fallback_font, north_base + Vector2(-5.0, -6.0), "北", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#9ec9ff"))
	draw_string(ThemeDB.fallback_font, Vector2(16.0, view_size.y - 12.0), "蓝=南北路  黄=东西路  绿箭头=可选方向", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#b8c7d8"))

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

func _draw_night_camp_background() -> void:
	var view_size := get_viewport_rect().size
	if view_size == Vector2.ZERO:
		view_size = Vector2(1280.0, 720.0)
	draw_rect(Rect2(Vector2.ZERO, view_size), Color("#050810"), true)
	var camp_center := Vector2(view_size.x * 0.5, view_size.y * 0.62)
	if is_instance_valid(_vehicle):
		camp_center = _vehicle.global_position + Vector2(0.0, 40.0)
	draw_rect(Rect2(camp_center.x - 120.0, camp_center.y - 20.0, 240.0, 80.0), Color("#1a2533"), true)
	draw_rect(Rect2(camp_center.x - 90.0, camp_center.y - 50.0, 180.0, 36.0), Color("#d89246"), true)
	draw_circle(Vector2(camp_center.x - 140.0, camp_center.y + 10.0), 8.0, Color("#6ed08b"))
	draw_circle(Vector2(camp_center.x + 140.0, camp_center.y + 10.0), 8.0, Color("#6ed08b"))
	for i in range(12):
		var star_x := float(i * 97 % int(view_size.x))
		var star_y := 40.0 + float(i * 53 % int(view_size.y * 0.35))
		draw_circle(Vector2(star_x, star_y), 1.5, Color(0.7, 0.75, 0.9, 0.35))


func _generate_layer_map() -> void:
	_map.generate(map_columns, map_rows, cell_size)
	_elevator_repair_progress = 0
	_current_district_index = -1

func _advance_layer() -> void:
	if _current_layer >= total_layers:
		_run_completed = true
		return
	_current_layer += 1
	_mode = TravelMode.DRIVE
	_segment_target_index = -1
	_exit_options.clear()
	_generate_layer_map()
	if is_instance_valid(_player):
		_player.set_active(false)
	if is_instance_valid(minimap_view):
		minimap_view.set_world_map(_map)
	_spawn_resources()
	if _map.start_node_index >= 0:
		_enter_node(_map.start_node_index, true)
