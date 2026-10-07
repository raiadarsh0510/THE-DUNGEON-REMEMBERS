extends Node3D

# Main3D: Top-level orchestrator for 3D gameplay in "The Dungeon Remembers"
# Coordinates Dungeon3D, DungeonCamera3D, HUD3D, 5-wave progression, audio, and win/loss states.

@onready var dungeon: Node3D = $Dungeon3D
@onready var camera: Node3D = $DungeonCamera3D
@onready var hud: CanvasLayer = $HUD3D
@onready var fx: Node = $FXManager3D

var current_wave: int = 1
const MAX_WAVES: int = 5
var active_enemies: Array[Node] = []
var wave_active: bool = false

@export var auto_start_wave: bool = true

func _ready() -> void:
	add_to_group("main")
	EventBus.enemy_spawned.connect(_on_enemy_spawned)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.request_game_restart.connect(restart_scene)
	
	if auto_start_wave:
		get_tree().create_timer(1.0).timeout.connect(func(): start_wave(1))

func start_next_wave() -> void:
	if not wave_active and current_wave <= MAX_WAVES:
		start_wave(current_wave)

func start_wave(wave_num: int) -> void:
	current_wave = wave_num
	wave_active = true
	active_enemies.clear()
	GameManager.set_state(GameManager.State.COMBAT)
	EventBus.wave_started.emit(wave_num)
	
	match wave_num:
		1:
			_spawn_staggered(["warrior", "warrior"])
		2:
			_spawn_staggered(["rogue", "warrior", "warrior"])
		3:
			_spawn_staggered(["mage", "rogue", "warrior", "warrior"])
		4:
			_spawn_staggered(["rogue", "mage", "rogue", "warrior", "warrior"])
		5:
			_spawn_boss_wave()

func _spawn_staggered(enemy_types: Array[String]) -> void:
	for i in range(enemy_types.size()):
		var type = enemy_types[i]
		if i > 0:
			await get_tree().create_timer(0.6).timeout
			if not is_instance_valid(self) or not wave_active:
				return
		var unit = dungeon.spawn_enemy(type)
		if unit:
			_register_enemy(unit)

func _spawn_boss_wave() -> void:
	# Spawn Grand Inquisitor Boss first
	var boss = dungeon.spawn_boss()
	if boss:
		_register_enemy(boss)
		EventBus.boss_spawned.emit(boss)
		
	# Followed by 2 vanguard bodyguards
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(self) and wave_active:
		var g1 = dungeon.spawn_warrior()
		if g1:
			_register_enemy(g1)
		var g2 = dungeon.spawn_warrior()
		if g2:
			_register_enemy(g2)

func _register_enemy(enemy: Node) -> void:
	if not active_enemies.has(enemy):
		active_enemies.append(enemy)
	if hud and hud.has_method("update_enemies_count"):
		hud.update_enemies_count(active_enemies.size())

func _on_enemy_spawned(enemy: Node) -> void:
	_register_enemy(enemy)

func _on_enemy_died(enemy: Node) -> void:
	active_enemies.erase(enemy)
	if hud and hud.has_method("update_enemies_count"):
		hud.update_enemies_count(active_enemies.size())
	
	if wave_active and active_enemies.is_empty():
		wave_active = false
		EventBus.wave_completed.emit(current_wave)
		
		if current_wave >= MAX_WAVES:
			# Final victory over all 5 incursions
			GameManager.set_state(GameManager.State.VICTORY)
			EventBus.boss_defeated.emit()
			EventBus.game_over.emit(true)
		else:
			# Preparation phase for next wave
			current_wave += 1
			ResourceManager.add_gold(50)
			ResourceManager.add_essence(20)
			GameManager.set_state(GameManager.State.PREPARATION)

func restart_scene() -> void:
	get_tree().paused = false
	GameManager.reset_stats()
	ResourceManager.reset_resources()
	MemoryManager.clear_all_memories()
	get_tree().reload_current_scene()
