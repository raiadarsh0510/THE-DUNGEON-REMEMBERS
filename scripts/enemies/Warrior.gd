extends CharacterBody2D

# Warrior.gd: Aggressive frontline invader with Memory & Adaptation AI.
# Implements the state machine: ENTER -> EVALUATE -> CHOOSE_PATH -> MOVE -> ATTACK.

enum AIState {
	ENTER,
	EVALUATE,
	MOVE,
	ATTACK,
	DEAD
}

@export var max_hp: float = 70.0
@export var move_speed: float = 110.0
@export var attack_damage: float = 12.0
@export var attack_interval: float = 1.0

var current_hp: float = 70.0
var ai_state: AIState = AIState.ENTER
var target_heart: Node2D = null
var is_dead: bool = false
var attack_cooldown: float = 0.0

# Route Waypoints
var current_waypoints: Array[Vector2] = []
var chosen_route_name: String = "Direct"
var has_adapted: bool = false

# Visuals & Thought Bubble
var hurt_flash_timer: float = 0.0
var walk_anim_timer: float = 0.0
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
	return "Warrior"

func _setup_ai() -> void:
	await get_tree().physics_frame
	find_heart()
	# Start by advancing towards the West Junction to evaluate routes
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
	
	walk_anim_timer += delta * 8.0
	
	match ai_state:
		AIState.ENTER:
			_process_enter_state()
		AIState.EVALUATE:
			_evaluate_routes_and_adapt()
		AIState.MOVE:
			_process_move_state(delta)
		AIState.ATTACK:
			_process_attack_state(delta)

func _process_enter_state() -> void:
	# Advance into West Junction
	if global_position.x >= 320.0 or nav_agent.is_navigation_finished():
		ai_state = AIState.EVALUATE
	else:
		_move_along_nav()

func _evaluate_routes_and_adapt() -> void:
	# Utility-based Route Scoring:
	# Score = PathDistance + MemoryDangerPenalty * Confidence
	
	# Route 1: Central Hall (Direct)
	var central_dist: float = 880.0
	var central_pos = Vector2(480, 360)
	var central_danger = MemoryManager.get_danger_at_location(central_pos, 100.0)
	var central_score = central_dist + (central_danger * 650.0)
	
	# Route 2: North Flank (Bypass A)
	var north_dist: float = 1100.0
	var north_pos = Vector2(580, 200)
	var north_danger = MemoryManager.get_danger_at_location(north_pos, 80.0)
	var is_north_blocked = false
	var dungeon_nodes = get_tree().get_nodes_in_group("dungeon")
	if dungeon_nodes.size() > 0 and dungeon_nodes[0].get("is_north_flank_blocked"):
		is_north_blocked = true
	var north_score = 999999.0 if is_north_blocked else (north_dist + (north_danger * 650.0))
	
	# Route 3: South Flank (Bypass B)
	var south_dist: float = 1100.0
	var south_pos = Vector2(580, 520)
	var south_danger = MemoryManager.get_danger_at_location(south_pos, 80.0)
	var south_score = south_dist + (south_danger * 650.0)
	
	# Determine safest & most efficient path
	if is_north_blocked and chosen_route_name == "North Flank":
		# Was previously heading north, but dungeon shifted!
		has_adapted = true
		if south_score <= central_score:
			chosen_route_name = "South Flank"
			current_waypoints = [
				Vector2(340, 520),
				Vector2(580, 520),
				Vector2(820, 520),
				Vector2(820, 360)
			]
			adaptation_alert_text = "SHIFT DETECTED! REROUTING (SOUTH)"
		else:
			chosen_route_name = "Central Direct"
			current_waypoints = [
				Vector2(580, 360),
				Vector2(820, 360)
			]
			adaptation_alert_text = "SHIFT DETECTED! FORCED CENTRAL"
		adaptation_alert_timer = 4.0
		EventBus.enemy_adapted.emit(self, "Rerouted due to living Dungeon Shift barrier")
	elif central_danger > 0.15 and (north_score < central_score or south_score < central_score):
		# ADAPTATION TRIGGERED: Memory of central danger forces alternative route!
		has_adapted = true
		if north_score <= south_score:
			chosen_route_name = "North Flank"
			current_waypoints = [
				Vector2(340, 200),
				Vector2(580, 200),
				Vector2(820, 200),
				Vector2(820, 360)
			]
			adaptation_alert_text = "ADAPTING: AVOIDING SPIKES! (NORTH)"
		else:
			chosen_route_name = "South Flank"
			current_waypoints = [
				Vector2(340, 520),
				Vector2(580, 520),
				Vector2(820, 520),
				Vector2(820, 360)
			]
			adaptation_alert_text = "ADAPTING: AVOIDING SPIKES! (SOUTH)"
		
		adaptation_alert_timer = 4.0
		EventBus.enemy_adapted.emit(self, "Evading remembered hazard via " + chosen_route_name)
	else:
		# Ignorant or confident: take direct route
		chosen_route_name = "Central Direct"
		current_waypoints = [
			Vector2(580, 360),
			Vector2(820, 360)
		]
	
	_set_next_waypoint()
	ai_state = AIState.MOVE

