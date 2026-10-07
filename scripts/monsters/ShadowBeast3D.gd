extends CharacterBody3D

# ShadowBeast3D: Void predator heavy defender.
# Visual: Obsidian quadruped with glowing violet eyes.
# AI: Aggressive interceptor that hunts invaders in corridors.

@export var max_hp: float = 80.0
@export var current_hp: float = 80.0
@export var move_speed: float = 4.2
@export var attack_damage: float = 18.0
@export var attack_interval: float = 1.0
@export var attack_range: float = 2.4
@export var monster_cost: int = 60
@export var monster_type: String = "Shadow Beast"

@onready var visuals: Node3D = $Visuals
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var hp_label: Label3D = $Label3D

var target_enemy: Node3D = null
var attack_timer: float = 0.0
var is_dead: bool = false

func _ready() -> void:
	current_hp = max_hp
	add_to_group("defenders")
	update_ui()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	if attack_timer > 0.0:
		attack_timer -= delta

	_find_nearest_enemy()

	if is_instance_valid(target_enemy):
		var dist = global_position.distance_to(target_enemy.global_position)
		if dist <= attack_range:
			velocity = Vector3.ZERO
			look_toward(target_enemy.global_position)
			if attack_timer <= 0.0:
				perform_attack(target_enemy)
			return
		else:
			var dir = (target_enemy.global_position - global_position)
			dir.y = 0.0
			if dir.length() > 0.1:
				dir = dir.normalized()
				velocity.x = dir.x * move_speed
				velocity.z = dir.z * move_speed
				look_toward(global_position + dir)
				if anim_player.has_animation("walk") and not anim_player.is_playing():
					anim_player.play("walk")
			else:
				velocity = Vector3.ZERO
	else:
		velocity = Vector3.ZERO
		if anim_player.has_animation("idle") and not anim_player.is_playing():
			anim_player.play("idle")

	move_and_slide()

func _find_nearest_enemy() -> void:
	target_enemy = null
	var min_dist = 16.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			var d = global_position.distance_to(enemy.global_position)
			if d < min_dist:
				min_dist = d
				target_enemy = enemy

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
	AudioManager.play_sfx("boss_roar", -2.0, 1.3)
	
	if is_instance_valid(target_node) and target_node.has_method("take_damage"):
		target_node.take_damage(attack_damage)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_hp -= amount
	update_ui()
	AudioManager.play_sfx("enemy_hit", 0.0, 0.8)
	if current_hp <= 0.0:
		die()

func update_ui() -> void:
	if hp_label:
		hp_label.text = "Shadow Beast: %d/%d" % [max(0, int(current_hp)), int(max_hp)]

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector3.ZERO
	update_ui()
	queue_free()
