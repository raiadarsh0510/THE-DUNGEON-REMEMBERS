extends Node

# Phase2Test.gd: In-engine automated validation suite for Phase 2 Acceptance Criteria.
# Validates Enemy Memory, Confidence, Decay, Route Adaptation, and Memory Chamber UI.

func _ready() -> void:
	print("\n==========================================")
	print(" RUNNING PHASE 2 TEST SUITE (IN-ENGINE)")
	print("==========================================")
	
	_run_tests()

func _run_tests() -> void:
	var main_scene = load("res://scenes/main/Main.tscn")
	assert(main_scene != null, "FAIL: Main.tscn failed to load")
	
	var main_inst = main_scene.instantiate()
	add_child(main_inst)
	print("[PASS] Main scene instantiated with MemoryManager autoload.")
	
	var dungeon = main_inst.get_node("Dungeon")
	var traps = dungeon.get_node("Traps")
	var initial_trap = traps.get_node("InitialSpikeTrap")
	var warrior_scene = load("res://scenes/enemies/Warrior.tscn")
	
	# Wait for navigation mesh initialization
	for i in range(10):
		await get_tree().physics_frame
	
	# -------------------------------------------------------------
	# TEST 1: Baseline Behavior (Ignorant Enemy Chooses Central Route)
	# -------------------------------------------------------------
	print("\n--- TEST 1: Baseline Invader Behavior (No Memories) ---")
	MemoryManager.clear_all_memories()
	assert(MemoryManager.get_all_memories().is_empty(), "MemoryManager must start empty")
	
	var warrior_1 = warrior_scene.instantiate()
	warrior_1.position = Vector2(140, 360)
	dungeon.get_node("Enemies").add_child(warrior_1)
	
	# Run simulation until warrior reaches West Junction and evaluates
	for i in range(120):
		await get_tree().physics_frame
	
	print("Warrior 1 chosen route: ", warrior_1.chosen_route_name, " | Adapted: ", warrior_1.has_adapted)
	assert(not warrior_1.has_adapted, "Warrior 1 must not adapt when no memories exist")
	assert(warrior_1.chosen_route_name == "Central Direct", "Warrior 1 must pick fastest Central Direct route")
	print("[PASS] Ignorant invader picked direct Central Hall route.")
	
	# -------------------------------------------------------------
	# TEST 2: Trap Triggered & Memory Created
	# -------------------------------------------------------------
	print("\n--- TEST 2: Trap Trigger & Memory Creation ---")
	warrior_1.position = initial_trap.position
	for i in range(15):
		await get_tree().physics_frame
	
	var mems = MemoryManager.get_all_memories()
	assert(not mems.is_empty(), "MemoryManager must record a memory after trap trigger!")
	var recorded_mem = mems[0]
	print("Recorded Memory: ", recorded_mem["description"])
	print("Confidence: ", recorded_mem["confidence"] * 100, "% | Severity: ", recorded_mem["severity"])
	assert(recorded_mem["event_type"] == "TRAP_TRIGGERED", "Event type must be TRAP_TRIGGERED")
	assert(recorded_mem["confidence"] == 1.0, "Initial confidence must be 1.0 (100%)")
	print("[PASS] Memory correctly created with 100% confidence and high severity.")
	
	# Clean up warrior 1
	warrior_1.die()
	for i in range(5):
		await get_tree().physics_frame
	
	# -------------------------------------------------------------
	# TEST 3: Enemy Adaptation (Remembered Hazard Forces Route Change)
	# -------------------------------------------------------------
	print("\n--- TEST 3: Enemy Adaptation (Route Diversion) ---")
	var warrior_2 = warrior_scene.instantiate()
	warrior_2.position = Vector2(140, 360)
	dungeon.get_node("Enemies").add_child(warrior_2)
	
	# Wait for warrior 2 to reach junction and evaluate routes
	for i in range(130):
		await get_tree().physics_frame
	
	print("Warrior 2 route: ", warrior_2.chosen_route_name, " | Adapted: ", warrior_2.has_adapted)
	print("Alert Text: '", warrior_2.adaptation_alert_text, "'")
	assert(warrior_2.has_adapted == true, "Warrior 2 MUST adapt based on memory!")
	assert(warrior_2.chosen_route_name != "Central Direct", "Warrior 2 must avoid Central Direct route!")
	assert(warrior_2.adaptation_alert_text != "", "Warrior 2 must display alert explaining why behavior changed!")
	
	# Allow warrior 2 to navigate up into North Flank corridor
	for i in range(120):
		await get_tree().physics_frame
	
	print("Warrior 2 position during bypass: ", warrior_2.position)
	# Check that warrior is moving through North Flank (y <= 260) or clearly diverged northward away from 360
	var has_diverged_from_center = warrior_2.position.y <= 260.0
	assert(has_diverged_from_center, "Warrior 2 must navigate northwards away from central spikes corridor (y: %f <= 260)" % warrior_2.position.y)
	print("[PASS] Invader genuinely changed route and avoided the central trap corridor based on memory.")
	
	warrior_2.die()
	
	# -------------------------------------------------------------
	# TEST 4: Memory Confidence Decay & Reinforcement
	# -------------------------------------------------------------
	print("\n--- TEST 4: Memory Confidence Decay & Reinforcement ---")
	MemoryManager.current_wave = 2
	MemoryManager.decay_memories(0.20)
	var decayed_mem = MemoryManager.get_all_memories()[0]
	var decayed_confidence: float = decayed_mem["confidence"]
	print("Confidence after wave decay: ", decayed_confidence * 100.0, "%")
	assert(decayed_confidence < 1.0, "Memory confidence must decay when unreinforced")
	print("[PASS] Memory confidence successfully decayed.")
	
	# Re-trigger reinforcement
	MemoryManager.record_event("Warrior", "TRAP_TRIGGERED", initial_trap.position, 0.85, "Reinforced encounter")
	var reinforced_mem = MemoryManager.get_all_memories()[0]
	print("Confidence after reinforcement: ", reinforced_mem["confidence"] * 100.0, "% | Encounters: ", reinforced_mem["encounter_count"])
	assert(reinforced_mem["confidence"] > decayed_confidence, "Confidence must restore on reinforcement")
	assert(reinforced_mem["encounter_count"] == 2, "Encounter count must increment to 2")
	print("[PASS] Memory reinforced upon subsequent encounter.")
	
	# -------------------------------------------------------------
	# TEST 5: Memory Chamber UI Inspection
	# -------------------------------------------------------------
	print("\n--- TEST 5: Memory Chamber UI Inspection ---")
	var hud = main_inst.get_node("HUD")
	var mem_chamber = hud.get_node("%MemoryChamber")
	assert(mem_chamber != null, "MemoryChamber UI node must exist in HUD")
	
	# Toggle open
	mem_chamber.open()
	assert(mem_chamber.visible == true, "MemoryChamber must become visible")
	
	# Verify memory cards populated
	var card_container = mem_chamber.get_node("%MemoryListContainer")
	var card_count = card_container.get_child_count()
	print("Memory cards visible in Chamber: ", card_count)
	assert(card_count > 0, "Memory cards must be displayed in Memory Chamber UI")
	print("[PASS] Memory Chamber UI displays remembered hazards and confidence levels.")
	
	mem_chamber.close()
	assert(mem_chamber.visible == false, "MemoryChamber must close cleanly")
	
	print("\n==========================================")
	print(" ALL PHASE 2 ACCEPTANCE CRITERIA PASSED!")
	print("==========================================\n")
	
	get_tree().quit(0)
