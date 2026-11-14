extends SceneTree

## 回归检查：交还任务物品后、报酬/结局写入前被打断（入夜、走出建筑），回来对话要能接着走完。
## 旧逻辑只给编史者 04 配了续接表：AD-1 在 repair_01 扣掉电机后入夜，回来从 return_start 开始，
## 「把电机组件装上去」因背包里没有电机被隐藏，只剩「还没准备好」，AD-1 永远无法完成。
## S-09（电池）同理。
## 运行：godot --headless --path . --script res://tools/handover_resume_checks.gd

const HOST_SOURCE := """
extends Node
var _run_journal = load("res://scripts/run_journal.gd").new()
var _backpack = load("res://scripts/items/inventory_data.gd").new()
var _current_layer := 2
var _map = null
var time_system = null
var banners: Array = []
func _on_journal_entry_added(encounter_id: String) -> void:
	banners.append(encounter_id)
"""

var _failures: Array[String] = []


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


## 模拟入夜/离开：中断会话，再像玩家回来在 NPC 旁按 E 一样重新开始对话。
func _interrupt_and_retalk(controller, npc, sid: String, interior: bool = true) -> void:
	if interior:
		controller.suspend_interior_dialogue_for_drive(sid)
	else:
		npc.reset_session()
	# 与 _handle_npc_dialogue_interact 相同的入口选择（任务物品已集齐 → 续接节点或 return_start）。
	var entry: String = controller._post_handover_resume_node(sid)
	if entry == "":
		entry = "return_start"
	_expect(not npc.is_active(), "%s dialogue should be suspended" % sid)
	npc.start_dialogue(sid, entry, controller._dialogue_context(sid))


func _finish(npc) -> void:
	for _i in range(10):
		if not npc.is_active():
			return
		if npc.phase != 1:
			return
		npc.advance_line()


func _start_return(controller, host, sid: String, item: String, count: int) -> Object:
	controller.run_state.set_phase(sid, "quest")
	controller.run_state.set_collect_count(sid, count)
	host._backpack.add(item, count)
	var npc = controller.npc_dialogue
	npc.start_dialogue(sid, "return_start", controller._dialogue_context(sid))
	_expect(npc.phase == 2, "%s return_start should offer options" % sid)
	return npc


func _check_ad1_interrupt_after_motor_removed(reward_index: int, encounter_id: String) -> void:
	var pair := _make_controller()
	var host: Node = pair[0]
	var controller: Node = pair[1]
	var sid := "ad_1_radar"
	var npc = _start_return(controller, host, sid, "quest:radar_motor", 1)
	npc.choose_option(0)  # 把电机组件装上去。
	_expect(npc.get_current_node_id() == "repair_01", "AD-1 should be on repair_01 (at %s)" % npc.get_current_node_id())
	_expect(not host._backpack.has("quest:radar_motor", 1), "motor should be removed on repair_01")
	# 入夜：玩家正看着「组件卡进旋转机构的槽位……」
	_interrupt_and_retalk(controller, npc, sid)
	_expect(_advance_to(npc, "reward_choice"), "AD-1 re-talk should reach reward_choice (at %s, phase %d)" % [npc.get_current_node_id(), npc.phase])
	_expect(npc.phase == 2, "AD-1 reward_choice should offer the three rewards")
	npc.choose_option(reward_index)
	_finish(npc)
	_expect(host._run_journal.has_encounter(encounter_id), "%s should be in the journal after the resumed talk" % encounter_id)
	_expect(controller.run_state.is_completed(sid), "AD-1 should be completed after the resumed talk")
	host.queue_free()


func _check_ad1_interrupt_after_reward() -> void:
	var pair := _make_controller()
	var host: Node = pair[0]
	var controller: Node = pair[1]
	var sid := "ad_1_radar"
	var npc = _start_return(controller, host, sid, "quest:radar_motor", 1)
	npc.choose_option(0)
	_expect(_advance_to(npc, "reward_choice"), "AD-1 should reach reward_choice")
	var fuel_before := int(host._backpack.items.get("fuel", 0))
	npc.choose_option(0)  # A · 五桶燃料
	_expect(_advance_to(npc, "path_a_02"), "AD-1 should reach path_a_02")
	var fuel_after := int(host._backpack.items.get("fuel", 0))
	_expect(fuel_after == fuel_before + 5, "path_a_02 should give 5 fuel (got %d -> %d)" % [fuel_before, fuel_after])
	_interrupt_and_retalk(controller, npc, sid)
	_finish(npc)
	_expect(int(host._backpack.items.get("fuel", 0)) == fuel_after, "resuming after path_a_02 must not give the fuel again")
	_expect(controller.run_state.is_completed(sid), "AD-1 should be completed after resuming past the reward")
	_expect(host._run_journal.get_entries().size() == 1, "AD-1 journal entry must be recorded exactly once")
	host.queue_free()


func _check_s09_interrupt_after_batteries() -> void:
	var pair := _make_controller()
	var host: Node = pair[0]
	var controller: Node = pair[1]
	var sid := "sentinel_s09"
	var npc = _start_return(controller, host, sid, "quest:sentinel_battery", 2)
	npc.choose_option(0)  # give_two
	_expect(npc.get_current_node_id() == "give_two", "S-09 should be on give_two (at %s)" % npc.get_current_node_id())
	_interrupt_and_retalk(controller, npc, sid, false)
	_expect(_advance_to(npc, "reward_choice"), "S-09 re-talk should reach reward_choice (at %s, phase %d)" % [npc.get_current_node_id(), npc.phase])
	npc.choose_option(1)  # blueprint
	_finish(npc)
	_expect(controller.run_state.is_completed(sid), "S-09 should be completed after the resumed talk")
	_expect(host._run_journal.get_entries().size() == 1, "S-09 journal entry should be recorded once (got %d)" % host._run_journal.get_entries().size())
	host.queue_free()


func _run() -> void:
	await process_frame
	_check_ad1_interrupt_after_motor_removed(0, "ad_1_radar_fuel")
	_check_ad1_interrupt_after_motor_removed(1, "ad_1_radar_coords")
	_check_ad1_interrupt_after_motor_removed(2, "ad_1_radar_tower")
	_check_ad1_interrupt_after_reward()
	_check_s09_interrupt_after_batteries()
	await process_frame
	if _failures.is_empty():
		print("HANDOVER_RESUME_CHECKS_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
