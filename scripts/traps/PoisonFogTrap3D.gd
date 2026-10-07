extends Node3D

# PoisonFogTrap3D: Floor vent discharging toxic gas clouds.
# Mechanics: Deals damage over time (8 DPS for 4s) and applies 30% slow.

@export var dps: float = 8.0
@export var duration: float = 4.0
@export var slow_factor: float = 0.70
@export var trap_cost: int = 45
@export var trap_type: String = "Poison Fog"
@export var cooldown: float = 4.5

@onready var trigger_area: Area3D = $TriggerArea
@onready var fog_mesh: MeshInstance3D = $FogCloud
@onready var fog_light: OmniLight3D = $FogLight

var is_active: bool = false
var cooldown_timer: float = 0.0

func _ready() -> void:
	add_to_group("traps")
	trigger_area.body_entered.connect(_on_body_entered)
	fog_mesh.visible = false
	fog_light.light_energy = 0.0

func _process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

func _on_body_entered(body: Node3D) -> void:
	if cooldown_timer > 0.0:
		return
	if body.is_in_group("enemies"):
		trigger_trap(body)

func trigger_trap(target_enemy: Node3D) -> void:
	cooldown_timer = cooldown
	EventBus.trap_triggered.emit(trap_type, global_position, target_enemy)
	AudioManager.play_sfx("trap_spring", 0.0, 1.3) # Hissing sound
	
	# Fog cloud visual activates
	fog_mesh.visible = true
	fog_mesh.scale = Vector3(0.2, 0.2, 0.2)
	fog_light.light_energy = 2.2
	
	var tw = create_tween()
	tw.tween_property(fog_mesh, "scale", Vector3(1.2, 0.8, 1.2), 0.5)
	tw.tween_interval(2.0)
	tw.tween_property(fog_mesh, "scale", Vector3.ZERO, 0.6)
	tw.parallel().tween_property(fog_light, "light_energy", 0.0, 0.6)
	tw.tween_callback(func(): fog_mesh.visible = false)
	
	# Affect target enemy and all overlapping enemies
	if is_instance_valid(target_enemy) and target_enemy.is_in_group("enemies"):
		_apply_poison_to(target_enemy)
	for body in trigger_area.get_overlapping_bodies():
		if body != target_enemy and body.is_in_group("enemies"):
			_apply_poison_to(body)

func _apply_poison_to(enemy: Node3D) -> void:
	if enemy.has_method("attempt_evade_trap") and enemy.attempt_evade_trap():
		return
	if enemy.has_method("apply_poison"):
		enemy.apply_poison(dps, duration)
	if enemy.has_method("apply_slow"):
		enemy.apply_slow(slow_factor, duration)
