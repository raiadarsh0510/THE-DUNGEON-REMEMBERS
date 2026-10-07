extends CharacterBody3D

# Alden Voss — Warrior (3D Invader with Memory & Adaptation)
# Visual: Blackened steel plate armor, brass trim, crimson cape, notched greatsword.
# AI: Utility Route Scoring with Dynamic Memory Adaptation.

const AdaptationSystem = preload("res://scripts/memory/AdaptationSystem.gd")

@export var max_hp: float = 70.0
@export var current_hp: float = 70.0
@export var move_speed: float = 4.2
@export var attack_damage: float = 14.0
@export var attack_interval: float = 1.2
@export var attack_range: float = 2.6
@export var gold_bounty: int = 25
@export var enemy_type: String = "Warrior"

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var visuals: Node3D = $Visuals
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var hp_label: Label3D = $Label3D

var target_heart: Node3D = null
var target_defender: Node3D = null
var attack_timer: float = 0.0
var is_dead: bool = false
var is_attacking: bool = false
var is_nav_ready: bool = false
var base_move_speed: float = 4.2

# Status effects
var slow_timer: float = 0.0
var stun_timer: float = 0.0
var poison_timer: float = 0.0
var poison_dps: float = 0.0

# Route navigation & Adaptation state
var selected_route_name: String = "Central"
var route_waypoints: Array = []
var waypoint_index: int = 0
var has_evaluated_adaptation: bool = false
var has_adapted: bool = false
var adaptation_alert_label: Label3D = null

func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemies")
	EventBus.enemy_spawned.emit(self)
	EventBus.dungeon_shifted.connect(_on_dungeon_shifted)
	update_ui()
	_create_adaptation_label()
	call_deferred("_setup_navigation")

func _on_dungeon_shifted(is_shifted: bool) -> void:
	if is_dead:
		return
	if is_shifted and selected_route_name == "WestFlank":
		evaluate_and_choose_route()
		if adaptation_alert_label:
			adaptation_alert_label.text = "[!] SHIFT DETECTED! REROUTING [%s]" % selected_route_name.to_upper()
			adaptation_alert_label.visible = true
			adaptation_alert_label.modulate = Color(1.0, 0.4, 0.2, 1.0)
			var tw = create_tween()
			tw.tween_property(adaptation_alert_label, "position:y", 3.4, 1.5)
			tw.parallel().tween_property(adaptation_alert_label, "modulate:a", 0.0, 1.8)

func get_enemy_type() -> String:
	return enemy_type

func _create_adaptation_label() -> void:
	adaptation_alert_label = Label3D.new()
	adaptation_alert_label.position = Vector3(0.0, 2.9, 0.0)
	adaptation_alert_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	adaptation_alert_label.font_size = 26
	adaptation_alert_label.outline_size = 6
	adaptation_alert_label.modulate = Color(1.0, 0.85, 0.2, 1.0) # Bright warning gold
	adaptation_alert_label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	adaptation_alert_label.visible = false
	add_child(adaptation_alert_label)

func _setup_navigation() -> void:
	target_heart = get_tree().get_first_node_in_group("dungeon_heart")
	evaluate_and_choose_route()
	is_nav_ready = true

func evaluate_and_choose_route() -> void:
	var dungeon = get_tree().get_first_node_in_group("dungeon")
	if dungeon == null:
		# Fallback to parent or find Dungeon3D
		dungeon = get_parent().get_parent()
		
	var available_routes = {}
	if dungeon and dungeon.has_method("get_routes_to_heart"):
		available_routes = dungeon.get_routes_to_heart()
	else:
		var target_pos = target_heart.global_position if target_heart else Vector3(0, 0, -12)
		available_routes = {
			"Central": [global_position, Vector3(0, 0, 10.5), Vector3(0, 0, 3), target_pos],
			"WestFlank": [global_position, Vector3(0, 0, 10.5), Vector3(-7, 0, 10.5), Vector3(-7, 0, 3), target_pos]
		}
	
	# Query AdaptationSystem based on MemoryManager knowledge
	var decision = AdaptationSystem.select_route(available_routes, enemy_type)
	selected_route_name = decision.get("route_name", "Central")
	route_waypoints = decision.get("waypoints", [])
	waypoint_index = 0
	
	if decision.get("memory_influenced", false):
		trigger_memory_adaptation(decision)
	else:
		if route_waypoints.size() > 0:
			nav_agent.target_position = route_waypoints[0]
		elif target_heart:
			nav_agent.target_position = target_heart.global_position

