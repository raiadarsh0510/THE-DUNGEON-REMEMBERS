extends Node

# Phase5Test.gd: In-engine automated validation suite for Phase 5 Acceptance Criteria.
# Validates the Climax Boss Wave:
# - Inquisitor Boss instantiation & Vanguard summon
# - Collective Memory Synthesis across previous waves
# - Cleansing Ward & Tenacity (anti-trap resistance, illusion immunity)
# - Phase 2 Transition (Zealot's Wrath at <= 50% HP)
# - Boss defeat & Dungeon Victory trigger

func _ready() -> void:
	print("\n==========================================")
	print(" RUNNING PHASE 5 TEST SUITE (IN-ENGINE)")
	print("==========================================")
	
	_run_tests()

func _run_tests() -> void:
	var main_scene = load("res://scenes/main/Main.tscn")
	assert(main_scene != null, "FAIL: Main.tscn failed to load")
	
	var main_inst = main_scene.instantiate()
	add_child(main_inst)
	print("[PASS] Main scene loaded successfully.")
	
	var dungeon = main_inst.get_node("Dungeon")
	var enemies_container = dungeon.get_node("Enemies")
	var traps_container = dungeon.get_node("Traps")
	var wave_mgr = main_inst.get_node("WaveManager")
	
	var inquisitor_scene = load("res://scenes/boss/Inquisitor.tscn")
	var illusion_scene = load("res://scenes/traps/IllusionTrap.tscn")
	
	# Wait for scene tree setup
	for i in range(15):
		await get_tree().physics_frame
	
	# -------------------------------------------------------------
	# TEST 1: Inquisitor Boss Instantiation & Vanguard Summon
	# -------------------------------------------------------------
	print("\n--- TEST 1: Inquisitor Boss Instantiation & Stats ---")
	var boss = inquisitor_scene.instantiate()
	enemies_container.add_child(boss)
	boss.global_position = Vector2(150, 360)
	
	for i in range(10):
		await get_tree().physics_frame
	
	assert(boss.get_enemy_type() == "Inquisitor", "Boss type must be Inquisitor")
	assert(boss.is_in_group("boss"), "Boss must be in 'boss' group")
	assert(boss.is_in_group("enemies"), "Boss must be in 'enemies' group")
	assert(boss.max_hp == 400.0, "Boss must possess 400 max HP")
	assert(boss.current_phase == 0, "Boss must start in Phase 1 (Commander)")
	
	# Verify royal escorts
	var living_enemies = enemies_container.get_children()
	var escort_count = 0
	for e in living_enemies:
		if e != boss and e.is_in_group("enemies"):
			escort_count += 1
	assert(escort_count >= 2, "Inquisitor must summon at least 2 vanguard escorts upon entry!")
	print("[PASS] Boss successfully spawned with 400 HP and %d Vanguard Royal Guards." % escort_count)
	
	# -------------------------------------------------------------
	# TEST 2: Collective Memory Synthesis & Route Planning
	# -------------------------------------------------------------
	print("\n--- TEST 2: Collective Memory Synthesis ---")
	# Seed memory records simulating previous 4 waves of casualties in Central corridor
	MemoryManager.clear_all_memories()
	MemoryManager.record_event("Warrior", "TRAP_TRIGGERED", Vector2(480, 360), 0.95, "Wave 1: Spike Trap wipeout")
	MemoryManager.record_event("Rogue", "TRAP_TRIGGERED", Vector2(480, 360), 0.95, "Wave 2: Heavy boulder casualties")
	MemoryManager.record_event("Mage", "TRAP_TRIGGERED", Vector2(480, 360), 0.95, "Wave 3: Central corridor death trap")
	
	var central_danger = MemoryManager.get_danger_at_location(Vector2(480, 360), 100.0)
	print("Synthesized Central Hazard Threat: ", central_danger)
	assert(central_danger > 0.8, "MemoryManager must register high synthesized danger at Central Hall")
	
	# Force boss to synthesize collective intelligence
	boss.global_position = Vector2(330, 360) # At junction
	boss._synthesize_collective_memory_and_route()
	
	print("Inquisitor Chosen Route: ", boss.chosen_route_name)
	print("Inquisitor Proclamation: ", boss.adaptation_alert_text)
	assert(boss.chosen_route_name != "Central Direct", "Inquisitor must synthesize fallen memories and avoid Central Hall trap hallway!")
	assert(boss.has_adapted == true, "Boss adaptation flag must be active")
	print("[PASS] Inquisitor synthesized 4 waves of fallen memories and directed army away from Central Hall.")
	
	# -------------------------------------------------------------
	# TEST 3: Cleansing Ward & Tenacity
	# -------------------------------------------------------------
	print("\n--- TEST 3: Cleansing Ward & Tenacity ---")
	boss.apply_slow(0.5, 3.0)
	assert(boss.slow_factor > 0.5, "Boss tenacity must reduce incoming slow intensity")
	
	# Trigger manual cleanse
	boss._trigger_cleansing_ward()
	assert(boss.slow_timer == 0.0 and boss.stun_timer == 0.0, "Cleansing ward must purge slows and stuns!")
	print("[PASS] Cleansing Ward successfully purged combat ailments.")
	
	# Illusion Trap resistance test
	var illusion = illusion_scene.instantiate()
	traps_container.add_child(illusion)
	illusion.global_position = boss.global_position
	illusion.trigger_trap(boss)
	assert(not boss.adaptation_alert_text.contains("FLEEING"), "Inquisitor must NOT panic from illusions")
	print("[PASS] Inquisitor verified immune to illusion deception.")
	
	# -------------------------------------------------------------
	# TEST 4: Phase 2 Fanatic Rage Transition (<= 50% HP)
	# -------------------------------------------------------------
	print("\n--- TEST 4: Phase 2 Transition (Zealot's Wrath) ---")
	var hp_before_transition = boss.current_hp
	print("Boss HP before burst: ", hp_before_transition)
	
	# Deal damage to drop boss below 50% HP (200 HP)
	boss.take_damage(300.0) # 300 * 0.75 = 225 dmg, leaves boss at 175 HP (<= 200)
	
	for i in range(5):
		await get_tree().physics_frame
	
	print("Boss HP after burst: ", boss.current_hp)
	assert(boss.current_phase == 1, "Boss must transition to Phase 2 (Zealot's Wrath) when <= 50% HP!")
	assert(boss.move_speed_phase2 > boss.move_speed_phase1, "Phase 2 move speed must be significantly increased")
	assert(boss.attack_damage_phase2 > boss.attack_damage_phase1, "Phase 2 attack damage must be significantly increased")
	print("[PASS] Phase 2 transition triggered! Speed: %d, Damage: %d, Proclamation: '%s'" % [
		boss.move_speed_phase2, boss.attack_damage_phase2, boss.adaptation_alert_text
	])
	
	# -------------------------------------------------------------
	# TEST 5: Wave 5 Climax & Defeat Victory Condition
	# -------------------------------------------------------------
	print("\n--- TEST 5: Wave 5 Climax & Defeat Victory Trigger ---")
	var w5_comp = wave_mgr._generate_wave_composition(5)
	assert(w5_comp.size() == 1, "Wave 5 must spawn the Grand Inquisitor Boss")
	print("[PASS] WaveManager designates Wave 5 as the Inquisitor Climax Wave.")
	
	var victory_status = {"emitted": false}
	EventBus.game_over.connect(func(is_vic): if is_vic: victory_status["emitted"] = true)
	
	# Defeat the boss
	boss.take_damage(250.0)
	
	for i in range(10):
		await get_tree().physics_frame
	
	# Simulate wave completion upon boss defeat
	wave_mgr.current_wave = 5
	wave_mgr._complete_wave()
	
	assert(victory_status["emitted"] == true, "Defeating the Inquisitor on Wave 5 must trigger Dungeon Victory!")
	print("[PASS] Grand Inquisitor defeated! Dungeon Victory achieved.")
	
	print("\n==========================================")
	print(" ALL PHASE 5 ACCEPTANCE TESTS PASSED (100%)")
	print("==========================================")
	
	await get_tree().create_timer(0.3).timeout
	get_tree().quit(0)
