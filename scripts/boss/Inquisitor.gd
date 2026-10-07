extends CharacterBody2D

# Inquisitor.gd: The Grand Inquisitor — Climax Boss of "The Dungeon Remembers".
# Dual-phase adaptive general who synthesizes ALL collective memory from
# fallen warriors, rogues, and mages across waves 1-4.
# Features:
# - Collective Memory Synthesis (chooses the route countering player's primary traps)
# - Cleansing Ward (periodically cleanses ailments, resists traps)
# - Vanguard Summoning (arrives with royal guard escorts)
# - Phase 2 Fanatic Rage (triggers at <= 50% HP, massive stat boost & flame aura)

enum BossPhase {
	PHASE_1_COMMANDER,
	PHASE_2_ZEALOT_WRATH
}

enum AIState {
	ENTER,
	EVALUATE,
	MOVE,
	ATTACK,
	DEAD
}

@export var max_hp: float = 400.0
@export var move_speed_phase1: float = 75.0
@export var move_speed_phase2: float = 125.0
@export var attack_damage_phase1: float = 24.0
@export var attack_damage_phase2: float = 38.0
@export var attack_interval_phase1: float = 1.1
@export var attack_interval_phase2: float = 0.75
@export var cleanse_interval: float = 3.5

var current_hp: float = 400.0
var current_phase: BossPhase = BossPhase.PHASE_1_COMMANDER
var ai_state: AIState = AIState.ENTER
var target_heart: Node2D = null
var is_dead: bool = false
var attack_cooldown: float = 0.0
var cleanse_cooldown: float = 2.0

var current_waypoints: Array[Vector2] = []
var chosen_route_name: String = "Central Direct"
var has_adapted: bool = false

var hurt_flash_timer: float = 0.0
var walk_anim_timer: float = 0.0
var cleanse_vfx_timer: float = 0.0
var phase2_burst_timer: float = 0.0
var adaptation_alert_text: String = ""
var adaptation_alert_timer: float = 0.0

var stun_timer: float = 0.0
var slow_timer: float = 0.0
var slow_factor: float = 1.0

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemies")
	add_to_group("boss")
	
	nav_agent.path_desired_distance = 16.0
	nav_agent.target_desired_distance = 44.0
	
	call_deferred("_setup_boss")

func get_enemy_type() -> String:
	return "Inquisitor"

func _setup_boss() -> void:
	await get_tree().physics_frame
	find_heart()
	ai_state = AIState.ENTER
	nav_agent.target_position = Vector2(340, 360)
	EventBus.boss_spawned.emit(self)
	_summon_royal_escorts()

func find_heart() -> void:
	var hearts = get_tree().get_nodes_in_group("dungeon_heart")
	if hearts.size() > 0:
		target_heart = hearts[0]

func _summon_royal_escorts() -> void:
	# Summons 2 vanguard warriors to accompany the boss
	var warrior_scene = load("res://scenes/enemies/Warrior.tscn")
	if not warrior_scene:
		return
	
	var parent_node = get_parent()
	if not parent_node:
		return
	
	for offset in [Vector2(-25, -25), Vector2(-25, 25)]:
		var guard = warrior_scene.instantiate()
		guard.global_position = global_position + offset
		parent_node.call_deferred("add_child", guard)
	
	adaptation_alert_text = "INQUISITOR: \"ADVANCE, MY VANGUARD!\""
	adaptation_alert_timer = 3.5

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	if hurt_flash_timer > 0.0:
		hurt_flash_timer -= delta
		queue_redraw()
	
	if cleanse_vfx_timer > 0.0:
		cleanse_vfx_timer -= delta
		queue_redraw()
		
	if phase2_burst_timer > 0.0:
		phase2_burst_timer -= delta
		queue_redraw()
	
	if adaptation_alert_timer > 0.0:
		adaptation_alert_timer -= delta
		queue_redraw()
	
	# Boss Tenacity: Stuns are reduced to 40% duration
	if stun_timer > 0.0:
		stun_timer -= delta
		velocity = Vector2.ZERO
		queue_redraw()
		return
	
	if slow_timer > 0.0:
		slow_timer -= delta
	
	# Periodic Cleansing Ward
	cleanse_cooldown -= delta
	if cleanse_cooldown <= 0.0:
		cleanse_cooldown = cleanse_interval
		_trigger_cleansing_ward()
	
	walk_anim_timer += delta * (14.0 if current_phase == BossPhase.PHASE_2_ZEALOT_WRATH else 7.0)
	
	match ai_state:
		AIState.ENTER:
			if global_position.x >= 320.0 or nav_agent.is_navigation_finished():
				ai_state = AIState.EVALUATE
			else:
				_move_along_nav()
		AIState.EVALUATE:
			_synthesize_collective_memory_and_route()
		AIState.MOVE:
			_process_move_state(delta)
		AIState.ATTACK:
			_process_attack_state(delta)

