extends CharacterBody3D

# Inquisitor3D: The Grand Inquisitor / Dungeon Breaker (Wave 5 Climax Boss)
# Core Innovation: Collective Memory Synthesis & Counter-Adaptation
# Features:
# - Player Tendency Analysis: Counter-adapts to player's most-used trap with heavy damage resistance
# - Siege Breaker: Demolishes raised Living Shift barriers with his colossal warhammer
# - Phase 2 Zealot Wrath (triggered at <= 50% HP): Flaming holy aura, increased speed and damage
# - Tenacity & Cleansing: Reduces stuns and cleanses debuffs

const AdaptationSystem = preload("res://scripts/memory/AdaptationSystem.gd")

enum BossPhase {
	PHASE_1_COMMANDER,
	PHASE_2_ZEALOT_WRATH
}

@export var max_hp: float = 300.0
@export var current_hp: float = 300.0
@export var move_speed_p1: float = 3.6
@export var move_speed_p2: float = 5.2
@export var attack_damage_p1: float = 28.0
@export var attack_damage_p2: float = 42.0
@export var attack_interval_p1: float = 1.2
@export var attack_interval_p2: float = 0.8
@export var attack_range: float = 3.0
@export var gold_bounty: int = 150
@export var enemy_type: String = "Inquisitor"

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var visuals: Node3D = $Visuals
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var hp_label: Label3D = $Label3D
@onready var hammer_light: OmniLight3D = $Visuals/Torso/ArmR/Hammer/HammerLight
@onready var aura_light: OmniLight3D = $Visuals/AuraLight

var current_phase: BossPhase = BossPhase.PHASE_1_COMMANDER
var move_speed: float = 3.6
var attack_damage: float = 28.0
var attack_interval: float = 1.2
var target_heart: Node3D = null
var target_defender: Node3D = null
var attack_timer: float = 0.0
var is_dead: bool = false
var is_nav_ready: bool = false

# Status effect timers (with Tenacity reduction)
var slow_timer: float = 0.0
var stun_timer: float = 0.0
var poison_timer: float = 0.0
var poison_dps: float = 0.0

# Counter-adaptation profile
var adaptive_immunity: String = "SPIKE" # SPIKE, ROCK, POISON, ILLUSION
var adaptation_quote: String = ""
var selected_route_name: String = "Central"
var route_waypoints: Array = []
var waypoint_index: int = 0
var has_shattered_barrier: bool = false

var adaptation_label: Label3D = null

func _ready() -> void:
	current_hp = max_hp
	move_speed = move_speed_p1
	attack_damage = attack_damage_p1
	attack_interval = attack_interval_p1
	
	add_to_group("enemies")
	add_to_group("boss")
	EventBus.enemy_spawned.emit(self)
	EventBus.boss_spawned.emit(self)
	
	_create_adaptation_label()
	_analyze_player_tendencies()
	update_ui()
	call_deferred("_setup_navigation")

func get_enemy_type() -> String:
	return enemy_type

func _create_adaptation_label() -> void:
	adaptation_label = Label3D.new()
	adaptation_label.position = Vector3(0.0, 3.4, 0.0)
	adaptation_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	adaptation_label.font_size = 26
	adaptation_label.outline_size = 8
	adaptation_label.modulate = Color(1.0, 0.85, 0.2, 1.0)
	adaptation_label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	add_child(adaptation_label)

func _analyze_player_tendencies() -> void:
	var profile = MemoryManager.get_player_tendency_profile()
	adaptive_immunity = profile.get("primary_trap", "SPIKE")
	
	match adaptive_immunity:
		"ROCK":
			adaptation_quote = "IMMUNITY: CRUSHING BOULDER RESISTANCE (-75%)"
			adaptation_label.text = "[!] INQUISITOR: \"YOUR FALLING STONES CANNOT CRUSH ME!\""
		"POISON":
			adaptation_quote = "IMMUNITY: VENOM PURGE (IMMUNE TO POISON & SLOW)"
			adaptation_label.text = "[!] INQUISITOR: \"HOLY LIGHT PURGES YOUR VILE POISONS!\""
		"ILLUSION":
			adaptation_quote = "IMMUNITY: TRUE SIGHT (IMMUNE TO ILLUSIONS)"
			adaptation_label.text = "[!] INQUISITOR: \"YOUR PHANTOM CHESTS CANNOT FOOL ME!\""
		_:
			adaptive_immunity = "SPIKE"
			adaptation_quote = "IMMUNITY: IMPALEMENT PLATING (-75% SPIKE DAMAGE)"
			adaptation_label.text = "[!] INQUISITOR: \"YOUR SPIKES BEND AGAINST MY GOLDEN ARMOR!\""
			
	adaptation_label.visible = true

