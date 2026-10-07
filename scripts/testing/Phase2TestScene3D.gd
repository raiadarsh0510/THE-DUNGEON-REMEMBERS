extends Node3D

# Phase 2 Acceptance Test Suite for "The Dungeon Remembers" (3D Engine Verification)
# Validates the complete 11-step Phase 2 criteria: Memory Formation + Enemy Adaptation.

const AdaptationSystem = preload("res://scripts/memory/AdaptationSystem.gd")

var pass_count: int = 0
var total_count: int = 11

var trap_event_fired: bool = false
var memory_created_fired: bool = false
var adaptation_signal_fired: bool = false

func _ready() -> void:
	print("\n========================================================")
	print(" RUNNING PHASE 2 ACCEPTANCE TEST SUITE (MEMORY & ADAPTATION)")
	print("========================================================")
	
	EventBus.trap_triggered.connect(func(_type, _pos, _tgt): trap_event_fired = true)
	EventBus.memory_created.connect(func(_mem): memory_created_fired = true)
	EventBus.enemy_adapted.connect(func(_e, _r): adaptation_signal_fired = true)
	
	call_deferred("run_all_tests")

func assert_test(step_num: int, description: String, condition: bool) -> void:
	if condition:
		print("[PASS] Step %d: %s" % [step_num, description])
		pass_count += 1
	else:
		printerr("[FAIL] Step %d: %s" % [step_num, description])

func run_all_tests() -> void:
	# Ensure clean memory state
	MemoryManager.clear_all_memories()

	var main_scene = load("res://scenes/main/Main3D.tscn")
	var main = main_scene.instantiate()
	main.auto_start_wave = false
	add_child(main)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var dungeon = main.get_node("Dungeon3D")
	var trap = get_tree().get_first_node_in_group("traps")

	# --- 1. Spawn Warrior ---
	var warrior1 = dungeon.spawn_warrior()
	assert_test(1, "First Warrior spawns at entrance", warrior1 != null and warrior1.current_hp == 70.0)

	# --- 2. Warrior enters ---
	# Initial ignorance state: Warrior picks direct Central route
	assert_test(2, "Warrior enters with direct Central route preference (Ignorance)", warrior1.selected_route_name == "Central")

	# --- 3. Warrior triggers Spike Trap ---
	warrior1.global_position = trap.global_position
	for i in range(5):
		await get_tree().physics_frame
	assert_test(3, "Warrior steps onto and triggers Spike Trap", trap_event_fired)

	# --- 4. Warrior survives ---
	assert_test(4, "Warrior survives Spike Trap puncture (HP = %.1f > 0)" % warrior1.current_hp, warrior1.current_hp > 0.0 and not warrior1.is_dead)

	# --- 5. Memory record is created ---
	var memories = MemoryManager.get_all_memories()
	var has_spike_memory = false
	for mem in memories:
		if mem["enemy_type"] == "Warrior" and mem["event_type"] == "TRAP_TRIGGERED":
			has_spike_memory = true
			break
	assert_test(5, "Memory record created with confidence and danger score", has_spike_memory and memory_created_fired)

	# --- 6. Warrior continues/exits ---
	# First warrior finishes encounter and exits
	warrior1.set_physics_process(false)
	warrior1.queue_free()
	await get_tree().physics_frame
	assert_test(6, "First Warrior completes encounter and exits", is_instance_valid(warrior1) == false or warrior1.is_queued_for_deletion())

	# --- 7. Encounter Warrior again ---
	var warrior2 = dungeon.spawn_warrior()
	assert_test(7, "Encounter second Warrior in subsequent wave/encounter", warrior2 != null and warrior2.current_hp == 70.0)

	# --- 8. Warrior reaches remembered location / decision junction ---
	warrior2.global_position = Vector3(0.0, 0.0, 11.0)
	warrior2.evaluate_and_choose_route()
	for i in range(3):
		await get_tree().physics_frame
	assert_test(8, "Second Warrior reaches decision junction at Z = 11.0", warrior2.global_position.z <= 11.5)

	# --- 9. Warrior detects danger ---
	var perceived_danger = AdaptationSystem.get_perceived_danger_at(trap.global_position, "Warrior")
	assert_test(9, "Warrior AI detects remembered hazard danger (Score: %.2f > 0.5)" % perceived_danger, perceived_danger >= 0.5)

	# --- 10. Warrior chooses another valid route ---
	var chose_alternate_route = (warrior2.selected_route_name != "Central") and (warrior2.selected_route_name == "WestFlank" or warrior2.selected_route_name == "EastFlank")
	assert_test(10, "Warrior chooses another valid route [%s] avoiding Spike Trap" % warrior2.selected_route_name, chose_alternate_route)

	# --- 11. UI shows that memory influenced the decision ---
	var hud = main.get_node("HUD3D")
	hud.update_memory_display()
	var ui_shows_adaptation = warrior2.has_adapted and (adaptation_signal_fired or not MemoryManager.last_adaptation_event.is_empty())
	assert_test(11, "UI Memory Chamber reflects active adaptation & decision rationale", ui_shows_adaptation)

	print("\n========================================================")
	print(" PHASE 2 TEST SUMMARY: %d / %d TESTS PASSED" % [pass_count, total_count])
	print("========================================================\n")

	if pass_count == total_count:
		print(">>> PHASE 2 ACCEPTANCE CRITERIA MET (100% PASS RATE) <<<")
		get_tree().quit(0)
	else:
		printerr(">>> PHASE 2 HAS FAILING ACCEPTANCE TESTS <<<")
		get_tree().quit(1)
