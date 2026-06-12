extends Node2D

const RunEndOverlayScript = preload("res://scripts/ui/run_end_overlay.gd")
const CommunicationTerminalScript = preload("res://scripts/ui/communication_terminal.gd")
const EndingOutcomeOverlayScript = preload("res://scripts/ui/ending_outcome_overlay.gd")
const StartGuideOverlayScript = preload("res://scripts/ui/start_guide_overlay.gd")
const DayTopdownRender = preload("res://scripts/day_topdown_render.gd")
const RunStateClass = preload("res://scripts/run_state.gd")
const NpcDialogueRunnerScript = preload("res://scripts/story/npc_dialogue_runner.gd")
const StoryDialogueUIScene = preload("res://scenes/ui/story_dialogue_ui.tscn")
const FUEL_EMPTY_EPSILON := 0.001
const THUNDER_LEITING_WAVE_PATH := "res://data/night_td/waves/night_wave_thunder_leiting.json"
var _building_pick_index: int = 0
var _foot_local_pos: Vector2 = Vector2.ZERO
var _foot_move_dir: Vector2 = Vector2.UP
var _foot_walk_phase: float = 0.0
var _foot_is_walking: bool = false

enum TravelMode { DRIVE, FOOT }

@export var vehicle_scene: PackedScene
@export var player_scene: PackedScene
@export var resource_scene: PackedScene
@export var map_columns: int = 24
@export var map_rows: int = 18
@export var cell_size: Vector2i = Vector2i(720, 720)
@export var interior_tile_scale: float = 2.15
@export var road_render_settings: RoadRenderSettings
@export var enable_road_tuning_panel: bool = true
@export var world_camera_zoom: float = 0.88
@export var world_camera_smoothing: float = 10.0

var _world_camera: Camera2D
@export var fuel_max: float = 999.0
@export var fuel_per_pixel: float = 0.01
@export var drive_speed: float = 1920.0
@export var total_layers: int = 3
@export var base_elevator_repair_cost: int = 3
@export var war_fog_enabled: bool = true
@export var debug_start_at_story: bool = true
@export var debug_start_near_special: bool = true

var _map: WorldMapData = WorldMapData.new()
var _mode: int = TravelMode.DRIVE
var _vehicle: VehicleUnit
var _player: PlayerCharacter
var _resource_nodes: Array[Area2D] = []
var _fuel: float = 0.0
var _vehicle_hp: float = 100.0
var _vehicle_hp_max: float = 100.0
var _backpack: InventoryData = InventoryData.new()
var _run_journal: RunJournal = RunJournal.new()
var _survival: PlayerSurvival = PlayerSurvival.new()
var _backpack_ui: BackpackUI
var _backpack_open := false
var _story_controller: StoryController
var _story_reward_rows: Array[Button] = []
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
var _vehicle_facing: Vector2 = Vector2.RIGHT
var _last_overworld_draw_cam: Vector2 = Vector2(-99999.0, -99999.0)
var _overworld_dirty: bool = true
var _last_draw_evening_tint: float = -1.0
var _last_foot_draw_pos: Vector2 = Vector2(-99999.0, -99999.0)
var _last_foot_walk_phase_draw: float = -999.0
var _foot_ui_accum: float = 0.0
var _drive_ui_accum: float = 0.0
const UI_REFRESH_INTERVAL := 0.16
var _ui_refresh_scheduled := false
var _last_pda_entries_sig := ""
var _foot_layout_cache: Dictionary = {}
var _world_map_overlay: WorldMapOverlay
var _drive_exit_locked: bool = false  ## 到岔口后须先松开方向键，再按一次才选路
var _current_layer: int = 1
var _elevator_repair_progress: int = 0
var _run_ended := false
var _run_end_reason := ""
var _final_choice_id := ""
var _final_defense_cleared := false
var _thunder_leiting_defeated := false
var _thunder_terminal_sequence_active := false
# 防御塔强化（Part B）：故事奖励道具安装后累加的乘法系数。随存档/昼夜流转。
var _tower_upgrades: Dictionary = NightTdUpgrades.default_state()
var _pending_thunder_district := -1
var _run_end_overlay: CanvasLayer
var _communication_terminal: CanvasLayer
var _ending_outcome_overlay: CanvasLayer
var _start_guide_overlay: CanvasLayer
var _base_fuel_max: float = 999.0
var _base_elevator_repair_cost: int = 3
var _run_difficulty_name: String = "普通"
var _run_squad_name: String = "拾荒者"
var _saved_travel_mode: int = TravelMode.DRIVE
var _evening_tint: float = 0.0
var _last_night_losses: Array[String] = []
var _last_night_salvage: String = ""
var _game_paused := false
var _pause_layer: CanvasLayer
var _pause_panel: PanelContainer
var _pause_confirm: ConfirmationDialog
var _fuel_empty_dialog: AcceptDialog
var _tower_upgrade_dialog: AcceptDialog
var _night_tutorial: NightTutorialOverlay
var _fuel_empty_prompt_open := false
var _war_fog_checkbox: CheckBox
var _repair_choice_panel: PanelContainer
var _repair_progress_label: Label
var _repair_progress_bar: ProgressBar
var _repair_hint_label: Label
var _repair_parts_btn: Button
var _repair_scrap_btn: Button
var _repair_wood_scrap_btn: Button
var _pda_panel: PdaHudPanel

@onready var time_system: TimeSystem = $Systems/TimeSystem
@onready var night_defense: NightDefenseSystem = $Systems/NightDefenseSystem
@onready var time_hud: Control = $HUD/TimePanel/MarginContainer/TimeHud
@onready var evening_notice: PanelContainer = $HUD/EveningNotice
@onready var low_stamina_warning: PanelContainer = $HUD/LowStaminaWarning
var night_td: NightTdController = null  # 由子场景决定是否存在（main.tscn 有，day_exploration.tscn 无）
@onready var fuel_label: Label = $HUD/InfoPanel/MarginContainer/VBoxContainer/FuelLabel
@onready var inventory_label: Label = $HUD/InfoPanel/MarginContainer/VBoxContainer/InventoryLabel
@onready var vitals_label: Label = $HUD/InfoPanel/MarginContainer/VBoxContainer/VitalsLabel

var _vitals_top_bar: PanelContainer
var _fuel_bar: ProgressBar
var _vehicle_hp_bar: ProgressBar
var _stamina_bar: ProgressBar
var _fuel_bar_label: Label
var _vehicle_hp_bar_label: Label
var _stamina_bar_label: Label
var _night_result_applied := false
@onready var backpack_button: Button = $HUD/InfoPanel/MarginContainer/VBoxContainer/BackpackButton
@onready var status_label: Label = $HUD/InfoPanel/MarginContainer/VBoxContainer/StatusLabel
@onready var minimap_view: MinimapView = $HUD/MapPanel/MarginContainer/VBoxContainer/MinimapView
@onready var map_info_label: Label = $HUD/MapPanel/MarginContainer/VBoxContainer/MapInfoLabel
@onready var prompt_label: Label = $HUD/ActionPanel/MarginContainer/VBoxContainer/PromptLabel
@onready var story_choice_buttons: VBoxContainer = $HUD/ActionPanel/MarginContainer/VBoxContainer/StoryChoiceButtons
@onready var story_accept_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/StoryChoiceButtons/StoryAcceptButton
@onready var story_decline_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/StoryChoiceButtons/StoryDeclineButton
@onready var story_reward_buttons: VBoxContainer = $HUD/ActionPanel/MarginContainer/VBoxContainer/StoryRewardButtons
@onready var disembark_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/ActionButtons/DisembarkButton
@onready var return_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/ActionButtons/ReturnButton
@onready var repair_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/ActionButtons/RepairButton
@onready var up_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/JunctionButtons/UpButton
@onready var down_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/JunctionButtons/DownButton
@onready var left_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/JunctionButtons/LeftButton
@onready var right_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/JunctionButtons/RightButton
@onready var back_track_button: Button = $HUD/ActionPanel/MarginContainer/VBoxContainer/ActionButtons/BackTrackButton
@onready var _action_panel_vbox: VBoxContainer = $HUD/ActionPanel/MarginContainer/VBoxContainer
@onready var action_buttons_row: HBoxContainer = $HUD/ActionPanel/MarginContainer/VBoxContainer/ActionButtons

var _last_dialogue_options_key: String = ""
var _story_dialogue_ui: StoryDialogueUI
var _story_choice_overlay_key: String = ""
var _clone_restart_overlay: CanvasLayer

func _ready() -> void:
	night_td = get_node_or_null("NightTd") as NightTdController  # 主场景有，子场景可能无
	_base_fuel_max = fuel_max
	_base_elevator_repair_cost = base_elevator_repair_cost
	_apply_run_config_from_manager()
	if road_render_settings == null:
		road_render_settings = RoadRenderSettings.new()
	DayTopdownRender.apply_settings(road_render_settings)
	if not _run_bootstrap_textures_ready():
		DayTopdownRender.reload_road_textures()
		DayTopdownRender.reload_prop_textures()
		DayTopdownRender.preload_wilderness_noise()
		DayTopdownRender.preload_interior_textures()
	if enable_road_tuning_panel:
		_setup_road_tuning_panel()
	_ensure_input_actions()
	_connect_buttons()
	_setup_pause_ui()
	_setup_backpack_ui()
	_setup_fuel_empty_dialog()
	_setup_story_controller()
	_setup_run_end_ui()
	_setup_stat_bars()
	_setup_world_camera()
	_setup_minimap_hud()
	_setup_world_map_overlay()
	_setup_hud_theme()
	_setup_repair_choice_popup()
	_spawn_vehicle()
	_spawn_player()
	_setup_day_night()
	if GameManager.consume_load_save_request():
		var save_data: Dictionary = SaveManager.load_game()
		if save_data.is_empty():
			_start_new_run()
		else:
			_apply_save_data(save_data)
	else:
		_start_new_run()
	_sync_view_cameras()
	_sync_day_entity_visibility()
	_refresh_ui()
	queue_redraw()
	if GameManager.should_dismiss_enter_overlay():
		call_deferred("_dismiss_enter_overlay")


func _dismiss_enter_overlay() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if GameManager.should_dismiss_enter_overlay():
		await GameManager.dismiss_enter_overlay()


func _setup_road_tuning_panel() -> void:
	var panel := RoadTuningPanel.new()
	panel.setup(road_render_settings, self)
	add_child(panel)


func _setup_hud_theme() -> void:
	var hud: CanvasLayer = get_node_or_null("HUD") as CanvasLayer
	if hud == null:
		return
	HudTheme.layout_hud(hud)
	if is_instance_valid(_vitals_top_bar):
		HudTheme.apply_vitals_bar(_vitals_top_bar)
	_setup_pda_hud()


func _setup_story_choice_overlay() -> void:
	if is_instance_valid(_story_dialogue_ui):
		return
	_story_dialogue_ui = StoryDialogueUIScene.instantiate() as StoryDialogueUI
	_story_dialogue_ui.name = "StoryDialogueUI"
	add_child(_story_dialogue_ui)
	_story_dialogue_ui.choice_pressed.connect(_on_story_dialogue_choice_pressed)
	_story_dialogue_ui.advance_requested.connect(_on_story_dialogue_advance_requested)
	_story_dialogue_ui.hide_dialogue()


func _on_story_dialogue_advance_requested() -> void:
	_try_advance_story_dialogue()


func _try_story_e_action_overlay() -> bool:
	if _mode == TravelMode.DRIVE and _try_enter_interior_at_drive_gate():
		return true
	if not _is_story_dialogue_visible() or not is_instance_valid(_story_dialogue_ui):
		return false
	var key := _story_choice_overlay_key
	if _story_dialogue_ui.is_choice_mode():
		if key.begins_with("gate|") or key.begins_with("disembark|"):
			_confirm_story_action_overlay(0)
			return true
		return false
	if key.begins_with("disembark|") or key.begins_with("thunder|") or key.begins_with("foot_return|"):
		_confirm_story_action_overlay(0)
		return true
	return false


func _try_enter_interior_at_drive_gate() -> bool:
	if _mode != TravelMode.DRIVE or _segment_target_index >= 0 or _is_night_phase():
		return false
	if not is_instance_valid(_story_controller):
		return false
	var buildings := _get_enterable_buildings()
	if buildings.is_empty():
		return false
	var district_index := _selected_enterable_district()
	if district_index < 0:
		return false
	var story_id := _story_controller.story_id_of_district(district_index)
	if story_id == "" or not StoryData.is_interior_encounter(story_id):
		return false
	if _story_controller.is_thunder_blocking_district(district_index):
		return false
	if not _can_enter_district(district_index):
		return false
	_story_controller.suspend_interior_dialogue_for_drive(story_id)
	_hide_story_choice_overlay()
	_enter_selected_building()
	return true


func _confirm_story_action_overlay(index: int) -> void:
	_on_story_dialogue_choice_pressed(index)


func _try_advance_story_dialogue() -> bool:
	if _try_story_e_action_overlay():
		return true
	if not _is_story_dialogue_visible() or not is_instance_valid(_story_dialogue_ui):
		return false
	if _story_dialogue_ui.is_choice_mode():
		return false
	if _story_dialogue_ui.try_advance_page():
		return true
	if _mode == TravelMode.FOOT and is_instance_valid(_story_controller):
		var npc := _story_controller.npc_dialogue
		if npc != null and npc.is_active() and npc.phase == NpcDialogueRunnerScript.Phase.LINE:
			npc.advance_line()
			_refresh_ui()
			return true
	if _mode == TravelMode.DRIVE and is_instance_valid(_story_controller):
		if _story_controller.advance_active_drive_dialogue():
			_refresh_ui()
			return true
	return false


func _on_story_dialogue_choice_pressed(index: int) -> void:
	if not is_instance_valid(_story_controller):
		return
	if _story_choice_overlay_key.begins_with("gate|"):
		if index == 0:
			_on_story_accept_pressed()
		else:
			_on_story_decline_pressed()
	elif _story_choice_overlay_key.begins_with("disembark|"):
		if index == 0:
			_on_disembark_pressed()
		elif index == 1:
			_on_return_pressed()
	elif _story_choice_overlay_key.begins_with("reward|"):
		_on_story_reward_pressed(index)
	elif _story_choice_overlay_key.begins_with("thunder|"):
		_begin_or_continue_thunder_gate()
	elif _story_choice_overlay_key.begins_with("foot_return|"):
		_story_controller.try_interior_story_interact(_current_district_index, _foot_local_pos)
	else:
		_story_controller.choose_dialogue_option(index)
	_hide_story_choice_overlay()
	_schedule_refresh_ui()


func _begin_or_continue_thunder_gate() -> void:
	if not is_instance_valid(_story_controller):
		return
	var district_index := _selected_enterable_district()
	if not _story_controller.is_thunder_blocking_district(district_index):
		return
	_thunder_terminal_sequence_active = true
	_pause_day_night_for_terminal_sequence()
	_story_controller.begin_thunder_gate_encounter(district_index)


func _current_dialogue_speaker() -> String:
	if not is_instance_valid(_story_controller):
		return ""
	var npc := _story_controller.npc_dialogue
	if npc != null and npc.is_active() and npc.current_speaker.strip_edges() != "":
		return npc.current_speaker
	var story_id := _story_controller.story_id_at_node(_current_node_index)
	if story_id != "":
		return StoryData.title_of(story_id)
	return ""


func _is_story_dialogue_visible() -> bool:
	return is_instance_valid(_story_dialogue_ui) and _story_dialogue_ui.visible


func _setup_pda_hud() -> void:
	if not has_node("HUD/InfoPanel/MarginContainer/VBoxContainer"):
		return
	var vbox: VBoxContainer = $HUD/InfoPanel/MarginContainer/VBoxContainer
	for legacy in [fuel_label, inventory_label, vitals_label, status_label, backpack_button]:
		if is_instance_valid(legacy):
			legacy.visible = false
			legacy.text = ""
			legacy.queue_free()
	if is_instance_valid(_pda_panel):
		return
	_pda_panel = PdaHudPanel.new()
	_pda_panel.name = "PdaHudPanel"
	_pda_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_child(_pda_panel)
	_pda_panel.backpack_pressed.connect(_toggle_backpack)
	_pda_panel.item_use_requested.connect(_on_pda_use_item)


func _on_pda_use_item(item_id: String) -> void:
	if not _use_backpack_item(item_id):
		return
	_refresh_ui()


func _setup_minimap_hud() -> void:
	if not has_node("HUD/MapPanel"):
		return
	var panel: Panel = $HUD/MapPanel
	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	transparent.set_border_width_all(0)
	transparent.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", transparent)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.offset_left = -196.0
	panel.offset_top = -212.0
	panel.offset_right = -HudTheme.SAFE_MARGIN
	panel.offset_bottom = -HudTheme.SAFE_MARGIN
	if is_instance_valid(minimap_view):
		minimap_view.custom_minimum_size = Vector2(168, 168)
	if is_instance_valid(map_info_label):
		map_info_label.visible = false


func _setup_world_map_overlay() -> void:
	var hud: CanvasLayer = get_node_or_null("HUD") as CanvasLayer
	if hud == null:
		return
	_world_map_overlay = WorldMapOverlay.new()
	_world_map_overlay.name = "WorldMapOverlay"
	hud.add_child(_world_map_overlay)
	_world_map_overlay.hide()


func _toggle_world_map() -> void:
	if not is_instance_valid(_world_map_overlay):
		return
	if _world_map_overlay.is_open():
		_close_world_map()
	else:
		_open_world_map()


func _open_world_map() -> void:
	if not is_instance_valid(_world_map_overlay) or not _is_exploration_allowed():
		return
	if _is_night_phase():
		return
	_sync_minimap_navigation()
	var segment_axis := ""
	if _segment_target_index >= 0 and _map.is_valid_index(_segment_from_index):
		segment_axis = _map.get_segment_axis(_segment_from_index, _segment_target_index)
	var node_index := _current_node_index
	if _segment_target_index >= 0:
		node_index = _segment_from_index
	var hints: Array[String] = []
	if _segment_target_index < 0:
		hints = _exit_directions_array()
	_world_map_overlay.open(
		_map,
		war_fog_enabled,
		_current_focus_position(),
		node_index,
		hints,
		segment_axis,
	)


func _close_world_map() -> void:
	if is_instance_valid(_world_map_overlay):
		_world_map_overlay.close_overlay()


func _mark_overworld_dirty() -> void:
	_overworld_dirty = true


func _setup_repair_choice_popup() -> void:
	var hud: CanvasLayer = get_node_or_null("HUD") as CanvasLayer
	if hud == null:
		return

	_repair_choice_panel = PanelContainer.new()
	_repair_choice_panel.name = "RepairChoicePanel"
	_repair_choice_panel.visible = false
	_repair_choice_panel.z_index = 120
	_repair_choice_panel.set_anchors_preset(Control.PRESET_CENTER)
	_repair_choice_panel.offset_left = -172.0
	_repair_choice_panel.offset_right = 172.0
	_repair_choice_panel.offset_top = -156.0
	_repair_choice_panel.offset_bottom = 156.0
	_repair_choice_panel.add_theme_stylebox_override("panel", HudTheme.panel_style(0.94))
	hud.add_child(_repair_choice_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	_repair_choice_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "选择修复材料"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("#eef6ff"))
	HudTheme.apply_label(title)
	vbox.add_child(title)

	var label := Label.new()
	label.text = "请选择修复材料："
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("#c8d8e8"))
	HudTheme.apply_label(label)
	vbox.add_child(label)

	_repair_progress_label = Label.new()
	_repair_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_repair_progress_label.add_theme_font_size_override("font_size", 13)
	_repair_progress_label.add_theme_color_override("font_color", Color("#f0d878"))
	HudTheme.apply_label(_repair_progress_label)
	_repair_progress_label.text = "修复进度 0 / 0"
	vbox.add_child(_repair_progress_label)

	_repair_progress_bar = ProgressBar.new()
	_repair_progress_bar.custom_minimum_size = Vector2(0, 10)
	_repair_progress_bar.show_percentage = false
	_repair_progress_bar.max_value = 100.0
	HudTheme.apply_progress_bar(_repair_progress_bar, Color("#52a872"))
	vbox.add_child(_repair_progress_bar)

	_repair_hint_label = Label.new()
	_repair_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_repair_hint_label.custom_minimum_size = Vector2(0, 20)
	_repair_hint_label.add_theme_font_size_override("font_size", 13)
	_repair_hint_label.add_theme_color_override("font_color", Color("#8a9aaa"))
	HudTheme.apply_label(_repair_hint_label)
	_repair_hint_label.text = ""
	vbox.add_child(_repair_hint_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_repair_parts_btn = Button.new()
	_repair_parts_btn.text = "零件 ×%d" % ItemDefs.REPAIR_PARTS_EACH
	_repair_parts_btn.focus_mode = Control.FOCUS_NONE
	_repair_parts_btn.pressed.connect(_on_repair_option_pressed.bind("parts"))
	_repair_parts_btn.set_meta("repair_base_text", _repair_parts_btn.text)
	_style_repair_option_button(_repair_parts_btn)
	vbox.add_child(_repair_parts_btn)

	_repair_scrap_btn = Button.new()
	_repair_scrap_btn.text = "废料 ×%d" % ItemDefs.REPAIR_SCRAP_EACH
	_repair_scrap_btn.focus_mode = Control.FOCUS_NONE
	_repair_scrap_btn.pressed.connect(_on_repair_option_pressed.bind("scrap"))
	_repair_scrap_btn.set_meta("repair_base_text", _repair_scrap_btn.text)
	_style_repair_option_button(_repair_scrap_btn)
	vbox.add_child(_repair_scrap_btn)

	_repair_wood_scrap_btn = Button.new()
	_repair_wood_scrap_btn.text = "木材 ×%d + 废料 ×%d" % [ItemDefs.REPAIR_WOOD_EACH, ItemDefs.REPAIR_SCRAP_ALT_EACH]
	_repair_wood_scrap_btn.focus_mode = Control.FOCUS_NONE
	_repair_wood_scrap_btn.pressed.connect(_on_repair_option_pressed.bind("wood_scrap"))
	_repair_wood_scrap_btn.set_meta("repair_base_text", _repair_wood_scrap_btn.text)
	_style_repair_option_button(_repair_wood_scrap_btn)
	vbox.add_child(_repair_wood_scrap_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "关闭"
	cancel_btn.focus_mode = Control.FOCUS_NONE
	cancel_btn.pressed.connect(_close_repair_choice_popup)
	_style_repair_option_button(cancel_btn)
	vbox.add_child(cancel_btn)


func _style_repair_option_button(button: Button) -> void:
	HudTheme.apply_button(button)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.14, 0.20, 0.96)
	normal.border_color = Color(0.32, 0.44, 0.56, 0.65)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.14, 0.20, 0.28, 0.98)
	hover.border_color = Color("#8ec8e8", 0.75)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.08, 0.12, 0.18, 0.98)
	button.add_theme_stylebox_override("pressed", pressed)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.05, 0.07, 0.10, 0.82)
	disabled.border_color = Color(0.18, 0.22, 0.28, 0.35)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_disabled_color", Color(0.38, 0.42, 0.48, 0.62))
	button.set_meta("repair_style_normal", normal)
	button.set_meta("repair_style_hover", hover)
	button.set_meta("repair_style_pressed", pressed)
	button.set_meta("repair_style_dim", disabled)


func _set_repair_option_enabled(button: Button, enabled: bool) -> void:
	if button == null:
		return
	var base_text := str(button.get_meta("repair_base_text", button.text))
	button.text = base_text if enabled else "%s · 资源不足" % base_text
	button.disabled = false
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.set_meta("repair_enabled", enabled)
	var normal := button.get_meta("repair_style_normal") as StyleBoxFlat
	var hover := button.get_meta("repair_style_hover") as StyleBoxFlat
	var pressed := button.get_meta("repair_style_pressed") as StyleBoxFlat
	var dim := button.get_meta("repair_style_dim") as StyleBoxFlat
	if enabled and normal != null and hover != null and pressed != null:
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_color_override("font_color", Color("#e6eef6"))
	elif dim != null:
		button.add_theme_stylebox_override("normal", dim)
		button.add_theme_stylebox_override("hover", dim)
		button.add_theme_stylebox_override("pressed", dim)
		button.add_theme_color_override("font_color", Color(0.42, 0.46, 0.52, 0.78))


