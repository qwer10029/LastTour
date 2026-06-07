extends Node
class_name SentinelGateDialogue

signal quest_accepted
signal quest_declined
signal reward_chosen(option: Dictionary)
signal dialogue_updated

enum Phase { IDLE, INTRO, INTRO_CHOICE, REWARD_CHOICE }

var phase: int = Phase.IDLE
var step: int = 0
var npc_bubble: String = ""
var player_bubble: String = ""
var awaiting_reward_key: bool = false


func is_active() -> bool:
	return phase != Phase.IDLE


func start_intro() -> void:
	phase = Phase.INTRO
	step = 0
	awaiting_reward_key = false
	_apply_intro_line()
	dialogue_updated.emit()


func advance_intro() -> bool:
	if phase != Phase.INTRO:
		return false
	step += 1
	if step >= SentinelEncounterDefs.GATE_LINES.size():
		phase = Phase.INTRO_CHOICE
		npc_bubble = SentinelEncounterDefs.GATE_CHOICE_NPC
		player_bubble = ""
		dialogue_updated.emit()
		return true
	_apply_intro_line()
	dialogue_updated.emit()
	return true


func accept_quest() -> void:
	if phase != Phase.INTRO_CHOICE:
		return
	phase = Phase.IDLE
	awaiting_reward_key = false
	npc_bubble = SentinelEncounterDefs.GATE_ACCEPT_NPC
	player_bubble = SentinelEncounterDefs.GATE_ACCEPT_PLAYER
	quest_accepted.emit()
	dialogue_updated.emit()


func decline_quest() -> void:
	if phase != Phase.INTRO_CHOICE:
		return
	phase = Phase.IDLE
	awaiting_reward_key = false
	npc_bubble = SentinelEncounterDefs.GATE_DECLINE_NPC
	player_bubble = ""
	quest_declined.emit()
	dialogue_updated.emit()


func start_reward() -> void:
	phase = Phase.REWARD_CHOICE
	awaiting_reward_key = true
	npc_bubble = SentinelEncounterDefs.REWARD_NPC
	player_bubble = ""
	dialogue_updated.emit()


func choose_reward_by_index(index: int) -> void:
	if phase != Phase.REWARD_CHOICE:
		return
	if index < 0 or index >= SentinelEncounterDefs.REWARD_OPTIONS.size():
		return
	var option: Dictionary = SentinelEncounterDefs.REWARD_OPTIONS[index].duplicate(true)
	phase = Phase.IDLE
	awaiting_reward_key = false
	npc_bubble = ""
	player_bubble = ""
	reward_chosen.emit(option)
	dialogue_updated.emit()


func clear_after_delay() -> void:
	npc_bubble = ""
	player_bubble = ""
	dialogue_updated.emit()


func _apply_intro_line() -> void:
	var line: Dictionary = SentinelEncounterDefs.GATE_LINES[step]
	var speaker := str(line.get("speaker", "npc"))
	var text := str(line.get("text", ""))
	if speaker == "player":
		player_bubble = text
		npc_bubble = ""
	else:
		npc_bubble = text
		player_bubble = ""
