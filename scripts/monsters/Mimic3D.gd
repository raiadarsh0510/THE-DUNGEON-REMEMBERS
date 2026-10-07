extends CharacterBody3D

# Mimic3D: Ambush predator disguised as a treasure chest.
# Mechanics: Dormant chest until invader steps close; snaps open with vicious surprise bite.

@export var max_hp: float = 60.0
@export var current_hp: float = 60.0
@export var attack_damage: float = 28.0
@export var attack_interval: float = 1.1
@export var attack_range: float = 2.4
@export var monster_cost: int = 50
@export var monster_type: String = "Mimic"

@onready var visuals: Node3D = $Visuals
@onready var lid: Node3D = $Visuals/ChestBase/Lid
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var hp_label: Label3D = $Label3D
@onready var eye_light: OmniLight3D = $Visuals/ChestBase/EyeLight

var target_enemy: Node3D = null
var attack_timer: float = 0.0
var is_dead: bool = false
var is_awakened: bool = false

func _ready() -> void:
	current_hp = max_hp
	add_to_group("defenders")
	eye_light.light_energy = 0.0
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
			if not is_awakened:
				awaken()
			look_toward(target_enemy.global_position)
			if attack_timer <= 0.0:
				perform_attack(target_enemy)

func awaken() -> void:
	is_awakened = true
	eye_light.light_energy = 2.5
	AudioManager.play_sfx("trap_spring", 0.0, 0.7) # Surprise snap sound
	if anim_player.has_animation("open"):
		anim_player.play("open")

func _find_nearest_enemy() -> void:
	target_enemy = null
	var min_dist = 6.0
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
	if anim_player.has_animation("bite"):
		anim_player.play("bite")
	AudioManager.play_sfx("boss_roar", 1.0, 1.8) # Snapping maw sound
	
	if is_instance_valid(target_node) and target_node.has_method("take_damage"):
		target_node.take_damage(attack_damage)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	if not is_awakened:
		awaken()
	current_hp -= amount
	update_ui()
	AudioManager.play_sfx("enemy_hit", 0.0, 1.0)
	if current_hp <= 0.0:
		die()

func update_ui() -> void:
	if hp_label:
		hp_label.text = "Mimic: %d/%d" % [max(0, int(current_hp)), int(max_hp)]

func die() -> void:
	if is_dead:
		return
	is_dead = true
	update_ui()
	queue_free()
