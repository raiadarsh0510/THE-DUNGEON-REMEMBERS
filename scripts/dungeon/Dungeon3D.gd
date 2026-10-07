extends Node3D

const DungeonRoom3D = preload("res://scripts/dungeon/DungeonRoom3D.gd")

# Dungeon3D: Multi-route gothic dark-fantasy dungeon environment.
# Features:
# - All 6 Modular Rooms: Treasury, Monster Den, Trap Room, Heart Chamber, Memory Chamber, Gate Room
# - Living Dungeon Shift Mechanic: Player spends 15 Essence to raise impassable obsidian barrier
# - Dynamic navigation route modification redirecting invaders in real time

@export var warrior_scene: PackedScene = preload("res://scenes/enemies/Warrior3D.tscn")
@export var rogue_scene: PackedScene = preload("res://scenes/enemies/Rogue3D.tscn")
@export var mage_scene: PackedScene = preload("res://scenes/enemies/Mage3D.tscn")

@export var spike_trap_scene: PackedScene = preload("res://scenes/traps/SpikeTrap3D.tscn")
@export var falling_rock_scene: PackedScene = preload("res://scenes/traps/FallingRockTrap3D.tscn")
@export var poison_fog_scene: PackedScene = preload("res://scenes/traps/PoisonFogTrap3D.tscn")
@export var illusion_trap_scene: PackedScene = preload("res://scenes/traps/IllusionTrap3D.tscn")

@export var goblin_scene: PackedScene = preload("res://scenes/monsters/Goblin3D.tscn")
@export var shadow_beast_scene: PackedScene = preload("res://scenes/monsters/ShadowBeast3D.tscn")
@export var mimic_scene: PackedScene = preload("res://scenes/monsters/Mimic3D.tscn")

@export var inquisitor_scene: PackedScene = preload("res://scenes/boss/Inquisitor3D.tscn")
@export var heart_scene: PackedScene = preload("res://scenes/dungeon/DungeonHeart3D.tscn")
@export var shift_barrier_scene: PackedScene = preload("res://scenes/dungeon/ShiftBarrier3D.tscn")

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var heart_spawn_point: Marker3D = $HeartSpawnPoint
@onready var enemy_spawn_point: Marker3D = $EnemySpawnPoint
@onready var traps_container: Node3D = $TrapsContainer
@onready var enemies_container: Node3D = $EnemiesContainer
@onready var rooms_container: Node3D = $RoomsContainer

var heart_instance: Node3D = null
var shift_barrier: StaticBody3D = null
var is_dungeon_shifted: bool = false

func _ready() -> void:
	add_to_group("dungeon")
	setup_navigation_mesh()
	spawn_heart()
	spawn_initial_trap()
	setup_shift_barrier()
	setup_six_rooms()
	EventBus.dungeon_shift_requested.connect(func(): execute_dungeon_shift())

func setup_six_rooms() -> void:
	# 1. GATE ROOM (Entrance Threshold, Z = 16)
	_create_room("Gate Room", RoomManager.RoomType.GATE_ROOM, Vector3(0, 0, 16), 0, 0, 0)
	
	# 2. MEMORY CHAMBER (Mystical Runic Alcove, X = -10, Z = 10.5)
	_create_room("Memory Chamber", RoomManager.RoomType.MEMORY_CHAMBER, Vector3(-9.5, 0, 10.5), 0, 5, 0)
	
	# 3. MONSTER DEN (Garrison Alcove, X = 10, Z = 10.5)
	_create_room("Monster Den", RoomManager.RoomType.MONSTER_DEN, Vector3(9.5, 0, 10.5), 0, 5, 0)
	
	# 4. TRAP ROOM (Defensive Corridor Core, X = 0, Z = 3)
	_create_room("Trap Room", RoomManager.RoomType.TRAP_ROOM, Vector3(0, 0, 3), 10, 0, 0)
	
	# 5. TREASURY (Economy Chamber yielding +25 Gold, X = -6.5, Z = -3)
	_create_room("Treasury", RoomManager.RoomType.TREASURY, Vector3(-6.5, 0, -3), 25, 0, 0)
	
	# 6. HEART CHAMBER (Player Core Sanctuary, X = 0, Z = -13)
	_create_room("Heart Chamber", RoomManager.RoomType.HEART_CHAMBER, Vector3(0, 0, -13), 0, 0, 10)

