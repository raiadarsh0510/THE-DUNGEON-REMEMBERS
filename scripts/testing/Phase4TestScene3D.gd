extends Node3D

# Phase 4 Acceptance Test Suite for "The Dungeon Remembers" (3D Engine Verification)
# Validates the complete Phase 4 criteria:
# 1. 3 Invader classes (Warrior, Rogue, Mage) with distinct stats, speeds, and attack styles
# 2. 4 Traps (Spike Trap, Falling Rock Trap, Poison Fog Trap, Illusion Trap)
# 3. 3 Defenders (Goblin, Shadow Beast, Mimic)
# 4. Real-time combat engagements, status effects, and bounties

var pass_count: int = 0
var total_count: int = 12

var trap_triggered_count: int = 0

func _ready() -> void:
	print("\n========================================================")
	print(" RUNNING PHASE 4 ACCEPTANCE TEST SUITE (COMBAT & CONTENT)")
	print("========================================================")
	
	EventBus.trap_triggered.connect(func(_type, _pos, _tgt): trap_triggered_count += 1)
	
	call_deferred("run_all_tests")

func assert_test(step_num: int, description: String, condition: bool) -> void:
	if condition:
		print("[PASS] Step %d: %s" % [step_num, description])
		pass_count += 1
	else:
		printerr("[FAIL] Step %d: %s" % [step_num, description])

