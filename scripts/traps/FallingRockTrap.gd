extends Area2D

# FallingRockTrap.gd: Inflicts heavy area-of-effect crushing damage.
# Triggers a falling boulder when enemies step onto the pressure rune.

@export var damage: float = 55.0
@export var damage_radius: float = 65.0
@export var cooldown: float = 3.5
@export var trap_name: String = "Falling Rock"

var is_ready: bool = true
var cooldown_timer: float = 0.0
var rock_falling_anim: float = 0.0 # 1.0 -> 0.0 during fall
var impact_vfx_timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _process(delta: float) -> void:
	if not is_ready:
		cooldown_timer -= delta
		if rock_falling_anim > 0.0:
			rock_falling_anim -= delta * 4.0
			if rock_falling_anim <= 0.0:
				_apply_area_crush()
			queue_redraw()
		elif impact_vfx_timer > 0.0:
			impact_vfx_timer -= delta
			queue_redraw()
		
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
	cooldown_timer = cooldown
	rock_falling_anim = 1.0 # Start drop animation
	queue_redraw()
	EventBus.trap_triggered.emit(trap_name, global_position, target)

func _apply_area_crush() -> void:
	impact_vfx_timer = 0.35
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = global_position.distance_to(enemy.global_position)
			if dist <= damage_radius and enemy.has_method("take_damage"):
				enemy.take_damage(damage)
				if enemy.has_method("apply_stun"):
					enemy.apply_stun(1.2)

func _draw() -> void:
	var plate_size = Vector2(44, 44)
	var half = plate_size / 2.0
	
	# Heavy stone floor plate
	draw_rect(Rect2(-half, plate_size), Color(0.22, 0.2, 0.18, 0.95))
	draw_rect(Rect2(-half, plate_size), Color(0.45, 0.4, 0.35, 1.0), false, 2.0)
	
	# Pressure rune in center
	var rune_col = Color(0.85, 0.65, 0.2, 0.9) if is_ready else Color(0.3, 0.3, 0.3, 0.5)
	draw_arc(Vector2.ZERO, 12.0, 0, TAU, 16, rune_col, 2.0)
	draw_line(Vector2(-8, 0), Vector2(8, 0), rune_col, 2.0)
	draw_line(Vector2(0, -8), Vector2(0, 8), rune_col, 2.0)
	
	# Falling rock animation
	if rock_falling_anim > 0.0:
		var rock_height = rock_falling_anim * 80.0
		var rock_scale = lerp(1.2, 0.5, rock_falling_anim)
		draw_circle(Vector2(0, -rock_height), 18.0 * rock_scale, Color(0.4, 0.35, 0.3, 0.95))
		draw_circle(Vector2(0, -rock_height), 18.0 * rock_scale, Color(0.15, 0.12, 0.1, 1.0), false, 2.0)
	
	# Impact shockwave
	if impact_vfx_timer > 0.0:
		var shock_radius = lerp(damage_radius, 10.0, impact_vfx_timer / 0.35)
		draw_arc(Vector2.ZERO, shock_radius, 0, TAU, 24, Color(0.9, 0.6, 0.2, 0.8), 3.0)
		draw_circle(Vector2.ZERO, shock_radius * 0.4, Color(0.5, 0.4, 0.3, 0.4))
	
	# Cooldown arc
	if not is_ready:
		var cd_ratio = 1.0 - (cooldown_timer / cooldown)
		draw_arc(Vector2.ZERO, 20.0, 0, TAU * cd_ratio, 16, Color(0.8, 0.5, 0.2, 0.8), 2.0)
