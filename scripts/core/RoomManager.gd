extends Node

# RoomManager.gd: Coordinates the 6 specialized dungeon rooms and economy bonuses.
# Rooms: TREASURY, MONSTER DEN, TRAP ROOM, HEART CHAMBER, MEMORY CHAMBER, GATE ROOM.

enum RoomType {
	TREASURY,
	MONSTER_DEN,
	TRAP_ROOM,
	HEART_CHAMBER,
	MEMORY_CHAMBER,
	GATE_ROOM
}

var rooms: Dictionary = {}

func _ready() -> void:
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.request_game_restart.connect(func(): rooms.clear())

func register_room(room: Node) -> void:
	if "room_type" in room:
		rooms[room.room_type] = room
	if "room_name" in room:
		rooms[room.room_name] = room
	rooms[room.name] = room

func get_room(key: Variant) -> Node:
	return rooms.get(key, null)

func has_room(key: Variant) -> bool:
	return rooms.has(key)

func get_all_rooms() -> Array:
	var unique_rooms: Array = []
	for r in rooms.values():
		if not unique_rooms.has(r):
			unique_rooms.append(r)
	return unique_rooms

func _on_wave_completed(_wave_number: int) -> void:
	for room in get_all_rooms():
		if is_instance_valid(room) and room.has_method("trigger_wave_bonus"):
			room.trigger_wave_bonus()