func _setup_navigation() -> void:
	target_heart = get_tree().get_first_node_in_group("dungeon_heart")
	var dungeon = get_tree().get_first_node_in_group("dungeon")
	if dungeon and dungeon.has_method("get_routes_to_heart"):
		var routes = dungeon.get_routes_to_heart()
		selected_route_name = "Central"
		route_waypoints = routes.get("Central", [])
	is_nav_ready = true

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	# Status timers
	if stun_timer > 0.0:
		stun_timer -= delta
		velocity = Vector3.ZERO
		return
		
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			move_speed = move_speed_p2 if current_phase == BossPhase.PHASE_2_ZEALOT_WRATH else move_speed_p1
			
	if poison_timer > 0.0:
		poison_timer -= delta
		if adaptive_immunity != "POISON":
			take_damage(poison_dps * delta)
		if is_dead:
			return

	if attack_timer > 0.0:
		attack_timer -= delta

	# Check for raised barriers in front of boss to shatter
	_check_for_barrier_slam()

	# Check for nearby defenders
	_find_nearest_defender()

	var combat_target = target_defender if is_instance_valid(target_defender) else target_heart
	if is_instance_valid(combat_target):
		var dist = global_position.distance_to(combat_target.global_position)
		if dist <= attack_range:
			velocity = Vector3.ZERO
			look_toward(combat_target.global_position)
			if attack_timer <= 0.0:
				perform_attack(combat_target)
			return

	if not is_nav_ready:
		return

	# Sequential waypoint progression
	if route_waypoints.size() > 0 and waypoint_index < route_waypoints.size():
		var wp = route_waypoints[waypoint_index]
		if global_position.distance_to(wp) < 1.6:
			waypoint_index += 1
			if waypoint_index < route_waypoints.size():
				nav_agent.target_position = route_waypoints[waypoint_index]
			elif target_heart:
				nav_agent.target_position = target_heart.global_position
	elif target_heart:
		nav_agent.target_position = target_heart.global_position

	var next_path_pos = nav_agent.get_next_path_position()
	var move_dir = (next_path_pos - global_position)
	move_dir.y = 0.0
	
	if move_dir.length() > 0.15:
		move_dir = move_dir.normalized()
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
		look_toward(global_position + move_dir)
		if anim_player.has_animation("walk") and not anim_player.is_playing():
			anim_player.play("walk")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if anim_player.has_animation("idle") and not anim_player.is_playing():
			anim_player.play("idle")

	move_and_slide()

func _check_for_barrier_slam() -> void:
	for barrier in get_tree().get_nodes_in_group("dungeon_shift_barrier"):
		if is_instance_valid(barrier) and barrier.get("is_active"):
			var dist = global_position.distance_to(barrier.global_position)
			if dist <= 4.0:
				shatter_barrier(barrier)

func shatter_barrier(barrier: Node) -> void:
	has_shattered_barrier = true
	AudioManager.play_sfx("boss_roar", 2.0, 0.8) # Earth-shattering slam sound
	AudioManager.play_sfx("heart_damage", 2.0, 0.6)
	
	if anim_player.has_animation("attack"):
		anim_player.play("attack")
		
	if barrier.has_method("deactivate_barrier"):
		barrier.deactivate_barrier()
		
	var dungeon = get_tree().get_first_node_in_group("dungeon")
	if dungeon and "is_dungeon_shifted" in dungeon:
		dungeon.is_dungeon_shifted = false
		EventBus.dungeon_shifted.emit(false)
		
	if adaptation_label:
		adaptation_label.text = "[!] SIEGE BREAKER: SHIFT BARRIER DEMOLISHED!"
		adaptation_label.modulate = Color(1.0, 0.3, 0.2, 1.0)