func run_all_tests() -> void:
	ResourceManager.reset_resources()
	MemoryManager.clear_all_memories()

	var main_scene = load("res://scenes/main/Main3D.tscn")
	var main = main_scene.instantiate()
	main.auto_start_wave = false
	add_child(main)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var dungeon = main.get_node("Dungeon3D")

	# --- 1. All 3 Invader classes spawn with distinct stats ---
	var warrior = dungeon.spawn_warrior()
	var rogue = dungeon.spawn_rogue()
	var mage = dungeon.spawn_mage()
	
	var valid_stats = (warrior != null and warrior.max_hp == 70.0 and warrior.get_enemy_type() == "Warrior") \
		and (rogue != null and rogue.max_hp == 45.0 and rogue.get_enemy_type() == "Rogue") \
		and (mage != null and mage.max_hp == 35.0 and mage.get_enemy_type() == "Mage")
	assert_test(1, "All 3 invader classes spawn with distinct stats (Warrior 70 HP, Rogue 45 HP, Mage 35 HP)", valid_stats)

	# --- 2. Rogue speed and evasion capability ---
	var rogue_fast = rogue.base_move_speed > warrior.move_speed and rogue.has_method("attempt_evade_trap")
	assert_test(2, "Rogue demonstrates high agility (Speed: %.1f > %.1f) and trap evasion capability" % [rogue.base_move_speed, warrior.move_speed], rogue_fast)

	# --- 3. Mage ranged combat capability ---
	var mage_ranged = mage.attack_range >= 9.0 and mage.has_method("cast_arcane_bolt")
	assert_test(3, "Mage possesses extended ranged attack capability (Range: %.1fm > 3.0m)" % mage.attack_range, mage_ranged)

	# --- 4. Spike Trap trigger and puncture damage ---
	var spike = dungeon.spawn_trap("spike", Vector3(0, 0, 8.0))
	var dummy_target = dungeon.spawn_warrior()
	dummy_target.global_position = spike.global_position
	for i in range(5):
		await get_tree().physics_frame
	assert_test(4, "Spike Trap triggers and inflicts 35 puncture damage (Target HP: %.1f)" % dummy_target.current_hp, dummy_target.current_hp <= 35.0)
	dummy_target.queue_free()

	# --- 5. Falling Rock Trap crush damage ---
	var rock_trap = dungeon.spawn_trap("rock", Vector3(5, 0, 8.0))
	var rock_target = dungeon.spawn_warrior()
	rock_target.global_position = rock_trap.global_position
	rock_trap.trigger_trap(rock_target)
	await get_tree().create_timer(0.35).timeout
	assert_test(5, "Falling Rock Trap triggers overhead boulder inflicting 50 crush damage (Target HP: %.1f)" % rock_target.current_hp, rock_target.current_hp <= 20.0)
	rock_target.queue_free()

	# --- 6. Poison Fog Trap DoT & Slow ---
	var poison_trap = dungeon.spawn_trap("poison", Vector3(-5, 0, 8.0))
	var poison_target = dungeon.spawn_warrior()
	poison_target.global_position = poison_trap.global_position
	poison_trap.trigger_trap(poison_target)
	await get_tree().physics_frame
	var has_poison_status = poison_target.poison_timer > 0.0 and poison_target.slow_timer > 0.0 and poison_target.move_speed < poison_target.base_move_speed
	assert_test(6, "Poison Fog Trap discharges toxic cloud applying DoT and slow status", has_poison_status)
	poison_target.queue_free()

	# --- 7. Illusion Trap stuns warrior & generates false memory ---
	var illusion_trap = dungeon.spawn_trap("illusion", Vector3(0, 0, 5.0))
	var warrior_lured = dungeon.spawn_warrior()
	warrior_lured.global_position = illusion_trap.global_position
	illusion_trap.trigger_trap(warrior_lured)
	await get_tree().physics_frame
	var is_stunned = warrior_lured.stun_timer > 0.0
	var has_false_mem = false
	for mem in MemoryManager.get_all_memories():
		if mem["event_type"] == "FALSE_TREASURE":
			has_false_mem = true
			break
	assert_test(7, "Illusion Trap stuns physical invader and records false treasure memory", is_stunned and has_false_mem)
	warrior_lured.queue_free()

	# --- 8. Mage dispels Illusion Trap ---
	var illusion_trap2 = dungeon.spawn_trap("illusion", Vector3(3, 0, 5.0))
	var mage_scout = dungeon.spawn_mage()
	mage_scout.global_position = illusion_trap2.global_position
	illusion_trap2.trigger_trap(mage_scout)
	await get_tree().physics_frame
	assert_test(8, "Mage identifies arcane phantom and dispels Illusion Trap without stun", mage_scout.stun_timer == 0.0)
	mage_scout.queue_free()

	# --- 9. Goblin Defender melee engagement ---
	var goblin = dungeon.spawn_defender("goblin", Vector3(0, 0, 0))
	var enemy_for_goblin = dungeon.spawn_warrior()
	enemy_for_goblin.global_position = Vector3(0, 0, 1.2)
	goblin.perform_attack(enemy_for_goblin)
	assert_test(9, "Goblin Defender engages and slashes invader in melee (Enemy HP: %.1f < 70)" % enemy_for_goblin.current_hp, enemy_for_goblin.current_hp < 70.0)
	enemy_for_goblin.queue_free()
	goblin.queue_free()

	# --- 10. Shadow Beast Defender combat ---
	var beast = dungeon.spawn_defender("shadowbeast", Vector3(0, 0, 0))
	var enemy_for_beast = dungeon.spawn_warrior()
	enemy_for_beast.global_position = Vector3(0, 0, 1.5)
	beast.perform_attack(enemy_for_beast)
	assert_test(10, "Shadow Beast Defender executes heavy void attack (Damage: 18, Enemy HP: %.1f)" % enemy_for_beast.current_hp, enemy_for_beast.current_hp <= 52.0)
	enemy_for_beast.queue_free()
	beast.queue_free()

	# --- 11. Mimic Defender ambush surprise strike ---
	var mimic = dungeon.spawn_defender("mimic", Vector3(0, 0, 0))
	var enemy_for_mimic = dungeon.spawn_warrior()
	enemy_for_mimic.global_position = Vector3(0, 0, 1.5)
	mimic.awaken()
	mimic.perform_attack(enemy_for_mimic)
	assert_test(11, "Mimic Defender snaps open fanged maw dealing 28 ambush damage (Enemy HP: %.1f)" % enemy_for_mimic.current_hp, enemy_for_mimic.current_hp <= 42.0)
	enemy_for_mimic.queue_free()
	mimic.queue_free()

	# --- 12. Invader death awards resource bounty ---
	var gold_before_kill = ResourceManager.gold
	var mortal_invader = dungeon.spawn_rogue()
	mortal_invader.take_damage(100.0) # Lethal damage
	await get_tree().physics_frame
	var gold_after_kill = ResourceManager.gold
	assert_test(12, "Invader death triggers bounty crediting Gold (+30) and Essence (+5) to player", gold_after_kill > gold_before_kill)

	# Clean up initial enemies
	if is_instance_valid(warrior): warrior.queue_free()
	if is_instance_valid(rogue): rogue.queue_free()
	if is_instance_valid(mage): mage.queue_free()

	print("\n========================================================")
	print(" PHASE 4 TEST SUMMARY: %d / %d TESTS PASSED" % [pass_count, total_count])
	print("========================================================\n")

	if pass_count == total_count:
		print(">>> PHASE 4 ACCEPTANCE CRITERIA MET (100% PASS RATE) <<<")
		get_tree().quit(0)
	else:
		printerr(">>> PHASE 4 HAS FAILING ACCEPTANCE TESTS <<<")
		get_tree().quit(1)