func _trigger_cleansing_ward() -> void:
	cleanse_vfx_timer = 0.5
	# Cleanse self
	slow_timer = 0.0
	stun_timer = 0.0
	slow_factor = 1.0
	
	# Disarm / suppress nearby traps
	var traps = get_tree().get_nodes_in_group("traps")
	for t in traps:
		if is_instance_valid(t) and global_position.distance_to(t.global_position) <= 75.0:
			if t.has_method("dispel_illusion"):
				t.dispel_illusion()
	queue_redraw()

func _synthesize_collective_memory_and_route() -> void:
	ai_state = AIState.MOVE
	has_adapted = true
	
	# Evaluate all corridors based on synthesized memory danger
	var central_danger = MemoryManager.get_danger_at_location(Vector2(480, 360), 110.0)
	var north_danger = MemoryManager.get_danger_at_location(Vector2(580, 200), 100.0)
	var south_danger = MemoryManager.get_danger_at_location(Vector2(580, 520), 100.0)
	
	var is_north_blocked = false
	var dungeon_nodes = get_tree().get_nodes_in_group("dungeon")
	if dungeon_nodes.size() > 0 and dungeon_nodes[0].get("is_north_flank_blocked"):
		is_north_blocked = true
	
	# Inquisitor assigns weights: prefers bypassing heaviest traps
	var central_score = 900.0 + (central_danger * 800.0)
	var north_score = 999999.0 if is_north_blocked else (1100.0 + (north_danger * 800.0))
	var south_score = 1100.0 + (south_danger * 800.0)
	
	if north_score <= central_score and north_score <= south_score and not is_north_blocked:
		chosen_route_name = "North Flank"
		current_waypoints = [
			Vector2(340, 200),
			Vector2(580, 200),
			Vector2(820, 200),
			Vector2(820, 360)
		]
		adaptation_alert_text = "INQUISITOR: \"I HAVE READ YOUR TRAPS! MARCH NORTH!\""
	elif south_score < central_score:
		chosen_route_name = "South Flank"
		current_waypoints = [
			Vector2(340, 520),
			Vector2(580, 520),
			Vector2(820, 520),
			Vector2(820, 360)
		]
		adaptation_alert_text = "INQUISITOR: \"THE CODEX WARNS OF CENTRAL PERIL! MARCH SOUTH!\""
	else:
		chosen_route_name = "Central Direct"
		current_waypoints = [
			Vector2(580, 360),
			Vector2(820, 360)
		]
		adaptation_alert_text = "INQUISITOR: \"BREAK THEIR CENTER! THE HEART AWAITS!\""
	
	adaptation_alert_timer = 4.0
	EventBus.enemy_adapted.emit(self, "Boss synthesized memory: chose %s" % chosen_route_name)
	_set_next_waypoint()

func _set_next_waypoint() -> void:
	if current_waypoints.size() > 0:
		var next_wp = current_waypoints.pop_front()
		nav_agent.target_position = next_wp
	elif target_heart:
		nav_agent.target_position = target_heart.global_position

