extends Node3D

# ImpactSparks3D: Transient 3D particle burst on weapon strikes and trap impacts.

@onready var particles: CPUParticles3D = $CPUParticles3D

func _ready() -> void:
	if particles:
		particles.emitting = true
	get_tree().create_timer(0.6).timeout.connect(queue_free)
