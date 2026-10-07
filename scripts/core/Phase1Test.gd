extends Node

# Phase1Test.gd: Node-based automated test runner ensuring full engine lifecycle and autoloads.

func _ready() -> void:
	print("\n==========================================")
	print(" RUNNING PHASE 1 TEST SUITE (IN-ENGINE)")
	print("==========================================")
	
	_run_tests()

func _run_tests() -> void:
	var main_scene = load("res://scenes/main/Main.tscn")
	assert(main_scene != null, "FAIL: Failed to load Main.tscn")
	
	var main_instance = main_scene.instantiate()
	add_child(main_instance)
	print("[PASS] Main scene loaded and instantiated.")
	
	var dungeon = main_instance.get_node("Dungeon")
	var heart = dungeon.get_node("Heart")
	var wave_manager = main_instance.get_node("WaveManager")
	var traps = dungeon.get_node("Traps")
	
	assert(dungeon != null, "Dungeon must exist")
	assert(heart != null, "Heart must exist")
	assert(wave_manager != null, "WaveManager must exist")
	print("[PASS] Dungeon, Heart, and WaveManager verified.")
	
	# Wait for physics & navigation
	for i in range(10):
		await get_tree().physics_frame
	
	# Test 1: Spike Trap detection and damage
	var initial_trap = traps.get_node_or_null("InitialSpikeTrap")
	assert(initial_trap != null, "InitialSpikeTrap must exist")
	print("[PASS] Initial Spike Trap exists at position: ", initial_trap.position)
	
	# Test 2: Spawning an enemy
	var warrior_scene = load("res://scenes/enemies/Warrior.tscn")
	var test_warrior = warrior_scene.instantiate()
	test_warrior.position = initial_trap.position
	dungeon.get_node("Enemies").add_child(test_warrior)
	print("[PASS] Spawned Warrior enemy directly on trap.")
	
	# Wait for trap trigger
	for i in range(15):
		await get_tree().physics_frame
	
	var hp_after_trap = test_warrior.current_hp
	print("Warrior HP after stepping on trap: ", hp_after_trap, " / ", test_warrior.max_hp)
	assert(hp_after_trap < test_warrior.max_hp, "Trap must damage Warrior!")
	print("[PASS] Trap detected and damaged Warrior (Damage dealt: %f)" % (test_warrior.max_hp - hp_after_trap))
	
	# Test 3: Enemy death and bounty
	var gold_before_death = ResourceManager.gold
	test_warrior.take_damage(100.0) # Lethal
	for i in range(5):
		await get_tree().physics_frame
	
	print("Gold before death: ", gold_before_death, " | Gold after death: ", ResourceManager.gold)
	assert(ResourceManager.gold > gold_before_death, "Gold bounty must be awarded on death!")
	print("[PASS] Enemy died and awarded Gold bounty.")
	
	# Test 4: Heart damage
	var initial_heart_hp = heart.current_hp
	heart.take_damage(20.0)
	print("Heart HP after taking 20 damage: ", heart.current_hp, " / ", heart.max_hp)
	assert(heart.current_hp == initial_heart_hp - 20.0, "Heart HP must decrease!")
	print("[PASS] Heart takes damage correctly.")
	
	# Test 5: Wave start and completion
	print("Testing Wave lifecycle...")
	wave_manager.start_next_wave()
	assert(wave_manager.is_wave_active == true, "Wave must be active")
	print("[PASS] Wave 1 started. Enemies to spawn: ", wave_manager.enemies_to_spawn)
	
	# Wait for first wave enemy to spawn (spawn_timer was 0.5s)
	for i in range(50):
		await get_tree().process_frame
		await get_tree().physics_frame
	
	var active_spawned = wave_manager.active_enemies.duplicate()
	print("Spawned in wave: ", active_spawned.size(), " active enemies.")
	assert(active_spawned.size() > 0, "At least 1 enemy should have spawned in wave!")
	print("[PASS] Enemies actively spawning during wave.")
	
	# Eliminate enemies to complete wave
	wave_manager.enemies_to_spawn = 0
	for enemy in active_spawned:
		if is_instance_valid(enemy):
			enemy.die()
	
	for i in range(10):
		await get_tree().process_frame
		await get_tree().physics_frame
		
	assert(not wave_manager.is_wave_active and wave_manager.current_wave >= 2, "Wave must complete")
	print("[PASS] Wave 1 completed. Current wave advanced to: ", wave_manager.current_wave)
	
	# Test 6: Next wave start
	wave_manager.start_next_wave()
	assert(wave_manager.is_wave_active, "Next wave must be active")
	print("[PASS] Next wave (Wave 2) started successfully.")
	
	# Test 7: Navigation agent movement
	var nav_warrior = warrior_scene.instantiate()
	nav_warrior.position = Vector2(150, 360)
	dungeon.get_node("Enemies").add_child(nav_warrior)
	
	# Wait for navigation setup and movement
	for i in range(60):
		await get_tree().physics_frame
	
	print("Warrior position after navigation: ", nav_warrior.position)
	assert(nav_warrior.position.x > 150, "Warrior must move towards Heart!")
	print("[PASS] Warrior navigated toward the Dungeon Heart (moved from 150 to %f)" % nav_warrior.position.x)
	
	print("\n==========================================")
	print(" ALL PHASE 1 ACCEPTANCE CRITERIA PASSED!")
	print("==========================================\n")
	
	get_tree().quit(0)
