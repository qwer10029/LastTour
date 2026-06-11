extends Node

const MUSIC_BUS_NAME := "Music"
const MIN_VOLUME_DB := -60.0

const CUES := {
	"menu_main": {
		"path": "res://assets/music/menu_main.wav",
		"loop": true,
		"volume_db": -13.0,
		"fade_sec": 1.8,
	},
	"menu_select": {
		"path": "res://assets/music/menu_select.wav",
		"loop": true,
		"volume_db": -15.0,
		"fade_sec": 1.2,
	},
	"opening_prologue": {
		"path": "res://assets/music/opening_prologue.wav",
		"loop": true,
		"volume_db": -14.0,
		"fade_sec": 1.6,
	},
	"day_exploration": {
		"path": "res://assets/music/day_exploration.mp3",
		"loop": true,
		"volume_db": -17.0,
		"fade_sec": 2.0,
	},
	"evening_warning": {
		"path": "res://assets/music/evening_warning.wav",
		"loop": false,
		"volume_db": -10.0,
		"fade_sec": 0.0,
	},
	"night_setup": {
		"path": "res://assets/music/night_setup.wav",
		"loop": true,
		"volume_db": -15.0,
		"fade_sec": 1.2,
	},
	"night_combat": {
		"path": "res://assets/music/night_combat.mp3",
		"loop": true,
		"volume_db": -13.5,
		"fade_sec": 0.9,
	},
	"terminal": {
		"path": "res://assets/music/terminal.mp3",
		"loop": true,
		"volume_db": -16.0,
		"fade_sec": 1.1,
	},
	"truth_reveal": {
		"path": "res://assets/music/truth_reveal.mp3",
		"loop": true,
		"volume_db": -14.5,
		"fade_sec": 1.6,
	},
	"final_choice": {
		"path": "res://assets/music/final_choice.wav",
		"loop": true,
		"volume_db": -14.0,
		"fade_sec": 1.5,
	},
	"run_reset": {
		"path": "res://assets/music/run_reset.wav",
		"loop": false,
		"volume_db": -9.0,
		"fade_sec": 0.0,
	},
}

var _players: Array[AudioStreamPlayer] = []
var _stinger_player: AudioStreamPlayer
var _active_player_index := 0
var _current_cue := ""
var _stream_cache: Dictionary = {}
var _fade_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_music_bus()
	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "MusicPlayer%d" % (i + 1)
		player.bus = MUSIC_BUS_NAME
		player.volume_db = MIN_VOLUME_DB
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)
	_stinger_player = AudioStreamPlayer.new()
	_stinger_player.name = "MusicStingerPlayer"
	_stinger_player.bus = MUSIC_BUS_NAME
	_stinger_player.volume_db = -8.0
	_stinger_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_stinger_player)


func play_cue(cue_id: String, fade_sec: float = -1.0, restart: bool = false) -> void:
	if not CUES.has(cue_id):
		push_warning("MusicManager: unknown cue '%s'." % cue_id)
		return
	if cue_id == _current_cue and not restart and _active_player().playing:
		return
	var stream := _stream_for(cue_id)
	if stream == null:
		return
	var data: Dictionary = CUES[cue_id]
	var fade := float(data.get("fade_sec", 1.0)) if fade_sec < 0.0 else fade_sec
	var target_db := float(data.get("volume_db", -14.0))
	var old_player := _active_player()
	_active_player_index = 1 - _active_player_index
	var new_player := _active_player()
	new_player.stop()
	new_player.stream = stream
	new_player.volume_db = target_db if fade <= 0.0 else MIN_VOLUME_DB
	new_player.play()
	_current_cue = cue_id
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if fade <= 0.0:
		old_player.stop()
		old_player.volume_db = MIN_VOLUME_DB
		return
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	if old_player.playing:
		_fade_tween.tween_property(old_player, "volume_db", MIN_VOLUME_DB, fade)
		_fade_tween.tween_callback(Callable(old_player, "stop")).set_delay(fade)
	_fade_tween.tween_property(new_player, "volume_db", target_db, fade)


func play_stinger(cue_id: String, volume_db: float = INF) -> void:
	if not CUES.has(cue_id):
		push_warning("MusicManager: unknown stinger '%s'." % cue_id)
		return
	var stream := _stream_for(cue_id)
	if stream == null:
		return
	var data: Dictionary = CUES[cue_id]
	_stinger_player.stop()
	_stinger_player.stream = stream
	_stinger_player.volume_db = float(data.get("volume_db", -8.0)) if volume_db == INF else volume_db
	_stinger_player.play()


func stop_music(fade_sec: float = 0.8) -> void:
	_current_cue = ""
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if fade_sec <= 0.0:
		for player in _players:
			player.stop()
			player.volume_db = MIN_VOLUME_DB
		return
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	for player in _players:
		if player.playing:
			_fade_tween.tween_property(player, "volume_db", MIN_VOLUME_DB, fade_sec)
			_fade_tween.tween_callback(Callable(player, "stop")).set_delay(fade_sec)


func current_cue() -> String:
	return _current_cue


func _active_player() -> AudioStreamPlayer:
	return _players[_active_player_index]


func _stream_for(cue_id: String) -> AudioStream:
	if _stream_cache.has(cue_id):
		return _stream_cache[cue_id]
	var data: Dictionary = CUES[cue_id]
	var path := str(data.get("path", ""))
	var stream := _load_audio_stream(path, bool(data.get("loop", true)))
	if stream == null:
		push_warning("MusicManager: could not load music cue '%s' at %s." % [cue_id, path])
		return null
	_stream_cache[cue_id] = stream
	return stream


func _load_audio_stream(path: String, loop_enabled: bool) -> AudioStream:
	var stream: AudioStream = null
	var abs_path := ProjectSettings.globalize_path(path)
	var ext := path.get_extension().to_lower()
	# 运行期直接从文件加载（不依赖编辑器导入），按扩展名分派 WAV / MP3 / OGG。
	if ext == "mp3":
		if FileAccess.file_exists(abs_path) and ClassDB.class_has_method("AudioStreamMP3", "load_from_file"):
			stream = AudioStreamMP3.load_from_file(abs_path)
	elif ext == "wav":
		if FileAccess.file_exists(abs_path) and ClassDB.class_has_method("AudioStreamWAV", "load_from_file"):
			stream = AudioStreamWAV.load_from_file(abs_path)
	if stream == null and ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop_enabled else AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop_enabled
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop_enabled
	return stream


func _ensure_music_bus() -> void:
	var bus_index := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	if bus_index >= 0:
		return
	AudioServer.add_bus()
	bus_index = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, MUSIC_BUS_NAME)
	AudioServer.set_bus_volume_db(bus_index, 0.0)
