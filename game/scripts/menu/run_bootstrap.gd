class_name RunBootstrap
extends RefCounted
## 新局启动前预加载渲染资源并生成世界地图，供加载场景汇报进度。

const DayTopdownRenderScript := preload("res://scripts/day_topdown_render.gd")

const MAP_COLUMNS := 24
const MAP_ROWS := 18
const CELL_SIZE := Vector2i(720, 720)
const TOTAL_LAYERS := 3
const DEBUG_START_NEAR_SPECIAL := true
const DEBUG_START_AT_STORY := true

const TEXTURE_STEP_WEIGHT := 0.40
const MAP_STEP_WEIGHT := 0.52
const STORY_STEP_WEIGHT := 0.08


static func build_new_run_map(on_progress: Callable = Callable()) -> WorldMapData:
	var map := WorldMapData.new()
	var current_layer := 1
	var is_final_layer := current_layer >= TOTAL_LAYERS
	_report(on_progress, TEXTURE_STEP_WEIGHT, "初始化路网网格…")
	map.generate(
		MAP_COLUMNS,
		MAP_ROWS,
		CELL_SIZE,
		0,
		is_final_layer,
		DEBUG_START_NEAR_SPECIAL,
		func(local_ratio: float, label: String) -> void:
			_report(
				on_progress,
				TEXTURE_STEP_WEIGHT + local_ratio * MAP_STEP_WEIGHT,
				label,
			),
	)
	_report(on_progress, TEXTURE_STEP_WEIGHT + MAP_STEP_WEIGHT, "布置剧情据点…")
	StoryData.ensure_story_districts(map, current_layer)
	StoryData.setup_tactical_hidden_sites(map, current_layer)
	ArmorySiteData.place_on_map(map, current_layer)
	if DEBUG_START_NEAR_SPECIAL:
		map.set_start_near_special_building(is_final_layer)
	elif StoryData.any_story_spawns_near_start():
		StoryData.set_debug_start_near_story(map)
	elif DEBUG_START_AT_STORY:
		StoryData.set_debug_start_near_story(map)
	_report(on_progress, TEXTURE_STEP_WEIGHT + MAP_STEP_WEIGHT + STORY_STEP_WEIGHT, "地图数据就绪")
	return map


static func preload_render_assets(on_progress: Callable = Callable()) -> void:
	_report(on_progress, 0.0, "加载路网材质…")
	DayTopdownRenderScript.reload_road_textures()
	_report(on_progress, 0.28, "加载场景道具…")
	DayTopdownRenderScript.reload_prop_textures()
	_report(on_progress, 0.56, "生成野外地表…")
	DayTopdownRenderScript.preload_wilderness_noise()
	_report(on_progress, 0.78, "加载室内贴图…")
	DayTopdownRenderScript.preload_interior_textures()
	_report(on_progress, TEXTURE_STEP_WEIGHT, "渲染资源就绪")


static func pack_bootstrap(map: WorldMapData) -> Dictionary:
	return {
		"map": map,
		"textures_preloaded": true,
		"current_layer": 1,
	}


static func _report(on_progress: Callable, ratio: float, label: String) -> void:
	if on_progress.is_valid():
		on_progress.call(clampf(ratio, 0.0, 1.0), label)
