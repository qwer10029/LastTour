extends Node
class_name StoryGateDialogue

signal quest_accepted(story_id: String)
signal quest_declined(story_id: String)
signal reward_chosen(story_id: String, choice: Dictionary)
signal dialogue_updated

enum Phase { IDLE, INTRO, INTRO_CHOICE, REWARD_CHOICE }

var phase: int = Phase.IDLE
var story_id: String = ""
var step: int = 0
var npc_bubble: String = ""
var player_bubble: String = ""


func is_active() -> bool:
	return phase != Phase.IDLE


func start_intro(p_story_id: String) -> void:
	story_id = p_story_id
	phase = Phase.INTRO
	step = 0
	_apply_intro_line()
	dialogue_updated.emit()


func advance_intro() -> void:
	if phase != Phase.INTRO or story_id == "":
		return
	step += 1
	var lines := StoryData.gate_lines(story_id)
	if step >= lines.size():
		phase = Phase.INTRO_CHOICE
		npc_bubble = StoryData.gate_field(story_id, "choice_npc", "")
		player_bubble = ""
	else:
		_apply_intro_line()
	dialogue_updated.emit()


func accept_quest() -> void:
	if phase != Phase.INTRO_CHOICE or story_id == "":
		return
	phase = Phase.IDLE
	npc_bubble = StoryData.gate_field(story_id, "accept_npc", "")
	player_bubble = StoryData.gate_field(story_id, "accept_player", "")
	var sid := story_id
	story_id = ""
	quest_accepted.emit(sid)
	dialogue_updated.emit()


func decline_quest() -> void:
	if phase != Phase.INTRO_CHOICE or story_id == "":
		return
	phase = Phase.IDLE
	npc_bubble = StoryData.gate_field(story_id, "decline_npc", "")
	player_bubble = ""
	var sid := story_id
	story_id = ""
	quest_declined.emit(sid)
	dialogue_updated.emit()


func start_reward(p_story_id: String) -> void:
	story_id = p_story_id
	phase = Phase.REWARD_CHOICE
	npc_bubble = StoryData.reward_gate_npc(story_id)
	player_bubble = ""
	dialogue_updated.emit()


func choose_reward_by_index(index: int) -> void:
	if phase != Phase.REWARD_CHOICE or story_id == "":
		return
	var choice := StoryData.choice_by_index(story_id, index)
	if choice.is_empty():
		return
	var sid := story_id
	story_id = ""
	phase = Phase.IDLE
	npc_bubble = ""
	player_bubble = ""
	reward_chosen.emit(sid, choice)
	dialogue_updated.emit()


func _apply_intro_line() -> void:
	var lines := StoryData.gate_lines(story_id)
	if step < 0 or step >= lines.size():
		return
	var line: Dictionary = lines[step]
	var speaker := str(line.get("speaker", "npc"))
	var text := str(line.get("text", ""))
	if speaker == "player":
		player_bubble = text
		npc_bubble = ""
	else:
		npc_bubble = text
		player_bubble = ""
