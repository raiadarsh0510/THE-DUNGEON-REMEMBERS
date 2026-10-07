extends Node

# Phase3Test.gd: In-engine automated validation suite for Phase 3 Acceptance Criteria.
# Validates the 6 Dungeon Rooms, Economy bonuses, Construction, and Dungeon Shift mechanic.

func _ready() -> void:
	print("\n==========================================")
	print(" RUNNING PHASE 3 TEST SUITE (IN-ENGINE)")
	print("==========================================")
	
	_run_tests()

func _run_tests() -> void:
	var main_scene = load("res://scenes/main/Main.tscn")
	assert(main_scene != null, "FAIL: Main.tscn failed to load")
	
	var main_inst = main_scene.instantiate()
	add_child(main_inst)
	print("[PASS] Main scene loaded with RoomManager & ShiftBarrier.")
	
	var dungeon = main_inst.get_node("Dungeon")
	var shift_barrier = dungeon.get_node("ShiftBarrier")
	var rooms_node = dungeon.get_node("Rooms")
	var warrior_scene = load("res://scenes/enemies/Warrior.tscn")
	
	# Wait for physics & node ready
	for i in range(15):
		await get_tree().physics_frame
	
	# -------------------------------------------------------------
	# TEST 1: Verification of All 6 Locked Room Types
	# -------------------------------------------------------------
	print("\n--- TEST 1: Verification of All 6 Locked Room Types ---")
	var registered_rooms = RoomManager.get_all_rooms()
	print("Registered Rooms in RoomManager: ", registered_rooms.size())
	assert(registered_rooms.size() >= 6, "All 6 locked rooms must be registered!")
	
	var room_types_found = []
	for r in registered_rooms:
		room_types_found.append(r.room_name)
		print(" - Room: ", r.room_name, " (Type: ", r.room_type, ")")
	
	assert(rooms_node.has_node("Treasury"), "Treasury must exist")
	assert(rooms_node.has_node("MonsterDen"), "Monster Den must exist")
	assert(rooms_node.has_node("TrapRoom"), "Trap Workshop must exist")
	assert(rooms_node.has_node("HeartChamber"), "Heart Sanctum must exist")
	assert(rooms_node.has_node("MemoryChamber"), "Memory Chamber must exist")
	assert(rooms_node.has_node("GateRoom"), "Gate Room must exist")
	print("[PASS] All 6 room types verified and active in dungeon hierarchy.")
	
	# -------------------------------------------------------------
	# TEST 2: Treasury Economy Generation
	# -------------------------------------------------------------
	print("\n--- TEST 2: Treasury Economy Generation ---")
	var gold_before_wave = ResourceManager.gold
	# Trigger wave completion signal
	EventBus.wave_completed.emit(1)
	for i in range(5):
		await get_tree().physics_frame
	
	var gold_after_wave = ResourceManager.gold
	print("Gold before wave bonus: ", gold_before_wave, " | After: ", gold_after_wave)
	assert(gold_after_wave > gold_before_wave, "Treasury must generate Gold upon wave completion!")
	print("[PASS] Treasury generated Gold revenue at wave completion (+%d Gold)." % (gold_after_wave - gold_before_wave))
	
	# -------------------------------------------------------------
	# TEST 3: Construction & Resource Consumption
	# -------------------------------------------------------------
	print("\n--- TEST 3: Trap Construction ---")
	var trap_cost = 40
	var gold_before_trap = ResourceManager.gold
	var trap_pos = Vector2(500, 360)
	var build_success = dungeon.spawn_spike_trap_at(trap_pos)
	print("Placed new Spike Trap at ", trap_pos, " | Success: ", build_success)
	assert(build_success == true, "Must successfully construct Spike Trap on valid floor!")
	assert(ResourceManager.gold == gold_before_trap - trap_cost, "Constructing trap must deduct 40 Gold!")
	print("[PASS] Trap construction verified with resource deduction.")
	
	# -------------------------------------------------------------
	# TEST 4: Dungeon Shift Activation & Barrier
	# -------------------------------------------------------------
	print("\n--- TEST 4: Living Dungeon Shift Activation ---")
	ResourceManager.essence = 25 # Ensure sufficient essence
	var essence_before_shift = ResourceManager.essence
	assert(shift_barrier.is_shifted == false, "Shift barrier must start inactive")
	
	# Request Dungeon Shift
	var shift_result = shift_barrier.activate_shift()
	assert(shift_result == true, "Dungeon Shift must activate successfully")
	assert(shift_barrier.is_shifted == true, "Shift barrier must be active")
	assert(dungeon.is_north_flank_blocked == true, "Dungeon must recognize North Flank as blocked")
	assert(ResourceManager.essence == essence_before_shift - 15, "Dungeon Shift must consume 15 Essence!")
	print("[PASS] Dungeon Shift successfully activated, consuming 15 Essence and raising barrier.")
	
	# -------------------------------------------------------------
	# TEST 5: Enemy Rerouting upon Dungeon Shift
	# -------------------------------------------------------------
	print("\n--- TEST 5: Enemy Rerouting Under Living Dungeon Shift ---")
	# Force an enemy into North Flank intent
	var warrior = warrior_scene.instantiate()
	warrior.position = Vector2(330, 360)
	dungeon.get_node("Enemies").add_child(warrior)
	warrior.chosen_route_name = "North Flank"
	
	# Evaluate while shift is active
	warrior._evaluate_routes_and_adapt()
	print("Warrior route under active shift: ", warrior.chosen_route_name)
	print("Alert Text: '", warrior.adaptation_alert_text, "'")
	assert(warrior.chosen_route_name != "North Flank", "Warrior must NOT choose blocked North corridor!")
	assert("SHIFT" in warrior.adaptation_alert_text, "Warrior must detect Dungeon Shift and explain rerouting!")
	print("[PASS] Invader dynamically rerouted away from living shift barrier.")
	
	warrior.die()
	
	# Deactivate shift to test normalization
	shift_barrier.deactivate_shift()
	assert(shift_barrier.is_shifted == false, "Shift barrier must normalize")
	assert(dungeon.is_north_flank_blocked == false, "Dungeon corridors must reopen")
	print("[PASS] Dungeon Shift normalized and corridors reopened.")
	
	# -------------------------------------------------------------
	# TEST 6: Room Interaction
	# -------------------------------------------------------------
	print("\n--- TEST 6: Room Selection & Interaction ---")
	var treasury_room = rooms_node.get_node("Treasury")
	treasury_room.select_room()
	assert(treasury_room.is_selected == true, "Room must register selection")
	treasury_room.deselect_room()
	assert(treasury_room.is_selected == false, "Room must register deselection")
	print("[PASS] Room selection and interaction verified.")
	
	print("\n==========================================")
	print(" ALL PHASE 3 ACCEPTANCE CRITERIA PASSED!")
	print("==========================================\n")
	
	get_tree().quit(0)
