extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_check_terminal_audit()
	await _check_tutorial_craft_button()
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


func _check_terminal_audit() -> void:
	var terminal_script := load("res://scripts/ui/communication_terminal.gd")
	var terminal: CanvasLayer = terminal_script.new()
	root.add_child(terminal)
	await process_frame
	terminal.start_flow([], 3, 1, {})
	var fail_report: Dictionary = terminal._evidence_audit_report()
	_expect(not bool(fail_report.get("passed", true)), "terminal audit should fail without truth encounters")

	var journal_entries: Array = [
		{"encounter_id": "furnace_truth", "title": "弹药库 · 熔炉", "body": ""},
		{"encounter_id": "chronicler_repair", "title": "社区档案室 · 编史者 04", "body": ""},
		{"encounter_id": "staff_officer_07_calibrate", "title": "废弃指挥部 · 战术室", "body": ""},
		{"encounter_id": "marian_obey", "title": "玛丽安公寓 · K-142", "body": ""},
	]
	terminal.start_flow(journal_entries, 3, 1, {})
	var pass_report: Dictionary = terminal._evidence_audit_report()
	_expect(bool(pass_report.get("passed", false)), "terminal audit should pass with all required truth encounters in current run")

	var meta := root.get_node_or_null("MetaManager")
	var saved_unlocked: Array = []
	if meta != null:
		saved_unlocked = (meta.encounters_unlocked as Array).duplicate()
		meta.encounters_unlocked.clear()
		for encounter_id in [
			"furnace_truth",
			"chronicler_repair",
			"staff_officer_07_calibrate",
			"marian_obey",
		]:
			meta.unlock_encounter(encounter_id)
	terminal.start_flow([], 3, 1, {})
	var archive_report: Dictionary = terminal._evidence_audit_report()
	_expect(
		bool(archive_report.get("passed", false)),
		"terminal audit should pass when required truth encounters are archived in meta",
	)

	terminal.start_flow(journal_entries, 3, 1, {})
	terminal._enter_phase(terminal.Phase.CAPTCHA)
	terminal._puzzle_solved = true
	terminal._on_primary_pressed()
	await process_frame
	_expect(terminal._phase == terminal.Phase.RESULT_FAIL, "captcha submit should always fail even with truth complete")

	terminal.start_flow(journal_entries, 3, 1, {})
	terminal._enter_phase(terminal.Phase.CAPTCHA)
	terminal._on_captcha_close_pressed()
	await process_frame
	terminal._on_primary_pressed()
	await process_frame
	_expect(terminal._phase == terminal.Phase.RESULT_PASS, "captcha close should pass when truth audit passes")
	_expect(terminal._audit_passed, "evidence audit should mark audit passed when truth complete")

	terminal.start_flow(journal_entries, 3, 1, {})
	terminal._on_report_chosen("habitable")
	await process_frame
	_expect(
		terminal._phase == terminal.Phase.CAPTCHA,
		"report step should always continue to captcha",
	)

	if meta != null:
		meta.encounters_unlocked.clear()
		for encounter_id in saved_unlocked:
			meta.unlock_encounter(str(encounter_id))

	terminal.queue_free()
	await process_frame


func _check_tutorial_craft_button() -> void:
	var root_control := Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.size = Vector2(1280, 720)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(root_control)

	var backpack := BackpackUI.new()
	root_control.add_child(backpack)
	await process_frame

	var director := TutorialDirector.new()
	root_control.add_child(director)
	await process_frame
	director.set_phase("day", "craft")

	var craft_signal_count := [0]
	var inv := InventoryData.new()
	inv.add("scrap", ItemDefs.CRAFT_PARTS_SCRAP_COST)
	inv.add("fuel", ItemDefs.CRAFT_PARTS_FUEL_COST)
	backpack.craft_parts_requested.connect(func(): craft_signal_count[0] += 1)
	backpack.show_backpack(inv)
	backpack.set_craft_highlight(true)
	for _i in range(5):
		backpack.set_craft_highlight(true)
		await process_frame

	var craft_btn := _find_button_by_text(backpack, "合成零件")
	_expect(craft_btn != null, "tutorial craft button should exist")
	if craft_btn != null:
		_expect(not craft_btn.disabled, "tutorial craft button should be enabled with recipe resources")
		_expect(craft_btn.mouse_filter != Control.MOUSE_FILTER_IGNORE, "tutorial craft button should accept mouse input")
		var objective_panel := director.get("_dialog_panel") as Control
		_expect(objective_panel != null, "tutorial objective panel should exist")
		if objective_panel != null:
			_expect(objective_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "tutorial objective panel should not intercept backpack clicks")

		backpack.craft_parts_requested.emit()
		_expect(int(craft_signal_count[0]) == 1, "tutorial craft button signal should be wired")

	root_control.queue_free()
	await process_frame