func _process_move_state(_delta: float) -> void:
	if not target_heart:
		find_heart()
		if not target_heart:
			velocity = Vector2.ZERO
			return
	
	# Distance to Heart
	if global_position.distance_to(target_heart.global_position) <= 58.0:
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
	var base_speed = move_speed_phase2 if current_phase == BossPhase.PHASE_2_ZEALOT_WRATH else move_speed_phase1
	var current_speed = base_speed * (slow_factor if slow_timer > 0.0 else 1.0)
	velocity = dir * current_speed
	move_and_slide()
	queue_redraw()

func _process_attack_state(delta: float) -> void:
	velocity = Vector2.ZERO
	attack_cooldown -= delta
	if attack_cooldown <= 0.0:
		var interval = attack_interval_phase2 if current_phase == BossPhase.PHASE_2_ZEALOT_WRATH else attack_interval_phase1
		var dmg = attack_damage_phase2 if current_phase == BossPhase.PHASE_2_ZEALOT_WRATH else attack_damage_phase1
		attack_cooldown = interval
		if target_heart and target_heart.has_method("take_damage"):
			target_heart.take_damage(dmg)
			hurt_flash_timer = 0.15
			queue_redraw()

func take_damage(amount: float) -> void:
	if is_dead:
		return
	
	# Boss Ward: reduces trap / environment damage by 35%
	var incoming = amount * 0.75 if current_phase == BossPhase.PHASE_1_COMMANDER else amount
	current_hp -= incoming
	hurt_flash_timer = 0.2
	
	EventBus.boss_damaged.emit(current_hp, max_hp)
	EventBus.enemy_damaged.emit(self, incoming, current_hp)
	queue_redraw()
	
	# Phase 2 Transition Check (<= 50% HP)
	if current_phase == BossPhase.PHASE_1_COMMANDER and current_hp <= (max_hp * 0.5):
		_trigger_phase_2_transition()
	
	if current_hp <= 0:
		die()

func _trigger_phase_2_transition() -> void:
	current_phase = BossPhase.PHASE_2_ZEALOT_WRATH
	phase2_burst_timer = 1.0
	cleanse_cooldown = 0.0
	_trigger_cleansing_ward()
	
	adaptation_alert_text = "PHASE 2: ZEALOT'S WRATH! \"PURGE THE HEART WITH HOLY FIRE!\""
	adaptation_alert_timer = 5.0
	EventBus.boss_phase_changed.emit(2)
	queue_redraw()

func apply_stun(duration: float) -> void:
	# Tenacity: Stuns are heavily diminished on the Inquisitor
	stun_timer = max(stun_timer, duration * 0.35)
	velocity = Vector2.ZERO
	queue_redraw()

func apply_slow(factor: float, duration: float) -> void:
	slow_factor = lerp(factor, 1.0, 0.5) # Resists 50% of slow
	slow_timer = max(slow_timer, duration * 0.5)

func dispel_illusion() -> void:
	adaptation_alert_text = "INQUISITOR: \"YOUR ILLUSIONS ARE NOTHING BEFORE THE LIGHT!\""
	adaptation_alert_timer = 3.5

func die() -> void:
	if is_dead:
		return
	is_dead = true
	ai_state = AIState.DEAD
	EventBus.boss_defeated.emit()
	EventBus.enemy_died.emit(self)
	queue_free()

