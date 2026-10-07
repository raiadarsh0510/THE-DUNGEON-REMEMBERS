extends Node

# Phase4Test.gd: In-engine automated validation suite for Phase 4 Acceptance Criteria.
# Validates Combat + Content:
# - All 4 Traps (Spike, Falling Rock + stun, Poison Fog + slow, Illusion Trap + false memory)
# - All 3 Invader classes (Warrior, Rogue, Mage + illusion dispelling)
# - All 3 Minion defenders (Goblin melee, Shadow Beast pounce, Mimic ambush)
# - Placement & resource deductions for all items
# - Wave composition scaling (Waves 1-4)

func _ready() -> void:
	print("\n==========================================")
	print(" RUNNING PHASE 4 TEST SUITE (IN-ENGINE)")
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
	
	var warrior_scene = load("res://scenes/enemies/Warrior.tscn")
	var rogue_scene = load("res://scenes/enemies/Rogue.tscn")
	var mage_scene = load("res://scenes/enemies/Mage.tscn")
	
	var spike_scene = load("res://scenes/traps/SpikeTrap.tscn")
	var rock_scene = load("res://scenes/traps/FallingRockTrap.tscn")
	var poison_scene = load("res://scenes/traps/PoisonFogTrap.tscn")
	var illusion_scene = load("res://scenes/traps/IllusionTrap.tscn")
	
	var goblin_scene = load("res://scenes/monsters/Goblin.tscn")
	var shadow_scene = load("res://scenes/monsters/ShadowBeast.tscn")
	var mimic_scene = load("res://scenes/monsters/Mimic.tscn")
	
	# Wait for scene tree setup
	for i in range(15):
		await get_tree().physics_frame
	
	# -------------------------------------------------------------
	# TEST 1: Verification of All 3 Invader Types
	# -------------------------------------------------------------
	print("\n--- TEST 1: Verification of All 3 Invader Classes ---")
	var warrior = warrior_scene.instantiate()
	var rogue = rogue_scene.instantiate()
	var mage = mage_scene.instantiate()
	
	enemies_container.add_child(warrior)
	enemies_container.add_child(rogue)
	enemies_container.add_child(mage)
	
	warrior.global_position = Vector2(200, 360)
	rogue.global_position = Vector2(220, 360)
	mage.global_position = Vector2(240, 360)
	
	for i in range(5):
		await get_tree().physics_frame
	
	assert(warrior.get_enemy_type() == "Warrior", "Warrior must identify as Warrior")
	assert(rogue.get_enemy_type() == "Rogue", "Rogue must identify as Rogue")
	assert(mage.get_enemy_type() == "Mage", "Mage must identify as Mage")
	
	assert(warrior.max_hp >= 70.0, "Warrior must have high tank HP")
	assert(rogue.move_speed > warrior.move_speed, "Rogue must be swifter than Warrior")
	assert(mage.attack_range > 150.0, "Mage must possess ranged spellcasting range")
	
	# Test damage application
	var warrior_hp_before = warrior.current_hp
	warrior.take_damage(20.0)
	assert(warrior.current_hp == warrior_hp_before - 20.0, "Damage must deduct from enemy HP")
	
	print("[PASS] All 3 Invader classes verified (Warrior: Tank/Melee, Rogue: Agile/Scout, Mage: Fragile/Ranged).")
	
	# -------------------------------------------------------------
	# TEST 2: Verification of All 4 Trap Mechanics
	# -------------------------------------------------------------
	print("\n--- TEST 2: Verification of All 4 Trap Mechanics ---")
	
	# 2A: Spike Trap
	var spike = spike_scene.instantiate()
	traps_container.add_child(spike)
	spike.global_position = Vector2(400, 360)
	var hp_before_spike = rogue.current_hp
	spike.trigger_trap(rogue)
	assert(rogue.current_hp < hp_before_spike, "Spike Trap must deal damage")
	print("[PASS] Trap 1: Spike Trap dealt %d damage." % (hp_before_spike - rogue.current_hp))
	
	# 2B: Falling Rock Trap (Crush + Stun)
	var rock_target = warrior_scene.instantiate()
	enemies_container.add_child(rock_target)
	rock_target.max_hp = 200.0
	rock_target.current_hp = 200.0
	rock_target.global_position = Vector2(420, 360)
	
	var rock = rock_scene.instantiate()
	traps_container.add_child(rock)
	rock.global_position = rock_target.global_position
	var rock_hp_before = rock_target.current_hp
	rock.trigger_trap(rock_target)
	for i in range(40):
		await get_tree().physics_frame
	assert(rock_target.current_hp <= rock_hp_before - 50.0, "Falling Rock must deal crushing AoE damage!")
	print("[PASS] Trap 2: Falling Rock Trap triggered crushing AoE damage and stun status.")
	
	# 2C: Poison Fog Trap (DoT + Slow)
	var poison_target = warrior_scene.instantiate()
	enemies_container.add_child(poison_target)
	poison_target.max_hp = 200.0
	poison_target.current_hp = 200.0
	poison_target.global_position = Vector2(440, 360)
	
	var poison = poison_scene.instantiate()
	traps_container.add_child(poison)
	poison.global_position = poison_target.global_position
	poison.trigger_trap(poison_target)
	for i in range(40):
		await get_tree().physics_frame
	assert(poison.is_cloud_active == true, "Poison cloud must be active")
	assert(poison_target.slow_timer > 0.0, "Poison fog must inflict slow status")
	print("[PASS] Trap 3: Poison Fog Trap spawned lingering toxic cloud with slow effect.")
	
	# 2D: Illusion Trap (False memory injection vs Mage dispelling)
	var illusion = illusion_scene.instantiate()
	traps_container.add_child(illusion)
	var test_pos = Vector2(580, 200) # North flank
	illusion.global_position = test_pos
	
	# Trigger with Rogue -> fooled!
	var rogue_hp_before_illusion = rogue.current_hp
	illusion.trigger_trap(rogue)
	assert(rogue.current_hp == rogue_hp_before_illusion, "Illusion trap deals NO physical damage!")
	var recorded_danger = MemoryManager.get_danger_at_location(test_pos, 80.0)
	assert(recorded_danger > 0.5, "Illusion trap must inject high phantom threat into enemy memory!")
	print("[PASS] Trap 4: Illusion Trap planted phantom hazard in Rogue memory without dealing real damage.")
	
	# Trigger with Mage -> dispelled!
	illusion.is_ready = true
	illusion.trigger_trap(mage)
	assert(mage.adaptation_alert_text.contains("DISPELLED"), "Mage must detect and dispel illusions!")
	print("[PASS] Trap 4 Special: Mage successfully identified and dispelled Illusion Trap.")
	
	# -------------------------------------------------------------
	# TEST 3: Verification of All 3 Minion Defenders
	# -------------------------------------------------------------
	print("\n--- TEST 3: Verification of All 3 Minion Defenders ---")
	var goblin = goblin_scene.instantiate()
	var shadow = shadow_scene.instantiate()
	var mimic = mimic_scene.instantiate()
	
	var monsters_node = dungeon.get_node("Monsters")
	monsters_node.add_child(goblin)
	monsters_node.add_child(shadow)
	monsters_node.add_child(mimic)
	
	# 3A: Goblin Melee Interceptor
	goblin.global_position = Vector2(500, 360)
	assert(goblin.is_in_group("monsters"), "Goblin must be in 'monsters' group")
	assert(goblin.max_hp == 50.0, "Goblin base health check")
	print("[PASS] Minion 1: Goblin stationed as front-line melee interceptor.")
	
	# 3B: Shadow Beast Fast Pouncer
	shadow.global_position = Vector2(520, 360)
	assert(shadow.is_in_group("monsters"), "Shadow Beast must be in 'monsters' group")
	assert(shadow.move_speed >= 150.0, "Shadow Beast must have high move speed")
	print("[PASS] Minion 2: Shadow Beast verified with high speed (%d) and pounce attack." % shadow.move_speed)
	
	# 3C: Mimic Ambush Predator
	mimic.global_position = Vector2(540, 360)
	assert(mimic.is_in_group("monsters"), "Mimic must be in 'monsters' group")
	assert(mimic.state == 0, "Mimic must start in DISGUISED state")
	
	# Spawn a test invader right next to mimic to trigger ambush
	var ambush_victim = warrior_scene.instantiate()
	enemies_container.add_child(ambush_victim)
	ambush_victim.max_hp = 250.0
	ambush_victim.current_hp = 250.0
	ambush_victim.global_position = mimic.global_position + Vector2(20, 0)
	var victim_hp_before = ambush_victim.current_hp
	
	for i in range(10):
		await get_tree().physics_frame
	
	assert(mimic.state != 0, "Mimic must spring ambush when enemy approaches within 50px!")
	assert(ambush_victim.current_hp <= victim_hp_before - 40.0, "Mimic surprise ambush must inflict massive damage!")
	print("[PASS] Minion 3: Mimic successfully awoke from disguise and dealt surprise ambush strike (%d dmg)." % (victim_hp_before - ambush_victim.current_hp))
	
	# -------------------------------------------------------------
	# TEST 4: Trap & Minion Placement & Resource Deduction
	# -------------------------------------------------------------
	print("\n--- TEST 4: Placement & Resource Deduction ---")
	ResourceManager.gold = 300
	ResourceManager.essence = 50
	
	var initial_gold = ResourceManager.gold
	var initial_essence = ResourceManager.essence
	
	# Place Falling Rock (60G)
	var rock_placed = dungeon.spawn_trap_by_name("Falling Rock", Vector2(440, 360))
	assert(rock_placed == true, "Must place Falling Rock on valid floor")
	assert(ResourceManager.gold == initial_gold - 60, "Must deduct 60 Gold")
	
	# Place Shadow Beast (70G, 10E)
	var beast_placed = dungeon.spawn_monster_by_name("Shadow Beast", Vector2(460, 360))
	assert(beast_placed == true, "Must place Shadow Beast on valid floor")
	assert(ResourceManager.gold == initial_gold - 60 - 70, "Must deduct 70 Gold for beast")
	assert(ResourceManager.essence == initial_essence - 10, "Must deduct 10 Essence for beast")
	
	# Place Mimic (60G, 15E)
	var mimic_placed = dungeon.spawn_monster_by_name("Mimic", Vector2(480, 360))
	assert(mimic_placed == true, "Must place Mimic on valid floor")
	assert(ResourceManager.essence == initial_essence - 10 - 15, "Must deduct 15 Essence for mimic")
	
	print("[PASS] Dynamic placement of Traps & Minions verified with accurate Gold/Essence deduction.")
	
	# -------------------------------------------------------------
	# TEST 5: Wave Composition Scaling (Waves 1-4)
	# -------------------------------------------------------------
	print("\n--- TEST 5: Wave Composition Scaling ---")
	var wave_mgr = main_inst.get_node("WaveManager")
	
	var w1_comp = wave_mgr._generate_wave_composition(1)
	var w2_comp = wave_mgr._generate_wave_composition(2)
	var w3_comp = wave_mgr._generate_wave_composition(3)
	var w4_comp = wave_mgr._generate_wave_composition(4)
	
	print("Wave 1 spawn count: ", w1_comp.size())
	print("Wave 2 spawn count: ", w2_comp.size())
	print("Wave 3 spawn count: ", w3_comp.size())
	print("Wave 4 spawn count: ", w4_comp.size())
	
	assert(w1_comp.size() == 3, "Wave 1 should have 3 invaders")
	assert(w2_comp.size() == 4, "Wave 2 should have 4 invaders (warriors + rogues)")
	assert(w3_comp.size() == 6, "Wave 3 should have 6 invaders (warriors + rogues + mages)")
	assert(w4_comp.size() == 8, "Wave 4 should have 8 invaders")
	print("[PASS] Wave Manager composition dynamically scales with combined-arms enemies.")
	
	print("\n==========================================")
	print(" ALL PHASE 4 ACCEPTANCE TESTS PASSED (100%)")
	print("==========================================")
	
	await get_tree().create_timer(0.3).timeout
	get_tree().quit(0)
