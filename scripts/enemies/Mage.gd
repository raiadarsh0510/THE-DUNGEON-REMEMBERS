extends CharacterBody2D

# Mage.gd: Strategic ranged invader.
# Strengths: Ranged arcane attacks, detects and dispels illusions.
# Weakness: Fragile health (40 HP).

enum AIState {
	ENTER,
	EVALUATE,
	MOVE,
	RANGED_ATTACK,
	DEAD
}

@export var max_hp: float = 40.0
@export var move_speed: float = 95.0
@export var attack_damage: float = 14.0
@export var attack_range: float = 190.0
@export var cast_interval: float = 1.4

var current_hp: float = 40.0
var ai_state: AIState = AIState.ENTER
var target_heart: Node2D = null
var is_dead: bool = false
var cast_cooldown: float = 0.0

var current_waypoints: Array[Vector2] = []
var chosen_route_name: String = "Direct"
var has_adapted: bool = false

var hurt_flash_timer: float = 0.0
var walk_anim_timer: float = 0.0
var cast_beam_timer: float = 0.0
var adaptation_alert_text: String = ""
var adaptation_alert_timer: float = 0.0
var stun_timer: float = 0.0
var slow_timer: float = 0.0
var slow_factor: float = 1.0

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemies")
	EventBus.enemy_spawned.emit(self)
	
	nav_agent.path_desired_distance = 12.0
	nav_agent.target_desired_distance = 36.0
	
	call_deferred("_setup_ai")

func get_enemy_type() -> String:
	return "Mage"

func _setup_ai() -> void:
	await get_tree().physics_frame
	find_heart()
	ai_state = AIState.ENTER
	nav_agent.target_position = Vector2(340, 360)

func find_heart() -> void:
	var hearts = get_tree().get_nodes_in_group("dungeon_heart")
	if hearts.size() > 0:
		target_heart = hearts[0]

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	if hurt_flash_timer > 0.0:
		hurt_flash_timer -= delta
		queue_redraw()
	
	if cast_beam_timer > 0.0:
		cast_beam_timer -= delta
		queue_redraw()
	
	if adaptation_alert_timer > 0.0:
		adaptation_alert_timer -= delta
		queue_redraw()
	
	if stun_timer > 0.0:
		stun_timer -= delta
		velocity = Vector2.ZERO
		queue_redraw()
		return
	
	if slow_timer > 0.0:
		slow_timer -= delta
	
	walk_anim_timer += delta * 6.0
	
	match ai_state:
		AIState.ENTER:
			if global_position.x >= 320.0 or nav_agent.is_navigation_finished():
				ai_state = AIState.EVALUATE
			else:
				_move_along_nav()
		AIState.EVALUATE:
			_evaluate_routes_and_adapt()
		AIState.MOVE:
			_process_move_state(delta)
		AIState.RANGED_ATTACK:
			_process_ranged_attack(delta)

func _evaluate_routes_and_adapt() -> void:
	var central_dist = 880.0
	var central_danger = MemoryManager.get_danger_at_location(Vector2(480, 360), 100.0)
	var central_score = central_dist + (central_danger * 600.0)
	
	var north_dist = 1100.0
	var north_danger = MemoryManager.get_danger_at_location(Vector2(580, 200), 80.0)
	var is_north_blocked = false
	var dungeon_nodes = get_tree().get_nodes_in_group("dungeon")
	if dungeon_nodes.size() > 0 and dungeon_nodes[0].get("is_north_flank_blocked"):
		is_north_blocked = true
	var north_score = 999999.0 if is_north_blocked else (north_dist + (north_danger * 600.0))
	
	var south_dist = 1100.0
	var south_danger = MemoryManager.get_danger_at_location(Vector2(580, 520), 80.0)
	var south_score = south_dist + (south_danger * 600.0)
	
	if is_north_blocked and chosen_route_name == "North Flank":
		has_adapted = true
		chosen_route_name = "South Flank" if south_score <= central_score else "Central Direct"
		if chosen_route_name == "South Flank":
			current_waypoints = [Vector2(340, 520), Vector2(580, 520), Vector2(820, 520), Vector2(820, 360)]
		else:
			current_waypoints = [Vector2(580, 360), Vector2(820, 360)]
		adaptation_alert_text = "MAGE: DUNGEON SHIFT SENSED!"
		adaptation_alert_timer = 3.5
		EventBus.enemy_adapted.emit(self, "Mage sensed shifted corridor")
	elif central_danger > 0.15 and (north_score < central_score or south_score < central_score):
		has_adapted = true
		if north_score <= south_score:
			chosen_route_name = "North Flank"
			current_waypoints = [Vector2(340, 200), Vector2(580, 200), Vector2(820, 200), Vector2(820, 360)]
			adaptation_alert_text = "MAGE: AVOIDING CENTRAL HAZARD"
		else:
			chosen_route_name = "South Flank"
			current_waypoints = [Vector2(340, 520), Vector2(580, 520), Vector2(820, 520), Vector2(820, 360)]
			adaptation_alert_text = "MAGE: AVOIDING CENTRAL HAZARD"
		adaptation_alert_timer = 4.0
		EventBus.enemy_adapted.emit(self, "Mage routed around danger")
	else:
		chosen_route_name = "Central Direct"
		current_waypoints = [Vector2(580, 360), Vector2(820, 360)]
	
	_set_next_waypoint()
	ai_state = AIState.MOVE

