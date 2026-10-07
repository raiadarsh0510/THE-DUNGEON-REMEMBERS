extends Area2D

# Heart.gd: The Dungeon Heart is the player's living core and command center.
# "You don't control the dungeon. You ARE the dungeon."

@export var max_hp: float = 100.0
var current_hp: float = 100.0

var pulse_time: float = 0.0
var pulse_speed: float = 2.5
var base_radius: float = 34.0
var current_radius: float = 34.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	current_hp = max_hp
	add_to_group("dungeon_heart")
	EventBus.heart_damaged.emit(current_hp, max_hp, 0.0)

func _process(delta: float) -> void:
	# Calculate pulse frequency: heartbeat becomes faster and more erratic as HP drops
	var hp_ratio = clamp(current_hp / max_hp, 0.1, 1.0)
	pulse_speed = lerp(6.0, 2.5, hp_ratio)
	pulse_time += delta * pulse_speed
	
	# Living organic throbbing pulse
	var wave = sin(pulse_time)
	var pulse_offset = pow(max(0.0, wave), 3.0) * 8.0
	current_radius = base_radius + pulse_offset
	
	queue_redraw()

func take_damage(amount: float) -> void:
	if current_hp <= 0:
		return
	
	current_hp = max(0.0, current_hp - amount)
	EventBus.heart_damaged.emit(current_hp, max_hp, amount)
	
	# Shake or spike visual
	current_radius += 10.0
	
	if current_hp <= 0:
		EventBus.heart_destroyed.emit()

func _draw() -> void:
	# 1. Outer living tendrils / aura
	var aura_color = Color(0.85, 0.1, 0.25, 0.35)
	if current_hp <= 30.0:
		aura_color = Color(1.0, 0.05, 0.1, 0.55)
	draw_circle(Vector2.ZERO, current_radius + 14.0, aura_color)
	
	# 2. Main organic core body
	var core_color = Color(0.65, 0.05, 0.15, 0.95)
	draw_circle(Vector2.ZERO, current_radius, core_color)
	
	# 3. Inner glowing crystalline nucleus
	var inner_radius = current_radius * 0.55
	var nucleus_color = Color(1.0, 0.35, 0.45, 0.9)
	draw_circle(Vector2.ZERO, inner_radius, nucleus_color)
	
	# 4. Veins / organic nodes
	var node_count = 6
	for i in range(node_count):
		var angle = (float(i) / node_count) * TAU + pulse_time * 0.2
		var pos = Vector2(cos(angle), sin(angle)) * (current_radius * 0.75)
		draw_circle(pos, 4.0, Color(0.9, 0.2, 0.3, 0.8))
		draw_line(Vector2.ZERO, pos, Color(0.4, 0.0, 0.1, 0.7), 2.0)
	
	# 5. Core highlight center
	draw_circle(Vector2(-current_radius * 0.2, -current_radius * 0.2), inner_radius * 0.35, Color(1.0, 0.8, 0.85, 0.8))