func _set_next_waypoint() -> void:
	if current_waypoints.size() > 0:
		var wp = current_waypoints.pop_front()
		nav_agent.target_position = wp
	else:
		# Final destination: Dungeon Heart
		if is_instance_valid(target_heart):
			nav_agent.target_position = target_heart.global_position

func _process_move_state(_delta: float) -> void:
	if not is_instance_valid(target_heart):
		find_heart()
		if not is_instance_valid(target_heart):
			return
	
	# Check distance to Heart
	if global_position.distance_to(target_heart.global_position) <= 52.0:
		ai_state = AIState.ATTACK
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
	adaptation_alert_text = "STUNNED!"
	adaptation_alert_timer = duration
	queue_redraw()

func apply_slow(factor: float, duration: float) -> void:
	slow_factor = factor
	slow_timer = max(slow_timer, duration)

func frighten_by_illusion() -> void:
	adaptation_alert_text = "PHANTOM TERROR! AVOIDING ROUTE!"
	adaptation_alert_timer = 3.0
	_evaluate_routes_and_adapt()

func _process_attack_state(delta: float) -> void:
	velocity = Vector2.ZERO
	attack_cooldown -= delta
	if attack_cooldown <= 0.0:
		attack_cooldown = attack_interval
		if target_heart and target_heart.has_method("take_damage"):
			target_heart.take_damage(attack_damage)
			hurt_flash_timer = 0.15
			queue_redraw()

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
	# Base shadow
	draw_ellipse(Vector2(0, 14), 14, 6, Color(0, 0, 0, 0.4))
	
	# Warrior armor color
	var body_color = Color(0.75, 0.2, 0.2, 1.0)
	if hurt_flash_timer > 0:
		body_color = Color(1.0, 1.0, 1.0, 1.0)
	elif has_adapted:
		# Subtle tactical tint when adapting
		body_color = Color(0.85, 0.4, 0.15, 1.0)
	
	var bob = sin(walk_anim_timer) * 2.0 if velocity.length() > 5.0 else 0.0
	
	# Body
	draw_circle(Vector2(0, bob), 14.0, body_color)
	draw_circle(Vector2(0, bob), 14.0, Color(0.2, 0.1, 0.1, 1.0), false, 2.0)
	
	# Helmet
	draw_rect(Rect2(-8, -6 + bob, 16, 7), Color(0.4, 0.42, 0.45, 1.0))
	draw_line(Vector2(-6, -2 + bob), Vector2(6, -2 + bob), Color(0.1, 0.1, 0.1, 1.0), 2.0)
	
	# Weapon
	var sword_dir = velocity.normalized()
	if sword_dir.length() < 0.1:
		sword_dir = Vector2.RIGHT
	draw_line(Vector2(0, bob), Vector2(0, bob) + sword_dir * 18.0, Color(0.85, 0.85, 0.9, 1.0), 3.0)
	
	# Health bar
	var bar_width = 28.0
	var bar_height = 4.0
	var bar_pos = Vector2(-bar_width / 2.0, -22.0 + bob)
	draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color(0.15, 0.15, 0.15, 0.85))
	var hp_ratio = clamp(current_hp / max_hp, 0.0, 1.0)
	var fill_color = Color(0.2, 0.85, 0.3, 1.0)
	if hp_ratio < 0.35:
		fill_color = Color(0.9, 0.2, 0.2, 1.0)
	elif hp_ratio < 0.65:
		fill_color = Color(0.95, 0.75, 0.1, 1.0)
	draw_rect(Rect2(bar_pos, Vector2(bar_width * hp_ratio, bar_height)), fill_color)
	draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color(0, 0, 0, 0.9), false, 1.0)
	
	# Thought bubble / adaptation alert
	if adaptation_alert_timer > 0.0:
		var text_pos = Vector2(-90, -36.0 + bob)
		draw_rect(Rect2(text_pos + Vector2(-4, -14), Vector2(188, 20)), Color(0.1, 0.1, 0.15, 0.9))
		draw_rect(Rect2(text_pos + Vector2(-4, -14), Vector2(188, 20)), Color(1.0, 0.6, 0.2, 0.9), false, 1.5)
		draw_string(ThemeDB.fallback_font, text_pos + Vector2(2, 0), adaptation_alert_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.85, 0.4, 1.0))
