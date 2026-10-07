extends Area3D

# DungeonHeart3D represents the conscious core of the living dungeon.
# Visual: Obsidian crystalline monolith with glowing ruby core and pulsating roots.
# Gameplay: Health pool, Heart Energy, and primary player loss condition.

@export var max_hp: float = 100.0
@export var current_hp: float = 100.0
@export var max_energy: float = 100.0
@export var current_energy: float = 100.0

@onready var core_mesh: MeshInstance3D = $Visuals/CoreMesh
@onready var monolith_mesh: MeshInstance3D = $Visuals/MonolithMesh
@onready var pulse_light: OmniLight3D = $PulseLight
@onready var hp_label: Label3D = $Label3D

var pulse_time: float = 0.0
var base_light_energy: float = 2.5
var is_destroyed: bool = false

func _ready() -> void:
	current_hp = max_hp
	current_energy = max_energy
	add_to_group("dungeon_heart")
	update_ui()

func _process(delta: float) -> void:
	if is_destroyed:
		return
	
	# Rhythmic organic living pulse (faster when HP is lower)
	var pulse_speed = 3.0 + (1.0 - (current_hp / max_hp)) * 3.5
	pulse_time += delta * pulse_speed
	
	var pulse_factor = (sin(pulse_time) + 1.0) * 0.5 # 0.0 to 1.0
	
	# Scale pulsing
	var scale_val = 1.0 + pulse_factor * 0.08
	core_mesh.scale = Vector3(scale_val, scale_val, scale_val)
	
	# Light and emission pulsing
	pulse_light.light_energy = base_light_energy + pulse_factor * 2.2
	
	# Slow rotation of crystalline monolith
	monolith_mesh.rotate_y(delta * 0.35)

func take_damage(amount: float) -> void:
	if is_destroyed:
		return
		
	current_hp = max(0.0, current_hp - amount)
	update_ui()
	
	# Trigger sound and event bus
	AudioManager.play_sfx("heartbeat", -2.0, 1.3)
	EventBus.heart_damaged.emit(current_hp, max_hp, amount)
	
	# Flash core bright white-crimson
	var mat = core_mesh.get_surface_override_material(0) as StandardMaterial3D
	if mat:
		var orig_color = mat.emission
		mat.emission = Color(1.0, 0.8, 0.8)
		get_tree().create_timer(0.08).timeout.connect(func():
			if is_instance_valid(mat):
				mat.emission = orig_color
		)
	
	if current_hp <= 0.0:
		destroy_heart()

func restore_health(amount: float) -> void:
	is_destroyed = false
	current_hp = min(max_hp, current_hp + amount)
	update_ui()
	EventBus.heart_damaged.emit(current_hp, max_hp, 0.0)

func reset_heart() -> void:
	is_destroyed = false
	current_hp = max_hp
	current_energy = max_energy
	pulse_light.light_energy = base_light_energy
	pulse_light.light_color = Color(1.0, 0.12, 0.22)
	update_ui()

func update_ui() -> void:
	if hp_label:
		hp_label.text = "HEART CORE: %d / %d" % [int(current_hp), int(max_hp)]
		if current_hp <= 30.0:
			hp_label.modulate = Color(1.0, 0.2, 0.2)
		else:
			hp_label.modulate = Color(1.0, 0.8, 0.8)

func destroy_heart() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	current_hp = 0.0
	update_ui()
	pulse_light.light_energy = 0.5
	pulse_light.light_color = Color(0.3, 0.05, 0.05)
	AudioManager.play_sfx("defeat_bell")
	EventBus.heart_destroyed.emit()
