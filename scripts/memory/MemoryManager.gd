extends Node

# MemoryManager.gd: The core of the Enemy Memory and Adaptation System.
# "The player learns. The enemy learns. The dungeon changes."

const MemoryRecord = preload("res://scripts/memory/MemoryRecord.gd")

# Collection of all active memories: key -> Dictionary
var memories: Dictionary = {}

# Decay configuration
@export var wave_decay_rate: float = 0.15
@export var min_confidence_threshold: float = 0.2

var current_wave: int = 1
var last_adaptation_event: Dictionary = {}

func _ready() -> void:
	EventBus.trap_triggered.connect(_on_trap_triggered)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.request_game_restart.connect(clear_all_memories)

func clear_all_memories() -> void:
	memories.clear()
	current_wave = 1
	last_adaptation_event.clear()

func _on_wave_started(wave_num: int) -> void:
	current_wave = wave_num

func _on_wave_completed(_wave_num: int) -> void:
	decay_memories(wave_decay_rate)

func _on_trap_triggered(trap_type: String, trap_pos: Variant, target: Node) -> void:
	var enemy_type = "Warrior"
	if target and target.has_method("get_enemy_type"):
		enemy_type = target.get_enemy_type()
	elif target and "Warrior" in target.name:
		enemy_type = "Warrior"
	
	var desc = ""
	if trap_pos is Vector3:
		desc = "%s encountered in corridor (%d, %d)" % [trap_type, int(trap_pos.x), int(trap_pos.z)]
	else:
		desc = "%s encountered in corridor (%d, %d)" % [trap_type, int(trap_pos.x), int(trap_pos.y)]
	record_event(enemy_type, "TRAP_TRIGGERED", trap_pos, 0.85, desc)

func record_event(enemy_type: String, event_type: String, loc: Variant, severity: float, description: String = "") -> Dictionary:
	var memory_key = ""
	if loc is Vector3:
		memory_key = "%s_%s_%d_%d" % [event_type, enemy_type, int(loc.x / 3.0) * 3, int(loc.z / 3.0) * 3]
	else:
		memory_key = "%s_%s_%d_%d" % [event_type, enemy_type, int(loc.x / 40.0) * 40, int(loc.y / 40.0) * 40]
	
	if memories.has(memory_key):
		# Reinforce existing memory
		var mem = memories[memory_key]
		mem["confidence"] = min(1.0, mem["confidence"] + 0.35)
		mem["encounter_count"] += 1
		mem["danger_score"] = max(mem.get("danger_score", severity), severity)
		mem["severity"] = mem["danger_score"]
		mem["last_wave"] = current_wave
		EventBus.memory_updated.emit(mem)
		return mem
	else:
		# Create new memory record
		var loc_str = ""
		if loc is Vector3:
			loc_str = "%s at (%d, %d)" % [event_type, int(loc.x), int(loc.z)]
		else:
			loc_str = "%s at (%d, %d)" % [event_type, int(loc.x), int(loc.y)]
			
		var mem = {
			"id": memory_key,
			"enemy_type": enemy_type,
			"event_type": event_type,
			"location": loc,
			"severity": severity,
			"danger_score": severity,
			"confidence": 1.0,
			"encounter_count": 1,
			"is_false_memory": false,
			"created_wave": current_wave,
			"last_wave": current_wave,
			"description": description if description != "" else loc_str
		}
		memories[memory_key] = mem
		EventBus.memory_created.emit(mem)
		return mem

func get_memories_for_enemy(enemy_type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for k in memories.keys():
		var mem = memories[k]
		if mem["enemy_type"] == enemy_type or enemy_type == "":
			result.append(mem)
	return result

func get_all_memories() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for k in memories.keys():
		list.append(memories[k])
	return list

func record_adaptation_decision(enemy: Node, decision_dict: Dictionary) -> void:
	last_adaptation_event = {
		"enemy": enemy,
		"route": decision_dict.get("route_name", ""),
		"reason": decision_dict.get("adaptation_reason", ""),
		"danger": decision_dict.get("perceived_danger", 0.0),
		"timestamp": Time.get_ticks_msec()
	}
	EventBus.enemy_adapted.emit(enemy, decision_dict.get("adaptation_reason", "Rerouted based on memory"))

func decay_memories(decay_amount: float) -> void:
	var keys_to_remove: Array[String] = []
	for key in memories.keys():
		var mem = memories[key]
		if mem["last_wave"] < current_wave:
			# Trauma factor: high danger decays slower
			var trauma = mem.get("danger_score", 0.8)
			var adjusted_decay = decay_amount * (1.0 - trauma * 0.4)
			mem["confidence"] = max(0.0, mem["confidence"] - adjusted_decay)
			EventBus.memory_decayed.emit(mem)
			if mem["confidence"] < min_confidence_threshold:
				keys_to_remove.append(key)
				
	for k in keys_to_remove:
		memories.erase(k)

func get_player_tendency_profile() -> Dictionary:
	var trap_counts = {
		"SPIKE": 0,
		"ROCK": 0,
		"POISON": 0,
		"ILLUSION": 0
	}
	var corridor_counts = {
		"Central": 0,
		"WestFlank": 0,
		"EastFlank": 0
	}
	
	for mem in memories.values():
		var desc = mem.get("description", "").to_upper()
		var ev = mem.get("event_type", "").to_upper()
		if "SPIKE" in desc or "SPIKE" in ev:
			trap_counts["SPIKE"] += mem.get("encounter_count", 1)
		elif "ROCK" in desc or "ROCK" in ev:
			trap_counts["ROCK"] += mem.get("encounter_count", 1)
		elif "POISON" in desc or "POISON" in ev:
			trap_counts["POISON"] += mem.get("encounter_count", 1)
		elif "ILLUSION" in desc or "TREASURE" in ev:
			trap_counts["ILLUSION"] += mem.get("encounter_count", 1)
		else:
			trap_counts["SPIKE"] += 1
			
		var loc = mem.get("location", Vector3.ZERO)
		var x = loc.x if loc is Vector3 else loc.x
		if x < -3.0:
			corridor_counts["WestFlank"] += 1
		elif x > 3.0:
			corridor_counts["EastFlank"] += 1
		else:
			corridor_counts["Central"] += 1
			
	var primary_trap = "SPIKE"
	var max_trap_c = -1
	for t in trap_counts.keys():
		if trap_counts[t] > max_trap_c:
			max_trap_c = trap_counts[t]
			primary_trap = t
			
	var primary_corridor = "Central"
	var max_corridor_c = -1
	for c in corridor_counts.keys():
		if corridor_counts[c] > max_corridor_c:
			max_corridor_c = corridor_counts[c]
			primary_corridor = c
			
	return {
		"primary_trap": primary_trap,
		"trap_counts": trap_counts,
		"primary_corridor": primary_corridor,
		"total_memories": memories.size()
	}

