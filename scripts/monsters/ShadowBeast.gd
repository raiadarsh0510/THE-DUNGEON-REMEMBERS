extends CharacterBody2D

# ShadowBeast.gd: Swift, terrifying stalker of the dungeon depths.
# High movement speed and lethal pounce strikes.

@export var max_hp: float = 65.0
@export var move_speed: float = 160.0
@export var attack_damage: float = 18.0
@export var pounce_range: float = 65.0
@export var attack_interval: float = 1.0
@export var detection_range: float = 220.0

var current_hp: float = 65.0
var attack_cooldown: float = 0.0
var target_enemy: Node2D = null
var home_position: Vector2 = Vector2.ZERO

var hurt_flash_timer: float = 0.0
var anim_timer: float = 0.0
var is_pouncing: bool = false
var pounce_timer: float = 0.0

func _ready() -> void:
	current_hp = max_hp
	home_position = global_position
	add_to_group("monsters")
	queue_redraw()

func _physics_process(delta: float) -> void:
	if hurt_flash_timer > 0.0:
		hurt_flash_timer -= delta
		queue_redraw()
	
	anim_timer += delta * 12.0
	attack_cooldown -= delta
	
	if pounce_timer > 0.0:
		pounce_timer -= delta
		if pounce_timer <= 0.0:
			is_pouncing = false
		queue_redraw()
	
	# Validate or find target
	if not is_instance_valid(target_enemy) or target_enemy.get("is_dead"):
		target_enemy = _find_nearest_enemy()
	
	if is_instance_valid(target_enemy):
		var dist = global_position.distance_to(target_enemy.global_position)
		if dist <= 35.0:
			# In melee range
			velocity = Vector2.ZERO
			if attack_cooldown <= 0.0:
				attack_cooldown = attack_interval
				_perform_strike(target_enemy)
		elif dist <= pounce_range and attack_cooldown <= 0.0:
			# Perform leap pounce
			attack_cooldown = attack_interval
			is_pouncing = true
			pounce_timer = 0.25
			var leap_dir = (target_enemy.global_position - global_position).normalized()
			velocity = leap_dir * (move_speed * 1.8)
			move_and_slide()
			_perform_strike(target_enemy)
		else:
			# Pursue target
			var dir = (target_enemy.global_position - global_position).normalized()
			velocity = dir * move_speed
			move_and_slide()
			queue_redraw()
	else:
		# Return to guard station
		var dist = global_position.distance_to(home_position)
		if dist > 12.0:
			velocity = (home_position - global_position).normalized() * (move_speed * 0.75)
			move_and_slide()
			queue_redraw()
		else:
			velocity = Vector2.ZERO

func _perform_strike(enemy: Node2D) -> void:
	if is_instance_valid(enemy) and enemy.has_method("take_damage"):
		enemy.take_damage(attack_damage)
		hurt_flash_timer = 0.1
		queue_redraw()

func _find_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var min_dist: float = detection_range
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
	queue_redraw()
	if current_hp <= 0:
		queue_free()

func _draw() -> void:
	# Shadow ground pool
	draw_ellipse(Vector2(0, 10), 12, 5, Color(0.05, 0.02, 0.1, 0.6))
	
	var col = Color(0.18, 0.08, 0.28, 1.0)
	if is_pouncing:
		col = Color(0.4, 0.1, 0.6, 1.0)
	if hurt_flash_timer > 0:
		col = Color(1.0, 1.0, 1.0, 1.0)
	
	var bob = sin(anim_timer) * 2.0 if velocity.length() > 5.0 else 0.0
	
	# Quadruped / feline shadow body
	draw_circle(Vector2(0, bob), 11.0, col)
	draw_circle(Vector2(0, bob), 11.0, Color(0.5, 0.1, 0.7, 0.7), false, 1.5)
	
	# Horns / feral ears
	draw_line(Vector2(-7, -4 + bob), Vector2(-12, -12 + bob), Color(0.4, 0.1, 0.6, 1.0), 2.5)
	draw_line(Vector2(7, -4 + bob), Vector2(12, -12 + bob), Color(0.4, 0.1, 0.6, 1.0), 2.5)
	
	# Glowing crimson beast eyes
	var look_dir = velocity.normalized() if velocity.length() > 0.1 else Vector2.RIGHT
	var eye_offset = look_dir * 3.0
	draw_circle(Vector2(-3, -2 + bob) + eye_offset, 2.5, Color(1.0, 0.15, 0.25, 1.0))
	draw_circle(Vector2(3, -2 + bob) + eye_offset, 2.5, Color(1.0, 0.15, 0.25, 1.0))
	
	# Shadow aura tendrils
	var tendril_x = sin(anim_timer * 1.5) * 4.0
	draw_line(Vector2(-6, 4 + bob), Vector2(-12 + tendril_x, 12 + bob), Color(0.3, 0.05, 0.45, 0.6), 1.5)
	draw_line(Vector2(6, 4 + bob), Vector2(12 - tendril_x, 12 + bob), Color(0.3, 0.05, 0.45, 0.6), 1.5)
	
	# Health bar
	var bar_width = 24.0
	var bar_pos = Vector2(-bar_width / 2.0, -19.0 + bob)
	draw_rect(Rect2(bar_pos, Vector2(bar_width, 3.0)), Color(0.12, 0.12, 0.14, 0.85))
	draw_rect(Rect2(bar_pos, Vector2(bar_width * (current_hp / max_hp), 3.0)), Color(0.65, 0.25, 0.95, 1.0))