func _has_repair_material(material: String) -> bool:
	match material:
		"parts":
			return _backpack.has("parts", ItemDefs.REPAIR_PARTS_EACH)
		"scrap":
			return _backpack.has("scrap", ItemDefs.REPAIR_SCRAP_EACH)
		"wood_scrap":
			return _backpack.has("wood", ItemDefs.REPAIR_WOOD_EACH) and _backpack.has("scrap", ItemDefs.REPAIR_SCRAP_ALT_EACH)
	return false


func _show_repair_choicf_hint(text: String, warning: bool = true) -> void:
	if not is_instance_valid(_repair_hint_label):
		return
	if text.is_empty():
		_repair_hint_label.text = ""
		_repair_hint_label.add_theme_color_override("font_color", Color("#8a9aaa"))
		return
	_repair_hint_label.text = text
	_repair_hint_label.add_theme_color_override("font_color", Color("#ff7070") if warning else Color("#7ed08b"))


func _close_repair_choice_popup() -> void:
	if is_instance_valid(_repair_choice_panel):
		_repair_choice_panel.visible = false
	_show_repair_choicf_hint("")


func _refresh_repair_choice_popup(status_text: String = "", status_warning: bool = true) -> void:
	if not is_instance_valid(_repair_choice_panel):
		return
	var total := _current_repair_cost()
	if is_instance_valid(_repair_progress_label):
		_repair_progress_label.text = "修复进度 %d / %d" % [_elevator_repair_progress, total]
	if is_instance_valid(_repair_progress_bar):
		_repair_progress_bar.max_value = float(maxi(total, 1))
		_repair_progress_bar.value = float(_elevator_repair_progress)
	_set_repair_option_enabled(_repair_parts_btn, _backpack.has("parts", ItemDefs.REPAIR_PARTS_EACH))
	_set_repair_option_enabled(_repair_scrap_btn, _backpack.has("scrap", ItemDefs.REPAIR_SCRAP_EACH))
	_set_repair_option_enabled(
		_repair_wood_scrap_btn,
		_backpack.has("wood", ItemDefs.REPAIR_WOOD_EACH) and _backpack.has("scrap", ItemDefs.REPAIR_SCRAP_ALT_EACH),
	)
	if not status_text.is_empty():
		_show_repair_choicf_hint(status_text, status_warning)
	elif _elevator_repair_progress >= total:
		_show_repair_choicf_hint("电梯修复完成", false)
	else:
		_show_repair_choicf_hint("")


func _on_repair_option_pressed(material: String) -> void:
	if not _has_repair_material(material):
		_refresh_repair_choice_popup("资源不足", true)
		return
	_repair_with_material(material)


func _run_bootstrap_textures_ready() -> bool:
	return GameManager.run_bootstrap_textures_preloaded()


func _apply_pregenerated_map(bootstrap: Dictionary) -> void:
	var map: Variant = bootstrap.get("map")
	if map is WorldMapData:
		_map = map
	_current_layer = maxi(int(bootstrap.get("current_layer", 1)), 1)
	_elevator_repair_progress = 0
	_current_district_index = -1
	_apply_overworld_biome_for_layer()


func _start_new_run() -> void:
	_run_ended = false
	_run_end_reason = ""
	_final_choice_id = ""
	_final_defense_cleared = false
	_thunder_leiting_defeated = false
	_tower_upgrades = NightTdUpgrades.default_state()
	_pending_thunder_district = -1
	_run_journal = RunJournal.new()
	_story_controller.reset_for_new_run()
	_init_player_loadout()
	if GameManager.has_run_bootstrap():
		_apply_pregenerated_map(GameManager.consume_run_bootstrap())
	else:
		_generate_layer_map()
	_fuel = fuel_max
	_reset_vehicle_hp_for_new_run()
	_spawn_resources()
	if is_instance_valid(minimap_view):
		minimap_view.set_world_map(_map)
		minimap_view.set_war_fog_enabled(war_fog_enabled)
	if _map.start_node_index >= 0:
		_enter_node(_map.start_node_index, true)
	if is_instance_valid(time_system):
		time_system.start_day(1)
	_play_music_cue("day_exploration", 1.0)
	if is_instance_valid(_start_guide_overlay):
		_start_guide_overlay.show_guide()

func _ensure_input_actions() -> void:
	for action_name in ["move_up", "move_down", "move_left", "move_right", "interact", "repair", "pause", "enter_defense_mode", "toggle_backpack", "toggle_journal", "toggle_world_map", "cycle_building"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
	# 步行与驾车/选路均支持 WASD 与方向键（↑北 ↓南 ←西 →东）
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
	_register_key_action("enter_defense_mode", KEY_F)
	_register_key_action("toggle_backpack", KEY_B)
	_register_key_action("toggle_journal", KEY_J)
	_register_key_action("toggle_world_map", KEY_M)
	_register_key_action("cycle_building", KEY_Q)

func _reset_action_keys(action_name: String) -> void:
	for event in InputMap.action_get_events(action_name):
		InputMap.action_erase_event(action_name, event)

func _register_key_action(action_name: String, keycode: Key) -> void:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)

func _connect_buttons() -> void:
	disembark_button.pressed.connect(_on_disembark_pressed)
	return_button.pressed.connect(_on_return_pressed)
	if is_instance_valid(story_accept_button):
		HudTheme.apply_choice_button(story_accept_button, Color("#7ec8a0"))
		story_accept_button.pressed.connect(_on_story_accept_pressed)
	if is_instance_valid(story_decline_button):
		HudTheme.apply_choice_button(story_decline_button, Color("#c8a080"))
		story_decline_button.pressed.connect(_on_story_decline_pressed)
	if is_instance_valid(prompt_label):
		prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(story_choice_buttons):
		story_choice_buttons.mouse_filter = Control.MOUSE_FILTER_PASS
	if is_instance_valid(story_reward_buttons):
		story_reward_buttons.mouse_filter = Control.MOUSE_FILTER_PASS
	repair_button.pressed.connect(_on_repair_pressed)
	if is_instance_valid(backpack_button):
		backpack_button.pressed.connect(_toggle_backpack)
	if is_instance_valid(back_track_button):
		back_track_button.focus_mode = Control.FOCUS_NONE
		back_track_button.pressed.connect(_take_back_at_node)
	if is_instance_valid(up_button):
		up_button.pressed.connect(func() -> void: _choose_exit_direction("up", true))
	if is_instance_valid(down_button):
		down_button.pressed.connect(func() -> void: _choose_exit_direction("down", true))
	if is_instance_valid(left_button):
		left_button.pressed.connect(func() -> void: _choose_exit_direction("left", true))
	if is_instance_valid(right_button):
		right_button.pressed.connect(func() -> void: _choose_exit_direction("right", true))

func _spawn_vehicle() -> void:
	if vehicle_scene == null:
		vehicle_scene = load("res://scenes/vehicle.tscn")
	_vehicle = vehicle_scene.instantiate()
	_vehicle.z_index = 20
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
	_seed_final_layer_evidence_spawns()
	for node in _resource_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_resource_nodes.clear()
	for district_index in _map.district_indices:
		if _map.is_tactical_dormant(district_index):
			continue
		var cell := _map.get_cell(district_index)
		if str(cell.get("story_id", "")) != "":
			continue
		_map.ensure_resource_spawn_collected_state(district_index)
		for spawn_data in cell.get("resource_spawns", []):
			var spawn_key := _map.resource_spawn_key(spawn_data)
			if spawn_key != "" and _map.is_resource_spawn_collected(district_index, spawn_key):
				continue
			var spawn_position := Vector2.ZERO
			var loot_id := "scrap"
			if spawn_data is Dictionary:
				spawn_position = Vector2(float(spawn_data.get("x", 0.0)), float(spawn_data.get("y", 0.0)))
				loot_id = str(spawn_data.get("item_id", "scrap"))
			elif spawn_data is Vector2:
				spawn_position = spawn_data
			var pickup := resource_scene.instantiate()
			add_child(pickup)
			pickup.visible = false
			pickup.monitorable = false
			pickup.monitoring = false
			var collision := pickup.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if is_instance_valid(collision):
				collision.disabled = true
			pickup.position = _map.cell_rect(district_index).position + spawn_position
			pickup.set_meta("district_index", district_index)
			pickup.set_meta("item_id", loot_id)
			if loot_id.begins_with("evidence:"):
				pickup.set_meta("skip_map_resource", true)
			if spawn_key != "":
				pickup.set_meta("spawn_key", spawn_key)
			if pickup.has_method("setup_loot"):
				pickup.setup_loot(loot_id)
			if pickup.has_signal("collected"):
				pickup.collected.connect(func(loot_id: String, p: Area2D): _on_resource_collected(district_index, loot_id, p))
			_resource_nodes.append(pickup)


func _seed_final_layer_evidence_spawns() -> void:
	if _current_layer < total_layers:
		return
	for district_index in _map.district_indices:
		if not _map.district_has_kunlun_control(district_index):
			continue
		var cell := _map.get_cell(district_index)
		var spawns: Array = cell.get("resource_spawns", [])
		var existing: Dictionary = {}
		for spawn_var in spawns:
			if spawn_var is Dictionary:
				existing[str(spawn_var.get("item_id", ""))] = true
		var offsets := {
			"clone_identity": Vector2(96.0, 80.0),
			"faction_conflict": Vector2(160.0, 112.0),
			"human_extinction_proof": Vector2(224.0, 144.0),
			"backdoor_info": Vector2(288.0, 96.0),
		}
		for evidence_id in EvidenceData.terminal_required_ids():
			var item_id := "evidence:%s" % evidence_id
			if existing.has(item_id) or _backpack.has(item_id, 1):
				continue
			var offset: Vector2 = offsets.get(str(evidence_id), Vector2(120.0 + float(spawns.size()) * 28.0, 112.0))
			spawns.append({
				"x": offset.x,
				"y": offset.y,
				"item_id": item_id,
			})
		cell["resource_spawns"] = spawns
		return

func _process(_delta: float) -> void:
	if _run_ended or _game_paused or _backpack_open:
		return
	if Input.is_action_just_pressed("enter_defense_mode"):
		if _mode == TravelMode.FOOT:
			_try_foot_console_interact()
		else:
			_try_enter_defense_mode()


func _physics_process(delta: float) -> void:
	if _run_ended:
		return
	if _game_paused or _backpack_open:
		return
	if is_instance_valid(night_td) and night_td.visible:
		_sync_view_cameras()
		_refresh_ui()
		queue_redraw()
		return
	if is_instance_valid(_world_map_overlay) and _world_map_overlay.is_open():
		_refresh_focus()
		_sync_world_map_overlay()
		return
	_update_evening_tint(delta)
	if _is_night_phase():
		_sync_view_cameras()
		_refresh_ui()
		queue_redraw()
		return

	if not _is_exploration_allowed():
		_sync_view_cameras()
		_refresh_ui()
		queue_redraw()
		return

	_check_vehicle_destroyed()
	_tick_survival(delta)
	_check_player_vitals_failure()
	_check_low_stamina_warning()

	if Input.is_action_just_pressed("interact"):
		if _try_story_e_action_overlay():
			pass
		elif _mode == TravelMode.FOOT:
			if not _try_foot_return_to_vehicle():
				_handle_foot_interact()
		elif _mode == TravelMode.DRIVE and _segment_target_index < 0:
			if _try_advance_story_dialogue():
				pass
			elif (
				is_instance_valid(_story_controller)
				and _story_controller.advance_active_drive_dialogue()
			):
				_refresh_ui()
			elif _story_controller.handle_drive_interact(_current_node_index):
				_refresh_ui()
			elif not _get_enterable_buildings().is_empty():
				var district_index := _selected_enterable_district()
				if not _can_enter_district(district_index):
					_story_controller.try_enter_district(district_index)
				else:
					_enter_selected_building()
			else:
				_take_back_at_node()
	_update_drive_exit_lock()
	if _mode == TravelMode.DRIVE and _segment_target_index < 0:
		var buildings := _get_enterable_buildings()
		if buildings.size() > 1 and Input.is_action_just_pressed("cycle_building"):
			_building_pick_index = (_building_pick_index + 1) % buildings.size()
			_mark_overworld_dirty()
		var gate_active := (
			is_instance_valid(_story_controller)
			and _story_controller._any_dialogue_active()
		)
		if not gate_active:
			_try_begin_drive_from_input()
	if Input.is_action_just_pressed("repair") and _mode == TravelMode.FOOT:
		_try_foot_console_interact()

	match _mode:
		TravelMode.DRIVE:
			_process_drive(delta)
		TravelMode.FOOT:
			_process_foot(delta)

	if is_instance_valid(_story_controller):
		_story_controller.tick_prop_dig_fx(delta)

	_sync_view_cameras()
	_refresh_focus()
	if _mode == TravelMode.FOOT:
		_foot_ui_accum += delta
		if _foot_ui_accum >= UI_REFRESH_INTERVAL:
			_foot_ui_accum = 0.0
			_schedule_refresh_ui()
	else:
		_foot_ui_accum = 0.0
		_drive_ui_accum += delta
		if _drive_ui_accum >= UI_REFRESH_INTERVAL:
			_drive_ui_accum = 0.0
			_schedule_refresh_ui()
	_request_overworld_redraw_if_needed()

func _request_overworld_redraw_if_needed() -> void:
	if _mode == TravelMode.FOOT:
		var foot_pos := _current_focus_position()
		var walk_anim_dirty := (
			_foot_is_walking
			and absf(_foot_walk_phase - _last_foot_walk_phase_draw) >= 0.42
		)
		if (
			_overworld_dirty
			or foot_pos.distance_squared_to(_last_foot_draw_pos) >= 64.0
			or walk_anim_dirty
		):
			queue_redraw()
			_overworld_dirty = false
			_last_foot_draw_pos = foot_pos
			if walk_anim_dirty:
				_last_foot_walk_phase_draw = _foot_walk_phase
		return
	if _evening_tint > 0.001:
		if _overworld_dirty or absf(_evening_tint - _last_draw_evening_tint) >= 0.01:
			queue_redraw()
			_overworld_dirty = false
			_last_draw_evening_tint = _evening_tint
		return
	if _segment_target_index >= 0:
		var cam_pos := _active_world_camera_position()
		if _overworld_dirty or cam_pos.distance_squared_to(_last_overworld_draw_cam) >= 144.0:
			queue_redraw()
			_overworld_dirty = false
			_last_overworld_draw_cam = cam_pos
		return
	if _overworld_dirty:
		queue_redraw()
		_overworld_dirty = false


func _active_world_camera_position() -> Vector2:
	if is_instance_valid(_world_camera) and _world_camera.enabled:
		return _world_camera.global_position
	if is_instance_valid(_vehicle):
		return _vehicle.global_position
	return Vector2.ZERO

func _setup_world_camera() -> void:
	_world_camera = Camera2D.new()
	_world_camera.name = "WorldCamera"
	_world_camera.enabled = false
	_world_camera.zoom = Vector2(world_camera_zoom, world_camera_zoom)
	_world_camera.position_smoothing_enabled = true
	_world_camera.position_smoothing_speed = world_camera_smoothing
	add_child(_world_camera)


func _sync_view_cameras() -> void:
	if is_instance_valid(night_td) and night_td.visible:
		if is_instance_valid(_world_camera):
			_world_camera.enabled = false
		if is_instance_valid(_player) and is_instance_valid(_player.camera):
			_player.camera.enabled = false
		if is_instance_valid(_vehicle) and is_instance_valid(_vehicle.camera):
			_vehicle.camera.enabled = false
		return
	var night_phase := _is_night_phase()
	if night_phase:
		if is_instance_valid(_world_camera):
			_world_camera.enabled = false
		var use_player_camera := _mode == TravelMode.FOOT
		if is_instance_valid(_player) and is_instance_valid(_player.camera):
			_player.camera.enabled = use_player_camera
			if use_player_camera:
				_player.camera.make_current()
		if is_instance_valid(_vehicle) and is_instance_valid(_vehicle.camera):
			_vehicle.camera.enabled = false
		return
	if _mode == TravelMode.FOOT:
		if is_instance_valid(_world_camera):
			_world_camera.enabled = false
		if is_instance_valid(_player) and is_instance_valid(_player.camera):
			_player.camera.enabled = false
		if is_instance_valid(_vehicle) and is_instance_valid(_vehicle.camera):
			_vehicle.camera.enabled = false
		return
	# 白天驾驶：大地图世界坐标 + 相机跟随车辆
	if is_instance_valid(_world_camera):
		_world_camera.enabled = true
		_world_camera.zoom = Vector2(world_camera_zoom, world_camera_zoom)
		_world_camera.global_position = _vehicle_world_position()
		_world_camera.make_current()
	if is_instance_valid(_player) and is_instance_valid(_player.camera):
		_player.camera.enabled = false
	if is_instance_valid(_vehicle) and is_instance_valid(_vehicle.camera):
		_vehicle.camera.enabled = false


func _camera_world_view_rect() -> Rect2:
	if not is_instance_valid(_world_camera) or not _world_camera.enabled:
		return Rect2(Vector2(-4000, -4000), Vector2(8000, 8000))
	var vp := get_viewport_rect().size
	if vp == Vector2.ZERO:
		vp = Vector2(1280.0, 720.0)
	var half := (vp / _world_camera.zoom) * 0.5
	var center := _world_camera.global_position
	return Rect2(center - half, half * 2.0)


func _world_rect_to_screen_rect(world_rect: Rect2) -> Rect2:
	var xf := get_viewport().get_canvas_transform()
	var top_left := xf * world_rect.position
	var bottom_right := xf * (world_rect.position + world_rect.size)
	return Rect2(top_left, bottom_right - top_left)


func _building_sign_overlaps_inventory_hud(district_rect: Rect2, toward_road: Vector2) -> bool:
	var sign_world := DayTopdownRender.district_building_sign_rect(district_rect, toward_road)
	var sign_screen := _world_rect_to_screen_rect(sign_world)
	return HudTheme.inventory_hud_screen_rect().intersects(sign_screen)

func _process_drive(delta: float) -> void:
	if _segment_target_index < 0 or not _map.is_valid_index(_segment_target_index):
		_update_vehicle_transform()
		return

	var axis := _get_segment_drive_axis()
	if axis == 0.0:
		_update_vehicle_transform()
		return
	if not _can_drive_with_current_fuel():
		_update_vehicle_transform()
		return
	var forward_dir := _map.direction_between(_segment_from_index, _segment_target_index)
	var forward_vec := _drive_direction_vector(forward_dir)
	if forward_vec.length_squared() > 0.01:
		_vehicle_facing = forward_vec if axis > 0.0 else -forward_vec
	var segment_len := maxf(_segment_length, 1.0)
	var distance_to_edge := (_segment_progress if axis < 0.0 else 1.0 - _segment_progress) * segment_len
	var desired_distance := minf(drive_speed * delta, maxf(distance_to_edge, 0.0))
	var movement_distance := desired_distance
	var fuel_used := 0.0
	if fuel_per_pixel > 0.0:
		var fuel_needed := desired_distance * fuel_per_pixel
		if fuel_needed > _fuel:
			var fuel_ratio := clampf(_fuel / maxf(fuel_needed, FUEL_EMPTY_EPSILON), 0.0, 1.0)
			movement_distance *= fuel_ratio
			fuel_used = _fuel
		else:
			fuel_used = fuel_needed
	_segment_progress += signf(axis) * movement_distance / segment_len
	_update_vehicle_transform()
	_fuel = maxf(_fuel - fuel_used, 0.0)

	if _segment_progress >= 1.0:
		_arrive_at_node(_segment_target_index)
	elif _segment_progress <= 0.0 and axis < 0.0:
		_segment_progress = 0.0
		_halt_at_node(_segment_from_index)
	if _fuel <= FUEL_EMPTY_EPSILON and fuel_per_pixel > 0.0:
		_fuel = 0.0
		_can_drive_with_current_fuel()

func _process_foot(delta: float) -> void:
	if _current_district_index < 0:
		return
	if is_instance_valid(_story_controller) and _story_controller.blocks_foot_exit(_current_district_index):
		_foot_is_walking = false
		return
	var foot_area := _map.get_foot_area_rect(_current_district_index)
	if foot_area.size == Vector2.ZERO:
		return
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector == Vector2.ZERO:
		_foot_is_walking = false
		return
	_foot_move_dir = input_vector.normalized()
	_foot_is_walking = true
	_foot_walk_phase += delta * 10.5
	var next_local := _foot_local_pos + input_vector * 96.0 * delta
	next_local.x = clampf(next_local.x, 8.0, foot_area.size.x - 8.0)
	next_local.y = clampf(next_local.y, 8.0, foot_area.size.y - 8.0)
	var foot_origin := _map.get_foot_origin(_current_district_index)
	var world_next := foot_origin + next_local
	if not _is_foot_blocked_at(world_next):
		_foot_local_pos = next_local
		_apply_foot_world_position()
		_refresh_focus()
	else:
		# 顶墙时仍播步态，避免角色僵住
		_foot_walk_phase += delta * 6.0
	_try_collect_interior_pickups()


func _try_collect_interior_pickups() -> void:
	if _current_district_index < 0:
		return
	var player_world := _map.get_foot_origin(_current_district_index) + _foot_local_pos
	var pickup_radius := 30.0
	var best_pickup: Area2D = null
	var best_distance := pickup_radius
	for node in _resource_nodes:
		if not is_instance_valid(node):
			continue
		if bool(node.get_meta("picked_up", false)):
			continue
		if int(node.get_meta("district_index", -1)) != _current_district_index:
			continue
		var dist := node.global_position.distance_to(player_world)
		if dist > pickup_radius:
			continue
		if dist < best_distance:
			best_distance = dist
			best_pickup = node
	if best_pickup != null and best_pickup.has_signal("collected"):
		var loot_id := str(best_pickup.get_meta("item_id", "scrap"))
		best_pickup.collected.emit(loot_id, best_pickup)
	if is_instance_valid(_story_controller):
		_story_controller.try_collect_foot_loot(_current_district_index, _foot_local_pos)


func _apply_foot_world_position() -> void:
	if not is_instance_valid(_player) or _current_district_index < 0:
		return
	_player.global_position = _map.get_foot_origin(_current_district_index) + _foot_local_pos