func _draw() -> void:
	# Base ground shadow
	draw_ellipse(Vector2(0, 14), 18, 7, Color(0, 0, 0, 0.6))
	
	var is_p2 = (current_phase == BossPhase.PHASE_2_ZEALOT_WRATH)
	var bob = sin(walk_anim_timer) * 2.0 if velocity.length() > 5.0 else 0.0
	
	# Phase 2 Aura (Blazing Crimson/Gold fire)
	if is_p2:
		var p2_pulse = sin(walk_anim_timer * 2.0) * 4.0
		draw_circle(Vector2(0, bob), 26.0 + p2_pulse, Color(0.9, 0.2, 0.1, 0.25))
		draw_arc(Vector2(0, bob), 28.0 + p2_pulse, 0, TAU, 32, Color(1.0, 0.6, 0.1, 0.6), 2.5)
	
	# Cleansing Ward pulse effect
	if cleanse_vfx_timer > 0.0:
		var ward_radius = lerp(80.0, 15.0, cleanse_vfx_timer / 0.5)
		draw_arc(Vector2.ZERO, ward_radius, 0, TAU, 32, Color(1.0, 0.9, 0.3, cleanse_vfx_timer * 2.0), 3.0)
	
	# Flowing Cape
	var cape_col = Color(0.85, 0.15, 0.15) if is_p2 else Color(0.6, 0.1, 0.15)
	draw_line(Vector2(-12, -8 + bob), Vector2(-16, 16 + bob), cape_col, 5.0)
	draw_line(Vector2(12, -8 + bob), Vector2(16, 16 + bob), cape_col, 5.0)
	
	# Body / Golden Heavy Plate Armor
	var armor_col = Color(0.95, 0.8, 0.3) if is_p2 else Color(0.85, 0.72, 0.25)
	if hurt_flash_timer > 0.0:
		armor_col = Color(1.0, 1.0, 1.0)
	
	draw_circle(Vector2(0, bob), 16.0, armor_col)
	draw_circle(Vector2(0, bob), 16.0, Color(0.3, 0.2, 0.05), false, 2.0)
	
	# Holy Inquisitorial Cross on Breastplate
	var cross_col = Color(0.9, 0.15, 0.15) if is_p2 else Color(0.2, 0.1, 0.3)
	draw_line(Vector2(0, -6 + bob), Vector2(0, 8 + bob), cross_col, 3.0)
	draw_line(Vector2(-5, -1 + bob), Vector2(5, -1 + bob), cross_col, 3.0)
	
	# Helmet / Visor
	draw_circle(Vector2(0, -10 + bob), 9.0, Color(0.8, 0.7, 0.3))
	draw_line(Vector2(-6, -11 + bob), Vector2(6, -11 + bob), Color(0.1, 0.1, 0.1), 2.5)
	
	# Radiant Halo
	var halo_col = Color(1.0, 0.3, 0.2) if is_p2 else Color(1.0, 0.9, 0.4)
	draw_arc(Vector2(0, -22 + bob), 8.0, 0, TAU, 16, halo_col, 2.0)
	
	# Halberd / Hammer
	var dir = velocity.normalized() if velocity.length() > 0.1 else Vector2.RIGHT
	var weapon_pos = Vector2(0, bob) + dir * 22.0
	draw_line(Vector2(0, bob), weapon_pos, Color(0.6, 0.5, 0.3), 3.0)
	draw_rect(Rect2(weapon_pos - Vector2(4, 8), Vector2(8, 16)), Color(0.9, 0.8, 0.4))
	
	# Boss Overhead Health Bar
	var bar_width = 46.0
	var bar_pos = Vector2(-bar_width / 2.0, -34.0 + bob)
	draw_rect(Rect2(bar_pos, Vector2(bar_width, 5.0)), Color(0.1, 0.1, 0.12, 0.9))
	var fill_col = Color(0.95, 0.25, 0.15) if is_p2 else Color(0.9, 0.75, 0.2)
	draw_rect(Rect2(bar_pos, Vector2(bar_width * (current_hp / max_hp), 5.0)), fill_col)
	draw_rect(Rect2(bar_pos, Vector2(bar_width, 5.0)), Color(0.8, 0.7, 0.3), false, 1.0)
	
	# Adaptation / Battle Cry Thought Bubble
	if adaptation_alert_timer > 0.0 and adaptation_alert_text != "":
		var bubble_pos = Vector2(0, -48.0 + bob)
		var text_col = Color(1.0, 0.4, 0.3) if is_p2 else Color(1.0, 0.9, 0.4)
		draw_rect(Rect2(bubble_pos - Vector2(110, 10), Vector2(220, 20)), Color(0.08, 0.08, 0.1, 0.92))
		draw_rect(Rect2(bubble_pos - Vector2(110, 10), Vector2(220, 20)), text_col, false, 1.5)
		draw_string(ThemeDB.fallback_font, bubble_pos + Vector2(0, 4), adaptation_alert_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, text_col)