func _create_room(r_name: String, r_type: int, r_pos: Vector3, g_bonus: int, e_bonus: int, h_bonus: int) -> Node3D:
	var room = DungeonRoom3D.new()
	room.name = r_name.replace(" ", "")
	room.room_name = r_name
	room.room_type = r_type
	room.position = r_pos
	room.bonus_gold = g_bonus
	room.bonus_essence = e_bonus
	room.bonus_energy = h_bonus
	
	var label = Label3D.new()
	label.name = "Label3D"
	label.text = r_name.to_upper()
	label.position = Vector3(0, 2.5, 0)
	label.font_size = 22
	label.modulate = Color(0.9, 0.85, 0.7, 0.85)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	room.add_child(label)
	
	rooms_container.add_child(room)
	return room

func setup_shift_barrier() -> void:
	if shift_barrier_scene:
		shift_barrier = shift_barrier_scene.instantiate()
		# Position across the West Flank Corridor
		shift_barrier.position = Vector3(-6.5, -3.5, 3.0)
		add_child(shift_barrier)

func execute_dungeon_shift() -> bool:
	const SHIFT_COST: int = 15
	
	if not is_dungeon_shifted:
		# Attempting to activate shift
		if not ResourceManager.spend_essence(SHIFT_COST):
			return false
		is_dungeon_shifted = true
		if shift_barrier:
			shift_barrier.activate_barrier()
	else:
		# Lowering barrier
		is_dungeon_shifted = false
		if shift_barrier:
			shift_barrier.deactivate_barrier()
			
	EventBus.dungeon_shifted.emit(is_dungeon_shifted)
	
	# Alert and update route for all active enemies
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("evaluate_and_choose_route"):
			enemy.evaluate_and_choose_route()
			
	return true

func setup_navigation_mesh() -> void:
	var nav_mesh = NavigationMesh.new()
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 1.8
	
	var verts = PackedVector3Array([
		# Entrance (0 to 3)
		Vector3(-6.0, 0.05, 12.0),
		Vector3(6.0, 0.05, 12.0),
		Vector3(6.0, 0.05, 20.0),
		Vector3(-6.0, 0.05, 20.0),
		
		# Junction bottom edge at Z = 9.0 (4 to 9)
		Vector3(-8.0, 0.05, 9.0),
		Vector3(-5.0, 0.05, 9.0),
		Vector3(-2.5, 0.05, 9.0),
		Vector3(2.5, 0.05, 9.0),
		Vector3(5.0, 0.05, 9.0),
		Vector3(8.0, 0.05, 9.0),
		
		# Corridor bottom edges at Z = -6.0 (10 to 15)
		Vector3(-8.0, 0.05, -6.0),
		Vector3(-5.0, 0.05, -6.0),
		Vector3(-2.5, 0.05, -6.0),
		Vector3(2.5, 0.05, -6.0),
		Vector3(5.0, 0.05, -6.0),
		Vector3(8.0, 0.05, -6.0),
		
		# Heart Chamber bottom edge at Z = -20.0 (16 to 17)
		Vector3(-8.5, 0.05, -20.0),
		Vector3(8.5, 0.05, -20.0)
	])
	
	nav_mesh.vertices = verts
	
	nav_mesh.add_polygon(PackedInt32Array([0, 1, 2]))
	nav_mesh.add_polygon(PackedInt32Array([0, 2, 3]))
	
	nav_mesh.add_polygon(PackedInt32Array([4, 6, 0]))
	nav_mesh.add_polygon(PackedInt32Array([6, 7, 1]))
	nav_mesh.add_polygon(PackedInt32Array([6, 1, 0]))
	nav_mesh.add_polygon(PackedInt32Array([7, 9, 1]))
	
	nav_mesh.add_polygon(PackedInt32Array([4, 5, 11]))
	nav_mesh.add_polygon(PackedInt32Array([4, 11, 10]))
	
	nav_mesh.add_polygon(PackedInt32Array([6, 7, 13]))
	nav_mesh.add_polygon(PackedInt32Array([6, 13, 12]))
	
	nav_mesh.add_polygon(PackedInt32Array([8, 9, 15]))
	nav_mesh.add_polygon(PackedInt32Array([8, 15, 14]))
	
	nav_mesh.add_polygon(PackedInt32Array([10, 15, 17]))
	nav_mesh.add_polygon(PackedInt32Array([10, 17, 16]))
	
	nav_region.navigation_mesh = nav_mesh