func _input(event: InputEvent) -> void:
	if _run_ended:
		return
	if event.is_action_pressed("toggle_world_map"):
		_toggle_world_map()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_B or event.physical_keycode == KEY_B or event.is_action_pressed("toggle_backpack"):
			_toggle_backpack()
			get_viewport().set_input_as_handled()
			return
		if not _game_paused and not _backpack_open and _segment_target_index < 0:
			if _is_story_dialogue_visible() and _story_dialogue_ui.is_choice_mode():
				var choice_count := _story_dialogue_ui.get_choice_count()
				for i in range(mini(9, choice_count)):
					var overlay_key := Key.KEY_1 + i
					if event.keycode == overlay_key or event.physical_keycode == overlay_key:
						_on_story_dialogue_choice_pressed(i)
						get_viewport().set_input_as_handled()
						return
			if _mode == TravelMode.FOOT and _current_district_index >= 0 and is_instance_valid(_story_controller):
				var foot_story_id := _story_controller.story_id_of_district(_current_district_index)
				if foot_story_id != "":
					var foot_npc := _story_controller.npc_dialogue
					if foot_npc != null and foot_npc.is_active() and foot_npc.phase == NpcDialogueRunnerScript.Phase.OPTIONS:
						var foot_option_count := foot_npc.get_option_labels().size()
						for i in range(mini(9, foot_option_count)):
							var foot_key := Key.KEY_1 + i
							if event.keycode == foot_key or event.physical_keycode == foot_key:
								_story_controller.choose_dialogue_option(i)
								get_viewport().set_input_as_handled()
								return
			if _mode == TravelMode.DRIVE:
				var story_id := _story_controller.story_id_at_node(_current_node_index) if is_instance_valid(_story_controller) else ""
				if story_id != "" and is_instance_valid(_story_controller):
					var npc := _story_controller.npc_dialogue
					if npc != null and npc.is_active() and npc.phase == NpcDialogueRunnerScript.Phase.OPTIONS:
						var option_count := npc.get_option_labels().size()
						for i in range(mini(9, option_count)):
							var reward_key := Key.KEY_1 + i
							if event.keycode == reward_key or event.physical_keycode == reward_key:
								_story_controller.choose_dialogue_option(i)
								get_viewport().set_input_as_handled()
								return
					var gate := _story_controller.gate_dialogue
					if gate != null and story_id != "" and gate.phase == StoryGateDialogue.Phase.REWARD_CHOICE:
						var choice_count := StoryData.reward_choice_count(story_id)
						for i in range(mini(9, choice_count)):
							var reward_key := Key.KEY_1 + i
							if event.keycode == reward_key or event.physical_keycode == reward_key:
								_story_controller.choose_reward_index(i)
								get_viewport().set_input_as_handled()
								return
				var buildings := _get_enterable_buildings()
				for i in range(mini(9, buildings.size())):
					var key := Key.KEY_1 + i
					if event.keycode == key or event.physical_keycode == key:
						_building_pick_index = i
						_mark_overworld_dirty()
						var district_index := int(buildings[i].get("district_index", -1))
						if not _can_enter_district(district_index):
							_story_controller.try_enter_district(district_index)
						else:
							_enter_selected_building()
						get_viewport().set_input_as_handled()
						return


func _unhandled_input(event: InputEvent) -> void:
	if _run_ended:
		return
	if is_instance_valid(_world_map_overlay) and _world_map_overlay.is_open():
		if event.is_action_pressed("toggle_world_map") or event.is_action_pressed("pause"):
			_close_world_map()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_backpack"):
		_toggle_backpack()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_journal"):
		_open_journal()
		get_viewport().set_input_as_handled()
		return
	if _backpack_open and event.is_action_pressed("pause"):
		_close_backpack()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if _game_paused or _backpack_open:
		return
	if _mode != TravelMode.DRIVE:
		return
	if _is_night_phase() or not _is_exploration_allowed():
		return
	if _segment_target_index >= 0:
		return
	if not event.is_pressed() or event.is_echo():
		return
	var direction := _just_pressed_drive_direction_from_event(event)
	if direction == "" or not _exit_options.has(direction):
		return
	_choose_exit_direction(direction)
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
	_current_district_index = -1
	_halt_at_node(node_index)

func _pick_auto_next(node_index: int) -> int:
	var connections := _map.get_connected_indices(node_index)
	for connected in connections:
		if connected != _previous_node_index:
			return connected
	return -1

func _build_exit_options(node_index: int) -> Dictionary:
	var options: Dictionary = {}
	for direction in _map.get_passable_directions(node_index):
		var neighbor := _map.get_neighbor_index(node_index, direction)
		if neighbor >= 0 and _map.is_drive_node(neighbor):
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
	_drive_exit_locked = true
	_building_pick_index = 0
	for district_index in _map.get_roadside_districts(node_index):
		_map.mark_explored(district_index)
	if is_instance_valid(_vehicle):
		_vehicle.set_active(true)
		_vehicle.global_position = _road_center(node_index)
	_sync_day_entity_visibility()
	if get_viewport() != null:
		get_viewport().gui_release_focus()
	_sync_minimap_navigation()
	_mark_overworld_dirty()
	queue_redraw()
	_last_overworld_draw_cam = _active_world_camera_position()


func _get_back_neighbor_index() -> int:
	if not _map.is_valid_index(_current_node_index) or not _map.is_valid_index(_arrived_from_index):
		return -1
	for neighbor in _map.get_passable_indices(_current_node_index):
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


func _pressed_drive_direction() -> String:
	if Input.is_action_pressed("move_up"):
		return "up"
	if Input.is_action_pressed("move_down"):
		return "down"
	if Input.is_action_pressed("move_left"):
		return "left"
	if Input.is_action_pressed("move_right"):
		return "right"
	return ""


func _just_pressed_drive_direction() -> String:
	if Input.is_action_just_pressed("move_up"):
		return "up"
	if Input.is_action_just_pressed("move_down"):
		return "down"
	if Input.is_action_just_pressed("move_left"):
		return "left"
	if Input.is_action_just_pressed("move_right"):
		return "right"
	return ""


func _just_pressed_drive_direction_from_event(event: InputEvent) -> String:
	if event.is_action_pressed("move_up"):
		return "up"
	if event.is_action_pressed("move_down"):
		return "down"
	if event.is_action_pressed("move_left"):
		return "left"
	if event.is_action_pressed("move_right"):
		return "right"
	return ""


func _update_drive_exit_lock() -> void:
	if _drive_exit_locked and _pressed_drive_direction() == "":
		_drive_exit_locked = false


func _choose_exit_direction(direction: String, from_ui: bool = false) -> void:
	if _mode != TravelMode.DRIVE or _segment_target_index >= 0:
		return
	if _drive_exit_locked and not from_ui:
		return
	if direction == "" or not _exit_options.has(direction):
		return
	_drive_exit_locked = false
	_begin_drive_segment(_current_node_index, int(_exit_options[direction]))


func _get_segment_drive_axis() -> float:
	if _segment_target_index < 0 or not _map.is_valid_index(_segment_from_index):
		return 0.0
	var forward_dir := _map.direction_between(_segment_from_index, _segment_target_index)
	var input_dir := _pressed_drive_direction()
	if input_dir == "":
		return 0.0
	var allowed := _map.allowed_input_directions_for_segment(_segment_from_index, _segment_target_index)
	if input_dir not in allowed:
		return 0.0
	if input_dir == forward_dir:
		return 1.0
	if input_dir == _map.opposite_direction(forward_dir):
		return -1.0
	return 0.0


func _try_begin_drive_from_input() -> void:
	if _segment_target_index >= 0:
		return
	if _drive_exit_locked:
		return
	var direction := _just_pressed_drive_direction()
	if direction == "" or not _exit_options.has(direction):
		return
	_choose_exit_direction(direction)


func _drive_direction_vector(direction: String) -> Vector2:
	match direction:
		"up":
			return Vector2.UP
		"down":
			return Vector2.DOWN
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
		_:
			return Vector2.ZERO


func _enter_node(node_index: int, is_run_start: bool = false) -> void:
	if not _map.is_valid_index(node_index):
		return
	_current_node_index = node_index
	if is_run_start:
		_arrived_from_index = -1
		_previous_node_index = -1
	_map.mark_explored(node_index)
	_current_district_index = -1
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
	if not _map.is_drive_node(to_index):
		return
	var travel_dir := _map.direction_between(from_index, to_index)
	if travel_dir == "" or not _map.is_direction_passable(from_index, travel_dir):
		return
	if not _can_drive_with_current_fuel():
		return
	_mode = TravelMode.DRIVE
	_current_node_index = from_index
	_segment_from_index = from_index
	_segment_target_index = to_index
	_segment_progress = 0.0
	_segment_length = maxf(_road_center(from_index).distance_to(_road_center(to_index)), 1.0)
	_drive_exit_locked = false
	if is_instance_valid(_vehicle):
		_vehicle.set_active(true)
		_vehicle.global_position = _map.cell_center(from_index)
	_sync_day_entity_visibility()
	for node in _resource_nodes:
		if is_instance_valid(node):
			node.visible = false
	_sync_minimap_navigation()
	_mark_overworld_dirty()
	queue_redraw()
	_last_overworld_draw_cam = _active_world_camera_position()

func _get_enterable_buildings() -> Array:
	var result: Array = []
	if not _map.is_valid_index(_current_node_index) or _segment_target_index >= 0:
		return result
	if not _map.is_drive_node(_current_node_index):
		return result
	for district_index in _map.get_roadside_districts(_current_node_index):
		if _map.is_tactical_dormant(district_index):
			continue
		var cell := _map.get_cell(district_index)
		result.append({
			"district_index": district_index,
			"label": _map.building_label(district_index),
			"building_type": str(cell.get("building_type", "")),
			"remaining": int(cell.get("resource_remaining", 0)),
		})
	return result


func _enter_selected_building() -> void:
	var buildings := _get_enterable_buildings()
	if buildings.is_empty():
		return
	_building_pick_index = clampi(_building_pick_index, 0, buildings.size() - 1)
	var entry: Dictionary = buildings[_building_pick_index]
	_begin_foot_mode(int(entry.get("district_index", -1)))


func _begin_foot_mode(district_index: int = -1) -> void:
	if district_index < 0:
		district_index = _current_district_index
	if district_index < 0 or not _map.is_district(district_index):
		return
	if is_instance_valid(_story_controller) and _story_controller.is_thunder_blocking_district(district_index):
		_thunder_terminal_sequence_active = true
		_pause_day_night_for_terminal_sequence()
		_story_controller.begin_thunder_gate_encounter(district_index)
		return
	if not _can_enter_district(district_index):
		return
	_current_district_index = district_index
	_map.ensure_foot_layout(_current_district_index)
	_mode = TravelMode.FOOT
	_segment_target_index = -1
	if is_instance_valid(_vehicle):
		_vehicle.set_active(false)
	if is_instance_valid(_player):
		_player.set_active(true)
		_player.set_physics_process(false)
		_player.set_blocked_checker(Callable())
		_player.world_bounds = Rect2()
		var door_world := _map.get_foot_door_world_pos(_current_district_index)
		var foot_origin := _map.get_foot_origin(_current_district_index)
		_foot_local_pos = door_world - foot_origin
		_foot_move_dir = Vector2.UP
		_foot_walk_phase = 0.0
		_foot_is_walking = false
		_apply_foot_world_position()
	_sync_day_entity_visibility()
	for node in _resource_nodes:
		if is_instance_valid(node):
			node.visible = false
	call_deferred("_on_foot_district_entered", _current_district_index)
	_cache_foot_layout_data(_current_district_index)
	_mark_overworld_dirty()
	_last_foot_draw_pos = Vector2(-99999.0, -99999.0)
	_drive_ui_accum = 0.0
	_schedule_refresh_ui()
	call_deferred("_deferred_foot_enter_setup", _current_district_index)

func _on_foot_district_entered(district_index: int) -> void:
	if _mode != TravelMode.FOOT or _current_district_index != district_index:
		return
	if is_instance_valid(_story_controller):
		_story_controller.on_entered_district_foot(district_index)

func _deferred_foot_enter_setup(district_index: int) -> void:
	if _mode != TravelMode.FOOT or _current_district_index != district_index:
		return
	if is_instance_valid(_story_controller):
		var sid := _story_controller.story_id_of_district(district_index)
		if sid != "" and _story_controller.run_state.is_quest_active(sid):
			_fix_district_pickup_positions(district_index)
			_story_controller.fix_foot_loot_positions(district_index)
	_schedule_refresh_ui()

func _return_to_vehicle() -> void:
	if _mode == TravelMode.FOOT and is_instance_valid(_story_controller) and _current_district_index >= 0:
		var exit_story_id := _story_controller.story_id_of_district(_current_district_index)
		if exit_story_id != "":
			_story_controller.suspend_interior_dialogue_for_drive(exit_story_id)
			_hide_story_choice_overlay()
	if (
		_mode == TravelMode.FOOT
		and is_instance_valid(_story_controller)
		and _story_controller.blocks_foot_exit(_current_district_index)
	):
		return
	if _story_controller.on_exited_district_to_drive(_current_district_index):
		_mode = TravelMode.DRIVE
		_current_district_index = -1
		if is_instance_valid(_player):
			_player.set_blocked_checker(Callable())
			_player.set_physics_process(true)
			_player.set_active(false)
		if is_instance_valid(_vehicle):
			_vehicle.set_active(true)
			if _map.is_valid_index(_current_node_index):
				_vehicle.global_position = _road_center(_current_node_index)
		_sync_day_entity_visibility()
		for node in _resource_nodes:
			if is_instance_valid(node):
				node.visible = false
		if _current_node_index >= 0:
			_halt_at_node(_current_node_index)
		_foot_ui_accum = 0.0
		_schedule_refresh_ui()
		return
	_mode = TravelMode.DRIVE
	if is_instance_valid(_player):
		_player.set_blocked_checker(Callable())
		_player.set_physics_process(true)
		_player.set_active(false)
	if is_instance_valid(_vehicle):
		_vehicle.set_active(true)
		if _map.is_valid_index(_current_node_index):
			_vehicle.global_position = _road_center(_current_node_index)
	_sync_day_entity_visibility()
	for node in _resource_nodes:
		if is_instance_valid(node):
			node.visible = false
	if _current_node_index >= 0:
		_halt_at_node(_current_node_index)
	_foot_ui_accum = 0.0
	_schedule_refresh_ui()

func _schedule_refresh_ui() -> void:
	if _ui_refresh_scheduled:
		return
	_ui_refresh_scheduled = true
	call_deferred("_run_scheduled_refresh_ui")


func _run_scheduled_refresh_ui() -> void:
	if not _ui_refresh_scheduled:
		return
	_ui_refresh_scheduled = false
	_refresh_ui()


func _pda_entries_signature(entries: Array) -> String:
	var parts: PackedStringArray = []
	for entry_var in entries:
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var
		parts.append("%s:%d" % [str(entry.get("id", "")), int(entry.get("count", 0))])
	return "|".join(parts)


func _on_disembark_pressed() -> void:
	if _try_enter_interior_at_drive_gate():
		return
	if is_instance_valid(_story_controller):
		if _story_controller.advance_active_drive_dialogue():
			_refresh_ui()
			return
		var npc := _story_controller.npc_dialogue
		if npc != null and npc.is_active():
			if npc.phase == NpcDialogueRunnerScript.Phase.OPTIONS:
				return
			if npc.phase == NpcDialogueRunnerScript.Phase.LINE:
				npc.advance_line()
				_refresh_ui()
				return
	if is_instance_valid(_story_controller) and is_instance_valid(_story_controller.gate_dialogue):
		var gate := _story_controller.gate_dialogue
		if gate.phase == StoryGateDialogue.Phase.INTRO_CHOICE:
			_story_controller.accept_gate_choice()
			return
		if gate.phase == StoryGateDialogue.Phase.REWARD_CHOICE:
			return
	if is_instance_valid(_story_controller) and _mode == TravelMode.DRIVE and _segment_target_index < 0:
		var story_id := _story_controller.story_id_at_node(_current_node_index)
		if story_id != "" and StoryData.dialogue_path(story_id) != "":
			var run_state := _story_controller.run_state
			if not run_state.is_completed(story_id):
				var need := int(StoryData.quest_def(story_id).get("collect_count", 0))
				var collected := run_state.get_collect_count(story_id)
				if not StoryData.is_interior_encounter(story_id):
					if not run_state.is_quest_active(story_id) or collected >= need:
						_story_controller.start_story_talk(story_id)
						_refresh_ui()
						return
	if _mode == TravelMode.DRIVE and not _get_enterable_buildings().is_empty():
		var district_index := _selected_enterable_district()
		if not _can_enter_district(district_index):
			_story_controller.try_enter_district(district_index)
			return
		_enter_selected_building()


func _on_return_pressed() -> void:
	if _mode == TravelMode.FOOT:
		_return_to_vehicle()
		return
	if is_instance_valid(_story_controller) and is_instance_valid(_story_controller.gate_dialogue):
		if _story_controller.gate_dialogue.phase == StoryGateDialogue.Phase.INTRO_CHOICE:
			_story_controller.decline_gate_choice()
			_refresh_ui()

func _on_repair_pressed() -> void:
	_try_foot_console_interact()

func _can_disembark() -> bool:
	if _mode != TravelMode.DRIVE or _segment_target_index >= 0:
		return false
	if _get_enterable_buildings().is_empty():
		return false
	var district_index := _selected_enterable_district()
	if (
		is_instance_valid(_story_controller)
		and _story_controller.is_thunder_blocking_district(district_index)
	):
		return true
	return _can_enter_district(district_index)


func _sync_day_entity_visibility() -> void:
	if _is_night_phase():
		return
	if _mode == TravelMode.FOOT:
		if is_instance_valid(_player):
			_player.visible = false
			if is_instance_valid(_player.sprite):
				_player.sprite.visible = false
		if is_instance_valid(_vehicle):
			_vehicle.visible = false
		return
	if is_instance_valid(_player):
		_player.visible = false
	if is_instance_valid(_vehicle):
		var driving := _segment_target_index >= 0
		_vehicle.visible = driving
		var vehicle_sprite := _vehicle.get_node_or_null("Sprite2D") as Sprite2D
		if vehicle_sprite != null:
			vehicle_sprite.visible = driving

func _can_repair_elevator() -> bool:
	return _mode == TravelMode.FOOT and _current_district_index >= 0 and _map.district_has_elevator(_current_district_index) and not _run_ended


func _can_use_kunlun_control() -> bool:
	return (
		_mode == TravelMode.FOOT
		and _current_district_index >= 0
		and _current_layer >= total_layers
		and _map.district_has_kunlun_control(_current_district_index)
		and not _run_ended
	)

func apply_run_config(manager: Node) -> void:
	if manager == null:
		return
	if manager.has_method("get_fuel_max"):
		fuel_max = manager.get_fuel_max(_base_fuel_max)
	if manager.has_method("get_difficulty_name"):
		_run_difficulty_name = manager.get_difficulty_name()
	if manager.has_method("get_squad_name"):
		_run_squad_name = manager.get_squad_name()


func _apply_run_config_from_manager() -> void:
	apply_run_config(GameManager)


func _current_repair_cost() -> int:
	return GameManager.get_elevator_repair_cost(_base_elevator_repair_cost) + maxi(_current_layer - 1, 0)

func _show_repair_choices() -> void:
	if not _can_repair_elevator():
		return
	var needed := _current_repair_cost() - _elevator_repair_progress
	if needed <= 0:
		return
	_refresh_repair_choice_popup()
	_repair_choice_panel.visible = true


func _repair_with_material(material: String) -> void:
	if not _has_repair_material(material):
		_refresh_repair_choice_popup("资源不足", true)
		return

	var consumed := false
	match material:
		"parts":
			consumed = _backpack.remove("parts", ItemDefs.REPAIR_PARTS_EACH)
		"scrap":
			consumed = _backpack.remove("scrap", ItemDefs.REPAIR_SCRAP_EACH)
		"wood_scrap":
			consumed = _backpack.remove("wood", ItemDefs.REPAIR_WOOD_EACH) and _backpack.remove("scrap", ItemDefs.REPAIR_SCRAP_ALT_EACH)

	if not consumed:
		_refresh_repair_choice_popup("资源不足", true)
		return

	var needed := _current_repair_cost() - _elevator_repair_progress
	if needed <= 0:
		return

	_elevator_repair_progress += 1
	_refresh_ui()

	if _elevator_repair_progress >= _current_repair_cost():
		_refresh_repair_choice_popup("电梯修复完成", false)
		_close_repair_choice_popup()
		if _current_layer >= total_layers:
			_request_terminal_access()
		else:
			_advance_layer()
		return

	_refresh_repair_choice_popup("已推进 1 步修复", false)


func _attempt_repair_elevator() -> void:
	if not _can_repair_elevator() or not _is_near_elevator_console():
		return
	_show_repair_choices()


func _attempt_kunlun_terminal() -> void:
	if not _can_use_kunlun_control() or not _is_near_kunlun_console():
		return
	if not _thunder_leiting_defeated:
		return
	_request_terminal_access()

func _on_resource_collected(district_index: int, item_id: String, pickup: Area2D) -> void:
	if is_instance_valid(pickup) and bool(pickup.get_meta("picked_up", false)):
		return
	var loot_id := str(item_id)
	if loot_id == "":
		loot_id = "scrap"
	if loot_id.begins_with("quest:"):
		if _story_controller.on_quest_item_collected(loot_id, district_index):
			_backpack.add(loot_id, 1)
			_refresh_backpack_if_open()
			_refresh_ui()
		if is_instance_valid(pickup):
			pickup.queue_free()
		return
	var skip_map := is_instance_valid(pickup) and bool(pickup.get_meta("skip_map_resource", false))
	var spawn_key := str(pickup.get_meta("spawn_key", "")) if is_instance_valid(pickup) else ""
	if not skip_map and spawn_key != "" and _map.is_resource_spawn_collected(district_index, spawn_key):
		return
	var added := _backpack.add(loot_id, 1)
	if added <= 0:
		return
	if not skip_map:
		if spawn_key != "":
			if not _map.mark_resource_spawn_collected(district_index, spawn_key):
				return
		elif not _map.collect_resource(district_index):
			return
	if added > 0:
		_refresh_ui()
		_refresh_backpack_if_open()
		if _mode == TravelMode.FOOT:
			_mark_overworld_dirty()
	if is_instance_valid(pickup):
		if skip_map:
			pickup.queue_free()
		else:
			pickup.set_meta("picked_up", true)
			pickup.visible = false
			var pickup_label := pickup.get_node_or_null("Label") as Label
			if is_instance_valid(pickup_label):
				pickup_label.visible = false
			_refresh_resource_pickups()


func _refresh_backpack_if_open() -> void:
	if is_instance_valid(_backpack_ui) and _backpack_ui.is_open():
		_backpack_ui.show_backpack(
			_backpack,
			_run_journal,
			false,
			_can_repair_vehicle_from_backpack(),
			_vehicle_hp,
			_vehicle_hp_max,
		)


func _can_repair_vehicle_from_backpack() -> bool:
	if _is_night_phase():
		return false
	if _vehicle_hp_max <= 0.0 or _vehicle_hp >= _vehicle_hp_max - 0.5:
		return false
	return ItemDefs.can_repair_vehicle_with_inventory(_backpack)


func _current_focus_position() -> Vector2:
	if _mode == TravelMode.FOOT and _current_district_index >= 0:
		return _map.get_foot_origin(_current_district_index) + _foot_local_pos
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

func _map_cell_visible_for_player(index: int) -> bool:
	if not war_fog_enabled:
		return true
	if not _map.is_valid_index(index):
		return false
	return bool(_map.get_cell(index)["explored"])

func _on_war_fog_toggled(enabled: bool) -> void:
	war_fog_enabled = enabled
	if is_instance_valid(minimap_view):
		minimap_view.set_war_fog_enabled(enabled)
	_mark_overworld_dirty()
	queue_redraw()

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
	_pause_panel.offset_bottom = 178.0
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

	_war_fog_checkbox = CheckBox.new()
	_war_fog_checkbox.text = "战争黑雾（关闭可显示全图，便于调试）"
	_war_fog_checkbox.button_pressed = war_fog_enabled
	_war_fog_checkbox.toggled.connect(_on_war_fog_toggled)
	box.add_child(_war_fog_checkbox)

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


func _setup_backpack_ui() -> void:
	var hud := get_node_or_null("HUD")
	if hud == null:
		return
	_backpack_ui = BackpackUI.new()
	_backpack_ui.name = "BackpackUI"
	_backpack_ui.z_index = 100
	hud.add_child(_backpack_ui)
	_backpack_ui.item_use_requested.connect(_on_backpack_use_item)
	_backpack_ui.item_discard_requested.connect(_on_backpack_discard_item)
	_backpack_ui.craft_parts_requested.connect(_on_backpack_craft_parts)
	_backpack_ui.vehicle_repair_requested.connect(_on_backpack_repair_vehicle)
	_backpack_ui.closed.connect(_on_backpack_closed)


