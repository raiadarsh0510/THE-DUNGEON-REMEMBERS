extends Node

# GameManager coordinates global game states, pauses, restarts, settings, and run statistics.

enum State {
	TITLE,
	PREPARATION,
	COMBAT,
	VICTORY,
	DEFEAT
}

var current_state: State = State.PREPARATION
var is_game_over: bool = false
var screen_shake_enabled: bool = true

# Comprehensive run statistics for Game Over & Victory screens
var stats_waves_survived: int = 0
var stats_invaders_slain: int = 0
var stats_traps_triggered: int = 0
var stats_memories_formed: int = 0
var stats_gold_harvested: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.heart_destroyed.connect(_on_heart_destroyed)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.trap_triggered.connect(func(_type, _pos, _tgt): stats_traps_triggered += 1)
	EventBus.memory_created.connect(func(_mem): stats_memories_formed += 1)
	EventBus.request_game_restart.connect(restart_game)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			toggle_pause()
		elif event.keycode == KEY_R and is_game_over:
			restart_game()

func set_state(new_state: State) -> void:
	current_state = new_state
	EventBus.game_state_changed.emit(State.keys()[current_state])

func toggle_pause() -> void:
	if is_game_over:
		return
	var tree = get_tree()
	tree.paused = not tree.paused
	EventBus.game_paused.emit(tree.paused)

func set_screen_shake_enabled(enabled: bool) -> void:
	screen_shake_enabled = enabled
	EventBus.settings_changed.emit()

func reset_stats() -> void:
	stats_waves_survived = 0
	stats_invaders_slain = 0
	stats_traps_triggered = 0
	stats_memories_formed = 0
	stats_gold_harvested = 0

func _on_wave_started(_wave_number: int) -> void:
	set_state(State.COMBAT)

func _on_wave_completed(wave_number: int) -> void:
	stats_waves_survived = max(stats_waves_survived, wave_number)
	set_state(State.PREPARATION)

func _on_enemy_died(enemy: Node) -> void:
	stats_invaders_slain += 1
	if enemy != null:
		if "gold_bounty" in enemy:
			stats_gold_harvested += enemy.gold_bounty
		elif enemy.has_meta("gold_bounty"):
			stats_gold_harvested += int(enemy.get_meta("gold_bounty"))
		elif enemy.get("gold_bounty") != null:
			stats_gold_harvested += int(enemy.get("gold_bounty"))

func _on_heart_destroyed() -> void:
	is_game_over = true
	set_state(State.DEFEAT)
	EventBus.game_over.emit(false)

func _on_boss_defeated() -> void:
	is_game_over = true
	set_state(State.VICTORY)
	EventBus.game_over.emit(true)

func start_new_game() -> void:
	get_tree().paused = false
	is_game_over = false
	reset_stats()
	ResourceManager.reset_resources()
	MemoryManager.clear_all_memories()
	set_state(State.PREPARATION)
	get_tree().change_scene_to_file("res://scenes/main/Main3D.tscn")

func restart_game() -> void:
	start_new_game()

func return_to_title() -> void:
	get_tree().paused = false
	is_game_over = false
	reset_stats()
	ResourceManager.reset_resources()
	MemoryManager.clear_all_memories()
	set_state(State.TITLE)
	get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")