func trigger_memory_adaptation(decision: Dictionary) -> void:
	has_adapted = true
	var reason = decision.get("adaptation_reason", "Avoiding remembered Spike Trap")
	MemoryManager.record_adaptation_decision(self, decision)
	
	# Show overhead adaptation alert
	if adaptation_alert_label:
		adaptation_alert_label.text = "[!] ADAPTING: AVOIDING SPIKES! [%s]" % selected_route_name.to_upper()
		adaptation_alert_label.visible = true
		var tw = create_tween()
		tw.tween_property(adaptation_alert_label, "position:y", 3.4, 1.5)
		tw.parallel().tween_property(adaptation_alert_label, "modulate:a", 0.0, 1.8)
	
	# Advance navigation target along adapted route
	if route_waypoints.size() > 0:
		nav_agent.target_position = route_waypoints[0]

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
			move_speed = base_move_speed
			
	if poison_timer > 0.0:
		poison_timer -= delta
		take_damage(poison_dps * delta)
		if is_dead:
			return

	if attack_timer > 0.0:
		attack_timer -= delta

	# Check for nearby defenders
	_find_nearest_defender()

	var combat_target = target_defender if is_instance_valid(target_defender) else target_heart
	if is_instance_valid(combat_target):
		var dist = global_position.distance_to(combat_target.global_position)
		if dist <= attack_range:
			velocity = Vector3.ZERO
			is_attacking = true
			look_toward(combat_target.global_position)
			if attack_timer <= 0.0:
				perform_attack(combat_target)
			return

	is_attacking = false

	if not is_nav_ready:
		return

	# Sequential waypoint progression
	if route_waypoints.size() > 0 and waypoint_index < route_waypoints.size():
		var wp = route_waypoints[waypoint_index]
		if global_position.distance_to(wp) < 1.4:
			waypoint_index += 1
			if waypoint_index < route_waypoints.size():
				nav_agent.target_position = route_waypoints[waypoint_index]
			else:
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

func look_toward(target_pos: Vector3) -> void:
	var look_target = target_pos
	look_target.y = global_position.y
	if global_position.distance_to(look_target) > 0.1:
		visuals.look_at(look_target, Vector3.UP)
		visuals.rotate_y(PI)

func _find_nearest_defender() -> void:
	target_defender = null
	var min_dist = 4.0
	for def in get_tree().get_nodes_in_group("defenders"):
		if is_instance_valid(def) and not def.get("is_dead"):
			var d = global_position.distance_to(def.global_position)
			if d < min_dist:
				min_dist = d
				target_defender = def

func perform_attack(target_node: Node = null) -> void:
	attack_timer = attack_interval
	if anim_player.has_animation("attack"):
		anim_player.play("attack")
	AudioManager.play_sfx("minion_attack", 1.0, 0.9)
	
	var combat_tgt = target_node if is_instance_valid(target_node) else (target_defender if is_instance_valid(target_defender) else target_heart)
	if is_instance_valid(combat_tgt) and combat_tgt.has_method("take_damage"):
		combat_tgt.take_damage(attack_damage)

func apply_slow(factor: float, duration: float) -> void:
	slow_timer = duration
	move_speed = base_move_speed * factor

func apply_poison(dps: float, duration: float) -> void:
	poison_dps = dps
	poison_timer = duration

func apply_stun(duration: float) -> void:
	stun_timer = duration
	velocity = Vector3.ZERO

func take_damage(amount: float) -> void:
	if is_dead:
		return
		
	current_hp -= amount
	update_ui()
	AudioManager.play_sfx("enemy_hit", 0.0, 1.1)
	EventBus.enemy_damaged.emit(self, amount, current_hp)
	flash_hit()
	
	if current_hp <= 0.0:
		die()

func flash_hit() -> void:
	var mesh = $Visuals/Torso as MeshInstance3D
	if mesh:
		var mat = mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			var orig = mat.emission
			mat.emission = Color(1.0, 0.2, 0.2)
			mat.emission_enabled = true
			get_tree().create_timer(0.08).timeout.connect(func():
				if is_instance_valid(mat):
					mat.emission = orig
			)

func update_ui() -> void:
	if hp_label:
		hp_label.text = "%s: %d/%d" % [enemy_type, max(0, int(current_hp)), int(max_hp)]

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector3.ZERO
	update_ui()
	EventBus.enemy_died.emit(self)
	
	if anim_player.has_animation("death"):
		anim_player.play("death")
		await anim_player.animation_finished
	else:
		var tw = create_tween()
		tw.tween_property(visuals, "scale", Vector3.ZERO, 0.25)
		await tw.finished
		
	queue_free()