func _setup_fuel_empty_dialog() -> void:
	var hud := get_node_or_null("HUD")
	_fuel_empty_dialog = AcceptDialog.new()
	_fuel_empty_dialog.name = "FuelEmptyDialog"
	_fuel_empty_dialog.title = "燃料耗尽"
	_fuel_empty_dialog.dialog_text = "车辆燃料已耗尽。请使用背包中的燃料桶补充燃料后继续。"
	_fuel_empty_dialog.ok_button_text = "打开背包"
	_fuel_empty_dialog.confirmed.connect(_on_fuel_empty_dialog_confirmed)
	_fuel_empty_dialog.close_requested.connect(_on_fuel_empty_dialog_closed)
	if hud != null:
		hud.add_child(_fuel_empty_dialog)
	else:
		add_child(_fuel_empty_dialog)


func _init_player_loadout() -> void:
	_survival.reset_for_new_run()
	_backpack.clear()
	if GameManager.has_method("get_starting_items"):
		_backpack.apply_starting_items(GameManager.get_starting_items())


func _toggle_backpack() -> void:
	if _run_ended:
		return
	# 背包始终可以打开，不受 NPC 对话影响
	if is_instance_valid(night_td) and night_td.visible:
		if _backpack_open:
			_close_backpack()
		return
	if not _is_exploration_allowed() and not _backpack_open:
		return
	if _backpack_open:
		_close_backpack()
	else:
		_open_backpack()


func _open_backpack(open_journal_tab: bool = false) -> void:
	if not is_instance_valid(_backpack_ui):
		return
	_backpack_open = true
	_backpack_ui.show_backpack(
		_backpack,
		_run_journal,
		open_journal_tab,
		_can_repair_vehicle_from_backpack(),
		_vehicle_hp,
		_vehicle_hp_max,
	)
	if is_instance_valid(time_system) and not _is_night_phase():
		time_system.pause()


func _open_journal() -> void:
	if _run_ended or _story_blocks_ui():
		return
	if is_instance_valid(night_td) and night_td.visible:
		return
	if not _is_exploration_allowed() and not _backpack_open:
		return
	if _backpack_open:
		_close_backpack()
		return
	_open_backpack(true)


func _close_backpack() -> void:
	_backpack_open = false
	if is_instance_valid(_backpack_ui):
		_backpack_ui.hide_backpack()
	if is_instance_valid(time_system) and not _game_paused and not _is_night_phase():
		time_system.resume()


func _on_backpack_closed() -> void:
	_backpack_open = false
	if is_instance_valid(time_system) and not _game_paused and not _is_night_phase():
		time_system.resume()


func _on_backpack_use_item(item_id: String) -> void:
	if not _use_backpack_item(item_id):
		return
	_refresh_backpack_if_open()
	_refresh_ui()


func _on_backpack_discard_item(item_id: String) -> void:
	if _backpack.remove(item_id, 1):
		_refresh_backpack_if_open()
		_refresh_ui()


func _on_backpack_craft_parts() -> void:
	var scrap_cost: int = ItemDefs.CRAFT_PARTS_SCRAP_COST
	var fuel_cost: int = ItemDefs.CRAFT_PARTS_FUEL_COST
	var parts_out: int = ItemDefs.CRAFT_PARTS_OUT

	if not _backpack.has("scrap", scrap_cost):
		print("[Craft] 废料不足（需 %d 个），无法合成零件。" % scrap_cost)
		return
	if fuel_cost > 0 and not _backpack.has("fuel", fuel_cost):
		print("[Craft] 燃料不足（需 %d 桶），无法合成零件。" % fuel_cost)
		return

	_backpack.remove("scrap", scrap_cost)
	if fuel_cost > 0:
		_backpack.remove("fuel", fuel_cost)
	_backpack.add("parts", parts_out)

	print("[Craft] 已将 %d 废料 + %d 燃料合成为 %d 零件。" % [scrap_cost, fuel_cost, parts_out])
	_refresh_backpack_if_open()
	_refresh_ui()


func _on_backpack_repair_vehicle() -> void:
	if _is_night_phase():
		return
	if not _can_repair_vehicle_from_backpack():
		_refresh_backpack_if_open()
		return
	if not _backpack.remove("parts", ItemDefs.VEHICLE_REPAIR_PARTS_EACH):
		return
	if not _backpack.remove("wood", ItemDefs.VEHICLE_REPAIR_WOOD_EACH):
		_backpack.add("parts", ItemDefs.VEHICLE_REPAIR_PARTS_EACH)
		return
	_vehicle_hp = minf(_vehicle_hp + ItemDefs.VEHICLE_REPAIR_HEAL_AMOUNT, _vehicle_hp_max)
	_refresh_backpack_if_open()
	_refresh_ui()
	print("[Repair] 车辆修复：消耗零件×%d + 木材×%d，恢复 %.0f 耐久。" % [
		ItemDefs.VEHICLE_REPAIR_PARTS_EACH,
		ItemDefs.VEHICLE_REPAIR_WOOD_EACH,
		ItemDefs.VEHICLE_REPAIR_HEAL_AMOUNT,
	])


func _use_backpack_item(item_id: String) -> bool:
	if not _backpack.has(item_id, 1):
		return false
	# 防御塔强化道具（Part B）：消耗式可叠加。安装即把 deltas 累加进 _tower_upgrades，
	# 夜晚建塔时生效。提示玩家本次强化效果与当前累计倍率。
	if NightTdUpgrades.is_upgrade_item(item_id):
		if NightTdUpgrades.apply_item(_tower_upgrades, item_id):
			_backpack.remove(item_id, 1)
			var eff := NightTdUpgrades.effect_text(item_id)
			var summary := NightTdUpgrades.summary_text(_tower_upgrades)
			_show_tower_upgrade_toast(
				"%s 已写入夜间防御系统：%s\n当前防御塔强化：%s" % [
					NightTdUpgrades.display_name(item_id), eff, summary
				]
			)
			return true
		return false
	match item_id:
		"supplies":
			_backpack.remove("supplies", 1)
			_survival.use_supplies()
			_check_low_stamina_warning()
			return true
		"fuel":
			_backpack.remove("fuel", 1)
			var fuel_recover := float(ItemDefs.get_def("fuel").get("restore_fuel", 140.0))
			_fuel = minf(_fuel + fuel_recover, fuel_max)
			_fuel_empty_prompt_open = false
			if is_instance_valid(_fuel_empty_dialog):
				_fuel_empty_dialog.hide()
			return true
		_:
			return false


## 防御塔强化安装提示（复用一个惰性创建的 AcceptDialog）。
func _show_tower_upgrade_toast(text: String) -> void:
	if not is_instance_valid(_tower_upgrade_dialog):
		_tower_upgrade_dialog = AcceptDialog.new()
		_tower_upgrade_dialog.name = "TowerUpgradeDialog"
		_tower_upgrade_dialog.title = "防御塔强化"
		_tower_upgrade_dialog.ok_button_text = "确认"
		var hud := get_node_or_null("HUD")
		if hud != null:
			hud.add_child(_tower_upgrade_dialog)
		else:
			add_child(_tower_upgrade_dialog)
	_tower_upgrade_dialog.dialog_text = text
	_tower_upgrade_dialog.popup_centered()


func _can_drive_with_current_fuel() -> bool:
	if fuel_per_pixel <= 0.0:
		return true
	if _fuel > FUEL_EMPTY_EPSILON:
		return true
	_fuel = 0.0
	if _backpack.has("fuel", 1):
		_show_empty_fuel_prompt()
	else:
		_trigger_out_of_fuel()
	return false


func _show_empty_fuel_prompt() -> void:
	if _fuel_empty_prompt_open:
		return
	_fuel_empty_prompt_open = true
	if not is_instance_valid(_fuel_empty_dialog):
		_open_backpack()
		return
	_fuel_empty_dialog.popup_centered()
	_refresh_ui()


func _on_fuel_empty_dialog_confirmed() -> void:
	_fuel_empty_prompt_open = false
	if _run_ended:
		return
	_open_backpack()
	_refresh_ui()


func _on_fuel_empty_dialog_closed() -> void:
	_fuel_empty_prompt_open = false


func _consume_repair_material() -> bool:
	if _backpack.has("parts", ItemDefs.REPAIR_PARTS_EACH):
		return _backpack.remove("parts", ItemDefs.REPAIR_PARTS_EACH)
	if _backpack.has("scrap", ItemDefs.REPAIR_SCRAP_EACH):
		return _backpack.remove("scrap", ItemDefs.REPAIR_SCRAP_EACH)
	if _backpack.has("wood", ItemDefs.REPAIR_WOOD_EACH) and _backpack.has("scrap", ItemDefs.REPAIR_SCRAP_ALT_EACH):
		return _backpack.remove("wood", ItemDefs.REPAIR_WOOD_EACH) and _backpack.remove("scrap", ItemDefs.REPAIR_SCRAP_ALT_EACH)
	return false


func _repair_button_label() -> String:
	if _backpack.has("parts", ItemDefs.REPAIR_PARTS_EACH) or _backpack.has("scrap", ItemDefs.REPAIR_SCRAP_EACH) or (_backpack.has("wood", ItemDefs.REPAIR_WOOD_EACH) and _backpack.has("scrap", ItemDefs.REPAIR_SCRAP_ALT_EACH)):
		return "修复电梯 (F · 自选材料)"
	return "修复电梯 (材料不足)"


func _tick_survival(delta: float) -> void:
	if not _is_exploration_allowed() or _is_night_phase():
		return
	_survival.tick(delta)


func _check_player_vitals_failure() -> void:
	if _run_ended or _survival.is_alive():
		return
	_run_ended = true
	_run_end_reason = "player_collapsed"
	if is_instance_valid(_player):
		_player.set_active(false)
	if is_instance_valid(_vehicle):
		_vehicle.set_active(false)
	_show_run_summary()


func _check_low_stamina_warning() -> void:
	if not is_instance_valid(low_stamina_warning):
		return
	var should_show := (
		_survival.stamina < 20.0
		and _survival.stamina > 0.0
		and _is_exploration_allowed()
		and not _is_night_phase()
		and not _run_ended
	)
	if should_show and not low_stamina_warning.visible:
		low_stamina_warning.show_warning()
	elif not should_show and low_stamina_warning.visible:
		low_stamina_warning.hide_warning()


func _inventory_summary() -> String:
	if _backpack.total_count() <= 0:
		return "空"
	var parts: PackedStringArray = []
	for entry in _backpack.get_sorted_entries():
		var id := str(entry["id"])
		parts.append("%s×%d" % [ItemDefs.get_item_name(id), int(entry["count"])])
	return " ".join(parts)


func _setup_stat_bars() -> void:
	var hud: CanvasLayer = $HUD
	if hud == null:
		return
	_vitals_top_bar = PanelContainer.new()
	_vitals_top_bar.name = "VitalsTopBar"
	HudTheme.apply_vitals_bar(_vitals_top_bar)
	hud.add_child(_vitals_top_bar)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", HudTheme.TOP_BAR_INNER)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", HudTheme.TOP_BAR_INNER)
	margin.add_theme_constant_override("margin_bottom", 6)
	_vitals_top_bar.add_child(margin)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	# 顶部横排：图标 + 中文名 + 彩色条 + 数字
	var specs: Array = [
		["⚡", "体力", "_stamina_bar", "_stamina_bar_label", HudTheme.desaturate(Color("#58d68d"))],
		["◎", "燃料", "_fuel_bar", "_fuel_bar_label", HudTheme.desaturate(Color("#f4d03f"))],
		["▲", "耐久", "_vehicle_hp_bar", "_vehicle_hp_bar_label", HudTheme.desaturate(Color("#bb8fce"))],
	]
	for spec in specs:
		var slot := _build_vital_slot(str(spec[0]), str(spec[1]), spec[4])
		var bar: ProgressBar = slot.get_node("VBox/ProgressBar")
		var value_lbl: Label = slot.get_node("VBox/ValueLabel")
		row.add_child(slot)
		match spec[2]:
			"_stamina_bar":
				_stamina_bar = bar
				_stamina_bar_label = value_lbl
			"_fuel_bar":
				_fuel_bar = bar
				_fuel_bar_label = value_lbl
			"_vehicle_hp_bar":
				_vehicle_hp_bar = bar
				_vehicle_hp_bar_label = value_lbl
	_update_stat_bars()


func _build_vital_slot(icon_text: String, title: String, fill_color: Color) -> HBoxContainer:
	var slot := HBoxContainer.new()
	slot.add_theme_constant_override("separation", 6)
	slot.alignment = BoxContainer.ALIGNMENT_BEGIN

	var icon_column := VBoxContainer.new()
	icon_column.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_column.add_theme_constant_override("separation", 2)

	var icon_bg := PanelContainer.new()
	icon_bg.custom_minimum_size = Vector2(28, 28)
	var icon_box := StyleBoxFlat.new()
	icon_box.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	icon_box.set_corner_radius_all(4)
	icon_bg.add_theme_stylebox_override("panel", icon_box)
	var icon := Label.new()
	icon.text = icon_text
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.add_theme_font_size_override("font_size", 16)
	icon.add_theme_color_override("font_color", fill_color)
	icon.set_meta("hud_glyph", true)
	HudTheme.apply_glyph_label(icon)
	icon_bg.add_child(icon)
	icon_column.add_child(icon_bg)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 9)
	title_lbl.add_theme_color_override("font_color", Color("#a8bcc8"))
	HudTheme.apply_label(title_lbl)
	icon_column.add_child(title_lbl)
	slot.add_child(icon_column)

	var column := VBoxContainer.new()
	column.name = "VBox"
	column.add_theme_constant_override("separation", 2)
	column.custom_minimum_size = Vector2(108, 0)

	var bar := ProgressBar.new()
	bar.name = "ProgressBar"
	bar.custom_minimum_size = Vector2(108, 12)
	bar.max_value = 100.0
	bar.show_percentage = false
	_apply_vital_bar_theme(bar, fill_color)
	column.add_child(bar)

	var value_lbl := Label.new()
	value_lbl.name = "ValueLabel"
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_lbl.add_theme_font_size_override("font_size", 11)
	value_lbl.add_theme_color_override("font_color", Color("#d8e4f0"))
	HudTheme.apply_label(value_lbl)
	column.add_child(value_lbl)

	slot.add_child(column)
	return slot


func _apply_vital_bar_theme(bar: ProgressBar, fill_color: Color) -> void:
	HudTheme.apply_progress_bar(bar, fill_color)


func _update_stat_bars() -> void:
	_set_bar(_stamina_bar, _stamina_bar_label, _survival.stamina, PlayerSurvival.STAMINA_MAX)
	_set_bar(_fuel_bar, _fuel_bar_label, _fuel, fuel_max)
	_set_bar(_vehicle_hp_bar, _vehicle_hp_bar_label, _vehicle_hp, _vehicle_hp_max)


func _set_bar(bar: ProgressBar, label: Label, current: float, maximum: float) -> void:
	if not is_instance_valid(bar) or not is_instance_valid(label):
		return
	var max_v := maxf(maximum, 1.0)
	bar.max_value = max_v
	bar.value = clampf(current, 0.0, max_v)
	label.text = "%d/%d" % [int(round(current)), int(round(max_v))]


func _setup_run_end_ui() -> void:
	_run_end_overlay = RunEndOverlayScript.new()
	add_child(_run_end_overlay)
	_run_end_overlay.ceremony_choice_made.connect(_on_final_ceremony_choice)
	_run_end_overlay.summary_closed.connect(_on_run_summary_closed)
	_communication_terminal = CommunicationTerminalScript.new()
	add_child(_communication_terminal)
	_communication_terminal.strike_completed.connect(_on_terminal_strike)
	_communication_terminal.transfer_completed.connect(_on_terminal_transfer)
	_ending_outcome_overlay = EndingOutcomeOverlayScript.new()
	add_child(_ending_outcome_overlay)
	_ending_outcome_overlay.closed.connect(_on_ending_outcome_closed)
	_start_guide_overlay = StartGuideOverlayScript.new()
	add_child(_start_guide_overlay)
	_start_guide_overlay.guide_closed.connect(_on_start_guide_closed)


func _check_vehicle_destroyed() -> bool:
	if _run_ended:
		return true
	if _vehicle_hp > 0.0:
		return false
	_trigger_vehicle_destroyed()
	return true


func _trigger_vehicle_destroyed() -> void:
	if _run_ended:
		return
	_run_ended = true
	_run_end_reason = "vehicle_destroyed"
	_freeze_run_for_end()
	_show_run_summary()


func _trigger_out_of_fuel() -> void:
	if _run_ended:
		return
	_fuel = 0.0
	_fuel_empty_prompt_open = false
	if is_instance_valid(_fuel_empty_dialog):
		_fuel_empty_dialog.hide()
	_run_ended = true
	_run_end_reason = "out_of_fuel"
	_freeze_run_for_end()
	_show_run_summary()


func _begin_final_ceremony() -> void:
	if _run_ended:
		return
	_run_ended = true
	_run_end_reason = "reached_top"
	_freeze_run_for_end()
	_play_music_cue("truth_reveal", 1.0)
	if is_instance_valid(_run_end_overlay):
		_run_end_overlay.show_ceremony()


func _request_terminal_access() -> void:
	if _run_ended:
		return
	if not _thunder_leiting_defeated:
		return
	_final_defense_cleared = true
	_thunder_terminal_sequence_active = true
	_pause_day_night_for_terminal_sequence()
	_open_communication_terminal()


func _on_thunder_boss_requested(district_index: int) -> void:
	_pending_thunder_district = district_index
	_thunder_terminal_sequence_active = true
	_pause_day_night_for_terminal_sequence()
	_start_thunder_leiting_boss()


func _thunder_leiting_session_options() -> Dictionary:
	return {
		"kind": "thunder_leiting_boss",
		"wave_plan_path": THUNDER_LEITING_WAVE_PATH,
		"phase_title": "不败之盾-雷霆",
		"no_day_advance": true,
		"tower_upgrades": _tower_upgrades.duplicate(true),
	}


func _start_thunder_leiting_boss() -> void:
	DayTopdownRender.reload_thunder_boss_sprites()
	_hide_exploration_story_ui()
	_force_return_to_vehicle_for_night()
	if is_instance_valid(time_system):
		time_system.pause()
	if is_instance_valid(evening_notice) and evening_notice.has_method("hide_notice"):
		evening_notice.hide_notice()
	var snapshot: Dictionary = {}
	if is_instance_valid(_backpack) and _backpack.has_method("to_dictionary"):
		snapshot = _backpack.to_dictionary().duplicate()
	var options := _thunder_leiting_session_options()
	if is_instance_valid(night_defense) and is_instance_valid(night_td):
		_night_result_applied = false
		night_defense.start_td_session(
			_backpack.total_count(),
			GameManager.difficulty,
			time_system.day_index if is_instance_valid(time_system) else 1,
			true,
			_vehicle_hp,
			_vehicle_hp_max,
			snapshot,
			options,
			_fuel,
			fuel_max
		)
		_refresh_ui()
		return
	var rs = export_run_state()
	rs.backpack_dict = snapshot
	rs.night_context = "thunder_leiting_boss"
	rs.night_session_options = options
	GameManager.request_night_defense(rs, options)


func _apply_thunder_leiting_victory() -> void:
	_thunder_leiting_defeated = true
	_final_defense_cleared = true
	_thunder_terminal_sequence_active = true
	_pause_day_night_for_terminal_sequence()
	_backpack.add("composite_armor_panel", 3)
	_backpack.add("auto_turret_auth", 3)
	var recognition := "enemy"
	if is_instance_valid(_story_controller):
		recognition = _story_controller.run_state.get_variable(
			"thunder_leiting",
			"thunder_recognition",
			"enemy",
		)
	var encounter_id := (
		"thunder_leiting_victory_ally"
		if str(recognition) == "ally"
		else "thunder_leiting_victory_enemy"
	)
	var day_n := time_system.day_index if is_instance_valid(time_system) else 1
	if _run_journal.add_story_outcome(encounter_id, _current_layer, day_n):
		_on_journal_entry_added(encounter_id)
	_refresh_backpack_if_open()


func _trigger_thunder_defeat_end() -> void:
	if _run_ended:
		return
	_run_ended = true
	_run_end_reason = "thunder_leiting"
	_freeze_run_for_end()
	_show_run_summary()


func _open_communication_terminal() -> void:
	if _run_ended:
		return
	_thunder_terminal_sequence_active = true
	_pause_day_night_for_terminal_sequence()
	if not is_instance_valid(_communication_terminal):
		_begin_final_ceremony()
		return
	var day_n := time_system.day_index if is_instance_valid(time_system) else 1
	_play_music_cue("terminal", 0.9)
	var snapshot := _backpack.to_dictionary() if is_instance_valid(_backpack) and _backpack.has_method("to_dictionary") else {}
	_communication_terminal.start_flow(_run_journal.get_entries(), _current_layer, day_n, snapshot)


func _should_pause_day_night_for_terminal_sequence() -> bool:
	return (
		_thunder_terminal_sequence_active
		or (
			_current_layer >= total_layers
			and _thunder_leiting_defeated
			and not _run_ended
		)
	)


func _pause_day_night_for_terminal_sequence() -> void:
	if is_instance_valid(time_system):
		time_system.pause()


func _on_terminal_strike() -> void:
	if _run_ended:
		return
	MetaManager.save_meta()
	_run_ended = true
	_run_end_reason = "strike"
	_freeze_run_for_end()
	if is_instance_valid(_communication_terminal):
		_communication_terminal.hide_terminal()
	_show_run_summary()


func _on_terminal_transfer() -> void:
	if _run_ended:
		return
	MetaManager.management_rights_transferred = true
	MetaManager.save_meta()
	if is_instance_valid(_communication_terminal):
		_communication_terminal.hide_terminal()
	_begin_final_ceremony()


func _freeze_run_for_end() -> void:
	_game_paused = false
	if is_instance_valid(_pause_layer):
		_pause_layer.visible = false
	if is_instance_valid(_fuel_empty_dialog):
		_fuel_empty_dialog.hide()
	if is_instance_valid(time_system):
		time_system.pause()
	if is_instance_valid(night_defense):
		night_defense.hide_td_session()
	if is_instance_valid(evening_notice) and evening_notice.has_method("hide_notice"):
		evening_notice.hide_notice()
	if is_instance_valid(_player):
		_player.set_active(false)
	if is_instance_valid(_vehicle):
		_vehicle.set_active(true)


func _on_final_ceremony_choice(choice_id: String) -> void:
	_final_choice_id = choice_id
	_play_music_cue("final_choice", 0.9)
	MetaManager.record_ending(choice_id)
	MetaManager.save_meta()
	if is_instance_valid(_ending_outcome_overlay):
		var day_n := time_system.day_index if is_instance_valid(time_system) else 1
		_ending_outcome_overlay.show_outcome(choice_id, _current_layer, day_n)
		return
	_show_run_summary()

func _on_ending_outcome_closed() -> void:
	if is_instance_valid(_ending_outcome_overlay):
		_ending_outcome_overlay.hide_overlay()
	_show_run_summary()


func _on_start_guide_closed() -> void:
	if is_instance_valid(_start_guide_overlay):
		_start_guide_overlay.hide_overlay()


func _show_run_summary() -> void:
	if not is_instance_valid(_run_end_overlay):
		return
	var title := ""
	match _run_end_reason:
		"vehicle_destroyed":
			title = "本局结束 · 车辆损毁"
		"player_collapsed":
			title = "本局结束 · 乘员倒下"
		"out_of_fuel":
			title = "本局结束 · 燃料耗尽"
		"reached_top":
			title = "本局结算 · 归档完成"
		"strike":
			title = "本局结束 · 通讯被打击"
		"furnace_consumed":
			title = "本局结束 · 熔炉销毁"
		"thunder_leiting":
			title = "游戏结束 · 最后的防线"
		_:
			title = "本局结算"
	var summary_data := _build_run_summary_data(title)
	_run_end_overlay.show_summary(summary_data)


