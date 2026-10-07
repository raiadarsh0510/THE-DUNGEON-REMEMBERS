extends Area2D

# IllusionTrap.gd: The core memory-manipulation trap!
# Generates phantom danger signals that plant false memories into enemy intelligence.
# "The player learns. The enemy learns. The dungeon changes."

@export var trap_name: String = "Illusion Trap"
@export var cooldown: float = 4.0

var is_ready: bool = true
var cooldown_timer: float = 0.0
var phantom_flash_timer: float = 0.0
var pulse_time: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _process(delta: float) -> void:
	pulse_time += delta * 3.0
	
	if phantom_flash_timer > 0.0:
		phantom_flash_timer -= delta
		queue_redraw()
	elif not is_ready:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			is_ready = true
			queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and is_ready:
		trigger_trap(body)

func trigger_trap(target: Node2D) -> void:
	if not is_ready:
		return
	is_ready = false
	cooldown_timer = cooldown
	phantom_flash_timer = 0.8
	queue_redraw()
	
	var enemy_type = "Warrior"
	if target.has_method("get_enemy_type"):
		enemy_type = target.get_enemy_type()
	
	# Check if enemy is a Mage (Mages can see through illusions!)
	if enemy_type == "Mage":
		# Mage disillusions the trap
		if target.has_method("dispel_illusion"):
			target.dispel_illusion()
		var mem = MemoryManager.record_event(enemy_type, "ILLUSION_DISPELLED", global_position, 0.1, "Mage saw through false trap")
		mem["confidence"] = 0.1
	else:
		# Warriors and Rogues are thoroughly fooled!
		MemoryManager.record_event(enemy_type, "TRAP_TRIGGERED", global_position, 0.95, "Terrifying phantom hazard encountered")
		if target.has_method("frighten_by_illusion"):
			target.frighten_by_illusion()
	
	EventBus.trap_triggered.emit(trap_name, global_position, target)

func _draw() -> void:
	var size = Vector2(40, 40)
	var half = size / 2.0
	
	# Mystic slate
	draw_rect(Rect2(-half, size), Color(0.12, 0.1, 0.16, 0.95))
	var border_color = Color(0.6, 0.3, 0.85, 0.8) if is_ready else Color(0.3, 0.25, 0.4, 0.5)
	draw_rect(Rect2(-half, size), border_color, false, 2.0)
	
	# Arcane phantom runes
	var alpha = 0.7 + sin(pulse_time) * 0.25 if is_ready else 0.3
	draw_arc(Vector2.ZERO, 12.0, 0, TAU, 16, Color(0.8, 0.4, 1.0, alpha), 1.5)
	draw_circle(Vector2.ZERO, 4.0, Color(0.9, 0.6, 1.0, alpha))
	
	# Phantom manifestation VFX upon trigger
	if phantom_flash_timer > 0.0:
		var flash_ratio = phantom_flash_timer / 0.8
		var specter_radius = lerp(45.0, 15.0, flash_ratio)
		draw_circle(Vector2.ZERO, specter_radius, Color(0.7, 0.1, 0.9, 0.4 * flash_ratio))
		draw_arc(Vector2.ZERO, specter_radius, 0, TAU, 24, Color(1.0, 0.5, 1.0, flash_ratio), 2.5)
		# Ghostly eyes
		draw_circle(Vector2(-10, -8), 4.0, Color(1.0, 1.0, 1.0, flash_ratio))
		draw_circle(Vector2(10, -8), 4.0, Color(1.0, 1.0, 1.0, flash_ratio))
		draw_string(ThemeDB.fallback_font, Vector2(-42, -26), "PHANTOM TERROR!", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1.0, 0.6, 1.0, flash_ratio))
	
	# Cooldown indicator
	if not is_ready and phantom_flash_timer <= 0.0:
		var cd_ratio = 1.0 - (cooldown_timer / cooldown)
		draw_arc(Vector2.ZERO, 18.0, 0, TAU * cd_ratio, 16, Color(0.7, 0.3, 0.9, 0.8), 2.0)
