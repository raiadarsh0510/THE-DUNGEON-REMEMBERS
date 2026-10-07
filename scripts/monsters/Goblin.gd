extends CharacterBody2D

# Goblin.gd: Cheap basic dungeon defender.
# Loyal minion stationed to intercept and hack down intruders.

@export var max_hp: float = 50.0
@export var move_speed: float = 115.0
@export var attack_damage: float = 10.0
@export var attack_interval: float = 0.8
@export var detection_range: float = 160.0

var current_hp: float = 50.0
var attack_cooldown: float = 0.0
var target_enemy: Node2D = null
var home_position: Vector2 = Vector2.ZERO

var hurt_flash_timer: float = 0.0
var walk_anim_timer: float = 0.0

func _ready() -> void:
	current_hp = max_hp
	home_position = global_position
	add_to_group("monsters")
	queue_redraw()

func _physics_process(delta: float) -> void:
	if hurt_flash_timer > 0.0:
		hurt_flash_timer -= delta
		queue_redraw()
	
	walk_anim_timer += delta * 10.0
	attack_cooldown -= delta
	
	# Find nearest living invader
	if not is_instance_valid(target_enemy) or target_enemy.get("is_dead"):
		target_enemy = _find_nearest_enemy()
	
	if is_instance_valid(target_enemy):
		var dist = global_position.distance_to(target_enemy.global_position)
		if dist <= 38.0:
			velocity = Vector2.ZERO
			if attack_cooldown <= 0.0:
				attack_cooldown = attack_interval
				if target_enemy.has_method("take_damage"):
					target_enemy.take_damage(attack_damage)
					hurt_flash_timer = 0.1
					queue_redraw()
		else:
			var dir = (target_enemy.global_position - global_position).normalized()
			velocity = dir * move_speed
			move_and_slide()
			queue_redraw()
	else:
		# Return to post
		var dist = global_position.distance_to(home_position)
		if dist > 10.0:
			velocity = (home_position - global_position).normalized() * (move_speed * 0.7)
			move_and_slide()
			queue_redraw()
		else:
			velocity = Vector2.ZERO

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
	draw_ellipse(Vector2(0, 10), 10, 4, Color(0, 0, 0, 0.4))
	
	var col = Color(0.25, 0.65, 0.25, 1.0)
	if hurt_flash_timer > 0:
		col = Color(1.0, 1.0, 1.0, 1.0)
	
	var bob = sin(walk_anim_timer) * 1.5 if velocity.length() > 5.0 else 0.0
	
	# Body
	draw_circle(Vector2(0, bob), 10.0, col)
	draw_circle(Vector2(0, bob), 10.0, Color(0.1, 0.35, 0.1, 1.0), false, 1.5)
	
	# Pointy goblin ears
	draw_line(Vector2(-8, -2 + bob), Vector2(-14, -6 + bob), col, 2.0)
	draw_line(Vector2(8, -2 + bob), Vector2(14, -6 + bob), col, 2.0)
	
	# Spiked club
	var dir = velocity.normalized() if velocity.length() > 0.1 else Vector2.RIGHT
	draw_line(Vector2(0, bob), Vector2(0, bob) + dir * 14.0, Color(0.5, 0.35, 0.2, 1.0), 3.0)
	draw_circle(Vector2(0, bob) + dir * 14.0, 3.5, Color(0.35, 0.2, 0.1, 1.0))
	
	# Health bar
	var bar_width = 20.0
	var bar_pos = Vector2(-bar_width / 2.0, -18.0 + bob)
	draw_rect(Rect2(bar_pos, Vector2(bar_width, 3.0)), Color(0.15, 0.15, 0.15, 0.85))
	draw_rect(Rect2(bar_pos, Vector2(bar_width * (current_hp / max_hp), 3.0)), Color(0.2, 0.85, 0.3, 1.0))
