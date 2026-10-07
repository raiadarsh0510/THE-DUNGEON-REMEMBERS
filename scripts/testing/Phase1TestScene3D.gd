extends Node3D

# Phase 1 Acceptance Test Suite for "The Dungeon Remembers" (3D Engine Verification)
# Validates the complete 12-step Phase 1 criteria specified in the design contract.

var pass_count: int = 0
var total_count: int = 12

var trap_event_received: bool = false
var defeat_event_received: bool = false

func _ready() -> void:
	print("\n========================================================")
	print(" RUNNING PHASE 1 ACCEPTANCE TEST SUITE (3D PROTOTYPE)")
	print("========================================================")
	
	EventBus.trap_triggered.connect(func(_type, _pos, _tgt):
		trap_event_received = true
	)
	EventBus.heart_destroyed.connect(func():
		defeat_event_received = true
	)
	
	call_deferred("run_all_tests")

func assert_test(step_num: int, description: String, condition: bool) -> void:
	if condition:
		print("[PASS] Step %d: %s" % [step_num, description])
		pass_count += 1
	else:
		printerr("[FAIL] Step %d: %s" % [step_num, description])

func run_all_tests() -> void:
	# 1. Start game
	var main_scene = load("res://scenes/main/Main3D.tscn")
	assert_test(1, "Game scene loads successfully", main_scene != null)
	var main = main_scene.instantiate()
	main.auto_start_wave = false
	add_child(main)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# 2. Heart exists
	var heart = get_tree().get_first_node_in_group("dungeon_heart")
	assert_test(2, "Dungeon Heart exists with valid HP", heart != null and heart.current_hp == 100.0)

	# 3. Warrior spawns
	var dungeon = main.get_node("Dungeon3D")
	var warrior = dungeon.spawn_warrior()
	assert_test(3, "Warrior spawns with full health (70 HP)", warrior != null and warrior.current_hp == 70.0)

	# 4. Warrior navigates
	var initial_z = warrior.global_position.z
	for i in range(25):
		await get_tree().physics_frame
	var moved_z = warrior.global_position.z
	assert_test(4, "Warrior navigates toward the Heart along the corridor", moved_z < initial_z)

	# 5. Warrior reaches Spike Trap
	var trap = get_tree().get_first_node_in_group("traps")
	assert_test(5, "Spike Trap is placed along corridor", trap != null)
	
	# Move warrior directly onto the trap area
	warrior.global_position = trap.global_position
	# Allow physics server to process collision
	for i in range(5):
		await get_tree().physics_frame

	# 6. Spike Trap activates
	assert_test(6, "Spike Trap activates and fires EventBus signal", trap_event_received)

	# 7. Warrior takes damage
	assert_test(7, "Warrior takes damage from Spike Trap", warrior.current_hp < 70.0)

	# 8. Warrior survives if HP allows
	assert_test(8, "Warrior survives with remaining HP (HP > 0)", warrior.current_hp > 0.0 and not warrior.is_dead)

	# 9. Warrior reaches Heart
	warrior.global_position = heart.global_position + Vector3(0, 0, 2.0)
	for i in range(3):
		await get_tree().physics_frame
	var dist_to_heart = warrior.global_position.distance_to(heart.global_position)
	assert_test(9, "Warrior reaches attack range of Dungeon Heart", dist_to_heart <= warrior.attack_range)

	# 10. Heart takes damage
	var heart_hp_before_attack = heart.current_hp
	warrior.perform_attack()
	await get_tree().physics_frame
	assert_test(10, "Heart takes damage from Warrior attack", heart.current_hp < heart_hp_before_attack)

	# 11. Player can lose
	# Pause warrior to prevent rogue attacks during defeat check
	warrior.set_physics_process(false)
	heart.take_damage(heart.current_hp)
	await get_tree().physics_frame
	assert_test(11, "Player can lose when Heart HP reaches zero", defeat_event_received and heart.is_destroyed)

	# 12. Player can restart
	heart.reset_heart()
	GameManager.reset_stats()
	assert_test(12, "Player can restart and restore game state cleanly", heart.current_hp == 100.0 and not heart.is_destroyed)

	print("\n========================================================")
	print(" PHASE 1 TEST SUMMARY: %d / %d TESTS PASSED" % [pass_count, total_count])
	print("========================================================\n")

	if pass_count == total_count:
		print(">>> PHASE 1 ACCEPTANCE CRITERIA MET (100% PASS RATE) <<<")
		get_tree().quit(0)
	else:
		printerr(">>> PHASE 1 HAS FAILING ACCEPTANCE TESTS <<<")
		get_tree().quit(1)
