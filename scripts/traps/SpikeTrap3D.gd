extends Area3D

# SpikeTrap3D: Physical dungeon trap that punctures invaders.
# Spikes thrust upwards from a dark stone baseplate upon detection.

@export var damage: float = 35.0
@export var trap_cooldown: float = 2.0
@export var trap_name: String = "Spike Trap"

@onready var spikes_mesh: Node3D = $Visuals/Spikes
@onready var plate_mesh: MeshInstance3D = $Visuals/BasePlate
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var is_ready: bool = true
var target_queue: Array[Node3D] = []

func _ready() -> void:
	add_to_group("traps")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemies"):
		if not target_queue.has(body):
			target_queue.append(body)
		if is_ready:
			trigger_trap()

func _on_body_exited(body: Node3D) -> void:
	target_queue.erase(body)

func trigger_trap() -> void:
	if not is_ready:
		return
	is_ready = false
	
	# Play thrust animation & procedural sound
	anim_player.play("thrust")
	AudioManager.play_sfx("spike_trap", 0.0, 1.0)
	
	# Collect targets from queue or overlapping bodies
	var targets = target_queue.duplicate()
	for body in get_overlapping_bodies():
		if body.is_in_group("enemies") and not targets.has(body):
			targets.append(body)
			
	if targets.is_empty():
		EventBus.trap_triggered.emit("spike", global_position, null)
	else:
		for target in targets:
			if is_instance_valid(target) and target.has_method("take_damage"):
				if target.has_method("attempt_evade_trap") and target.attempt_evade_trap():
					continue
				target.take_damage(damage)
				EventBus.trap_triggered.emit("spike", global_position, target)
			
	# Cooldown reset
	get_tree().create_timer(trap_cooldown).timeout.connect(func():
		is_ready = true
		if target_queue.size() > 0:
			trigger_trap()
	)
