extends SceneTree

const CAPTURE_DIR := "user://codex_scene_captures"

var _root: Window
var _capture_viewport: SubViewport
var _scene_root: Node


func _initialize() -> void:
	_root = root
	_root.size = Vector2i(1280, 720)
	_capture_viewport = SubViewport.new()
	_capture_viewport.size = Vector2i(1280, 720)
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_capture_viewport.disable_3d = true
	_root.add_child(_capture_viewport)
	_scene_root = Node.new()
	_scene_root.name = "CaptureSceneRoot"
	_capture_viewport.add_child(_scene_root)
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	if DisplayServer.get_name() == "headless":
		print("CAPTURE_SKIPPED headless display server cannot provide viewport images")
		await _exercise_scene_loads()
		quit()
		return
	await _capture_day()
	await _capture_night()
	await _capture_ending_ceremony()
	await _capture_ending_outcome()
	quit()


func _exercise_scene_loads() -> void:
	await _capture_day(false)
	await _capture_night(false)
	await _capture_ending_ceremony(false)
	await _capture_ending_outcome(false)


func _clear_root() -> void:
	for child in _scene_root.get_children():
		child.queue_free()


func _settle(frames: int = 8) -> void:
	for i in range(frames):
		await process_frame


func _save_viewport(name: String) -> void:
	await _settle(2)
	var texture := _capture_viewport.get_texture()
	if texture == null:
		push_error("Capture viewport texture is unavailable for %s" % name)
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		push_error("Capture image is unavailable for %s" % name)
		return
	var path := "%s/%s.png" % [CAPTURE_DIR, name]
	var err := image.save_png(path)
	if err != OK:
		push_error("Failed to save capture %s: %s" % [path, err])
	else:
		print("CAPTURED %s" % ProjectSettings.globalize_path(path))


func _capture_day(save_image: bool = true) -> void:
	_clear_root()
	var scene := load("res://scenes/day_exploration.tscn") as PackedScene
	if scene == null:
		push_error("Cannot load day scene")
		return
	var day := scene.instantiate()
	_scene_root.add_child(day)
	await _settle(20)
	if save_image:
		await _save_viewport("day_exploration")
	else:
		print("SCENE_LOADED day_exploration")


func _capture_night(save_image: bool = true) -> void:
	_clear_root()
	var scene := load("res://scenes/night_td/night_td.tscn") as PackedScene
	if scene == null:
		push_error("Cannot load night scene")
		return
	var night := scene.instantiate()
	_scene_root.add_child(night)
	await _settle(5)
	if night.has_method("start_session"):
		night.start_session(
			10,
			GameManager.Difficulty.NORMAL,
			1,
			true,
			100.0,
			100.0,
			{"scrap": 5, "wood": 3, "parts": 2, "fuel": 2, "supplies": 4},
			)
	await _settle(20)
	if save_image:
		await _save_viewport("night_td")
	else:
		print("SCENE_LOADED night_td")


func _capture_ending_ceremony(save_image: bool = true) -> void:
	_clear_root()
	_add_backdrop()
	var overlay_script := load("res://scripts/ui/run_end_overlay.gd")
	if overlay_script == null:
		push_error("Cannot load run end overlay")
		return
	var overlay := overlay_script.new() as CanvasLayer
	_scene_root.add_child(overlay)
	await _settle(5)
	if overlay.has_method("show_ceremony"):
		overlay.show_ceremony()
	await _settle(12)
	if save_image:
		await _save_viewport("ending_ceremony")
	else:
		print("SCENE_LOADED ending_ceremony")


func _capture_ending_outcome(save_image: bool = true) -> void:
	_clear_root()
	_add_backdrop()
	var overlay_script := load("res://scripts/ui/ending_outcome_overlay.gd")
	if overlay_script == null:
		push_error("Cannot load ending outcome overlay")
		return
	var overlay := overlay_script.new() as CanvasLayer
	_scene_root.add_child(overlay)
	await _settle(5)
	if overlay.has_method("show_outcome"):
		overlay.show_outcome("stop_signal", 3, 12)
	await _settle(12)
	if save_image:
		await _save_viewport("ending_outcome")
	else:
		print("SCENE_LOADED ending_outcome")


func _add_backdrop() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.025, 0.04, 1.0)
	_scene_root.add_child(backdrop)
