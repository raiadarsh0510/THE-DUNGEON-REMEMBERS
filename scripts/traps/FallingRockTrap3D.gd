extends Node3D

# FallingRockTrap3D: Heavy overhead crushing boulder trap.
# Mechanics: Suspended rock crashes down when an invader steps beneath, crushing targets in radius.

@export var damage: float = 50.0
@export var impact_radius: float = 2.2
@export var trap_cost: int = 50
@export var trap_type: String = "Falling Rock"

@onready var trigger_area: Area3D = $TriggerArea
@onready var boulder: Node3D = $Boulder
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var impact_light: OmniLight3D = $ImpactLight

var is_triggered: bool = false

func _ready() -> void:
	add_to_group("traps")
	trigger_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if is_triggered:
		return
	if body.is_in_group("enemies"):
		trigger_trap(body)

func trigger_trap(target_enemy: Node3D) -> void:
	is_triggered = true
	EventBus.trap_triggered.emit(trap_type, global_position, target_enemy)
	AudioManager.play_sfx("trap_spring", 0.0, 0.85)
	
	if anim_player:
		anim_player.play("drop")
	
	# Boulder hits floor after 0.25s
	get_tree().create_timer(0.25).timeout.connect(func():
		_impact_crush()
	)

func _impact_crush() -> void:
	AudioManager.play_sfx("heart_damage", 1.0, 0.7) # Deep thunderous crash
	if impact_light:
		impact_light.light_energy = 3.0
		var tw = create_tween()
		tw.tween_property(impact_light, "light_energy", 0.0, 0.4)
		
	# Damage all enemies in impact radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			var d = global_position.distance_to(enemy.global_position)
			if d <= impact_radius:
				if enemy.has_method("attempt_evade_trap") and enemy.attempt_evade_trap():
					continue
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage)
					
	# Boulder crumbles/fades away
	var crumble_tw = create_tween()
	crumble_tw.tween_property(boulder, "scale", Vector3.ZERO, 0.5)
