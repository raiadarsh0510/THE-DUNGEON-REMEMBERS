extends CharacterBody2D

# Mimic.gd: Deceptive ambush predator disguised as a treasure chest.
# Lies motionless until an unsuspecting invader draws near, then snaps open
# with devastating surprise ambush damage!

enum MimicState {
	DISGUISED,
	AMBUSH_STRIKE,
	ACTIVE_COMBAT
}

@export var max_hp: float = 80.0
@export var move_speed: float = 100.0
@export var ambush_damage: float = 45.0
@export var regular_damage: float = 22.0
@export var ambush_trigger_range: float = 50.0
@export var attack_interval: float = 0.9

var current_hp: float = 80.0
var state: MimicState = MimicState.DISGUISED
var attack_cooldown: float = 0.0
var target_enemy: Node2D = null
var home_position: Vector2 = Vector2.ZERO

var hurt_flash_timer: float = 0.0
var anim_timer: float = 0.0
var ambush_anim_timer: float = 0.0

func _ready() -> void:
	current_hp = max_hp
	home_position = global_position
	add_to_group("monsters")
	queue_redraw()

func _physics_process(delta: float) -> void:
	if hurt_flash_timer > 0.0:
		hurt_flash_timer -= delta
		queue_redraw()
	
	anim_timer += delta * 8.0
	attack_cooldown -= delta
	
	match state:
		MimicState.DISGUISED:
			velocity = Vector2.ZERO
			# Scan for passing enemies
			var nearest = _find_nearest_enemy(ambush_trigger_range)
			if is_instance_valid(nearest):
				# Trigger ambush!
				state = MimicState.AMBUSH_STRIKE
				ambush_anim_timer = 0.4
				target_enemy = nearest
				if target_enemy.has_method("take_damage"):
					target_enemy.take_damage(ambush_damage)
				hurt_flash_timer = 0.15
				queue_redraw()
				
		MimicState.AMBUSH_STRIKE:
			velocity = Vector2.ZERO
			ambush_anim_timer -= delta
			if ambush_anim_timer <= 0.0:
				state = MimicState.ACTIVE_COMBAT
			queue_redraw()
			
		MimicState.ACTIVE_COMBAT:
			if not is_instance_valid(target_enemy) or target_enemy.get("is_dead"):
				target_enemy = _find_nearest_enemy(180.0)
			
			if is_instance_valid(target_enemy):
				var dist = global_position.distance_to(target_enemy.global_position)
				if dist <= 38.0:
					velocity = Vector2.ZERO
					if attack_cooldown <= 0.0:
						attack_cooldown = attack_interval
						if target_enemy.has_method("take_damage"):
							target_enemy.take_damage(regular_damage)
							hurt_flash_timer = 0.1
							queue_redraw()
				else:
					var dir = (target_enemy.global_position - global_position).normalized()
					velocity = dir * move_speed
					move_and_slide()
					queue_redraw()
			else:
				# Return to station and disguise again
				var dist = global_position.distance_to(home_position)
				if dist > 8.0:
					velocity = (home_position - global_position).normalized() * (move_speed * 0.7)
					move_and_slide()
					queue_redraw()
				else:
					velocity = Vector2.ZERO
					state = MimicState.DISGUISED
					queue_redraw()

func _find_nearest_enemy(range_limit: float) -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var min_dist: float = range_limit
	for e in enemies:
		if is_instance_valid(e) and not e.get("is_dead"):
			var d = global_position.distance_to(e.global_position)
			if d < min_dist:
				min_dist = d
				nearest = e
	return nearest

func take_damage(amount: float) -> void:
	current_hp -= amount
	hurt_flash_timer = 0.2
	if state == MimicState.DISGUISED:
		# Attacked while sleeping -> wake up!
		state = MimicState.ACTIVE_COMBAT
	queue_redraw()
	if current_hp <= 0:
		queue_free()

func _draw() -> void:
	# Base shadow
	draw_ellipse(Vector2(0, 10), 14, 5, Color(0, 0, 0, 0.5))
	
	var is_flashing = hurt_flash_timer > 0.0
	
	if state == MimicState.DISGUISED:
		# Deceptive innocent wooden chest with golden lock
		var wood_col = Color(1.0, 1.0, 1.0) if is_flashing else Color(0.45, 0.28, 0.14)
		var iron_col = Color(0.85, 0.7, 0.2) # Gold trim
		
		# Chest base
		draw_rect(Rect2(-12, -4, 24, 14), wood_col)
		draw_rect(Rect2(-12, -4, 24, 14), iron_col, false, 1.5)
		
		# Chest lid (curved / rounded top)
		draw_rect(Rect2(-13, -12, 26, 8), wood_col)
		draw_rect(Rect2(-13, -12, 26, 8), iron_col, false, 1.5)
		
		# Keyhole
		draw_circle(Vector2(0, -2), 2.5, Color(0.15, 0.1, 0.05))
		draw_line(Vector2(0, -2), Vector2(0, 2), Color(0.15, 0.1, 0.05), 1.5)
	else:
		# Snapping Maw & Sharp Teeth!
		var wood_col = Color(1.0, 1.0, 1.0) if is_flashing else Color(0.5, 0.25, 0.12)
		var bob = sin(anim_timer) * 1.5 if velocity.length() > 5.0 else 0.0
		
		# Lower jaw / base
		draw_rect(Rect2(-12, -2 + bob, 24, 12), wood_col)
		
		# Gaping bloodthirsty mouth
		draw_rect(Rect2(-10, -10 + bob, 20, 10), Color(0.4, 0.05, 0.1))
		
		# Vicious teeth
		for i in range(4):
			var tx = -8 + i * 5
			# Top teeth
			draw_line(Vector2(tx, -10 + bob), Vector2(tx + 2, -5 + bob), Color(0.95, 0.95, 0.85), 2.0)
			# Bottom teeth
			draw_line(Vector2(tx, -1 + bob), Vector2(tx + 2, -6 + bob), Color(0.95, 0.95, 0.85), 2.0)
		
		# Purple slobbering tongue
		var tongue_swing = sin(anim_timer * 1.5) * 4.0
		draw_line(Vector2(0, -4 + bob), Vector2(tongue_swing, 4 + bob), Color(0.7, 0.15, 0.6), 3.5)
		
		# Open lid tilted up
		draw_line(Vector2(-13, -10 + bob), Vector2(13, -18 + bob), wood_col, 4.0)
		
		# Menacing predatory eyes
		draw_circle(Vector2(-6, -14 + bob), 2.5, Color(1.0, 0.8, 0.1))
		draw_circle(Vector2(6, -16 + bob), 2.5, Color(1.0, 0.8, 0.1))
		
		# Health bar
		var bar_width = 24.0
		var bar_pos = Vector2(-bar_width / 2.0, -24.0 + bob)
		draw_rect(Rect2(bar_pos, Vector2(bar_width, 3.0)), Color(0.12, 0.12, 0.14, 0.85))
		draw_rect(Rect2(bar_pos, Vector2(bar_width * (current_hp / max_hp), 3.0)), Color(0.9, 0.6, 0.2, 1.0))
