extends Node3D

# FXManager3D: Central visual effects and game feel coordinator.
# Handles 3D floating damage numbers, impact particle bursts, screen shake, and hit-stop.

@export var damage_number_scene: PackedScene = preload("res://scenes/vfx/DamageNumber3D.tscn")
@export var impact_sparks_scene: PackedScene = preload("res://scenes/vfx/ImpactSparks3D.tscn")

var camera_controller: Node3D = null

func _ready() -> void:
	add_to_group("fx_manager")
	call_deferred("_setup_connections")

func _setup_connections() -> void:
	camera_controller = get_tree().get_first_node_in_group("dungeon_camera")
	if camera_controller == null:
		# Fallback: look for DungeonCamera3D
		camera_controller = get_parent().get_node_or_null("DungeonCamera3D")
		
	EventBus.enemy_damaged.connect(_on_enemy_damaged)
	EventBus.heart_damaged.connect(_on_heart_damaged)
	EventBus.trap_triggered.connect(_on_trap_triggered)
	EventBus.dungeon_shifted.connect(func(is_s): if is_s: trigger_camera_shake(0.5, 0.35))
	EventBus.boss_spawned.connect(func(_b): trigger_camera_shake(0.8, 0.5))

func _on_enemy_damaged(enemy: Node, amount: float, _curr_hp: float) -> void:
	if not is_instance_valid(enemy):
		return
	var pos = enemy.global_position if "global_position" in enemy else Vector3.ZERO
	spawn_damage_number(amount, pos + Vector3(randf_range(-0.3, 0.3), 1.5, randf_range(-0.3, 0.3)))
	spawn_impact_sparks(pos + Vector3(0, 1.0, 0))
	
	if amount >= 30.0:
		trigger_hit_stop(0.04)
		trigger_camera_shake(0.35, 0.2)

func _on_heart_damaged(_curr: float, _max: float, dmg: float) -> void:
	trigger_camera_shake(clamp(dmg * 0.12, 0.3, 1.2), 0.35)
	trigger_hit_stop(0.05)

func _on_trap_triggered(trap_type: String, pos: Variant, _target: Node) -> void:
	if trap_type in ["Falling Rock", "rock"]:
		trigger_camera_shake(0.7, 0.4)
		trigger_hit_stop(0.05)
		if pos is Vector3:
			spawn_impact_sparks(pos + Vector3(0, 0.5, 0))

func spawn_damage_number(amount: float, pos: Vector3, is_crit: bool = false, col: Color = Color.WHITE) -> Node3D:
	if damage_number_scene:
		var dmg_node = damage_number_scene.instantiate()
		dmg_node.position = pos
		add_child(dmg_node)
		if dmg_node.has_method("setup"):
			dmg_node.setup(amount, is_crit, col)
		return dmg_node
	return null

func spawn_impact_sparks(pos: Vector3) -> Node3D:
	if impact_sparks_scene:
		var sparks = impact_sparks_scene.instantiate()
		sparks.position = pos
		add_child(sparks)
		return sparks
	return null

func trigger_camera_shake(intensity: float, duration: float) -> void:
	if not camera_controller:
		camera_controller = get_tree().get_first_node_in_group("dungeon_camera")
	if camera_controller and camera_controller.has_method("trigger_shake"):
		camera_controller.trigger_shake(intensity, duration)

func trigger_hit_stop(duration_sec: float = 0.04) -> void:
	# Subtle frame freeze on high impact
	Engine.time_scale = 0.05
	var timer = get_tree().create_timer(duration_sec, true, false, true)
	timer.timeout.connect(func():
		Engine.time_scale = 1.0
	)