func get_routes_to_heart() -> Dictionary:
	var routes = {
		"Central": [
			Vector3(0.0, 0.0, 16.0),
			Vector3(0.0, 0.0, 10.5),
			Vector3(0.0, 0.0, 3.0),   # Directly crosses Spike Trap
			Vector3(0.0, 0.0, -7.0),
			Vector3(0.0, 0.0, -12.0)  # Heart Core
		],
		"EastFlank": [
			Vector3(0.0, 0.0, 16.0),
			Vector3(0.0, 0.0, 10.5),
			Vector3(6.5, 0.0, 10.5),  # Turns East
			Vector3(6.5, 0.0, 3.0),
			Vector3(6.5, 0.0, -7.0),
			Vector3(0.0, 0.0, -7.0),
			Vector3(0.0, 0.0, -12.0)
		]
	}
	
	# West Flank is available ONLY when living Dungeon Shift barrier is NOT active
	if not is_dungeon_shifted:
		routes["WestFlank"] = [
			Vector3(0.0, 0.0, 16.0),
			Vector3(0.0, 0.0, 10.5),
			Vector3(-6.5, 0.0, 10.5), # Turns West
			Vector3(-6.5, 0.0, 3.0),
			Vector3(-6.5, 0.0, -7.0),
			Vector3(0.0, 0.0, -7.0),
			Vector3(0.0, 0.0, -12.0)
		]
		
	return routes

func spawn_heart() -> void:
	if heart_instance == null and heart_scene:
		heart_instance = heart_scene.instantiate()
		heart_instance.position = heart_spawn_point.position
		add_child(heart_instance)

func spawn_initial_trap() -> void:
	if spike_trap_scene:
		var trap = spike_trap_scene.instantiate()
		trap.position = Vector3(0.0, 0.0, 3.0)
		traps_container.add_child(trap)

func spawn_warrior() -> Node3D:
	if warrior_scene:
		var warrior = warrior_scene.instantiate()
		warrior.position = enemy_spawn_point.position
		enemies_container.add_child(warrior)
		return warrior
	return null

func spawn_rogue() -> Node3D:
	if rogue_scene:
		var rogue = rogue_scene.instantiate()
		rogue.position = enemy_spawn_point.position
		enemies_container.add_child(rogue)
		return rogue
	return null

func spawn_mage() -> Node3D:
	if mage_scene:
		var mage = mage_scene.instantiate()
		mage.position = enemy_spawn_point.position
		enemies_container.add_child(mage)
		return mage
	return null

func spawn_enemy(enemy_name: String) -> Node3D:
	match enemy_name.to_lower():
		"rogue":
			return spawn_rogue()
		"mage":
			return spawn_mage()
		_:
			return spawn_warrior()

func spawn_trap(type_name: String, pos: Vector3 = Vector3(0, 0, 3)) -> Node3D:
	var trap_node: Node3D = null
	match type_name.to_lower():
		"rock", "falling rock", "fallingrock":
			if falling_rock_scene:
				trap_node = falling_rock_scene.instantiate()
		"poison", "poison fog", "poisonfog":
			if poison_fog_scene:
				trap_node = poison_fog_scene.instantiate()
		"illusion", "illusion trap":
			if illusion_trap_scene:
				trap_node = illusion_trap_scene.instantiate()
		_:
			if spike_trap_scene:
				trap_node = spike_trap_scene.instantiate()
				
	if trap_node:
		trap_node.position = pos
		traps_container.add_child(trap_node)
		EventBus.trap_placed.emit(type_name, pos)
		return trap_node
	return null

func spawn_defender(type_name: String, pos: Vector3 = Vector3(0, 0, 0)) -> Node3D:
	var defender_node: Node3D = null
	match type_name.to_lower():
		"shadow beast", "shadowbeast", "beast":
			if shadow_beast_scene:
				defender_node = shadow_beast_scene.instantiate()
		"mimic":
			if mimic_scene:
				defender_node = mimic_scene.instantiate()
		_:
			if goblin_scene:
				defender_node = goblin_scene.instantiate()
				
	if defender_node:
		defender_node.position = pos
		add_child(defender_node)
		return defender_node
	return null

func spawn_boss() -> Node3D:
	if inquisitor_scene:
		var boss = inquisitor_scene.instantiate()
		boss.position = enemy_spawn_point.position
		enemies_container.add_child(boss)
		return boss
	return null