func _build_run_summary_data(title: String) -> Dictionary:
	var day_n := 1
	if is_instance_valid(time_system):
		day_n = time_system.day_index
	var stats: Array = [
		{"label": "难度", "value": _run_difficulty_name},
		{"label": "分队", "value": _run_squad_name},
		{"label": "抵达层数", "value": "%d / %d" % [_current_layer, total_layers]},
		{"label": "生存天数", "value": "%d" % day_n},
		{"label": "车辆耐久", "value": "%.0f / %.0f" % [_vehicle_hp, _vehicle_hp_max]},
		{"label": "体力", "value": "%.0f" % _survival.stamina},
		{"label": "燃料", "value": "%.1f" % _fuel},
		{"label": "地图探索", "value": "%d / %d 格" % [_map.explored_count(), _map.cells.size()]},
	]
	if not _last_night_losses.is_empty():
		stats.append({"label": "夜间损耗", "value": "、".join(_last_night_losses)})
	if _last_night_salvage != "":
		stats.append({"label": "夜间回收", "value": _last_night_salvage})

	var inventory: Array = []
	for entry in _backpack.get_sorted_entries():
		var item_id := str(entry["id"])
		var count := int(entry["count"])
		if item_id == "" or count <= 0:
			continue
		inventory.append({"id": item_id, "count": count})

	var log_lines: PackedStringArray = []
	if _run_end_reason == "vehicle_destroyed":
		log_lines.append("车辆在夜间防线崩溃后失去作战能力。")
		log_lines.append("昆仑程序将判定本次勘探失败，新的克隆体即将被派遣。")
	elif _run_end_reason == "player_collapsed":
		log_lines.append("体力耗尽，乘员已无法继续行动。")
		log_lines.append("本局勘探失败，新的克隆体即将被派遣。")
	elif _run_end_reason == "out_of_fuel":
		log_lines.append("车辆燃料耗尽，背包中也没有可用燃料桶。")
		log_lines.append("本局勘探停在荒路上，新的克隆体即将被派遣。")
	elif _run_end_reason == "strike":
		log_lines.append("通讯终端身份验证未通过，昆仑程序对本次勘探实施打击。")
		log_lines.append("本局失败；与终端的接触已被记录，新的克隆体即将被派遣。")
	elif _run_end_reason == "furnace_consumed":
		log_lines.append("熔炉判定你为战时残次品，执行了销毁程序。")
	elif _run_end_reason == "thunder_leiting":
		var recognition := "enemy"
		if is_instance_valid(_story_controller):
			recognition = str(
				_story_controller.run_state.get_variable("thunder_leiting", "thunder_recognition", "enemy")
			)
		if recognition == "ally":
			log_lines.append("你倒在不败之盾面前。它最后说：「你是个好兵。但规矩……就是规矩。」")
		else:
			log_lines.append("你倒在不败之盾面前。它最后说：「敌人。这就是结局。」")
		log_lines.append("它会记住你，像它记住那道永远不会来的指令一样。")
		log_lines.append("昆仑程序已记录本次勘探失败，正在培育下一名克隆体。")
	elif _run_end_reason == "reached_top":
		log_lines.append("你已抵达顶层并完成归档仪式。")
		if _final_choice_id != "":
			log_lines.append("最终抉择: %s" % RunEndingDefs.choice_title(_final_choice_id))
			log_lines.append(RunEndingDefs.choice_summary(_final_choice_id))
		match _final_choice_id:
			"stop_signal":
				log_lines.append("终止信号已发送。克隆循环停止。")
				log_lines.append("（真结局 · 制作人员名单）")
			"message_only":
				log_lines.append("未发送终止信号。程序将继续运转。")
			"fake_success":
				log_lines.append("虚假成功信号已注入。循环以讽刺的方式停摆。")

	var is_failure := _run_end_reason in [
		"vehicle_destroyed",
		"player_collapsed",
		"out_of_fuel",
		"strike",
		"furnace_consumed",
		"thunder_leiting",
	]
	return {
		"title": title,
		"is_failure": is_failure,
		"stats": stats,
		"inventory": inventory,
		"log_lines": log_lines,
	}


func _on_run_summary_closed() -> void:
	if SaveManager.has_save():
		SaveManager.delete_save()
	if is_instance_valid(_run_end_overlay):
		_run_end_overlay.hide_overlay()
	GameManager.go_to_main_menu()


func _toggle_pause() -> void:
	if _run_ended:
		return
	if _pause_confirm != null and _pause_confirm.visible:
		return
	if _game_paused:
		_resume_from_pause()
	else:
		_pause_game()


func _pause_game() -> void:
	if _backpack_open:
		_close_backpack()
	_game_paused = true
	if is_instance_valid(_pause_layer):
		_pause_layer.visible = true
	if is_instance_valid(time_system) and not time_system.is_paused():
		time_system.pause()
	# 夜晚塔防会话自走一套 _process（战斗计时、刷怪、敌人移动、炮塔开火），
	# 不受 time_system 暂停影响，必须显式冻结，否则按 ESC 后夜晚仍在流逝。
	if is_instance_valid(night_td):
		night_td.set_session_paused(true)


func _resume_from_pause() -> void:
	_game_paused = false
	if is_instance_valid(_pause_layer):
		_pause_layer.visible = false
	if is_instance_valid(night_td):
		night_td.set_session_paused(false)
	if is_instance_valid(time_system):
		if _is_night_phase():
			time_system.pause()
		elif _should_pause_day_night_for_terminal_sequence():
			time_system.pause()
		else:
			time_system.resume()


func _load_travel_inventory(travel: Dictionary) -> void:
	_backpack.clear()
	_survival.reset_for_new_run()
	if travel.has("items"):
		_backpack.load_from_dictionary(travel["items"])
	elif travel.has("inventory"):
		var legacy_count := int(travel.get("inventory", 0))
		if legacy_count > 0:
			_backpack.add("scrap", legacy_count)
	if travel.has("survival"):
		_survival.load_from_dictionary(travel["survival"])


## 从 RunState 恢复全部状态（场景切换后初始化）。
func init_from_run_state(rs) -> void:
	if rs == null:
		return
	var should_open_terminal := bool(rs.pending_open_terminal)
	var save_data: Dictionary = rs.to_full_dict()
	_apply_save_data(save_data)
	# 恢复 RunState 特有字段（不在 save_data 中的）
	_last_night_losses.clear()
	for s in rs.last_night_losses:
		_last_night_losses.append(s)
	_last_night_salvage = rs.last_night_salvage
	_run_difficulty_name = rs.run_difficulty_name
	_run_squad_name = rs.run_squad_name
	_final_defense_cleared = rs.final_defense_cleared
	_thunder_leiting_defeated = rs.thunder_leiting_defeated
	_thunder_terminal_sequence_active = rs.thunder_terminal_sequence_active
	GameManager.difficulty = rs.difficulty
	GameManager.squad_id = rs.squad_id
	_apply_run_config_from_manager()
	_vehicle_hp_max = _get_vehicle_hp_max()
	_vehicle_hp = clampf(_vehicle_hp, 0.0, _vehicle_hp_max)
	if is_instance_valid(minimap_view):
		minimap_view.set_world_map(_map)
		minimap_view.set_war_fog_enabled(war_fog_enabled)
	_sync_day_entity_visibility()
	# 恢复时间（如果 RunState 指定了 phase，则跳到对应阶段）
	if is_instance_valid(time_system) and not rs.time_dict.is_empty():
		time_system.load_from_dictionary(rs.time_dict)
		_restore_time_phase_after_load(should_open_terminal)
	_sync_minimap_navigation()
	_refresh_ui()
	if should_open_terminal:
		rs.pending_open_terminal = false
		call_deferred("_open_communication_terminal")
	queue_redraw()


## 导出当前全部状态为 RunState（用于场景切换前保存）。
func export_run_state():
	var rs = RunStateClass.new()
	# 通过 save 格式捕获（已有完整的序列化逻辑）
	var save_data: Dictionary = capture_save_data()
	rs.from_full_dict(save_data)
	# 补充 RunState 特有字段
	rs.total_layers = total_layers
	rs.run_difficulty_name = _run_difficulty_name
	rs.run_squad_name = _run_squad_name
	rs.final_defense_cleared = _final_defense_cleared
	rs.thunder_leiting_defeated = _thunder_leiting_defeated
	rs.thunder_terminal_sequence_active = _thunder_terminal_sequence_active
	rs.last_night_losses.clear()
	for s in _last_night_losses:
		rs.last_night_losses.append(s)
	rs.last_night_salvage = _last_night_salvage
	return rs


func capture_save_data() -> Dictionary:
	var player_pos := Vector2.ZERO
	if is_instance_valid(_player):
		player_pos = _player.global_position
	return {
		"difficulty": GameManager.difficulty,
		"squad_id": GameManager.squad_id,
		"fuel_max": fuel_max,
		"vehicle_hp": _vehicle_hp,
		"vehicle_hp_max": _vehicle_hp_max,
		"base_elevator_repair_cost": _base_elevator_repair_cost,
		"map": _map.to_dictionary(),
		"travel": {
			"mode": _mode,
			"fuel": _fuel,
			"items": _backpack.to_dictionary(),
			"survival": _survival.to_dictionary(),
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
			"final_defense_cleared": _final_defense_cleared,
			"thunder_leiting_defeated": _thunder_leiting_defeated,
			"thunder_terminal_sequence_active": _thunder_terminal_sequence_active,
			"run_ended": _run_ended,
			"run_end_reason": _run_end_reason,
			"final_choice_id": _final_choice_id,
			"tower_upgrades": _tower_upgrades.duplicate(true),
		},
		"time": time_system.to_dictionary() if is_instance_valid(time_system) else {},
		"foot": {
			"player_x": player_pos.x,
			"player_y": player_pos.y,
		},
		"journal": _run_journal.to_array(),
		"stories": _story_controller.to_save_dict(),
	}


func _apply_save_data(data: Dictionary) -> void:
	GameManager.difficulty = int(data.get("difficulty", GameManager.Difficulty.NORMAL))
	GameManager.squad_id = str(data.get("squad_id", "scavenger"))
	fuel_max = float(data.get("fuel_max", _base_fuel_max))
	_vehicle_hp_max = float(data.get("vehicle_hp_max", _get_vehicle_hp_max()))
	_vehicle_hp = clampf(float(data.get("vehicle_hp", _vehicle_hp_max)), 0.0, _vehicle_hp_max)
	_base_elevator_repair_cost = int(data.get("base_elevator_repair_cost", base_elevator_repair_cost))
	_apply_run_config_from_manager()
	_vehicle_hp_max = _get_vehicle_hp_max()
	_vehicle_hp = clampf(_vehicle_hp, 0.0, _vehicle_hp_max)

	_map.load_from_dictionary(data.get("map", {}))
	_run_journal = RunJournal.new()
	_run_journal.load_from_array(data.get("journal", []))
	var stories_save: Dictionary = data.get("stories", {})
	if stories_save.is_empty() and data.has("sentinel"):
		stories_save = _migrate_sentinel_save_to_stories(data.get("sentinel", {}))
	_story_controller.load_save_dict(stories_save)
	var travel: Dictionary = data.get("travel", {})
	_mode = int(travel.get("mode", TravelMode.DRIVE))
	_fuel = float(travel.get("fuel", fuel_max))
	_load_travel_inventory(travel)
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
	StoryData.ensure_story_districts(_map, _current_layer)
	_elevator_repair_progress = int(layer.get("elevator_repair_progress", 0))
	_final_defense_cleared = bool(layer.get("final_defense_cleared", false))
	_thunder_leiting_defeated = bool(layer.get("thunder_leiting_defeated", false))
	_thunder_terminal_sequence_active = bool(layer.get("thunder_terminal_sequence_active", false))
	if _final_defense_cleared and not _thunder_leiting_defeated:
		_thunder_leiting_defeated = true
	if _thunder_leiting_defeated:
		_final_defense_cleared = true
		_thunder_terminal_sequence_active = true
	_run_ended = bool(layer.get("run_ended", false))
	_run_end_reason = str(layer.get("run_end_reason", ""))
	_final_choice_id = str(layer.get("final_choice_id", ""))
	_tower_upgrades = NightTdUpgrades.sanitize(layer.get("tower_upgrades", {}))
	if _run_ended and _run_end_reason in ["vehicle_destroyed", "player_collapsed", "out_of_fuel", "strike"]:
		_show_run_summary()
	elif _run_ended and _run_end_reason == "reached_top":
		if _final_choice_id != "":
			_show_run_summary()
		else:
			_begin_final_ceremony()

	if is_instance_valid(time_system):
		time_system.load_from_dictionary(data.get("time", {}))

	_spawn_resources()
	_story_controller.restore_after_load()
	_refresh_resource_pickups()
	if is_instance_valid(minimap_view):
		minimap_view.set_world_map(_map)
		minimap_view.set_war_fog_enabled(war_fog_enabled)

	if _mode == TravelMode.FOOT:
		_restore_foot_mode_from_save(data.get("foot", {}))
	else:
		if is_instance_valid(_player):
			_player.set_active(false)
		if is_instance_valid(_vehicle):
			_vehicle.set_active(true)
		_restore_drive_state_after_load()

	_sync_day_entity_visibility()
	_restore_time_phase_after_load()
	_apply_overworld_biome_for_layer()
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
		_player.set_physics_process(false)
		_map.ensure_foot_layout(_current_district_index)
		var foot_origin := _map.get_foot_origin(_current_district_index)
		_foot_local_pos = Vector2(float(foot.get("player_x", 0.0)), float(foot.get("player_y", 0.0))) - foot_origin
		if foot.has("player_x"):
			_apply_foot_world_position()
		else:
			var door_world := _map.get_foot_door_world_pos(_current_district_index)
			_foot_local_pos = door_world - foot_origin
			_apply_foot_world_position()
	for node in _resource_nodes:
		if is_instance_valid(node):
			node.visible = int(node.get_meta("district_index", -1)) == _current_district_index
	_sync_day_entity_visibility()
	if is_instance_valid(_story_controller):
		var sid := _story_controller.story_id_of_district(_current_district_index)
		if sid == "" or (
			not _story_controller.run_state.is_quest_active(sid)
			and not _story_controller.run_state.is_completed(sid)
		):
			_story_controller.ensure_interior_encounter_at(_current_district_index)
	_refresh_ui()


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


func _restore_time_phase_after_load(keep_terminal_music: bool = false) -> void:
	if not is_instance_valid(time_system):
		return
	match time_system.phase:
		TimeSystem.Phase.NIGHT_SETUP:
			_force_return_to_vehicle_for_night()
			if is_instance_valid(night_defense):
				var snapshot: Dictionary = {}
				if is_instance_valid(_backpack) and _backpack.has_method("to_dictionary"):
					snapshot = _backpack.to_dictionary().duplicate()
				night_defense.start_td_session(
					_backpack.total_count(), GameManager.difficulty, time_system.day_index, true,
					_vehicle_hp, _vehicle_hp_max, snapshot,
					{"tower_upgrades": _tower_upgrades.duplicate(true)}, _fuel, fuel_max
				)
			_play_music_cue("night_setup", 0.9)
			time_system.pause()
		TimeSystem.Phase.NIGHT_RESOLVE:
			time_system.finish_night_and_advance_day()
		TimeSystem.Phase.EVENING:
			if _should_pause_day_night_for_terminal_sequence():
				time_system.pause()
			else:
				time_system.resume()
			if is_instance_valid(evening_notice) and evening_notice.has_method("show_evening_warning"):
				evening_notice.show_evening_warning(time_system.get_day_remaining_sec())
			if is_instance_valid(low_stamina_warning) and low_stamina_warning.has_method("hide_warning"):
				low_stamina_warning.hide_warning()
			if not keep_terminal_music:
				_play_music_cue("day_exploration", 1.0)
		_:
			if _should_pause_day_night_for_terminal_sequence():
				time_system.pause()
			else:
				time_system.resume()
			if is_instance_valid(evening_notice):
				evening_notice.hide_notice()
			if not keep_terminal_music:
				_play_music_cue("day_exploration", 1.0)


func _refresh_resource_pickups() -> void:
	for node in _resource_nodes:
		if not is_instance_valid(node) or not node.has_meta("district_index"):
			continue
		var district_index := int(node.get_meta("district_index"))
		var show_map_loot := (
			_mode == TravelMode.FOOT
			and district_index == _current_district_index
			and not bool(node.get_meta("picked_up", false))
			and not (
				is_instance_valid(_story_controller)
				and _story_controller.should_hide_map_loot(district_index)
			)
		)
		node.visible = show_map_loot
		var pickup_label := node.get_node_or_null("Label") as Label
		if is_instance_valid(pickup_label):
			var show_name := false
			if node.visible and _current_district_index >= 0:
				var foot_origin := _map.get_foot_origin(_current_district_index)
				show_name = _should_show_loot_label_at(node.global_position - foot_origin)
			pickup_label.visible = show_name
			if show_name:
				pickup_label.add_theme_font_size_override("font_size", 10)
				HudTheme.apply_label(pickup_label)
	_story_controller.refresh_quest_pickups(_mode == TravelMode.FOOT, _current_district_index)
	_story_controller.refresh_unlocked_loot(_mode == TravelMode.FOOT, _current_district_index)


func _should_show_loot_label_at(local_pos: Vector2) -> bool:
	if Input.is_key_pressed(KEY_ALT):
		return true
	return local_pos.distance_to(_foot_local_pos) <= 40.0


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
	if is_instance_valid(time_hud) and time_hud.has_method("set_layer"):
		time_hud.set_layer(_current_layer, total_layers)
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


func _music_manager() -> Node:
	return get_tree().root.get_node_or_null("MusicManager") if get_tree() != null else null


func _play_music_cue(cue_id: String, fade_sec: float = -1.0, restart: bool = false) -> void:
	var music := _music_manager()
	if music != null and music.has_method("play_cue"):
		music.play_cue(cue_id, fade_sec, restart)


func _play_music_stinger(cue_id: String, volume_db: float = INF) -> void:
	var music := _music_manager()
	if music != null and music.has_method("play_stinger"):
		music.play_stinger(cue_id, volume_db)


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
	if is_instance_valid(low_stamina_warning) and low_stamina_warning.has_method("hide_warning"):
		low_stamina_warning.hide_warning()
	_play_music_stinger("evening_warning", -11.0)


func _on_night_setup_started(day_index: int, manual_setup: bool) -> void:
	_night_result_applied = false
	_force_return_to_vehicle_for_night()
	if is_instance_valid(time_system):
		time_system.pause()
	if is_instance_valid(evening_notice) and evening_notice.has_method("hide_notice"):
		evening_notice.hide_notice()
	if is_instance_valid(night_defense):
		# 传入背包快照（字典），而非 live 引用，切断耦合
		var snapshot: Dictionary = {}
		if is_instance_valid(_backpack) and _backpack.has_method("to_dictionary"):
			snapshot = _backpack.to_dictionary().duplicate()
		night_defense.start_td_session(
			_backpack.total_count(), GameManager.difficulty, day_index, manual_setup,
			_vehicle_hp, _vehicle_hp_max, snapshot,
			{"tower_upgrades": _tower_upgrades.duplicate(true)}, _fuel, fuel_max
		)
	_play_music_cue("night_setup", 1.0)
	_refresh_ui()
	_maybe_show_night_tutorial()


## 首次进入夜晚布防时弹出图文教程；看过后由 MetaManager 记住不再自动弹出。
func _maybe_show_night_tutorial(force: bool = false) -> void:
	var meta := get_node_or_null("/root/MetaManager")
	if not force and meta != null and bool(meta.get("night_tutorial_seen")):
		return
	if is_instance_valid(_night_tutorial):
		return
	_night_tutorial = NightTutorialOverlay.new()
	_night_tutorial.name = "NightTutorialOverlay"
	var hud := get_node_or_null("HUD")
	if hud != null:
		hud.add_child(_night_tutorial)
	else:
		add_child(_night_tutorial)
	_night_tutorial.finished.connect(func():
		_night_tutorial = null
		var m := get_node_or_null("/root/MetaManager")
		if m != null and m.has_method("mark_night_tutorial_seen"):
			m.mark_night_tutorial_seen()
	)


func on_td_combat_ended(result: Dictionary) -> String:
	_night_result_applied = true
	_apply_night_result(result)
	return _format_night_loss_summary()


func _format_night_loss_summary() -> String:
	if _last_night_losses.is_empty():
		return ""
	var loss_counts: Dictionary = {}
	for item_name in _last_night_losses:
		loss_counts[item_name] = int(loss_counts.get(item_name, 0)) + 1
	var parts: PackedStringArray = []
	for item_name in loss_counts:
		parts.append("%s ×%d" % [item_name, int(loss_counts[item_name])])
	return "\n\n物资损耗：\n  %s" % ", ".join(parts)


func _on_night_td_finished(result: Dictionary) -> void:
	if is_instance_valid(night_defense):
		night_defense.hide_td_session()
	if not _night_result_applied:
		_apply_night_result(result)
	_night_result_applied = false
	if _check_vehicle_destroyed():
		return
	var kind := str(result.get("kind", "normal"))
	if kind == "thunder_leiting_boss":
		var outcome := str(result.get("outcome", "success"))
		if outcome == "success":
			_apply_thunder_leiting_victory()
			_pause_day_night_for_terminal_sequence()
			var district := _pending_thunder_district
			_pending_thunder_district = -1
			_refresh_ui()
			_mark_overworld_dirty()
			if district >= 0:
				call_deferred("_begin_foot_mode", district)
		else:
			_pending_thunder_district = -1
			_trigger_thunder_defeat_end()
		return
	if is_instance_valid(time_system):
		time_system.finish_night_and_advance_day()
	_refresh_ui()


func _apply_night_result(result: Dictionary) -> void:
	_survival.apply_night_defense_outcome(str(result.get("outcome", "success")))
	_fuel = maxf(_fuel - float(result.get("fuel_loss", 0.0)), 0.0)
	if result.has("base_hp"):
		_vehicle_hp = clampf(float(result.get("base_hp", _vehicle_hp)), 0.0, _vehicle_hp_max)
	if result.has("base_hp_max"):
		_vehicle_hp_max = float(result.get("base_hp_max", _vehicle_hp_max))
		_vehicle_hp = clampf(_vehicle_hp, 0.0, _vehicle_hp_max)
	# 记录损失明细（用于结算 UI）
	_last_night_losses.clear()
	_last_night_salvage = ""
	var breach_losses: Variant = result.get("breach_losses", {})
	var breach_total: int = int(result.get("breach_total", 0))
	if breach_total > 0 and breach_losses is Dictionary:
		for item_id: String in (breach_losses as Dictionary).keys():
			var n := int((breach_losses as Dictionary)[item_id])
			if n > 0:
				_last_night_losses.append("%s×%d" % [ItemDefs.get_item_name(str(item_id)), n])
	else:
		# 旧模式兼容：无真实背包时的随机损耗
		var severity: String = str(result.get("loss_severity", "none"))
		var outcome: String = str(result.get("outcome", "success"))
		if outcome == "vehicle_destroyed":
			severity = "total"
		var inv_loss: int = int(result.get("inventory_loss", 0))
		if severity != "none" or inv_loss > 0:
			_remove_backpack_items_for_night(inv_loss, severity)
		if result.has("salvage") and not (result["salvage"] as Dictionary).is_empty():
			_apply_night_salvage(result["salvage"])
	# 新接口：最终背包快照（包含所有建造消耗、突破损失、夜末回收的最终结果）
	if result.has("final_backpack_dict") and not result["final_backpack_dict"].is_empty():
		if is_instance_valid(_backpack) and _backpack.has_method("load_from_dictionary"):
			_backpack.load_from_dictionary(result["final_backpack_dict"])
		# 生成回收文本
		var salvage: Variant = result.get("salvage", {})
		if salvage is Dictionary and not salvage.is_empty():
			var added: Array[String] = []
			for item_id: String in (salvage as Dictionary).keys():
				var amount := int((salvage as Dictionary)[item_id])
				if amount > 0:
					added.append("%s×%d" % [ItemDefs.get_item_name(str(item_id)), amount])
			if not added.is_empty():
				_last_night_salvage = "夜末回收：" + "、".join(added)