func _set_next_waypoint() -> void:
	if current_waypoints.size() > 0:
		nav_agent.target_position = current_waypoints.pop_front()
	elif is_instance_valid(target_heart):
		nav_agent.target_position = target_heart.global_position

func _process_move_state(_delta: float) -> void:
	if not is_instance_valid(target_heart):
		find_heart()
		if not is_instance_valid(target_heart):
			return
	
	# Stop at ranged casting distance!
	if global_position.distance_to(target_heart.global_position) <= attack_range:
		ai_state = AIState.RANGED_ATTACK
		velocity = Vector2.ZERO
		return
	
	if nav_agent.is_navigation_finished():
		if current_waypoints.size() > 0:
			_set_next_waypoint()
		else:
			nav_agent.target_position = target_heart.global_position
	
	_move_along_nav()

func _move_along_nav() -> void:
	var next_pos = nav_agent.get_next_path_position()
	var dir = (next_pos - global_position).normalized()
	var current_speed = move_speed * (slow_factor if slow_timer > 0.0 else 1.0)
	velocity = dir * current_speed
	move_and_slide()
	queue_redraw()

func apply_stun(duration: float) -> void:
	stun_timer = max(stun_timer, duration)
	velocity = Vector2.ZERO
	adaptation_alert_text = "MAGE: STUNNED!"
	adaptation_alert_timer = duration
	queue_redraw()

func apply_slow(factor: float, duration: float) -> void:
	slow_factor = factor
	slow_timer = max(slow_timer, duration)

func _process_ranged_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	cast_cooldown -= delta
	if cast_cooldown <= 0.0:
		cast_cooldown = cast_interval
		if is_instance_valid(target_heart) and target_heart.has_method("take_damage"):
			target_heart.take_damage(attack_damage)
			cast_beam_timer = 0.25
			queue_redraw()

func dispel_illusion() -> void:
	adaptation_alert_text = "MAGE: ILLUSION REVEALED & DISPELLED!"
	adaptation_alert_timer = 3.5

func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_hp -= amount
	hurt_flash_timer = 0.2
	EventBus.enemy_damaged.emit(self, amount, current_hp)
	queue_redraw()
	if current_hp <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	ai_state = AIState.DEAD
	EventBus.enemy_died.emit(self)
	queue_free()

func _draw() -> void:
	draw_ellipse(Vector2(0, 12), 12, 5, Color(0, 0, 0, 0.4))
	
	var robe_col = Color(0.3, 0.45, 0.85, 1.0)
	if hurt_flash_timer > 0:
		robe_col = Color(1.0, 1.0, 1.0, 1.0)
	
	var bob = sin(walk_anim_timer) * 1.5 if velocity.length() > 5.0 else 0.0
	
	# Robe / Wizard hat
	draw_circle(Vector2(0, bob), 12.0, robe_col)
	draw_circle(Vector2(0, bob), 12.0, Color(0.15, 0.2, 0.4, 1.0), false, 1.5)
	
	# Arcane staff with glowing crystal
	var staff_pos = Vector2(10, -4 + bob)
	draw_line(staff_pos + Vector2(0, 16), staff_pos - Vector2(0, 12), Color(0.4, 0.3, 0.2, 1.0), 2.5)
	draw_circle(staff_pos - Vector2(0, 12), 4.5, Color(0.4, 0.8, 1.0, 0.9))
	
	# Ranged casting beam / magic projectile
	if cast_beam_timer > 0.0 and is_instance_valid(target_heart):
		var target_local = to_local(target_heart.global_position)
		draw_line(staff_pos - Vector2(0, 12), target_local, Color(0.3, 0.8, 1.0, 0.85), 3.0)
		draw_circle(target_local, 10.0, Color(0.5, 0.9, 1.0, 0.6))
	
	# Health bar
	var bar_width = 24.0
	var bar_height = 3.5
	var bar_pos = Vector2(-bar_width / 2.0, -20.0 + bob)
	draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color(0.15, 0.15, 0.15, 0.85))
	var hp_ratio = clamp(current_hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(bar_pos, Vector2(bar_width * hp_ratio, bar_height)), Color(0.3, 0.7, 1.0, 1.0))
	draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color(0, 0, 0, 0.9), false, 1.0)
	
	# Alert
	if adaptation_alert_timer > 0.0:
		var text_pos = Vector2(-95, -34.0 + bob)
		draw_rect(Rect2(text_pos + Vector2(-4, -14), Vector2(195, 18)), Color(0.1, 0.1, 0.2, 0.9))
		draw_rect(Rect2(text_pos + Vector2(-4, -14), Vector2(195, 18)), Color(0.4, 0.7, 1.0, 0.9), false, 1.5)
		draw_string(ThemeDB.fallback_font, text_pos + Vector2(2, 0), adaptation_alert_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.7, 0.9, 1.0, 1.0))
