extends Node3D

# Phase 5 Acceptance Test Suite for "The Dungeon Remembers" (3D Engine Verification)
# Validates the complete Phase 5 criteria:
# 1. Player tendency synthesis from past encounters
# 2. Grand Inquisitor / Dungeon Breaker boss spawning & stats
# 3. Dynamic counter-adaptation: specific immunity to player's primary trap
# 4. Player counterplay: unadapted attacks deal normal damage
# 5. Siege Breaker: Boss shatters raised living shift barriers
# 6. Phase 2 Zealot Wrath transition at <= 50% HP (stat boosts, flame aura)
# 7. Boss defeat and victory resolution

var pass_count: int = 0
var total_count: int = 11

var boss_spawned_fired: bool = false
var boss_defeated_fired: bool = false

func _ready() -> void:
	print("\n========================================================")
	print(" RUNNING PHASE 5 ACCEPTANCE TEST SUITE (ADAPTIVE BOSS)")
	print("========================================================")
	
	EventBus.boss_spawned.connect(func(_b): boss_spawned_fired = true)
	EventBus.boss_defeated.connect(func(): boss_defeated_fired = true)
	
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

	# --- 1. Simulate Player Tendency (Spike Trap Reliance across waves 1-4) ---
	for i in range(5):
		MemoryManager.record_event(
			"Warrior",
			"TRAP_TRIGGERED",
			Vector3(0, 0, 3.0),
			0.85,
			"Spike Trap impalement hazard"
		)
	var profile = MemoryManager.get_player_tendency_profile()
	assert_test(1, "Player tendency synthesized: Primary habit identified as [%s]" % profile.primary_trap, profile.primary_trap == "SPIKE" and profile.total_memories >= 1)

	var main_scene = load("res://scenes/main/Main3D.tscn")
	var main = main_scene.instantiate()
	main.auto_start_wave = false
	add_child(main)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var dungeon = main.get_node("Dungeon3D")

	# --- 2. Spawn Grand Inquisitor / Dungeon Breaker ---
	var boss = dungeon.spawn_boss()
	assert_test(2, "The Grand Inquisitor spawns as 3D boss with full health (300 HP)", boss != null and boss.current_hp == 300.0 and boss_spawned_fired)

	# --- 3. Boss analyzes profile and activates counter-adaptation ---
	var adapted_spike = boss.adaptive_immunity == "SPIKE"
	assert_test(3, "Boss analyzes player profile and gains Impalement Plating (-75% Spike damage)", adapted_spike)

	# --- 4. Verify 75% Damage Resistance to Primary Trap ---
	var hp_before = boss.current_hp
	boss.take_damage(40.0, "SPIKE")
	var hp_loss = hp_before - boss.current_hp
	# With 75% resistance, 40 damage becomes 10 damage
	assert_test(4, "Impalement Plating resists spike damage (Dealt 40 dmg -> Incurred %.1f HP loss [75%% resisted])" % hp_loss, hp_loss <= 11.0)

	# --- 5. Player Counterplay: Unadapted Tactics deal full damage ---
	var hp_before_counter = boss.current_hp
	boss.take_damage(40.0, "UNADAPTED")
	var hp_loss_counter = hp_before_counter - boss.current_hp
	assert_test(5, "Player counterplay effective: Unadapted attacks bypass immunity (Dealt 40 -> Incurred %.1f HP loss)" % hp_loss_counter, hp_loss_counter >= 39.0)

	# --- 6. Living Shift Barrier raised ---
	dungeon.execute_dungeon_shift()
	var barrier = dungeon.shift_barrier
	assert_test(6, "Living Dungeon Shift barrier raised across West Flank", barrier != null and barrier.is_active and dungeon.is_dungeon_shifted)

	# --- 7. Siege Breaker: Boss shatters Living Barrier ---
	boss.global_position = barrier.global_position + Vector3(0, 0, 1.5)
	boss.shatter_barrier(barrier)
	await get_tree().physics_frame
	assert_test(7, "Siege Breaker: Grand Inquisitor hammer slam shatters and demolishes barrier", not barrier.is_active and not dungeon.is_dungeon_shifted and boss.has_shattered_barrier)

	# --- 8. Phase 1 stats verified ---
	var p1_stats = boss.current_phase == 0 and boss.move_speed == boss.move_speed_p1 and boss.attack_damage == boss.attack_damage_p1
	assert_test(8, "Phase 1 Commander stance verified (Speed: %.1f, Attack: %.1f)" % [boss.move_speed, boss.attack_damage], p1_stats)

	# --- 9. Phase 2 Zealot Wrath transition at <= 50% HP ---
	boss.take_damage(100.0)
	boss.take_damage(100.0)
	boss.take_damage(200.0)
	# Force HP down to 140 (<= 150)
	boss.current_hp = 140.0
	boss.take_damage(0.0) # Triggers check
	await get_tree().physics_frame
	var p2_active = boss.current_phase == 1 and boss.move_speed == boss.move_speed_p2 and boss.attack_damage == boss.attack_damage_p2
	assert_test(9, "Phase 2 Zealot Wrath triggers at <= 50%% HP (Speed: %.1f -> %.1f, Attack: %.1f -> %.1f)" % [boss.move_speed_p1, boss.move_speed, boss.attack_damage_p1, boss.attack_damage], p2_active)

	# --- 10. Flame Aura & Holy Fire Visuals active ---
	var aura_active = boss.aura_light != null and boss.aura_light.light_energy >= 3.0
	assert_test(10, "Fanatic flame aura and hammer light intensify in Phase 2", aura_active)

	# --- 11. Boss Defeat & Victory Resolution ---
	boss.take_damage(1000.0) # Lethal blow
	await get_tree().physics_frame
	assert_test(11, "The Grand Inquisitor is defeated, firing victory event (EventBus.boss_defeated)", boss_defeated_fired)

	print("\n========================================================")
	print(" PHASE 5 TEST SUMMARY: %d / %d TESTS PASSED" % [pass_count, total_count])
	print("========================================================\n")

	if pass_count == total_count:
		print(">>> PHASE 5 ACCEPTANCE CRITERIA MET (100% PASS RATE) <<<")
		get_tree().quit(0)
	else:
		printerr(">>> PHASE 5 HAS FAILING ACCEPTANCE TESTS <<<")
		get_tree().quit(1)