## 把夜末结算的回收物资加入背包，并记录用于结算文本。
func _apply_night_salvage(salvage: Variant) -> void:
	if not (salvage is Dictionary) or (salvage as Dictionary).is_empty():
		return
	var added: Array[String] = []
	for item_id: String in (salvage as Dictionary).keys():
		var amount := int((salvage as Dictionary)[item_id])
		if amount <= 0:
			continue
		var got := _backpack.add(str(item_id), amount)
		if got > 0:
			added.append("%s×%d" % [ItemDefs.get_item_name(str(item_id)), got])
	if not added.is_empty():
		_last_night_salvage = "夜末回收：" + "、".join(added)


func _remove_backpack_items_for_night(loss_count: int, severity: String) -> void:
	if _backpack.total_count() <= 0:
		return
	var entries := _backpack.get_sorted_entries()
	var material_entries: Array[Dictionary] = []
	for entry in entries:
		if not str(entry["id"]).begins_with("evidence:"):
			material_entries.append(entry)
	if material_entries.is_empty():
		return
	var total_loss := mini(loss_count, _backpack.total_count())
	if total_loss <= 0:
		match severity:
			"partial":
				total_loss = randi_range(1, 2)
			"severe":
				total_loss = randi_range(3, 5)
			"total":
				for entry in material_entries:
					total_loss += int(entry["count"])
		total_loss = mini(total_loss, _backpack.total_count())
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _i in range(total_loss):
		if material_entries.is_empty():
			break
		var idx := rng.randi_range(0, material_entries.size() - 1)
		var item_id: String = str(material_entries[idx]["id"])
		var removed := _backpack.remove(item_id, 1)
		if removed:
			_last_night_losses.append(ItemDefs.get_item_name(item_id))
			material_entries[idx]["count"] = int(material_entries[idx]["count"]) - 1
			if int(material_entries[idx]["count"]) <= 0:
				material_entries.remove_at(idx)


func _show_night_loss_popup() -> void:
	var loss_counts: Dictionary = {}
	for name in _last_night_losses:
		loss_counts[name] = int(loss_counts.get(name, 0)) + 1
	var parts: PackedStringArray = []
	for name in loss_counts:
		parts.append("%s ×%d" % [name, int(loss_counts[name])])
	var msg := "夜间物资损耗明细：\n  %s\n\n剩余背包：%s" % [", ".join(parts), _inventory_summary()]
	var dialog := AcceptDialog.new()
	dialog.title = "物资损耗"
	dialog.dialog_text = msg
	dialog.ok_button_text = "确认"
	add_child(dialog)
	dialog.confirmed.connect(func():
		dialog.queue_free()
		if is_instance_valid(time_system):
			time_system.finish_night_and_advance_day()
	)
	dialog.close_requested.connect(func():
		dialog.queue_free()
		if is_instance_valid(time_system):
			time_system.finish_night_and_advance_day()
	)
	dialog.popup_centered()


func _get_vehicle_hp_max() -> float:
	if is_instance_valid(night_td):
		return night_td.base_max_hp
	return _vehicle_hp_max


func _reset_vehicle_hp_for_new_run() -> void:
	_vehicle_hp_max = _get_vehicle_hp_max()
	_vehicle_hp = _vehicle_hp_max


func _on_day_started(_day_index: int) -> void:
	if _check_vehicle_destroyed():
		return
	if is_instance_valid(evening_notice) and evening_notice.has_method("hide_notice"):
		evening_notice.hide_notice()
	if is_instance_valid(time_system):
		time_system.resume()
	_play_music_cue("day_exploration", 1.0)
	if is_instance_valid(night_defense):
		night_defense.hide_td_session()
	_refresh_ui()


func _on_time_phase_changed(_old_phase: int, new_phase: int) -> void:
	if new_phase == TimeSystem.Phase.DAY and is_instance_valid(evening_notice):
		evening_notice.hide_notice()
	if new_phase == TimeSystem.Phase.DAY:
		_play_music_cue("day_exploration", 1.0)
	_refresh_ui()


func _is_enter_defense_mode_event(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.is_echo()):
		return false
	if event.is_action_pressed("enter_defense_mode"):
		return true
	return event.keycode == KEY_F or event.physical_keycode == KEY_F


func _try_enter_defense_mode() -> bool:
	if not is_instance_valid(time_system):
		return false
	if not time_system.can_manual_enter_defense():
		return false
	if _game_paused or _backpack_open:
		return false
	if is_instance_valid(night_td) and night_td.visible:
		return true
	if _segment_target_index >= 0:
		_cancel_drive_segment_for_night()
	if _segment_target_index >= 0:
		return false
	_ensure_vehicle_ready_for_night()
	if _mode != TravelMode.DRIVE:
		return false
	time_system.enter_night_setup(true)
	return true


func _cancel_drive_segment_for_night() -> void:
	if _segment_target_index < 0:
		return
	var node_index := _segment_target_index if _segment_progress >= 0.5 else _segment_from_index
	_segment_target_index = -1
	_segment_progress = 0.0
	if _map.is_valid_index(node_index):
		_halt_at_node(node_index)
	else:
		_halt_at_node(_current_node_index)


func _ensure_vehicle_ready_for_night() -> void:
	_saved_travel_mode = _mode
	if _map.is_valid_index(_current_node_index) and _map.is_district(_current_node_index):
		_current_district_index = _current_node_index
	if _mode == TravelMode.FOOT:
		_return_to_vehicle()
	_mode = TravelMode.DRIVE
	_segment_target_index = -1
	if is_instance_valid(_player):
		_player.set_active(false)
		_player.set_blocked_checker(Callable())
	if is_instance_valid(_vehicle):
		_vehicle.set_active(true)
		var anchor_index := maxi(_current_node_index, maxi(_current_district_index, 0))
		if _map.is_valid_index(anchor_index):
			_vehicle.global_position = _map.cell_center(anchor_index)
	for node in _resource_nodes:
		if is_instance_valid(node):
			node.visible = false
	_sync_day_entity_visibility()


func _force_return_to_vehicle_for_night() -> void:
	_ensure_vehicle_ready_for_night()


func _refresh_ui() -> void:
	var in_td := is_instance_valid(night_td) and night_td.visible
	if is_instance_valid(backpack_button):
		backpack_button.visible = false
	if is_instance_valid(_pda_panel):
		_pda_panel.visible = not in_td
	if has_node("HUD/InfoPanel"):
		$HUD/InfoPanel.visible = not in_td
	if has_node("HUD/MapPanel"):
		$HUD/MapPanel.visible = not in_td
	if has_node("HUD/ActionPanel"):
		$HUD/ActionPanel.visible = false
	if has_node("HUD/TimePanel"):
		$HUD/TimePanel.visible = not in_td
	if is_instance_valid(time_hud) and time_hud.has_method("set_layer"):
		time_hud.set_layer(_current_layer, total_layers)
	if is_instance_valid(_vitals_top_bar):
		_vitals_top_bar.visible = not in_td
	if is_instance_valid(evening_notice) and not in_td:
		evening_notice.offset_top = HudTheme.TOP_HUD_Y + HudTheme.TOP_BAR_HEIGHT + 8.0
	if is_instance_valid(fuel_label):
		fuel_label.visible = false
	if is_instance_valid(vitals_label):
		vitals_label.visible = false
	_update_stat_bars()
	if is_instance_valid(inventory_label):
		inventory_label.visible = false
	_refresh_resource_pickups()

	if is_instance_valid(_pda_panel):
		var entries := _backpack.get_sorted_entries()
		var pda_sig := "%s|%s|%s" % [
			_pda_entries_signature(entries),
			_backpack_open,
			_is_exploration_allowed(),
		]
		if pda_sig != _last_pda_entries_sig:
			_last_pda_entries_sig = pda_sig
			_pda_panel.refresh({
				"entries": entries,
				"backpack_open": _backpack_open,
				"backpack_enabled": _is_exploration_allowed(),
			})
	if is_instance_valid(status_label):
		status_label.visible = false
	if is_instance_valid(map_info_label):
		map_info_label.visible = false
	_sync_minimap_navigation()

	if is_instance_valid(prompt_label):
		_update_prompts()

var _last_reward_story_id: String = ""

func _hide_exploration_story_ui() -> void:
	_hide_story_choice_overlay()
	if has_node("HUD/ActionPanel"):
		$HUD/ActionPanel.visible = false
	if is_instance_valid(prompt_label):
		prompt_label.text = ""
		prompt_label.visible = false
	if is_instance_valid(disembark_button):
		disembark_button.visible = false
	if is_instance_valid(return_button):
		return_button.visible = false
	if is_instance_valid(repair_button):
		repair_button.visible = false


func _update_prompts() -> void:
	if is_instance_valid(night_td) and night_td.visible:
		_hide_exploration_story_ui()
		return
	prompt_label.text = ""
	prompt_label.visible = false
	_set_story_choice_buttons_visible(false)
	# Only clear/recreate reward buttons when the story context changes (avoids flicker)
	var current_story_id := _story_controller.story_id_at_node(_current_node_index) if is_instance_valid(_story_controller) else ""
	if current_story_id != _last_reward_story_id:
		_last_reward_story_id = current_story_id
		_clear_story_reward_buttons()
	disembark_button.visible = false
	return_button.visible = false
	repair_button.visible = false
	if is_instance_valid(back_track_button):
		back_track_button.visible = false
	_sync_junction_buttons()
	var overlay_active := _update_foot_story_prompts()
	if not overlay_active:
		overlay_active = _update_thunder_dialogue_prompts()
	if not overlay_active:
		overlay_active = _update_thunder_gate_prompts()
	if not overlay_active:
		overlay_active = _update_story_gate_prompts()
	if not overlay_active:
		_hide_story_choice_overlay()
	_update_foot_prompts()
	_sync_action_panel_visibility()


func _update_foot_prompts() -> void:
	if _mode != TravelMode.FOOT or _current_district_index < 0 or _is_night_phase():
		return
	if _game_paused or _backpack_open:
		return
	if is_instance_valid(_story_controller) and _story_controller._any_dialogue_active():
		return
	if is_instance_valid(_story_dialogue_ui) and _story_dialogue_ui.visible:
		return
	if (_can_repair_elevator() and _is_near_elevator_console()) or (_can_use_kunlun_control() and _is_near_kunlun_console()):
		return
	# 返回提示画在门口世界坐标，底部 ActionPanel 不再重复显示
	prompt_label.text = ""
	prompt_label.visible = false
	$HUD/ActionPanel.visible = false


func _update_foot_story_prompts() -> bool:
	if _mode != TravelMode.FOOT or _current_district_index < 0 or _is_night_phase():
		return false
	if not is_instance_valid(_story_controller):
		return false
	var story_id := _story_controller.story_id_of_district(_current_district_index)
	if story_id == "":
		return false
	var prompt: Dictionary = _story_controller.build_prompt(story_id)
	if (
		StoryData.is_interior_encounter(story_id)
		and _story_controller.run_state.is_quest_active(story_id)
	):
		var need := int(StoryData.quest_def(story_id).get("collect_count", 0))
		if _story_controller.run_state.get_collect_count(story_id) >= need:
			if not (_story_controller.npc_dialogue != null and _story_controller.npc_dialogue.is_active()):
				if _story_controller.is_near_interior_npc(
					story_id, _current_district_index, _foot_local_pos
				):
					var return_text := StoryData.prompt_return(story_id)
					return _show_story_e_action_overlay(
						return_text,
						_clean_action_button_label(return_text),
						"foot_return",
					)
	if bool(prompt.get("show_dialogue_options", false)):
		var option_labels: Array[String] = []
		for opt_var in prompt.get("dialogue_options", []):
			option_labels.append(str(opt_var))
		return _show_story_choice_overlay(str(prompt.get("text", "")), option_labels, "dialogue")
	var continue_hint := str(prompt.get("continue_hint", prompt.get("continuf_hint", "")))
	if continue_hint != "":
		return _show_story_narrative_overlay(str(prompt.get("text", "")), continue_hint)
	return false


func _show_story_narrative_overlay(body: String, hint: String) -> bool:
	if not is_instance_valid(_story_dialogue_ui):
		_setup_story_choice_overlay()
	if not is_instance_valid(_story_dialogue_ui):
		return false
	var overlay_key := "narrative|%s|%s" % [body, hint]
	if overlay_key == _story_choice_overlay_key and _story_dialogue_ui.visible:
		return true
	_story_choice_overlay_key = overlay_key
	var speaker := _current_dialogue_speaker()
	var show_triangle := hint.contains("E") or hint.contains("继续")
	_story_dialogue_ui.show_narrative(body, speaker, show_triangle)
	if has_node("HUD/ActionPanel"):
		$HUD/ActionPanel.visible = false
	return true


func _show_story_e_action_overlay(body: String, action_label: String, mode: String) -> bool:
	if not is_instance_valid(_story_dialogue_ui):
		_setup_story_choice_overlay()
	if not is_instance_valid(_story_dialogue_ui):
		return false
	var clean_action := _clean_action_button_label(action_label)
	var f_hint := "按 F %s" % clean_action
	var text := body.strip_edges()
	var overlay_key := "%s|%s|%s" % [mode, text, clean_action]
	if overlay_key == _story_choice_overlay_key and _story_dialogue_ui.visible:
		return true
	_story_choice_overlay_key = overlay_key
	if text != "" and not text.contains(f_hint):
		text = "%s\n%s" % [text, f_hint]
	_story_dialogue_ui.show_narrative(text, _current_dialogue_speaker(), false)
	if has_node("HUD/ActionPanel"):
		$HUD/ActionPanel.visible = false
	return true


func _update_thunder_dialogue_prompts() -> bool:
	if _mode != TravelMode.DRIVE or _segment_target_index >= 0 or _is_night_phase():
		return false
	if not is_instance_valid(_story_controller):
		return false
	var npc := _story_controller.npc_dialogue
	if npc == null or not npc.is_active() or npc.story_id != "thunder_leiting":
		return false
	var prompt: Dictionary = _story_controller.build_prompt("thunder_leiting")
	var continue_hint := str(prompt.get("continue_hint", prompt.get("continuf_hint", "")))
	if continue_hint != "":
		return _show_story_narrative_overlay(
			str(prompt.get("text", "")),
			continue_hint,
		)
	return false


func _update_thunder_gate_prompts() -> bool:
	if _mode != TravelMode.DRIVE or _segment_target_index >= 0 or _is_night_phase():
		return false
	if not is_instance_valid(_story_controller):
		return false
	if (
		_story_controller.npc_dialogue != null
		and _story_controller.npc_dialogue.is_active()
	):
		return false
	var district_index := _selected_enterable_district()
	if not _story_controller.is_thunder_blocking_district(district_index):
		return false
	var ready_for_battle := false
	if is_instance_valid(_story_controller):
		var rs := _story_controller.run_state
		var checkpoint := str(rs.get_dialogue_node("thunder_leiting"))
		ready_for_battle = bool(
			rs.get_variable("thunder_leiting", "pre_battle_done", false)
		) or checkpoint in ["combat_ready", "combat_prompt"]
	if ready_for_battle:
		return _show_story_e_action_overlay("战前交涉已结束。", "进入布防战", "thunder")
	return _show_story_e_action_overlay(
		"昆仑控制中心门口被「不败之盾-雷霆」封锁。",
		"交涉",
		"thunder",
	)


func _update_story_gate_prompts() -> bool:
	if _mode != TravelMode.DRIVE or _segment_target_index >= 0 or _is_night_phase():
		return false
	if not is_instance_valid(_story_controller):
		return false
	var story_id := _story_controller.story_id_at_node(_current_node_index)
	if story_id == "":
		return false
	var prompt: Dictionary = _story_controller.build_prompt(story_id)
	if (
		str(prompt.get("text", "")).is_empty()
		and not bool(prompt.get("show_story_choice", false))
		and not bool(prompt.get("show_reward_choice", false))
		and not bool(prompt.get("show_dialogue_options", false))
	):
		return false
	if bool(prompt.get("show_story_choice", false)):
		var choice_labels: Array[String] = [
			str(prompt.get("disembark", "帮忙")),
			str(prompt.get("decline", "算了")),
		]
		return _show_story_choice_overlay(str(prompt.get("text", "")), choice_labels, "gate")
	if bool(prompt.get("show_dialogue_options", false)):
		var option_labels: Array[String] = []
		for opt_var in prompt.get("dialogue_options", []):
			option_labels.append(str(opt_var))
		return _show_story_choice_overlay(str(prompt.get("text", "")), option_labels, "dialogue")
	if bool(prompt.get("show_reward_choice", false)):
		var reward_labels := _reward_choice_labels(story_id)
		if reward_labels.is_empty():
			return false
		return _show_story_choice_overlay(
			str(prompt.get("text", "")),
			reward_labels,
			"reward",
		)
	var continue_hint := str(prompt.get("continue_hint", prompt.get("continuf_hint", "")))
	if continue_hint != "":
		return _show_story_narrative_overlay(
			str(prompt.get("text", "")),
			continue_hint,
		)
	if bool(prompt.get("show_disembark", false)) and bool(prompt.get("show_decline", false)):
		var action_labels := _disembark_choice_labels(prompt)
		if action_labels.is_empty():
			return false
		return _show_story_choice_overlay(
			str(prompt.get("text", "")),
			action_labels,
			"disembark",
		)
	if bool(prompt.get("show_disembark", false)):
		return _show_story_e_action_overlay(
			str(prompt.get("text", "")),
			str(prompt.get("disembark", "确认")),
			"disembark",
		)
	return false


func _clean_action_button_label(text: String) -> String:
	var label := text.strip_edges()
	label = label.replace(" (F)", "").replace("(F)", "")
	if label.begins_with("F "):
		label = label.substr(2).strip_edges()
	if label.begins_with("按 F "):
		label = label.substr(4).strip_edges()
	return label if label != "" else "确认"


func _disembark_choice_labels(prompt: Dictionary) -> Array[String]:
	var labels: Array[String] = []
	if bool(prompt.get("show_disembark", false)):
		labels.append(_clean_action_button_label(str(prompt.get("disembark", "确认"))))
	if bool(prompt.get("show_decline", false)):
		labels.append(_clean_action_button_label(str(prompt.get("decline", "取消"))))
	return labels


func _reward_choice_labels(story_id: String) -> Array[String]:
	var labels: Array[String] = []
	for choice_var in StoryData.reward_choices(story_id):
		if typeof(choice_var) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_var
		var title := str(choice.get("prompt", choice.get("label", ""))).strip_edges()
		var desc := str(choice.get("description", "")).strip_edges()
		if title == "":
			continue
		labels.append(title if desc.is_empty() else "%s — %s" % [title, desc])
	return labels


func _set_story_choice_buttons_visible(visible: bool) -> void:
	if is_instance_valid(story_choice_buttons):
		story_choice_buttons.visible = visible


func _hide_action_button_row() -> void:
	if is_instance_valid(action_buttons_row):
		action_buttons_row.visible = false


func _show_story_choice_overlay(title: String, options: Array, mode: String = "dialogue") -> bool:
	if not is_instance_valid(_story_dialogue_ui):
		_setup_story_choice_overlay()
	if not is_instance_valid(_story_dialogue_ui):
		return false
	var labels: Array[String] = []
	for opt_var in options:
		var label := str(opt_var).strip_edges()
		if label != "":
			labels.append(label)
	if labels.is_empty():
		return false
	var overlay_key := "%s|%s|%s" % [mode, title, "|".join(labels)]
	if overlay_key == _story_choice_overlay_key and _story_dialogue_ui.visible:
		return true
	_story_choice_overlay_key = overlay_key
	var hint := ""
	if labels.size() <= 1:
		hint = "按 1 或 E 选择"
	elif labels.size() == 2:
		if mode in ["gate", "disembark"]:
			hint = "按 1 或 E 选第一项，2 选第二项"
		else:
			hint = "按 1 / 2 选择"
	else:
		hint = "按 1～%d 选择" % labels.size()
	_story_dialogue_ui.show_choices(
		title.strip_edges(),
		labels,
		_current_dialogue_speaker(),
		hint,
	)
	if has_node("HUD/ActionPanel"):
		$HUD/ActionPanel.visible = false
	return true


func _hide_story_choice_overlay() -> void:
	_story_choice_overlay_key = ""
	if is_instance_valid(_story_dialogue_ui):
		_story_dialogue_ui.hide_dialogue()


func _on_journal_entry_added(encounter_id: String) -> void:
	_refresh_backpack_if_open()
	var title := JournalData.title_of(encounter_id)
	if is_instance_valid(evening_notice) and evening_notice.has_method("show_message"):
		evening_notice.show_message(
			"勘探日记已更新",
			"「%s」已写入本局日记。\n按 B 打开背包，切到「勘探日记」查看。" % title,
			6.0,
		)


func _on_tactical_sites_revealed(source_id: String = "", auto_open_map: bool = false) -> void:
	_spawn_resources()
	_mark_overworld_dirty()
	queue_redraw()
	if is_instance_valid(minimap_view):
		minimap_view.queue_redraw()
	_sync_world_map_overlay()
	if is_instance_valid(evening_notice) and evening_notice.has_method("show_message"):
		var title := "战术坐标已更新"
		var body := "地图上出现 3 处隐藏物资点。"
		if source_id == "ad_1_radar":
			title = "雷达回波坐标已更新"
			body = "地图上出现 3 处雷达扫描到的隐藏建筑。"
		elif source_id == "chronicler_04":
			title = "物资登记坐标已更新"
			body = "编史者提供的两处隐藏仓库坐标已叠加至导航。"
		evening_notice.show_message(title, body)
	if auto_open_map:
		call_deferred("_open_world_map")


func _clear_story_reward_buttons() -> void:
	_last_dialogue_options_key = ""
	_story_reward_rows.clear()
	if not is_instance_valid(story_reward_buttons):
		return
	for child in story_reward_buttons.get_children():
		child.queue_free()
	story_reward_buttons.visible = false


func _show_story_dialogue_options(_story_id: String, options: Variant) -> void:
	_set_story_choice_buttons_visible(false)
	_hide_action_button_row()
	if not is_instance_valid(story_reward_buttons):
		return
	if typeof(options) != TYPE_ARRAY:
		return
	var labels: Array[String] = []
	for opt_var in options as Array:
		labels.append(str(opt_var))
	var options_key := "|".join(labels)
	if options_key == _last_dialogue_options_key and story_reward_buttons.visible:
		return
	_last_dialogue_options_key = options_key
	_story_reward_rows.clear()
	for child in story_reward_buttons.get_children():
		child.queue_free()
	story_reward_buttons.visible = false
	var accents: Array[Color] = [
		Color("#7ec8a0"),
		Color("#8ec8e8"),
		Color("#c8a080"),
		Color("#bb8fce"),
	]
	for i in range((options as Array).size()):
		var label_text := str((options as Array)[i])
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 56)
		btn.text = "%d · %s" % [i + 1, label_text]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var accent: Color = accents[i % accents.size()]
		btn.add_theme_color_override("font_color", accent)
		btn.disabled = false
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_story_dialogue_option_pressed.bind(i))
		story_reward_buttons.add_child(btn)
		_story_reward_rows.append(btn)
	story_reward_buttons.visible = true
	if is_instance_valid(_action_panel_vbox):
		_action_panel_vbox.move_child(story_reward_buttons, _action_panel_vbox.get_child_count() - 1)


func _on_story_dialogue_option_pressed(index: int) -> void:
	if not is_instance_valid(_story_controller):
		return
	_story_controller.choose_dialogue_option(index)
	_clear_story_reward_buttons()
	_refresh_ui()


