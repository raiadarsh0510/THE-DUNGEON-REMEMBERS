extends Node

# Centralized EventBus for "The Dungeon Remembers" (3D Architecture)
# Decouples core game systems according to design architecture.

# Trap signals
signal trap_triggered(trap_type: String, trap_position: Variant, target: Node)
signal trap_placed(trap_type: String, trap_position: Variant)
signal monster_placed(monster_type: String, monster_position: Variant)

# Enemy signals
signal enemy_spawned(enemy: Node)
signal enemy_damaged(enemy: Node, amount: float, current_hp: float)
signal enemy_died(enemy: Node)

# Boss signals
signal boss_spawned(boss: Node)
signal boss_damaged(current_hp: float, max_hp: float)
signal boss_phase_changed(phase: int)
signal boss_defeated()

# Dungeon Heart signals
signal heart_damaged(current_hp: float, max_hp: float, damage: float)
signal heart_destroyed()

# Wave signals
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)

# Memory & Adaptation signals
signal memory_created(memory_data: Dictionary)
signal memory_updated(memory_data: Dictionary)
signal memory_decayed(memory_data: Dictionary)
signal enemy_adapted(enemy: Node, reason: String)
signal memory_chamber_toggled(is_open: bool)

# Dungeon Shift signals
signal dungeon_shifted(is_shifted: bool)
signal dungeon_shift_requested()

# Resource signals
signal resources_changed(gold: int, essence: int, heart_energy: int)

# Game state signals
signal game_state_changed(new_state: String)
signal game_paused(is_paused: bool)
signal request_game_restart()
signal game_over(victory: bool)
signal settings_changed()
