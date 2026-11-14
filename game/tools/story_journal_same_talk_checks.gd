extends SceneTree

## 回归检查：关键情报 NPC 在「同一次对话」里走到结局，日记/计数/横幅立即生效。
## 旧逻辑把日记写入推迟到 story_done（「对话结束。勘探日记已更新。」）之后的 end_dialogue：
## 玩家停在那一句就走出建筑（或入夜）时，本局日记仍是空的，要再找 NPC 对话一次才写入。
## 运行：godot --headless --path . --script res://tools/story_journal_same_talk_checks.gd

const HOST_SOURCE := """
extends Node
var _run_journal = load("res://scripts/run_journal.gd").new()
var _backpack = load("res://scripts/items/inventory_data.gd").new()
var _current_layer := 1
var _map = null
var time_system = null
var banners: Array = []
func _on_journal_entry_added(encounter_id: String) -> void:
	banners.append(encounter_id)
"""

var _failures: Array[String] = []
var _jd: Node


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _make_controller() -> Array:
	var host_script := GDScript.new()
	host_script.source_code = HOST_SOURCE
	host_script.reload()
	var host: Node = host_script.new()
	root.add_child(host)
	var controller: Node = load("res://scripts/story/story_controller.gd").new()
	host.add_child(controller)
	controller.setup(host)
	return [host, controller]


func _advance_to(npc, node_id: String, max_steps: int = 12) -> bool:
	for _i in range(max_steps):
		if npc.get_current_node_id() == node_id:
			return true
		if npc.phase != 1:  # Phase.LINE
			return false
		npc.advance_line()
	return npc.get_current_node_id() == node_id


func _truth_count(host) -> int:
	var ids: Array = []
	for entry in host._run_journal.get_entries():
		ids.append(str(entry.get("encounter_id", "")))
	return int(_jd.collected_required_truth_count(ids))


func _check_chronicler() -> void:
	var pair := _make_controller()
	var host: Node = pair[0]
	var controller: Node = pair[1]
	var sid := "chronicler_04"
	controller.run_state.set_phase(sid, "quest")
	controller.run_state.set_collect_count(sid, 2)
	host._backpack.add("quest:chronicler_memory", 2)
	var npc = controller.npc_dialogue
	npc.start_dialogue(sid, "return_start", controller._dialogue_context(sid))
	_expect(npc.phase == 2, "chronicler return_start should offer options")
	npc.choose_option(0)  # 把存储模块装回去。
	_expect(_advance_to(npc, "story_done"), "chronicler should reach story_done (at %s)" % npc.get_current_node_id())
	# 玩家此刻看到「对话结束。勘探日记已更新。」——日记必须已经写好。
	_expect(host._run_journal.has_encounter("chronicler_repair"), "chronicler_repair should be in the run journal when '对话结束。勘探日记已更新。' shows")
	_expect(_truth_count(host) == 1, "intel counter should read 1 / 4 at story_done (got %d)" % _truth_count(host))
	_expect(host.banners == ["chronicler_repair"], "key-intel banner should fire once at story_done (got %s)" % [host.banners])
	# 停在这一句直接走出建筑（同 suspend_interior_dialogue_for_drive），再回来对话。
	controller.suspend_interior_dialogue_for_drive(sid)
	_expect(host._run_journal.has_encounter("chronicler_repair"), "entry must survive leaving the building at story_done")
	var entry: String = controller._interior_dialogue_entry(sid)
	npc.start_dialogue(sid, entry, controller._dialogue_context(sid))
	for _i in range(8):
		if not npc.is_active():
			break
		npc.advance_line()
	_expect(controller.run_state.is_completed(sid), "chronicler should be completed after the re-talk")
	_expect(host._run_journal.get_entries().size() == 1, "re-talk must not duplicate the journal entry (got %d)" % host._run_journal.get_entries().size())
	_expect(host.banners.size() == 1, "re-talk must not repeat the banner (got %s)" % [host.banners])
	host.queue_free()


func _check_same_talk(sid: String, unlock_node: String, encounter_id: String) -> void:
	var pair := _make_controller()
	var host: Node = pair[0]
	var controller: Node = pair[1]
	var npc = controller.npc_dialogue
	npc.start_dialogue(sid, unlock_node, controller._dialogue_context(sid))
	_expect(_advance_to(npc, "story_done"), "%s should reach story_done from %s" % [sid, unlock_node])
	_expect(host._run_journal.has_encounter(encounter_id), "%s should be in the run journal at story_done" % encounter_id)
	_expect(host.banners == [encounter_id], "%s banner should fire at story_done (got %s)" % [encounter_id, host.banners])
	_expect(_truth_count(host) == 1, "%s should count as 1 key intel at story_done" % encounter_id)
	npc.advance_line()  # story_done → story_done_close (end_dialogue)
	_expect(not npc.is_active(), "%s dialogue should close after story_done" % sid)
	_expect(controller.run_state.is_completed(sid), "%s should be completed after closing" % sid)
	_expect(host._run_journal.get_entries().size() == 1 and host.banners.size() == 1, "%s must be recorded exactly once" % encounter_id)
	host.queue_free()


func _run() -> void:
	await process_frame
	_jd = root.get_node("JournalData")
	_check_chronicler()
	_check_same_talk("furnace_qc", "path_b_survive_02", "furnace_truth")
	_check_same_talk("staff_officer_07", "path_b_05", "staff_officer_07_calibrate")
	_check_same_talk("marian_k142", "path_a_reward", "marian_obey")
	await process_frame
	if _failures.is_empty():
		print("STORY_JOURNAL_SAME_TALK_CHECKS_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