func _show_story_reward_choices(story_id: String) -> void:
	_set_story_choice_buttons_visible(false)
	_clear_story_reward_buttons()
	if not is_instance_valid(story_reward_buttons):
		return
	var choices := StoryData.reward_choices(story_id)
	var accents: Array[Color] = [
		Color("#7ec8a0"),
		Color("#8ec8e8"),
		Color("#c8a080"),
		Color("#bb8fce"),
		Color("#e8a86e"),
	]
	for i in range(choices.size()):
		if typeof(choices[i]) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choices[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 56)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var title := str(choice.get("prompt", choice.get("label", "")))
		var desc := str(choice.get("description", ""))
		btn.text = title if desc.is_empty() else "%s\n%s" % [title, desc]
		btn.add_theme_font_size_override("font_size", 12)
		HudTheme.apply_choice_button(btn, accents[i % accents.size()])
		var index := i
		btn.pressed.connect(func() -> void: _on_story_reward_pressed(index))
		story_reward_buttons.add_child(btn)
		_story_reward_rows.append(btn)
	story_reward_buttons.visible = not _story_reward_rows.is_empty()


func _on_story_reward_pressed(index: int) -> void:
	if not is_instance_valid(_story_controller):
		return
	var gate := _story_controller.gate_dialogue
	if not is_instance_valid(gate) or gate.phase != StoryGateDialogue.Phase.REWARD_CHOICE:
		return
	_story_controller.choose_reward_index(index)


func _on_story_accept_pressed() -> void:
	if not is_instance_valid(_story_controller):
		return
	var npc := _story_controller.npc_dialogue
	if npc != null and npc.is_active() and npc.phase == NpcDialogueRunnerScript.Phase.OPTIONS:
		_story_controller.choose_dialogue_option(0)
		_refresh_ui()
		return
	var gate := _story_controller.gate_dialogue
	if is_instance_valid(gate) and gate.phase == StoryGateDialogue.Phase.INTRO_CHOICE:
		_story_controller.accept_gate_choice()
		_refresh_ui()


func _on_story_decline_pressed() -> void:
	if not is_instance_valid(_story_controller):
		return
	var npc := _story_controller.npc_dialogue
	if npc != null and npc.is_active() and npc.phase == NpcDialogueRunnerScript.Phase.OPTIONS:
		_story_controller.choose_dialogue_option(1)
		_refresh_ui()
		return
	var gate := _story_controller.gate_dialogue
	if is_instance_valid(gate) and gate.phase == StoryGateDialogue.Phase.INTRO_CHOICE:
		_story_controller.decline_gate_choice()
		_refresh_ui()


func _sync_junction_buttons() -> void:
	var junction_root := get_node_or_null("HUD/ActionPanel/MarginContainer/VBoxContainer/JunctionButtons")
	if junction_root != null:
		junction_root.visible = false


func _sync_action_panel_visibility() -> void:
	if not has_node("HUD/ActionPanel"):
		return
	if is_instance_valid(night_td) and night_td.visible:
		_hide_exploration_story_ui()
		return
	var panel: Panel = $HUD/ActionPanel
	if _mode == TravelMode.FOOT:
		panel.visible = false
		return
	if _is_night_phase():
		panel.visible = false
		return
	var has_content := false
	if is_instance_valid(prompt_label) and not prompt_label.text.strip_edges().is_empty():
		has_content = true
	for btn in [disembark_button, return_button, repair_button, back_track_button]:
		if is_instance_valid(btn) and btn.visible:
			has_content = true
			break
	if is_instance_valid(story_choice_buttons) and story_choice_buttons.visible:
		has_content = true
	if is_instance_valid(story_reward_buttons) and story_reward_buttons.visible:
		has_content = true
	if is_instance_valid(_story_dialogue_ui) and _story_dialogue_ui.visible:
		has_content = true
	panel.visible = has_content and not _is_story_dialogue_visible()


func _enterable_hotkey_map() -> Dictionary:
	var result: Dictionary = {}
	var buildings := _get_enterable_buildings()
	for i in range(mini(9, buildings.size())):
		result[int(buildings[i].get("district_index", -1))] = i + 1
	return result

func _exit_directions_array() -> Array[String]:
	var result: Array[String] = []
	for direction in _exit_options.keys():
		result.append(str(direction))
	return result

func _sync_minimap_navigation() -> void:
	var segment_axis := ""
	if _segment_target_index >= 0 and _map.is_valid_index(_segment_from_index):
		segment_axis = _map.get_segment_axis(_segment_from_index, _segment_target_index)
	var node_index := _current_node_index
	if _segment_target_index >= 0:
		node_index = _segment_from_index
	var hints: Array[String] = []
	if _segment_target_index < 0:
		hints = _exit_directions_array()
	if is_instance_valid(minimap_view):
		minimap_view.set_navigation_hints(node_index, hints, segment_axis)
	_sync_world_map_overlay(node_index, hints, segment_axis)


func _sync_world_map_overlay(
	node_index: int = -1,
	hints: Array[String] = [],
	segment_axis: String = "",
) -> void:
	if not is_instance_valid(_world_map_overlay) or not _world_map_overlay.is_open():
		return
	if node_index < 0:
		node_index = _current_node_index
		if _segment_target_index >= 0:
			node_index = _segment_from_index
	if hints.is_empty() and _segment_target_index < 0:
		hints = _exit_directions_array()
	if segment_axis == "" and _segment_target_index >= 0 and _map.is_valid_index(_segment_from_index):
		segment_axis = _map.get_segment_axis(_segment_from_index, _segment_target_index)
	_world_map_overlay.refresh(_current_focus_position(), node_index, hints, segment_axis)

func _road_center(index: int) -> Vector2:
	if not _map.is_valid_index(index):
		return Vector2.ZERO
	return _map.cell_center(index)


func _vehicle_world_position() -> Vector2:
	if _segment_target_index >= 0 and _map.is_valid_index(_segment_from_index) and _map.is_valid_index(_segment_target_index):
		var from_pos := _road_center(_segment_from_index)
		var to_pos := _road_center(_segment_target_index)
		return from_pos.lerp(to_pos, clampf(_segment_progress, 0.0, 1.0))
	if _current_node_index >= 0:
		return _road_center(_current_node_index)
	return Vector2.ZERO


func _current_travel_axis() -> String:
	if _segment_target_index >= 0 and _map.is_valid_index(_segment_from_index) and _map.is_valid_index(_segment_target_index):
		return _map.get_segment_axis(_segment_from_index, _segment_target_index)
	return ""

func _world_view_transform(full_map_view: bool = false) -> Transform2D:
	var view_size := get_viewport_rect().size
	if view_size == Vector2.ZERO:
		view_size = Vector2(1280.0, 720.0)
	var world_size := _map.get_world_size()
	var content_rect := _full_map_content_rect(view_size) if full_map_view else _route_content_rect(view_size)
	var scale := minf(content_rect.size.x / maxf(world_size.x, 1.0), content_rect.size.y / maxf(world_size.y, 1.0)) * 0.98
	var origin := content_rect.position + (content_rect.size - world_size * scale) * 0.5
	return Transform2D(Vector2(scale, 0.0), Vector2(0.0, scale), origin)

func _full_map_content_rect(view_size: Vector2) -> Rect2:
	var margin := 24.0
	return Rect2(
		Vector2(margin, margin),
		Vector2(maxf(view_size.x - margin * 2.0, 1.0), maxf(view_size.y - margin * 2.0, 1.0))
	)

func _route_content_rect(view_size: Vector2) -> Rect2:
	var left := 124.0
	var top := 144.0
	var right := 124.0
	var bottom := 150.0
	return Rect2(
		Vector2(left, top),
		Vector2(maxf(view_size.x - left - right, 1.0), maxf(view_size.y - top - bottom, 1.0))
	)

func _update_vehicle_transform() -> void:
	if not is_instance_valid(_vehicle):
		return
	_vehicle.global_position = _vehicle_world_position()
	if _segment_target_index >= 0 and _vehicle_facing.length_squared() > 0.01:
		_vehicle.rotation = _vehicle_facing.angle() - DayTopdownRender.VEHICLE_SPRITE_FORWARD.angle()
	if is_instance_valid(_world_camera) and _world_camera.enabled:
		_world_camera.global_position = _vehicle.global_position

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
	var play_rect := _map.get_foot_play_rect(district_index)
	if play_rect.size == Vector2.ZERO:
		return position
	return Vector2(
		clampf(position.x, play_rect.position.x, play_rect.end.x),
		clampf(position.y, play_rect.position.y, play_rect.end.y),
	)


func _is_foot_blocked_at(world_pos: Vector2) -> bool:
	if _current_district_index < 0 or _mode != TravelMode.FOOT:
		return false
	var foot_origin := _map.get_foot_origin(_current_district_index)
	var foot_area := _map.get_foot_area_rect(_current_district_index)
	var cell := _map.get_cell(_current_district_index)
	var local := world_pos - foot_origin
	if local.x < 0.0 or local.y < 0.0 or local.x >= foot_area.size.x or local.y >= foot_area.size.y:
		return true
	var probe_offsets: Array[Vector2] = [
		Vector2.ZERO, Vector2(-6, 0), Vector2(6, 0), Vector2(0, -6), Vector2(0, 6),
	]
	for offset in probe_offsets:
		var probe_pos: Vector2 = world_pos + offset
		var probe_local: Vector2 = probe_pos - foot_origin
		if probe_local.x < 0.0 or probe_local.y < 0.0 or probe_local.x >= foot_area.size.x or probe_local.y >= foot_area.size.y:
			continue
		if _map.is_foot_tile_blocked(cell, foot_origin, probe_pos):
			return true
	return false


func _fix_district_pickup_positions(district_index: int) -> void:
	if district_index < 0:
		return
	var walkable: Array[Vector2] = _map.get_walkable_world_positions(district_index)
	if walkable.is_empty():
		return
	var rect := _map.cell_rect(district_index)
	var cell := _map.get_cell(district_index)
	var spot_idx := 0
	for node in _resource_nodes:
		if not is_instance_valid(node):
			continue
		if int(node.get_meta("district_index", -1)) != district_index:
			continue
		if _map.is_foot_tile_blocked(cell, _map.get_foot_origin(district_index), node.global_position):
			node.global_position = walkable[spot_idx % walkable.size()]
			spot_idx += 1


func _clamp_to_walkable(position: Vector2) -> Vector2:
	if _current_district_index < 0:
		return position
	var rect := _map.cell_rect(_current_district_index)
	var result := _clamp_to_cell(position, _current_district_index)
	if not _is_foot_blocked_at(result):
		return result
	# 落在障碍上时退回区块中心
	return _map.get_foot_door_world_pos(_current_district_index)

func _draw() -> void:
	if _is_night_phase() and (not is_instance_valid(night_td) or not night_td.visible):
		_draw_night_camp_background()
		return
	if is_instance_valid(night_td) and night_td.visible:
		return
	match _mode:
		TravelMode.DRIVE:
			_draw_day_overworld()
		TravelMode.FOOT:
			_draw_foot_interior()
	if _evening_tint > 0.001 and _mode == TravelMode.DRIVE:
		_draw_evening_tint_screen_overlay()

func _draw_evening_tint_screen_overlay() -> void:
	var xform := get_canvas_transform()
	var inv := xform.affine_inverse()
	var view_size := get_viewport_rect().size
	if view_size == Vector2.ZERO:
		view_size = Vector2(1280.0, 720.0)
	var corners := PackedVector2Array([
		inv * Vector2.ZERO,
		inv * Vector2(view_size.x, 0.0),
		inv * Vector2(view_size.x, view_size.y),
		inv * Vector2(0.0, view_size.y),
	])
	draw_colored_polygon(corners, Color(0.05, 0.08, 0.18, _evening_tint))


func _viewport_shows_road_segment(from_pos: Vector2, to_pos: Vector2, view_rect: Rect2) -> bool:
	var min_p := from_pos.min(to_pos)
	var max_p := from_pos.max(to_pos)
	var seg_rect := Rect2(min_p, max_p - min_p).grow(DayTopdownRender.road_width() * 0.55)
	return view_rect.intersects(seg_rect)


func _overworld_road_lit(explored: bool, in_viewport: bool) -> bool:
	return not war_fog_enabled or explored or in_viewport


func _district_visible_through_fog(district_index: int) -> bool:
	if not war_fog_enabled:
		return true
	if _map.is_tactical_revealed(district_index):
		return true
	return bool(_map.get_cell(district_index).get("explored", false))


func _draw_day_overworld() -> void:
	var view_rect := _camera_world_view_rect().grow(280.0)
	var world_bounds := Rect2(Vector2.ZERO, _map.get_world_size())
	var backdrop := Color("#182028") if DayTopdownRender.is_snow_biome() else Color("#0e1216")
	draw_rect(world_bounds.grow(480.0), backdrop, true)
	var ground_rect := view_rect.intersection(world_bounds.grow(120.0))
	if ground_rect.size.x > 0.0 and ground_rect.size.y > 0.0:
		DayTopdownRender.draw_tiled_wilderness_ground(self, ground_rect)

	for index in range(_map.cells.size()):
		var cell := _map.get_cell(index)
		var kind := str(cell["kind"])
		var rect := _map.cell_rect(index)
		if not view_rect.intersects(rect):
			continue
		if kind == "road" or kind == "junction" or kind == "hub":
			var in_viewport := true
			if war_fog_enabled and not bool(cell["explored"]) and not in_viewport:
				draw_rect(rect, Color("#06080c"), true)
				continue
			var explored := _overworld_road_lit(bool(cell["explored"]), in_viewport)
			var cell_seed := int(cell.get("seed", index + 1))
			DayTopdownRender.draw_road_cell(self, rect, explored, cell_seed)
			continue
		if kind == "empty" or kind == "district":
			continue
		if war_fog_enabled and not bool(cell["explored"]):
			draw_rect(rect, Color("#06080c"), true)
			continue
		if DayTopdownRender.has_wilderness_ground():
			continue
		var terrain_explored := bool(cell["explored"]) or not war_fog_enabled
		var terrain_seed := int(cell.get("seed", index + 1))
		DayTopdownRender.draw_ruin_cell(self, rect, kind, terrain_explored, terrain_seed)

	# 先路口、后直路：每个 drive 格先贴路口，再沿方向 trim 后接邻格
	DayTopdownRender.draw_road_network(
		self,
		_map,
		view_rect,
		func(from_index: int, to_index: int, from_center: Vector2, to_center: Vector2) -> bool:
			var segment_in_view := _viewport_shows_road_segment(from_center, to_center, view_rect)
			if not war_fog_enabled:
				return true
			var from_explored := bool(_map.get_cell(from_index).get("explored", false))
			var to_explored := bool(_map.get_cell(to_index).get("explored", false))
			return segment_in_view or (from_explored and to_explored),
		func(from_index: int, to_index: int, from_center: Vector2, to_center: Vector2) -> bool:
			if from_index == to_index:
				var node_in_view := view_rect.grow(DayTopdownRender.road_width()).has_point(from_center)
				return _overworld_road_lit(bool(_map.get_cell(from_index).get("explored", false)), node_in_view)
			var segment_in_view := _viewport_shows_road_segment(from_center, to_center, view_rect)
			var from_explored := bool(_map.get_cell(from_index).get("explored", false))
			var to_explored := bool(_map.get_cell(to_index).get("explored", false))
			return _overworld_road_lit(from_explored and to_explored, segment_in_view),
	)

	for district_index in _map.district_indices:
		if _map.is_tactical_dormant(district_index):
			continue
		var dcell := _map.get_cell(district_index)
		var drect := _map.cell_rect(district_index)
		if not view_rect.intersects(drect):
			continue
		if war_fog_enabled and not _district_visible_through_fog(district_index):
			draw_rect(drect, Color("#06080c"), true)
			continue
		var d_explored := _district_visible_through_fog(district_index)
		var d_seed := int(dcell.get("seed", district_index + 1))
		DayTopdownRender.draw_ruin_cell(self, drect, "empty", d_explored, d_seed)

	for index in range(_map.cells.size()):
		if _map.is_district(index):
			continue
		var cell := _map.get_cell(index)
		var rect := _map.cell_rect(index)
		if not view_rect.intersects(rect):
			continue
		var in_viewport := view_rect.intersects(rect)
		if war_fog_enabled and not bool(cell.get("explored", false)) and not in_viewport:
			continue
		var explored := bool(cell.get("explored", false)) or not war_fog_enabled or in_viewport
		var props := _map.get_terrain_props(index)
		if not props.is_empty():
			DayTopdownRender.draw_terrain_props(self, rect, props, explored)

	for index in range(_map.cells.size()):
		if not _map.is_drive_node(index) or not _map.should_draw_blockage_overlay(index):
			continue
		var cell := _map.get_cell(index)
		var blockages: Dictionary = _map.get_road_blockages(index)
		if blockages.is_empty():
			continue
		var rect := _map.cell_rect(index)
		if not view_rect.intersects(rect):
			continue
		var in_viewport := view_rect.intersects(rect)
		if war_fog_enabled and not bool(cell.get("explored", false)) and not in_viewport:
			continue
		var explored := bool(cell.get("explored", false)) or not war_fog_enabled or in_viewport
		DayTopdownRender.draw_road_blockages(
			self,
			rect,
			_map.cell_center(index),
			blockages,
			explored,
			_map.get_road_directions(index).size(),
		)

	var can_enter := not _get_enterable_buildings().is_empty()
	var enterables := _get_enterable_buildings()
	var hotkey_map := _enterable_hotkey_map() if can_enter else {}
	for index in range(_map.cells.size()):
		if not _map.is_drive_node(index):
			continue
		if war_fog_enabled and not bool(_map.get_cell(index).get("explored", false)):
			continue
		var road_rect := _map.cell_rect(index)
		if not view_rect.intersects(road_rect):
			continue
		for district_index in _map.get_roadside_districts(index):
			if _map.is_tactical_dormant(district_index):
				continue
			if war_fog_enabled and not bool(_map.get_cell(district_index).get("explored", false)):
				_map.mark_explored(district_index)
			var side := _map.cell_center(district_index) - _map.cell_center(index)
			if side.length_squared() < 1.0:
				continue
			var highlight := false
			if can_enter and index == _current_node_index:
				var pick := clampi(_building_pick_index, 0, maxi(enterables.size() - 1, 0))
				if pick < enterables.size() and int(enterables[pick].get("district_index", -1)) == district_index:
					highlight = true
			var dcell := _map.get_cell(district_index)
			var district_rect := _map.cell_rect(district_index)
			var show_sign := not _building_sign_overlaps_inventory_hud(district_rect, -side.normalized())
			var entrance: Vector2 = DayTopdownRender.draw_roadside_facade(
				self,
				road_rect,
				side.normalized(),
				str(dcell.get("building_type", "")),
				_map.building_label(district_index),
				highlight,
				district_rect,
				show_sign,
			)
			if index == _current_node_index and hotkey_map.has(district_index):
				DayTopdownRender.draw_hotkey_badge(
					self,
					entrance,
					str(hotkey_map[district_index]),
					highlight,
				)
			var story_id := str(dcell.get("story_id", ""))
			var toward_road := _map.district_toward_road_vector(district_index)
			if (
				is_instance_valid(_story_controller)
				and _story_controller.should_show_thunder_gate_boss(district_index)
			):
				DayTopdownRender.draw_thunder_gate_boss(self, entrance, 1.0, toward_road)
			elif (
				is_instance_valid(_story_controller)
				and _story_controller.should_show_gate_npc(story_id)
			):
				DayTopdownRender.draw_gate_npc(self, entrance, story_id, 1.0, toward_road)
			if highlight:
				draw_circle(entrance, 32.0, Color("#f0c168", 0.28))
				draw_arc(entrance, 32.0, 0.0, TAU, 32, Color("#f0c168"), 4.0)
			elif _map.is_tactical_revealed(district_index):
				draw_arc(entrance, 36.0, 0.0, TAU, 28, Color("#68b0ff", 0.65), 2.5)

	for district_index in _map.district_indices:
		if not _map.is_tactical_revealed(district_index):
			continue
		if bool(_map.get_cell(district_index).get("explored", false)):
			continue
		var pin_rect := _map.cell_rect(district_index)
		if not view_rect.intersects(pin_rect):
			continue
		var pin_center := pin_rect.position + pin_rect.size * 0.5
		draw_circle(pin_center, 14.0, Color("#68b0ff", 0.18))
		draw_arc(pin_center, 14.0, 0.0, TAU, 24, Color("#88c8ff", 0.85), 2.0)
		var pin_label := _map.building_label(district_index)
		if pin_label != "":
			HudTheme.draw_string(self, pin_center + Vector2(-40.0, -22.0), pin_label, 11, Color("#a8d8ff"))

	var vpos := _vehicle_world_position()
	if _segment_target_index < 0 and view_rect.has_point(vpos):
		DayTopdownRender.draw_vehicle_marker(self, vpos, 1.0, _current_travel_axis(), _vehicle_facing)

	if is_instance_valid(_story_controller):
		_story_controller.draw_gate_bubbles(self, vpos, Callable(self, "_draw_world_speech_bubble"))

	if _segment_target_index < 0 and _map.is_valid_index(_current_node_index):
		var node_center := _map.cell_center(_current_node_index)
		if view_rect.has_point(node_center):
			for direction in _exit_options.keys():
				var tip := node_center
				var arm := 52.0
				match str(direction):
					"up":
						tip += Vector2(0.0, -arm)
					"down":
						tip += Vector2(0.0, arm)
					"left":
						tip += Vector2(-arm, 0.0)
					"right":
						tip += Vector2(arm, 0.0)
				draw_line(node_center, tip, Color("#7dffb2"), 6.0)
				draw_rect(Rect2(tip - Vector2(8, 8), Vector2(16, 16)), Color("#e8fff0"), true)


func _draw_world_speech_bubble(anchor: Vector2, text: String, fill: Color, border: Color) -> void:
	var bubble_w := clampf(float(text.length()) * 11.0 + 20.0, 72.0, 220.0)
	var bubble_h := 22.0
	var bubble_size := Vector2(bubble_w, bubble_h)
	var bubble_pos := _clamp_world_speech_bubble_position(
		Vector2(anchor.x - bubble_w * 0.5, anchor.y - bubble_h - 6.0),
		bubble_size,
	)
	draw_rect(Rect2(bubble_pos, Vector2(bubble_w, bubble_h)), Color(0.05, 0.09, 0.13, 0.84), true)
	draw_rect(Rect2(bubble_pos, Vector2(bubble_w, bubble_h)), border, false, 1.0)
	HudTheme.draw_string(self, bubble_pos + Vector2(8.0, 14.0), text, 11, fill)


func _clamp_world_speech_bubble_position(world_pos: Vector2, bubble_size: Vector2) -> Vector2:
	var to_screen := get_global_transform_with_canvas()
	var screen_pos := to_screen * world_pos
	var screen_size := to_screen.basis_xform(bubble_size)
	screen_size = Vector2(absf(screen_size.x), absf(screen_size.y))
	var viewport_size := get_viewport_rect().size
	var margin := 8.0
	var top_safe := HudTheme.TOP_HUD_Y + HudTheme.TOP_BAR_HEIGHT + 14.0
	var max_x := maxf(margin, viewport_size.x - screen_size.x - margin)
	var max_y := maxf(top_safe, viewport_size.y - screen_size.y - margin)
	screen_pos.x = clampf(screen_pos.x, margin, max_x)
	screen_pos.y = clampf(screen_pos.y, top_safe, max_y)
	return to_screen.affine_inverse() * screen_pos


func _draw_door_exit_hint(door_rect: Rect2) -> void:
	if _current_district_index < 0 or _mode != TravelMode.FOOT:
		return
	if _is_story_dialogue_visible():
		return
	if door_rect.size.x <= 0.0 or door_rect.size.y <= 0.0:
		return
	var text := _story_controller.foot_door_hint(_current_district_index) if is_instance_valid(_story_controller) else "E 返回车辆"
	var bubble_w := clampf(float(text.length()) * 10.0 + 24.0, 72.0, 140.0)
	var bubble_h := 16.0
	var door_center_x := door_rect.position.x + door_rect.size.x * 0.5
	var bubble_pos := Vector2(door_center_x - bubble_w * 0.5, door_rect.position.y - bubble_h - 10.0)
	draw_rect(Rect2(bubble_pos, Vector2(bubble_w, bubble_h)), Color(0.05, 0.09, 0.13, 0.74), true)
	draw_rect(Rect2(bubble_pos, Vector2(bubble_w, bubble_h)), Color("#c8a060", 0.42), false, 1.0)
	HudTheme.draw_string(self, bubble_pos + Vector2(10.0, 12.0), text, 10, Color("#f0d8a0"))


