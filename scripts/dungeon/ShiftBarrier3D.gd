extends StaticBody3D

# ShiftBarrier3D: Living obsidian dungeon barrier.
# Raised during Dungeon Shift to close a corridor and redirect invading forces.

@export var is_active: bool = false
@onready var col_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var rune_light: OmniLight3D = $RuneLight

func _ready() -> void:
	add_to_group("dungeon_shift_barrier")
	if is_active:
		position.y = 1.8
		col_shape.disabled = false
		rune_light.light_energy = 2.0
	else:
		position.y = -3.5
		col_shape.disabled = true
		rune_light.light_energy = 0.0

func activate_barrier() -> void:
	if is_active:
		return
	is_active = true
	col_shape.disabled = false
	anim_player.play("rise")
	AudioManager.play_sfx("dungeon_shift", 1.0, 0.95)
	
	# Light activates
	var tw = create_tween()
	tw.tween_property(rune_light, "light_energy", 2.5, 0.6)

func deactivate_barrier() -> void:
	if not is_active:
		return
	is_active = false
	anim_player.play_backwards("rise")
	AudioManager.play_sfx("dungeon_shift", -2.0, 1.1)
	
	var tw = create_tween()
	tw.tween_property(rune_light, "light_energy", 0.0, 0.5)
	tw.tween_callback(func(): col_shape.disabled = true)
