extends Area2D

# SpikeTrap.gd: Inflicts physical puncture damage when enemies tread upon it.
# Serves as the primary physical trap for Phase 1.

@export var damage: float = 35.0
@export var cooldown: float = 2.0
@export var trap_name: String = "Spike Trap"

var is_ready: bool = true
var cooldown_timer: float = 0.0
var spike_extension: float = 0.0 # 0.0 = retracted, 1.0 = fully sprung

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	queue_redraw()

func _process(delta: float) -> void:
	if not is_ready:
		cooldown_timer -= delta
		if spike_extension > 0.0:
			spike_extension = max(0.0, spike_extension - delta * 2.0)
			queue_redraw()
		if cooldown_timer <= 0.0:
			is_ready = true
			spike_extension = 0.0
			queue_redraw()
			# Check if an enemy is already standing on it
			_check_overlapping()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		trigger_trap(body)

func _on_area_entered(area: Node2D) -> void:
	var parent = area.get_parent()
	if parent and parent.is_in_group("enemies"):
		trigger_trap(parent)

func _check_overlapping() -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("enemies"):
			trigger_trap(body)
			break

func trigger_trap(target: Node2D) -> void:
	if not is_ready:
		return
	
	is_ready = false
	cooldown_timer = cooldown
	spike_extension = 1.0
	queue_redraw()
	
	if target.has_method("take_damage"):
		target.take_damage(damage)
	
	EventBus.trap_triggered.emit(trap_name, global_position, target)

func _draw() -> void:
	var size = Vector2(40.0, 40.0)
	var half = size / 2.0
	var rect = Rect2(-half, size)
	
	# Metal grate base plate
	var plate_color = Color(0.18, 0.2, 0.22, 0.95)
	draw_rect(rect, plate_color)
	draw_rect(rect, Color(0.35, 0.38, 0.42, 1.0), false, 2.0)
	
	# Hole indicators
	var spike_points = [
		Vector2(-10, -10), Vector2(10, -10),
		Vector2(0, 0),
		Vector2(-10, 10), Vector2(10, 10)
	]
	
	for p in spike_points:
		draw_circle(p, 3.5, Color(0.08, 0.08, 0.1, 1.0))
		
		# If ready or extending, draw metallic spikes
		if spike_extension > 0.1 or is_ready:
			var spike_height = 8.0 * (spike_extension if not is_ready else 0.4)
			var spike_col = Color(0.85, 0.85, 0.9, 1.0) if is_ready else Color(0.95, 0.2, 0.2, 1.0)
			draw_circle(p, 2.5 + spike_height * 0.3, spike_col)
			draw_line(p, p + Vector2(0, -spike_height), Color(1.0, 1.0, 1.0, 0.9), 2.0)
	
	# Cooldown indicator border
	if not is_ready:
		var cd_ratio = 1.0 - (cooldown_timer / cooldown)
		draw_arc(Vector2.ZERO, 18.0, 0, TAU * cd_ratio, 16, Color(1.0, 0.6, 0.1, 0.8), 2.0)
