extends Node

# WaveManager.gd: Controls wave progression, enemy composition, and wave lifecycle.
# Supports varied composition across waves (Warrior frontline, Rogue flankers, Mage backline).

@export var warrior_scene: PackedScene = preload("res://scenes/enemies/Warrior.tscn")
@export var rogue_scene: PackedScene = preload("res://scenes/enemies/Rogue.tscn")
@export var mage_scene: PackedScene = preload("res://scenes/enemies/Mage.tscn")
@export var inquisitor_scene: PackedScene = preload("res://scenes/boss/Inquisitor.tscn")
@export var spawn_interval: float = 2.8

var current_wave: int = 1
var is_wave_active: bool = false
var spawn_queue: Array[PackedScene] = []
var active_enemies: Array[Node2D] = []
var spawn_timer: float = 0.0

var enemies_to_spawn: int:
	get:
		return spawn_queue.size()
	set(val):
		if val == 0:
			spawn_queue.clear()

var dungeon_ref: Node2D = null

func _ready() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.heart_destroyed.connect(_on_heart_destroyed)

func setup(dungeon: Node2D) -> void:
	dungeon_ref = dungeon

func start_next_wave() -> void:
	if is_wave_active:
		return
	
	is_wave_active = true
	spawn_queue = _generate_wave_composition(current_wave)
	spawn_timer = 0.5 # Fast initial spawn
	
	EventBus.wave_started.emit(current_wave)

func _generate_wave_composition(wave_num: int) -> Array[PackedScene]:
	var queue: Array[PackedScene] = []
	match wave_num:
		1:
			# Wave 1: 3 Warriors (Tutorial & baseline memory test)
			queue = [warrior_scene, warrior_scene, warrior_scene]
		2:
			# Wave 2: 2 Warriors + 2 Rogues (Swift flanking pressure)
			queue = [warrior_scene, rogue_scene, warrior_scene, rogue_scene]
		3:
			# Wave 3: 2 Warriors + 2 Rogues + 2 Mages (Full combined-arms assault)
			queue = [warrior_scene, rogue_scene, mage_scene, warrior_scene, rogue_scene, mage_scene]
		4:
			# Wave 4: 3 Warriors + 3 Rogues + 2 Mages (Heavy multi-route invasion)
			queue = [
				warrior_scene, warrior_scene, rogue_scene,
				mage_scene, warrior_scene, rogue_scene,
				rogue_scene, mage_scene
			]
		5:
			# Wave 5: The Grand Inquisitor Boss Arrival!
			queue = [inquisitor_scene]
		_:
			# Wave 6+: Scaled elite battalion
			queue = [
				warrior_scene, warrior_scene, rogue_scene,
				rogue_scene, mage_scene, mage_scene,
				warrior_scene, rogue_scene
			]
	return queue

func _process(delta: float) -> void:
	if not is_wave_active:
		return
	
	if spawn_queue.size() > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_next_in_queue()
			spawn_timer = spawn_interval
	elif active_enemies.is_empty():
		_complete_wave()

func _spawn_next_in_queue() -> void:
	if spawn_queue.is_empty():
		return
	if not dungeon_ref or not dungeon_ref.has_node("Enemies") or not dungeon_ref.has_node("SpawnPoint"):
		return
	
	var scene_to_spawn = spawn_queue.pop_front()
	var enemy = scene_to_spawn.instantiate()
	var spawn_pos = dungeon_ref.get_node("SpawnPoint").global_position
	# Add slight jitter so enemies don't overlap exactly
	spawn_pos += Vector2(randf_range(-12, 12), randf_range(-16, 16))
	enemy.global_position = spawn_pos
	
	dungeon_ref.get_node("Enemies").add_child(enemy)
	active_enemies.append(enemy)

func _on_enemy_died(enemy: Node2D) -> void:
	if enemy in active_enemies:
		active_enemies.erase(enemy)
	
	# Check wave completion
	if is_wave_active and spawn_queue.is_empty() and active_enemies.is_empty():
		_complete_wave()

func _complete_wave() -> void:
	is_wave_active = false
	var finished_wave = current_wave
	EventBus.wave_completed.emit(finished_wave)
	if finished_wave >= 5:
		EventBus.game_over.emit(true)
	current_wave += 1

func _on_heart_destroyed() -> void:
	is_wave_active = false
	spawn_queue.clear()
