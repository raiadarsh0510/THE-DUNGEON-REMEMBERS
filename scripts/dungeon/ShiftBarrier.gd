extends StaticBody2D

# ShiftBarrier.gd: Represents a controlled section of the living dungeon
# that can morph into an impassable living barrier via Dungeon Shift.
# "The player learns. The enemy learns. The dungeon changes."

@export var essence_cost: int = 15
@export var shift_duration: float = 10.0
@export var shift_cooldown: float = 12.0

var is_shifted: bool = false
var duration_remaining: float = 0.0
var cooldown_remaining: float = 0.0
var pulse_time: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	collision_shape.disabled = true
	EventBus.dungeon_shift_requested.connect(activate_shift)
	queue_redraw()

func _process(delta: float) -> void:
	pulse_time += delta * 4.0
	
	if is_shifted:
		duration_remaining -= delta
		if duration_remaining <= 0.0:
			deactivate_shift()
		queue_redraw()
	elif cooldown_remaining > 0.0:
		cooldown_remaining -= delta

func activate_shift() -> bool:
	if is_shifted:
		return false
	if cooldown_remaining > 0.0:
		return false
	
	if not ResourceManager.spend_essence(essence_cost):
		return false
	
	is_shifted = true
	duration_remaining = shift_duration
	cooldown_remaining = shift_cooldown
	collision_shape.disabled = false
	
	# Notify dungeon and systems
	EventBus.dungeon_shifted.emit(true)
	queue_redraw()
	return true

func deactivate_shift() -> void:
	is_shifted = false
	collision_shape.disabled = true
	EventBus.dungeon_shifted.emit(false)
	queue_redraw()

func _draw() -> void:
	var barrier_size = Vector2(36, 80)
	var half = barrier_size / 2.0
	var rect = Rect2(-half, barrier_size)
	
	if is_shifted:
		# Pulsing living barrier
		var alpha = 0.85 + sin(pulse_time) * 0.15
		var barrier_color = Color(0.6, 0.15, 0.85, alpha)
		draw_rect(rect, barrier_color)
		draw_rect(rect, Color(0.9, 0.5, 1.0, 1.0), false, 3.0)
		
		# Spiked teeth along the wall
		var tooth_count = 5
		var step_y = barrier_size.y / tooth_count
		for i in range(tooth_count):
			var tooth_y = -half.y + (i + 0.5) * step_y
			draw_line(Vector2(-half.x, tooth_y), Vector2(half.x, tooth_y), Color(1.0, 0.8, 1.0, 0.9), 2.5)
		
		# Remaining duration indicator
		var ratio = duration_remaining / shift_duration
		draw_rect(Rect2(-half.x, half.y + 4, barrier_size.x * ratio, 4), Color(0.9, 0.4, 1.0, 1.0))
		draw_string(ThemeDB.fallback_font, Vector2(-46, -half.y - 8), "SHIFTED WALL", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1.0, 0.6, 1.0, 1.0))
	else:
		# Inactive shift node indicator (organic seal)
		draw_rect(rect, Color(0.2, 0.1, 0.3, 0.2), false, 1.0)
		var seal_col = Color(0.6, 0.3, 0.8, 0.5) if cooldown_remaining <= 0.0 else Color(0.4, 0.4, 0.4, 0.3)
		draw_arc(Vector2.ZERO, 14.0, 0, TAU, 16, seal_col, 1.5)
		if cooldown_remaining <= 0.0:
			draw_string(ThemeDB.fallback_font, Vector2(-38, -half.y - 6), "[SHIFT NODE]", HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.7, 0.5, 0.9, 0.6))