func _handle_foot_interact() -> void:
	if _try_advance_story_dialogue():
		return
	if is_instance_valid(_story_controller):
		if _story_controller.try_interact_foot_loot(_current_district_index, _foot_local_pos):
			queue_redraw()
			return
	if is_instance_valid(_story_controller):
		if _story_controller.try_interior_story_interact(_current_district_index, _foot_local_pos):
			_refresh_ui()
			return
	if is_instance_valid(_story_controller) and _story_controller.blocks_foot_exit(_current_district_index):
		var npc_retry := _story_controller.npc_dialogue
		if npc_retry == null or not npc_retry.is_active():
			_story_controller.ensure_interior_encounter_at(_current_district_index)
			_refresh_ui()
			return
		if is_instance_valid(evening_notice) and evening_notice.has_method("show_message"):
			evening_notice.show_message("先完成抉择，才能离开。", "")
		return


func _try_foot_console_interact() -> bool:
	if _is_near_kunlun_console():
		_attempt_kunlun_terminal()
		return true
	if _is_near_elevator_console():
		_attempt_repair_elevator()
		return true
	return false


func _try_foot_return_to_vehicle() -> bool:
	if _mode != TravelMode.FOOT:
		return false
	if not _is_near_foot_door():
		return false
	if is_instance_valid(_story_controller) and _story_controller.blocks_foot_exit(_current_district_index):
		var npc_retry := _story_controller.npc_dialogue
		if npc_retry == null or not npc_retry.is_active():
			_story_controller.ensure_interior_encounter_at(_current_district_index)
			_refresh_ui()
			return true
		if is_instance_valid(evening_notice) and evening_notice.has_method("show_message"):
			evening_notice.show_message("先完成抉择，才能离开。", "")
		return true
	_return_to_vehicle()
	return true


func _foot_tile_panel_rect(district_index: int, tile: Vector2i) -> Rect2:
	var panel := _interior_panel_rect(district_index)
	var cell := _map.get_cell(district_index)
	var cols: int = maxi(int(cell.get("foot_grid_cols", 1)), 1)
	var rows: int = maxi(int(cell.get("foot_grid_rows", 1)), 1)
	var tile_px := panel.size.x / float(cols)
	var tile_py := panel.size.y / float(rows)
	return Rect2(
		panel.position + Vector2(float(tile.x) * tile_px, float(tile.y) * tile_py),
		Vector2(tile_px, tile_py),
	)


func _foot_door_panel_rect(district_index: int = _current_district_index) -> Rect2:
	return _foot_tile_panel_rect(district_index, _map.get_foot_door_tile(district_index))


func _elevator_console_panel_rect(district_index: int = _current_district_index) -> Rect2:
	return _foot_tile_panel_rect(district_index, _map.get_foot_console_tile(district_index))


func _is_near_foot_door() -> bool:
	if _current_district_index < 0 or _mode != TravelMode.FOOT:
		return false
	var door_rect := _foot_door_panel_rect()
	var player_panel := _foot_local_to_panel(_foot_local_pos, _current_district_index)
	var door_center := door_rect.position + door_rect.size * 0.5
	return player_panel.distance_to(door_center) <= maxf(door_rect.size.x, door_rect.size.y) * 2.4


func _is_near_elevator_console() -> bool:
	if not _can_repair_elevator():
		return false
	return _is_near_interior_console()


func _is_near_kunlun_console() -> bool:
	if not _can_use_kunlun_control():
		return false
	return _is_near_interior_console()


func _is_near_interior_console() -> bool:
	var console_rect := _elevator_console_panel_rect()
	var player_panel := _foot_local_to_panel(_foot_local_pos, _current_district_index)
	var console_center := console_rect.position + console_rect.size * 0.5
	return player_panel.distance_to(console_center) <= maxf(console_rect.size.x, console_rect.size.y) * 1.45


func _elevator_repair_progress_ratio() -> float:
	var total := maxf(_current_repair_cost(), 1)
	return clampf(float(_elevator_repair_progress) / float(total), 0.0, 1.0)


func _elevator_consolf_hint_text() -> String:
	var needed := _current_repair_cost() - _elevator_repair_progress
	if needed <= 0:
		return "电梯已就绪"
	return "F 修复电梯 · %d/%d" % [_elevator_repair_progress, _current_repair_cost()]


func _draw_elevator_consolf_hint(console_rect: Rect2) -> void:
	if not _can_repair_elevator() or not _is_near_elevator_console():
		return
	_draw_interior_consolf_hint(console_rect, _elevator_consolf_hint_text(), Color("#f0c168"))


func _draw_kunlun_consolf_hint(console_rect: Rect2) -> void:
	if not _can_use_kunlun_control() or not _is_near_kunlun_console():
		return
	var hint_text := "F 接入通信终端" if _thunder_leiting_defeated else "终端离线 · 雷霆封锁中"
	_draw_interior_consolf_hint(console_rect, hint_text, Color("#6eb8ff"))


func _draw_interior_consolf_hint(console_rect: Rect2, text: String, accent: Color) -> void:
	_draw_interior_consolf_hint_on_canvas(self, console_rect, text, accent)


func _draw_interior_consolf_hint_on_canvas(
	canvas: CanvasItem,
	console_rect: Rect2,
	text: String,
	accent: Color,
) -> void:
	var center := console_rect.position + console_rect.size * 0.5
	var bubble_w := maxf(96.0, float(text.length()) * 7.0 + 16.0)
	var bubble_h := 16.0
	var bubble_pos := Vector2(center.x - bubble_w * 0.5, console_rect.position.y - 22.0)
	canvas.draw_rect(Rect2(bubble_pos, Vector2(bubble_w, bubble_h)), Color(0.05, 0.09, 0.13, 0.78), true)
	canvas.draw_rect(Rect2(bubble_pos, Vector2(bubble_w, bubble_h)), accent, false, 1.0)
	HudTheme.draw_string(canvas, bubble_pos + Vector2(8.0, 12.0), text, 10, Color("#f8ecd8"))


func _draw_interior_building_label(panel: Rect2, title: String) -> void:
	if title.is_empty():
		return
	var view_size := get_viewport_rect().size
	if view_size == Vector2.ZERO:
		view_size = Vector2(1280.0, 720.0)
	var gap := 14.0
	var label_w := maxf(56.0, float(title.length()) * 13.0 + 20.0)
	var label_h := 24.0
	var pos := Vector2(
		minf(panel.end.x + gap, view_size.x - label_w - HudTheme.SAFE_MARGIN),
		panel.position.y + 10.0,
	)
	draw_rect(Rect2(pos, Vector2(label_w, label_h)), Color(0.04, 0.07, 0.11, 0.82), true)
	draw_rect(Rect2(pos, Vector2(label_w, label_h)), Color("#6a8ca8", 0.62), false, 1.0)
	HudTheme.draw_string(self, pos + Vector2(10.0, 16.0), title, 13, Color("#d8e8f4"))


func _interior_panel_rect(district_index: int) -> Rect2:
	var cell := _map.get_cell(district_index)
	var cols: int = maxi(int(cell.get("foot_grid_cols", 1)), 1)
	var rows: int = maxi(int(cell.get("foot_grid_rows", 1)), 1)
	var tile_px := float(WorldMapData.FOOT_TILE_SIZE) * interior_tile_scale
	var panel_size := Vector2(float(cols) * tile_px, float(rows) * tile_px)
	var view_size := get_viewport_rect().size
	if view_size == Vector2.ZERO:
		view_size = Vector2(1280.0, 720.0)
	return Rect2(
		(view_size - panel_size) * 0.5 + Vector2(0.0, 36.0),
		panel_size,
	)


func _foot_local_to_panel(local_pos: Vector2, district_index: int) -> Vector2:
	var panel := _interior_panel_rect(district_index)
	var foot_area := _map.get_foot_area_rect(district_index)
	if foot_area.size == Vector2.ZERO:
		return panel.position
	var scale := panel.size / foot_area.size
	return panel.position + local_pos * scale


func _cache_foot_layout_data(district_index: int) -> void:
	if district_index < 0:
		return
	var cell := _map.get_cell(district_index)
	var cols: int = maxi(int(cell.get("foot_grid_cols", 1)), 1)
	var rows: int = maxi(int(cell.get("foot_grid_rows", 1)), 1)
	var blocked_set: Dictionary = {}
	for raw in cell.get("foot_blocked", []):
		var tile := Vector2i.ZERO
		if raw is Vector2i:
			tile = raw
		elif raw is Dictionary:
			tile = Vector2i(int(raw.get("x", 0)), int(raw.get("y", 0)))
		blocked_set[tile] = true
	_foot_layout_cache[district_index] = {
		"cols": cols,
		"rows": rows,
		"blocked": blocked_set,
		"seed": int(cell.get("seed", district_index + 1)),
	}


func _foot_layout_data(district_index: int) -> Dictionary:
	if _foot_layout_cache.has(district_index):
		return _foot_layout_cache[district_index]
	_cache_foot_layout_data(district_index)
	return _foot_layout_cache.get(district_index, {})


func _draw_foot_interior_static_layer(canvas: CanvasItem, district_index: int, panel: Rect2) -> void:
	var layout := _foot_layout_data(district_index)
	if layout.is_empty():
		return
	var cols: int = int(layout.get("cols", 1))
	var rows: int = int(layout.get("rows", 1))
	var blocked_set: Dictionary = layout.get("blocked", {})
	var floor_seed: int = int(layout.get("seed", district_index + 1))
	var tile_px := panel.size.x / float(cols)
	var tile_py := panel.size.y / float(rows)
	var building_type := str(_map.get_cell(district_index).get("building_type", ""))
	var story_id := str(_map.get_cell(district_index).get("story_id", ""))
	DayTopdownRender.draw_interior_floor_grid(canvas, panel, cols, rows, floor_seed, building_type)
	var has_console := (
		building_type == "elevator"
		or building_type == "kunlun_control"
		or _map.district_has_elevator(district_index)
		or _map.district_has_kunlun_control(district_index)
	)
	var console_tile := _map.get_foot_console_tile(district_index)
	var skip_obstacle_tiles := story_id == "marian_k142"
	for gx in range(cols):
		for gy in range(rows):
			if skip_obstacle_tiles:
				continue
			if not blocked_set.has(Vector2i(gx, gy)):
				continue
			var tile := Vector2i(gx, gy)
			if has_console and tile == console_tile:
				continue
			var tile_rect := Rect2(
				panel.position + Vector2(float(gx) * tile_px, float(gy) * tile_py),
				Vector2(tile_px, tile_py),
			)
			DayTopdownRender.draw_interior_tile(canvas, tile_rect, true)
	var door_rect := _foot_door_panel_rect_for_panel(district_index, panel)
	DayTopdownRender.draw_interior_door(canvas, door_rect, true)
	canvas.draw_rect(panel, Color("#4a6070"), false, 2.0)
	_draw_interior_building_label(panel, _map.building_label(district_index))
	if story_id == "furnace_qc":
		DayTopdownRender.draw_furnace_machine(canvas, panel, true)
	elif story_id == "chronicler_04":
		DayTopdownRender.draw_chronicler_archive(canvas, panel, true)
	elif story_id == "staff_officer_07":
		DayTopdownRender.draw_tactical_hologram(canvas, panel, true)
	elif story_id == "ad_1_radar":
		DayTopdownRender.draw_radar_ad1(canvas, panel, true)
		if is_instance_valid(_story_controller):
			var npc_hint := _story_controller.interior_npc_interact_hint(
				story_id, district_index, _foot_local_pos
			)
			if not npc_hint.is_empty():
				var hint_center := panel.position + panel.size * Vector2(0.5, 0.34)
				_draw_interior_consolf_hint_on_canvas(
					canvas,
					Rect2(hint_center - Vector2(48.0, 24.0), Vector2(96.0, 48.0)),
					str(npc_hint.get("text", "F 交谈")),
					Color("#88ffb0"),
				)
	elif story_id == "marian_k142":
		DayTopdownRender.draw_marian_room(canvas, panel, true)


func _draw_interior_story_quest_prop(
	canvas: CanvasItem,
	district_index: int,
	story_id: String,
) -> void:
	if not is_instance_valid(_story_controller):
		return
	var prop := _story_controller.interior_quest_prop_display(story_id, district_index)
	if prop.is_empty():
		return
	var prop_local: Vector2 = prop.get("local", Vector2.ZERO)
	var prop_panel := _foot_local_to_panel(prop_local, district_index)
	var interact_hint := _story_controller.quest_interact_hint(district_index, _foot_local_pos)
	var show_hint := not interact_hint.is_empty()
	var hint_text := str(interact_hint.get("text", "")) if show_hint else ""
	DayTopdownRender.draw_interior_quest_prop(
		canvas,
		prop_panel,
		str(prop.get("prop", "rubble_pile")),
		show_hint,
		hint_text,
	)


func _foot_door_panel_rect_for_panel(district_index: int, panel: Rect2) -> Rect2:
	var door_rect := _foot_door_panel_rect(district_index)
	return Rect2(
		panel.position + (door_rect.position - _interior_panel_rect(district_index).position),
		door_rect.size,
	)


func _draw_foot_interior() -> void:
	if _current_district_index < 0:
		return
	var view_size := get_viewport_rect().size
	if view_size == Vector2.ZERO:
		view_size = Vector2(1280.0, 720.0)
	draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.02, 0.04, 0.08, 0.92), true)

	var panel := _interior_panel_rect(_current_district_index)
	var layout := _foot_layout_data(_current_district_index)
	var cols: int = maxi(int(layout.get("cols", 1)), 1)
	var rows: int = maxi(int(layout.get("rows", 1)), 1)
	var tile_px := panel.size.x / float(cols)
	var tile_py := panel.size.y / float(rows)
	_draw_foot_interior_static_layer(self, _current_district_index, panel)
	var door_rect := _foot_door_panel_rect(_current_district_index)
	if _map.district_has_kunlun_control(_current_district_index):
		var kunlun_rect := _elevator_console_panel_rect(_current_district_index)
		DayTopdownRender.draw_elevator_console(
			self,
			kunlun_rect,
			_is_near_kunlun_console(),
			0.0,
		)
		_draw_kunlun_consolf_hint(kunlun_rect)
	elif _map.district_has_elevator(_current_district_index):
		var console_rect := _elevator_console_panel_rect(_current_district_index)
		DayTopdownRender.draw_elevator_console(
			self,
			console_rect,
			_is_near_elevator_console(),
			_elevator_repair_progress_ratio(),
		)
		_draw_elevator_consolf_hint(console_rect)
	_draw_door_exit_hint(door_rect)
	var player_panel := _foot_local_to_panel(_foot_local_pos, _current_district_index)
	DayTopdownRender.draw_player_marker(
		self,
		player_panel,
		0.95,
		_foot_move_dir,
		_foot_walk_phase,
		_foot_is_walking,
	)
	var foot_origin := _map.get_foot_origin(_current_district_index)
	var hide_map_loot := (
		is_instance_valid(_story_controller)
		and _story_controller.should_hide_map_loot(_current_district_index)
	)
	if not hide_map_loot:
		for node in _resource_nodes:
			if not is_instance_valid(node):
				continue
			if bool(node.get_meta("picked_up", false)):
				continue
			if int(node.get_meta("district_index", -1)) != _current_district_index:
				continue
			var loot_local := node.global_position - foot_origin
			var loot_panel := _foot_local_to_panel(loot_local, _current_district_index)
			var loot_id := str(node.get_meta("item_id", "scrap"))
			var loot_radius := maxf(tile_px, tile_py) * 0.36
			var show_loot_name := _should_show_loot_label_at(loot_local)
			DayTopdownRender.draw_loot_pickup(self, loot_panel, loot_id, loot_radius, show_loot_name)
	_draw_interior_story_loot(tile_px, tile_py)


func _draw_interior_story_loot(tile_px: float, tile_py: float) -> void:
	if not is_instance_valid(_story_controller) or _current_district_index < 0:
		return
	var loot_radius := maxf(tile_px, tile_py) * 0.36
	for node in _story_controller.get_foot_loot_nodes():
		if not is_instance_valid(node):
			continue
		if not _story_controller.is_foot_loot_visible(node, _current_district_index):
			continue
		var loot_local: Vector2 = _story_controller.get_foot_loot_local(node, _current_district_index)
		var loot_panel: Vector2 = _foot_local_to_panel(loot_local, _current_district_index)
		var loot_id := str(node.get_meta("item_id", "scrap"))
		var show_loot_name := _should_show_loot_label_at(loot_local)
		var label_text := _story_controller.foot_loot_label(node)
		var prop_id := _story_controller.foot_loot_prop_id(node)
		if prop_id != "":
			continue
		else:
			DayTopdownRender.draw_loot_pickup(
				self,
				loot_panel,
				loot_id,
				loot_radius,
				show_loot_name,
				label_text,
			)
	var story_id := _story_controller.story_id_of_district(_current_district_index)
	if story_id != "":
		_draw_interior_story_quest_prop(self, _current_district_index, story_id)
	var dig_fx := _story_controller.get_prop_dig_fx(_current_district_index)
	if not dig_fx.is_empty():
		var dig_panel := _foot_local_to_panel(dig_fx.get("local", Vector2.ZERO), _current_district_index)
		var dig_item := str(dig_fx.get("item_id", "scrap"))
		DayTopdownRender.draw_loot_pickup(
			self,
			dig_panel,
			dig_item,
			loot_radius,
			true,
			ItemIconFactory.loot_display_name(dig_item),
		)

func _draw_night_camp_background() -> void:
	var view_size := get_viewport_rect().size
	if view_size == Vector2.ZERO:
		view_size = Vector2(1280.0, 720.0)
	draw_rect(Rect2(Vector2.ZERO, view_size), Color("#050810"), true)
	var camp_center := Vector2(view_size.x * 0.5, view_size.y * 0.62)
	if _map.is_valid_index(_current_district_index):
		var camp_rect := _map.cell_rect(_current_district_index)
		camp_center = camp_rect.position + camp_rect.size * 0.5
	draw_rect(Rect2(camp_center.x - 120.0, camp_center.y - 20.0, 240.0, 80.0), Color("#1a2533"), true)
	draw_rect(Rect2(camp_center.x - 90.0, camp_center.y - 50.0, 180.0, 36.0), Color("#d89246"), true)
	draw_circle(Vector2(camp_center.x - 140.0, camp_center.y + 10.0), 8.0, Color("#6ed08b"))
	draw_circle(Vector2(camp_center.x + 140.0, camp_center.y + 10.0), 8.0, Color("#6ed08b"))
	for i in range(12):
		var star_x := float(i * 97 % int(view_size.x))
		var star_y := 40.0 + float(i * 53 % int(view_size.y * 0.35))
		draw_circle(Vector2(star_x, star_y), 1.5, Color(0.7, 0.75, 0.9, 0.35))


func _setup_story_controller() -> void:
	_story_controller = StoryController.new()
	_story_controller.name = "StoryController"
	add_child(_story_controller)
	_story_controller.setup(self)
	_story_controller.ui_refresh_requested.connect(_on_story_ui_refresh)
	_story_controller.thunder_boss_requested.connect(_on_thunder_boss_requested)


var _story_refresh_guard := false

func _on_story_ui_refresh() -> void:
	if _story_refresh_guard:
		return
	_story_refresh_guard = true
	_schedule_refresh_ui()
	_refresh_backpack_if_open()
	_story_refresh_guard = false


func _story_blocks_ui() -> bool:
	return is_instance_valid(_story_controller) and _story_controller.is_ui_locked()


func _trigger_clone_restart() -> void:
	if _run_ended:
		return
	_run_ended = true
	_run_end_reason = "furnace_consumed"
	_hide_story_choice_overlay()
	if is_instance_valid(_story_controller):
		if is_instance_valid(_story_controller.npc_dialogue):
			_story_controller.npc_dialogue.reset_session()
		_story_controller._ui_locked = false
	if is_instance_valid(_player):
		_player.set_active(false)
	if is_instance_valid(_vehicle):
		_vehicle.set_active(false)
	_show_clone_restart_overlay()


func _show_clone_restart_overlay() -> void:
	if is_instance_valid(_clone_restart_overlay):
		_clone_restart_overlay.queue_free()
	_clone_restart_overlay = CanvasLayer.new()
	_clone_restart_overlay.layer = 140
	add_child(_clone_restart_overlay)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.08, 0.92)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_clone_restart_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clone_restart_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 220)
	HudTheme.apply_panel_container(panel)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "我死了。"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HudTheme.apply_label(title)
	vbox.add_child(title)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = "昆仑程序已记录本次勘探失败。正在培育下一名克隆体。\n\n新局将在 10 秒后开始……"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HudTheme.apply_label(body)
	vbox.add_child(body)
	get_tree().create_timer(10.0).timeout.connect(_on_clone_restart_timer_done)


func _on_clone_restart_timer_done() -> void:
	if is_instance_valid(_clone_restart_overlay):
		_clone_restart_overlay.queue_free()
		_clone_restart_overlay = null
	if SaveManager.has_save():
		SaveManager.delete_save()
	_start_new_run()


func _selected_enterable_district() -> int:
	var buildings := _get_enterable_buildings()
	if buildings.is_empty():
		return -1
	_building_pick_index = clampi(_building_pick_index, 0, buildings.size() - 1)
	return int(buildings[_building_pick_index].get("district_index", -1))


func _can_enter_district(district_index: int) -> bool:
	if not is_instance_valid(_story_controller):
		return district_index >= 0
	return _story_controller.can_enter_district(district_index)


func _migrate_sentinel_save_to_stories(sentinel: Dictionary) -> Dictionary:
	var phase := StoryRunState.PHASE_NONE
	if bool(sentinel.get("completed", false)):
		phase = StoryRunState.PHASE_DONE
	elif bool(sentinel.get("quest_active", false)):
		if int(sentinel.get("batteries_collected", 0)) >= 2:
			phase = StoryRunState.PHASE_REWARD
		else:
			phase = StoryRunState.PHASE_QUEST
	return {
		"sentinel_s09": {
			"phase": phase,
			"district": int(sentinel.get("district_index", -1)),
			"collect_count": int(sentinel.get("batteries_collected", 0)),
		},
	}


func _apply_overworld_biome_for_layer() -> void:
	var biome := DayTopdownRender.OverworldBiome.SNOW if _current_layer >= total_layers else DayTopdownRender.OverworldBiome.WILDERNESS
	DayTopdownRender.set_overworld_biome(biome)
	_mark_overworld_dirty()


func _generate_layer_map() -> void:
	if is_instance_valid(_story_controller):
		_story_controller.reset_for_new_run()
	_map.generate(
		map_columns,
		map_rows,
		cell_size,
		0,
		_current_layer >= total_layers,
		debug_start_near_special,
	)
	StoryData.ensure_story_districts(_map, _current_layer)
	StoryData.setup_tactical_hidden_sites(_map, _current_layer)
	if debug_start_near_special:
		_map.set_start_near_special_building(_current_layer >= total_layers)
	elif StoryData.any_story_spawns_near_start():
		StoryData.set_debug_start_near_story(_map)
	elif debug_start_at_story:
		StoryData.set_debug_start_near_story(_map)
	_elevator_repair_progress = 0
	_current_district_index = -1
	_apply_overworld_biome_for_layer()

func _advance_layer() -> void:
	if _run_ended:
		return
	if _current_layer >= total_layers:
		_request_terminal_access()
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
		minimap_view.set_war_fog_enabled(war_fog_enabled)
	_spawn_resources()
	if _map.start_node_index >= 0:
		_enter_node(_map.start_node_index, true)
