class_name MemoryRecord
extends RefCounted

# MemoryRecord: Data model representing an invader's memory of dungeon encounters.
# Follows the RRR specification: records event, location, severity, confidence, decay.

var id: String = ""
var enemy_type: String = "Warrior"
var event_type: String = "TRAP_TRIGGERED"
var location: Vector3 = Vector3.ZERO
var danger_score: float = 0.85
var confidence: float = 1.0
var encounter_count: int = 1
var is_false_memory: bool = false
var decay_rate: float = 0.15
var created_wave: int = 1
var last_wave: int = 1
var description: String = ""

func _init(p_enemy_type: String = "Warrior", p_event_type: String = "TRAP_TRIGGERED", p_loc: Vector3 = Vector3.ZERO, p_danger: float = 0.85, p_desc: String = "") -> void:
	enemy_type = p_enemy_type
	event_type = p_event_type
	location = p_loc
	danger_score = p_danger
	confidence = 1.0
	encounter_count = 1
	id = "%s_%s_%d_%d" % [event_type, enemy_type, int(location.x / 3.0) * 3, int(location.z / 3.0) * 3]
	description = p_desc if p_desc != "" else "%s at (%d, %d)" % [event_type, int(location.x), int(location.z)]

func reinforce(additional_danger: float = 0.0, current_wave: int = 1) -> void:
	confidence = min(1.0, confidence + 0.35)
	encounter_count += 1
	last_wave = current_wave
	if additional_danger > 0.0:
		danger_score = max(danger_score, additional_danger)

func decay(amount: float) -> void:
	# Traumatic high-danger memories decay slower
	var adjusted_decay = amount * (1.0 - danger_score * 0.4)
	confidence = max(0.0, confidence - adjusted_decay)

func to_dict() -> Dictionary:
	return {
		"id": id,
		"enemy_type": enemy_type,
		"event_type": event_type,
		"location": location,
		"danger_score": danger_score,
		"confidence": confidence,
		"encounter_count": encounter_count,
		"is_false_memory": is_false_memory,
		"last_wave": last_wave,
		"description": description
	}