func _find_button_by_text(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found := _find_button_by_text(child, text)
		if found != null:
			return found
	return null


func _check_td_mechanics() -> void:
	var scene := load("res://scenes/night_td/night_td.tscn") as PackedScene
	_expect(scene != null, "night TD scene should load")
	if scene == null:
		return
	_expect(float(NightTdDefs.get_tower_def("splash").get("range", 0.0)) >= 160.0, "splash tower should have wider range")
	var hacker_def := NightTdDefs.get_tower_def("hacker")
	_expect(int(NightTdDefs.get_tower_def("trap").get("cost", 0)) == 2, "trap deploy cost should stay unchanged")
	_expect(int(hacker_def.get("cost", 0)) == 13, "hacker deploy cost should match 10 parts plus 3 wood")
	_expect(int(hacker_def.get("build_cost", {}).get("parts", 0)) == 10, "hacker tower should cost 10 parts")
	_expect(int(hacker_def.get("build_cost", {}).get("wood", 0)) == 3, "hacker tower should cost a few wood")
	_expect(int(hacker_def.get("salvage", {}).get("scrap", 0)) == 1, "destroyed hacker tower should return scrap")
	_expect(absf(float(NightTdDefs.get_enemy_def("drone").get("hack_resist", 0.0)) - 2.0) < 0.01, "basic enemies should resist hacking twice as long")
	var repair_inv := InventoryData.new()
	repair_inv.add("parts", ItemDefs.VEHICLE_REPAIR_PARTS_EACH)
	repair_inv.add("wood", ItemDefs.VEHICLE_REPAIR_WOOD_EACH)
	_expect(ItemDefs.can_repair_vehicle_with_inventory(repair_inv), "vehicle repair should require parts and wood")
	var empty_energy := NightTdEnergy.new()
	empty_energy.production_rate = 4.0
	empty_energy.capacity = 60.0
	empty_energy.current = 0.0
	empty_energy.register_tower(9001, 2.0)
	empty_energy.tick(1.0, {9001: 4.0})
	_expect(empty_energy.last_actual_draw <= empty_energy.last_production_rate + 0.001, "empty energy storage should cap actual draw to generation rate")
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

	var hud := td.get_node_or_null("Hud")
	_expect(hud != null, "night TD HUD should exist")
	if hud != null:
		hud.set_seen_enemy_types(["drone"])
		hud.show_enemy_gallery()
		var gallery := hud.get("_gallery_list") as ItemList
		_expect(gallery != null, "enemy gallery list should exist")
		if gallery != null:
			_expect(gallery.get_item_count() == 1, "enemy gallery should hide unseen enemy types")
			_expect(str(gallery.get_item_metadata(0)) == "drone", "enemy gallery should keep seen enemy metadata")
		var gallery_panel := hud.get_node_or_null("Shell/EnemyGalleryOverlay/EnemyGalleryPanel") as PanelContainer
		_expect(gallery_panel != null, "enemy gallery panel should exist")
		if gallery_panel != null:
			_expect(gallery_panel.custom_minimum_size.x <= 540.0 and gallery_panel.custom_minimum_size.y <= 340.0, "enemy gallery should be smaller than the old centered popup")
		if hud.has_method("_on_gallery_auto_hide_timeout"):
			hud.call("_on_gallery_auto_hide_timeout")
			await create_timer(0.5).timeout
			_expect(not bool(hud.get_node_or_null("Shell/EnemyGalleryOverlay").visible), "enemy gallery should auto-hide after timeout")
		hud.hide_enemy_gallery()
		hud.show_enemy_first_seen("thunder_leiting")
		var thunder_portrait := hud.get("_gallery_portrait") as TextureRect
		var thunder_detail := hud.get("_gallery_detail") as Label
		_expect(thunder_portrait != null and thunder_portrait.texture != null, "thunder first-seen popup should show an image")
		_expect(thunder_detail != null and thunder_detail.text.find("突破特性") >= 0, "thunder first-seen popup should show description text")
		hud.hide_enemy_gallery()
		var power_scroll := hud.get("_power_scroll") as ScrollContainer
		_expect(power_scroll != null, "power panel should use a scroll window")
		if power_scroll != null:
			_expect(power_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "power panel scroll should be vertical auto")

	var core := td.get_node_or_null("Field/DefenceCoreVisual")
	_expect(core != null, "night TD defence core visual should exist")
	if core != null:
		var core_tex := core.get("_core_tex") as Texture2D
		_expect(core_tex != null, "night TD base should show a vehicle marker texture")
		if core_tex != null:
			_expect(core_tex.get_width() > 0 and core_tex.get_height() > 0, "night TD base marker texture should be drawable")

	_expect(td.get_node_or_null("Hud/Shell/DurabilityBar/Title") == null, "bottom durability bar should not show isolated vehicle endurance text")

	td._on_fuel_boost_pressed()
	td._update_fuel_boost(1.0)
	_expect(absf(float(td._fuel_boost_spent) - 1.2) < 0.02, "fuel boost should burn fuel gradually")
	_expect(absf(float(td._vehicle_fuel) - 18.8) < 0.02, "fuel boost should reduce vehicle fuel")
	var result: Dictionary = td._build_result()
	_expect(absf(float(result.get("fuel_boost_loss", 0.0)) - 1.2) < 0.02, "result should record boost fuel loss")
	_expect(float(result.get("fuel_loss", 0.0)) >= 1.2, "result fuel_loss should include boost fuel spent")

	td._session_kind = "normal"
	td._session_options = {
		"previous_night_result": {
			"outcome": "success",
			"base_hp": 100.0,
			"base_hp_max": 100.0,
			"enemies_killed": 12,
			"threat_power": 10,
			"enemies_reached": 0,
		},
		"resource_counts": {"parts": 30, "scrap": 40, "wood": 8, "fuel": 8, "supplies": 5},
	}
	var high_pressure: float = td._compute_adaptive_enemy_pressure()
	td._session_options = {
		"previous_night_result": {
			"outcome": "partial",
			"base_hp": 40.0,
			"base_hp_max": 100.0,
			"enemies_killed": 2,
			"threat_power": 10,
			"enemies_reached": 4,
		},
		"resource_counts": {"parts": 1, "scrap": 2, "wood": 0, "fuel": 1, "supplies": 0},
	}
	var low_pressure: float = td._compute_adaptive_enemy_pressure()
	_expect(high_pressure > low_pressure, "adaptive enemy pressure should rise after strong defense and rich resources")

	td._session_kind = "tutorial"
	td.phase = td.Phase.COMBAT
	td._tutorial_combat_lesson_done = false
	td._tutorial_combat_step = "click_select"
	td._towers.clear()
	td._towers.append({
		"id": 909,
		"type": "hacker",
		"cell": Vector2i(2, 2),
		"world_pos": Vector2.ZERO,
		"removed": false,
		"power_scale": 1.0,
	})
	if td._energy == null:
		td._energy = NightTdEnergy.load_config("res://data/night_td/energy.json")
	td._energy.register_tower(909, 1.0)
	td.hud.update_power_list(td._powered_tower_rows())
	td._select_power_tower(909)
	_expect(str(td._tutorial_combat_step) == "box_select", "clicking hacker tower should complete tutorial tower selection step")

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
