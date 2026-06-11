extends Node

## 设置管理（Part E）：音量（主/音乐）、全屏开关，持久化到 user://settings.cfg。
## 开机即加载并应用。音乐总线由 MusicManager 在其 _ready 里创建，故本 autoload
## 排在其后，_ready 时总线已存在。

const SETTINGS_PATH := "user://settings.cfg"
const MUSIC_BUS_NAME := "Music"
const MIN_DB := -40.0   # 滑条 0% 对应的分贝（再低听感上等于静音）

var master_volume: float = 1.0   # 0..1 线性
var music_volume: float = 1.0    # 0..1 线性
var fullscreen: bool = false


func _ready() -> void:
	load_settings()
	apply_all()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "master", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", 1.0)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("video", "fullscreen", false))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)


func apply_all() -> void:
	_apply_bus_volume("Master", master_volume)
	_apply_bus_volume(MUSIC_BUS_NAME, music_volume)
	_apply_fullscreen()


func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_bus_volume("Master", master_volume)
	save_settings()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_bus_volume(MUSIC_BUS_NAME, music_volume)
	save_settings()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_fullscreen()
	save_settings()


## 线性音量(0..1) → 分贝。0 时静音；否则在 [MIN_DB, 0] 间映射。
func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if linear <= 0.001:
		AudioServer.set_bus_mute(idx, true)
		return
	AudioServer.set_bus_mute(idx, false)
	var db := linear_to_db(linear)
	AudioServer.set_bus_volume_db(idx, clampf(db, MIN_DB, 6.0))


func _apply_fullscreen() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
