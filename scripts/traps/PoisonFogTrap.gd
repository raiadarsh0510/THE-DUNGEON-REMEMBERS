extends Area2D

# PoisonFogTrap.gd: Inflicts damage-over-time with a lingering toxic gas cloud.

@export var tick_damage: float = 6.0
@export var cloud_duration: float = 4.0
@export var cloud_radius: float = 60.0
@export var cooldown: float = 3.0
@export var trap_name: String = "Poison Fog"

var is_ready: bool = true
var is_cloud_active: bool = false
var cloud_timer: float = 0.0
var cooldown_timer: float = 0.0
var tick_timer: float = 0.0
var pulse_anim: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _process(delta: float) -> void:
	pulse_anim += delta * 5.0
	
	if is_cloud_active:
		cloud_timer -= delta
		tick_timer -= delta
		if tick_timer <= 0.0:
			tick_timer = 0.5
			_apply_poison_ticks()
		queue_redraw()
		
		if cloud_timer <= 0.0:
			is_cloud_active = false
			cooldown_timer = cooldown
			queue_redraw()
	elif not is_ready:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			is_ready = true
			queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and is_ready:
		trigger_trap(body)

func trigger_trap(target: Node2D) -> void:
	if not is_ready:
		return
	is_ready = false
	is_cloud_active = true
	cloud_timer = cloud_duration
	tick_timer = 0.0
	queue_redraw()
	EventBus.trap_triggered.emit(trap_name, global_position, target)

func _apply_poison_ticks() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			if global_position.distance_to(enemy.global_position) <= cloud_radius:
				if enemy.has_method("take_damage"):
					enemy.take_damage(tick_damage)
				if enemy.has_method("apply_slow"):
					enemy.apply_slow(0.65, 1.0)

func _draw() -> void:
	var vent_size = Vector2(40, 40)
	var half = vent_size / 2.0
	
	# Metal vent grate
	draw_rect(Rect2(-half, vent_size), Color(0.14, 0.18, 0.14, 0.95))
	draw_rect(Rect2(-half, vent_size), Color(0.3, 0.45, 0.3, 1.0), false, 2.0)
	
	# Vent slits
	for i in range(-2, 3):
		draw_line(Vector2(-12, i * 6), Vector2(12, i * 6), Color(0.08, 0.1, 0.08, 1.0), 2.5)
	
	# Poison cloud VFX
	if is_cloud_active:
		var alpha = 0.35 + sin(pulse_anim) * 0.1
		draw_circle(Vector2.ZERO, cloud_radius, Color(0.2, 0.8, 0.2, alpha))
		draw_circle(Vector2(sin(pulse_anim) * 10, cos(pulse_anim) * 8), cloud_radius * 0.7, Color(0.4, 0.9, 0.3, alpha * 0.8))
		draw_arc(Vector2.ZERO, cloud_radius, 0, TAU, 24, Color(0.3, 0.9, 0.3, 0.7), 2.0)
	
	# Cooldown arc
	if not is_ready and not is_cloud_active:
		var cd_ratio = 1.0 - (cooldown_timer / cooldown)
		draw_arc(Vector2.ZERO, 18.0, 0, TAU * cd_ratio, 16, Color(0.4, 0.8, 0.3, 0.8), 2.0)