func _find_nearest_defender() -> void:
	target_defender = null
	var min_dist = 5.0
	for def in get_tree().get_nodes_in_group("defenders"):
		if is_instance_valid(def) and not def.get("is_dead"):
			var d = global_position.distance_to(def.global_position)
			if d < min_dist:
				min_dist = d
				target_defender = def

func look_toward(target_pos: Vector3) -> void:
	var look_target = target_pos
	look_target.y = global_position.y
	if global_position.distance_to(look_target) > 0.1:
		visuals.look_at(look_target, Vector3.UP)
		visuals.rotate_y(PI)

func perform_attack(target_node: Node) -> void:
	attack_timer = attack_interval
	if anim_player.has_animation("attack"):
		anim_player.play("attack")
	AudioManager.play_sfx("boss_roar", 1.0, 1.0)
	
	if is_instance_valid(target_node) and target_node.has_method("take_damage"):
		target_node.take_damage(attack_damage)

func apply_slow(factor: float, duration: float) -> void:
	if adaptive_immunity == "POISON":
		return # Immune to venom slow
	slow_timer = duration * 0.5 # Boss tenacity
	move_speed = (move_speed_p2 if current_phase == BossPhase.PHASE_2_ZEALOT_WRATH else move_speed_p1) * factor

func apply_poison(dps: float, duration: float) -> void:
	if adaptive_immunity == "POISON":
		return # Immune
	poison_dps = dps
	poison_timer = duration * 0.5

func apply_stun(duration: float) -> void:
	if adaptive_immunity == "ILLUSION":
		return # Immune
	stun_timer = duration * 0.3 # 70% stun reduction

func take_damage(amount: float, source_type: String = "") -> void:
	if is_dead:
		return
		
	var final_dmg = amount
	var st = source_type.to_upper()
	if st == "UNADAPTED" or st == "DEFENDER" or st == "SECONDARY":
		final_dmg = amount
	elif adaptive_immunity == "SPIKE" and (st == "SPIKE" or st == ""):
		final_dmg = amount * 0.25
	elif adaptive_immunity == "ROCK" and (st == "ROCK"):
		final_dmg = amount * 0.25

	current_hp -= final_dmg
	update_ui()
	AudioManager.play_sfx("enemy_hit", 0.0, 0.7)
	EventBus.boss_damaged.emit(current_hp, max_hp)
	EventBus.enemy_damaged.emit(self, final_dmg, current_hp)
	
	# Check Phase 2 transition (<= 50% HP)
	if current_phase == BossPhase.PHASE_1_COMMANDER and current_hp <= (max_hp * 0.5):
		_transition_to_phase2()

	if current_hp <= 0.0:
		die()

func _transition_to_phase2() -> void:
	current_phase = BossPhase.PHASE_2_ZEALOT_WRATH
	move_speed = move_speed_p2
	attack_damage = attack_damage_p2
	attack_interval = attack_interval_p2
	
	AudioManager.play_sfx("boss_roar", 3.0, 0.9)
	if aura_light:
		aura_light.light_color = Color(1.0, 0.4, 0.1, 1.0)
		aura_light.light_energy = 4.0
	if hammer_light:
		hammer_light.light_color = Color(1.0, 0.2, 0.1, 1.0)
		hammer_light.light_energy = 5.0
		
	if adaptation_label:
		adaptation_label.text = "[!] PHASE 2: FANATIC WRATH! \"PURGE THE HEART!\""
		adaptation_label.modulate = Color(1.0, 0.2, 0.1, 1.0)

func update_ui() -> void:
	if hp_label:
		var phase_name = "COMMANDER" if current_phase == BossPhase.PHASE_1_COMMANDER else "ZEALOT WRATH"
		hp_label.text = "THE GRAND INQUISITOR [%s]: %d/%d\n%s" % [phase_name, max(0, int(current_hp)), int(max_hp), adaptation_quote]

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector3.ZERO
	update_ui()
	EventBus.boss_defeated.emit()
	EventBus.enemy_died.emit(self)
	queue_free()
