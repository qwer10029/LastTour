extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_check_evidence_items()
	await _check_terminal_audit()
	await _check_td_mechanics()
	if _failures.is_empty():
		print("TD_FEATURE_CHECKS_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _check_evidence_items() -> void:
	var inv := InventoryData.new()
	_expect(inv.add("evidence:backdoor_info", 1) == 1, "evidence item should be accepted by inventory")
	_expect(inv.has("evidence:backdoor_info", 1), "evidence item should be countable")
	_expect(ItemDefs.get_def("evidence:backdoor_info").get("is_evidence", false), "evidence item def should be synthesized")
	_expect(ItemIconFactory.loot_draw_id("evidence:backdoor_info") == "evidence", "evidence should use evidence draw id")


func _check_terminal_audit() -> void:
	var terminal_script := load("res://scripts/ui/communication_terminal.gd")
	var terminal: CanvasLayer = terminal_script.new()
	root.add_child(terminal)
	await process_frame
	terminal.start_flow([], 3, 1, {})
	var fail_report: Dictionary = terminal._evidence_audit_report()
	_expect(not bool(fail_report.get("passed", true)), "terminal audit should fail without evidence")
	var evidence_pack := {}
	for evidence_id in _terminal_required_evidence_ids():
		evidence_pack["evidence:%s" % evidence_id] = 1
	terminal.start_flow([], 3, 1, evidence_pack)
	var pass_report: Dictionary = terminal._evidence_audit_report()
	_expect(bool(pass_report.get("passed", false)), "terminal audit should pass with all required evidence")
	terminal.queue_free()
	await process_frame


func _check_td_mechanics() -> void:
	var scene := load("res://scenes/night_td/night_td.tscn") as PackedScene
	_expect(scene != null, "night TD scene should load")
	if scene == null:
		return
	_expect(float(NightTdDefs.get_tower_def("splash").get("range", 0.0)) >= 160.0, "splash tower should have wider range")
	var repair_inv := InventoryData.new()
	repair_inv.add("parts", ItemDefs.VEHICLE_REPAIR_PARTS_EACH)
	repair_inv.add("wood", ItemDefs.VEHICLE_REPAIR_WOOD_EACH)
	_expect(ItemDefs.can_repair_vehicle_with_inventory(repair_inv), "vehicle repair should require parts and wood")
	_check_wave_scheduler_counts_are_stable()
	var td: Node = scene.instantiate()
	root.add_child(td)
	await process_frame
	td.start_session(
		10,
		1,
		1,
		false,
		100.0,
		100.0,
		{"scrap": 20, "wood": 10, "parts": 10, "fuel": 5, "supplies": 5},
		{},
		20.0,
		100.0
	)
	await process_frame
	td.set_process(false)

	td._on_fuel_boost_pressed()
	td._update_fuel_boost(1.0)
	_expect(absf(float(td._fuel_boost_spent) - 1.2) < 0.02, "fuel boost should burn fuel gradually")
	_expect(absf(float(td._vehicle_fuel) - 18.8) < 0.02, "fuel boost should reduce vehicle fuel")
	var result: Dictionary = td._build_result()
	_expect(absf(float(result.get("fuel_boost_loss", 0.0)) - 1.2) < 0.02, "result should record boost fuel loss")
	_expect(float(result.get("fuel_loss", 0.0)) >= 1.2, "result fuel_loss should include boost fuel spent")

	td._towers.clear()
	td._towers.append({
		"id": 101,
		"type": "cryo_beacon",
		"cell": Vector2i(1, 1),
		"world_pos": Vector2.ZERO,
		"removed": false,
		"power_scale": 1.0,
	})
	td._mark_tower_cache_dirty()
	_expect(td._slow_factor_at(Vector2(8, 0), {"effect_immune": false}) < 1.0, "noise beacon should slow normal enemies")
	_expect(td._slow_factor_at(Vector2(8, 0), {"effect_immune": true}) == 1.0, "noise beacon should not slow effect-immune enemies")

	td._enemies.clear()
	td._enemies.append({"eid": 1, "type": "repair_mender", "faction": "enemy", "hp": 95.0, "max_hp": 95.0, "pos": Vector2.ZERO, "heal_radius": 82.0, "heal_per_sec": 8.0})
	td._enemies.append({"eid": 2, "type": "drone", "faction": "enemy", "hp": 20.0, "max_hp": 55.0, "pos": Vector2(24, 0)})
	td._rebuild_enemy_index_cache()
	td._healer_aura_accum = 0.0
	td._update_enemy_auras(0.2)
	_expect(float(td._enemies[1]["hp"]) > 20.0 and float(td._enemies[1]["hp"]) <= 55.0, "repair mender should heal nearby enemies without exceeding max hp")

	td._enemies.clear()
	td._enemies.append({
		"eid": 10,
		"type": "terminal_overseer",
		"faction": "enemy",
		"hp": 900.0,
		"max_hp": 900.0,
		"pos": Vector2.ZERO,
		"summon_enemy": "swarm",
		"summon_interval_sec": 8.0,
		"summon_timer": 0.1,
		"max_summoned_alive": 8,
		"summoned_by": -1,
	})
	td._rebuild_enemy_index_cache()
	td._update_enemy_specials(0.2)
	_expect(td._enemies.size() == 2 and int(td._enemies[1].get("summoned_by", -1)) == 10, "terminal overseer should summon enemies while alive")
	_expect(absf(float(td._breach_damage_for({"breach_damage_factor": 0.66, "base_damage": 30.0})) - 66.0) < 0.01, "boss breach should deal 66 percent of max vehicle hp")

	td._towers.clear()
	td._towers.append({
		"id": 201,
		"type": "jammer",
		"cell": Vector2i(1, 1),
		"world_pos": Vector2.ZERO,
		"removed": false,
		"power_scale": 1.0,
		"cooldown": 0.0,
		"target_eid": -1,
	})
	td._enemies.clear()
	td._enemies.append({"eid": 21, "type": "drone", "faction": "enemy", "hp": 55.0, "max_hp": 55.0, "pos": Vector2(48, 0)})
	td._enemies.append({"eid": 22, "type": "drone", "faction": "enemy", "hp": 55.0, "max_hp": 55.0, "pos": Vector2(72, 0)})
	td._rebuild_enemy_index_cache()
	td._update_towers(1.0)
	var first_target := int(td._towers[0].get("target_eid", -1))
	td._enemies[1]["pos"] = Vector2(8, 0)
	td._towers[0]["cooldown"] = 0.0
	td._update_towers(1.0)
	_expect(int(td._towers[0].get("target_eid", -1)) == first_target, "damaging tower should keep a valid locked target")
	td._enemies[0]["hp"] = 0.0
	td._towers[0]["cooldown"] = 0.0
	td._update_towers(1.0)
	_expect(int(td._towers[0].get("target_eid", -1)) == 22, "damaging tower should retarget after locked target dies")

	td._towers.clear()
	td._towers.append({
		"id": 301,
		"type": "hacker",
		"cell": Vector2i(2, 2),
		"world_pos": Vector2.ZERO,
		"removed": false,
		"power_scale": 1.0,
		"target_eid": -1,
		"hack_progress": 0.0,
	})
	td._enemies.clear()
	td._enemies.append({"eid": 41, "type": "drone", "faction": "enemy", "hp": 55.0, "max_hp": 55.0, "pos": Vector2(20, 0), "base_damage": 4.0, "speed": 40.0, "hack_resist": 1.0, "hack_immune": false})
	td._enemies.append({"eid": 42, "type": "heavy", "faction": "enemy", "hp": 220.0, "max_hp": 220.0, "pos": Vector2(48, 0), "base_damage": 12.0, "speed": 22.0, "hack_resist": 1.0, "hack_immune": false})
	td._rebuild_enemy_index_cache()
	td._update_hackers(0.1)
	_expect(int(td._towers[0].get("target_eid", -1)) == 42, "idle powered hacker should auto-target a high-value enemy in range")
	td._towers[0]["target_eid"] = 41
	td._selected_hacker_id = 301
	td._on_cell_combat_clicked(Vector2i(5, 5))
	_expect(int(td._towers[0].get("target_eid", -1)) == 41, "missed hacker assignment click should not clear previous target")

	td.queue_free()
	await process_frame


func _check_wave_scheduler_counts_are_stable() -> void:
	var plan := NightTdWavePlan.new()
	plan.waves = [{
		"id": 1,
		"entries": [
			{"enemy": "drone", "count": 3, "spawn_interval": 0.1},
			{"enemy": "scout", "count": 2, "spawn_interval": 0.1},
		],
	}]
	var easy := NightTdWaveScheduler.new()
	easy.build_from_plan(plan, 0, 1)
	var hard_late := NightTdWaveScheduler.new()
	hard_late.build_from_plan(plan, 2, 8)
	_expect(easy.total_spawn_events == 5, "easy wave count should match plan count")
	_expect(hard_late.total_spawn_events == 5, "hard late wave count should not inflate enemy count")


func _terminal_required_evidence_ids() -> Array[String]:
	var out: Array[String] = []
	var evidence_data := root.get_node_or_null("EvidenceData")
	if evidence_data != null and evidence_data.has_method("terminal_required_ids"):
		var ids: Variant = evidence_data.call("terminal_required_ids")
		if ids is Array:
			for id in ids:
				out.append(str(id))
	if out.is_empty():
		out = ["backdoor_info", "clone_identity", "faction_conflict", "human_extinction_proof"]
	return out
