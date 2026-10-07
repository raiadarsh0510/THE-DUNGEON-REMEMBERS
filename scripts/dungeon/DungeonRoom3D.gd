extends Node3D
class_name DungeonRoom3D

# DungeonRoom3D: Represents one of the 6 specialized modular dungeon chambers.
# Types: TREASURY, MONSTER DEN, TRAP ROOM, HEART CHAMBER, MEMORY CHAMBER, GATE ROOM.

@export var room_name: String = "Treasury"
@export var room_type: int = 0 # Matches RoomManager.RoomType
@export var bonus_gold: int = 0
@export var bonus_essence: int = 0
@export var bonus_energy: int = 0

@onready var room_label: Label3D = $Label3D

func _ready() -> void:
	add_to_group("dungeon_rooms")
	RoomManager.register_room(self)
	if room_label:
		room_label.text = room_name.to_upper()

func trigger_wave_bonus() -> void:
	if bonus_gold > 0:
		ResourceManager.add_gold(bonus_gold)
		AudioManager.play_sfx("gold_chime", 0.0, 1.1)
	if bonus_essence > 0:
		ResourceManager.add_essence(bonus_essence)
	if bonus_energy > 0:
		ResourceManager.add_heart_energy(bonus_energy)
