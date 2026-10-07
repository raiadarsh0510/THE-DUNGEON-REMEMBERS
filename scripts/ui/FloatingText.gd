extends Node2D

# FloatingText.gd: Renders rising, fading combat and bounty indicators.
# Adds high-impact visual feedback (damage numbers, gold gain, status text).

var text: String = ""
var color: Color = Color.WHITE
var font_size: int = 14
var duration: float = 0.75
var timer: float = 0.0
var rise_speed: float = 50.0
var velocity: Vector2 = Vector2.ZERO
var scale_val: float = 1.2

func setup(p_text: String, p_color: Color = Color.WHITE, p_size: int = 14, p_duration: float = 0.75) -> void:
	text = p_text
	color = p_color
	font_size = p_size
	duration = p_duration
	timer = duration
	velocity = Vector2(randf_range(-18, 18), -rise_speed)
	scale_val = 1.3
	queue_redraw()

func _process(delta: float) -> void:
	timer -= delta
	position += velocity * delta
	velocity.y *= 0.94 # Slight drag
	scale_val = lerp(scale_val, 1.0, delta * 8.0)
	queue_redraw()
	
	if timer <= 0.0:
		queue_free()

func _get_font() -> Font:
	if ThemeDB.fallback_font != null:
		return ThemeDB.fallback_font
	return SystemFont.new()

func _draw() -> void:
	var alpha = clamp(timer / (duration * 0.4), 0.0, 1.0)
	var col = Color(color.r, color.g, color.b, alpha)
	var shadow_col = Color(0, 0, 0, alpha * 0.85)
	var f = _get_font()
	if f == null:
		return
	
	var scaled_size = int(float(font_size) * scale_val)
	# Draw shadow outline
	draw_string(f, Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, -1, scaled_size, shadow_col)
	draw_string(f, Vector2(-1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, -1, scaled_size, shadow_col)
	# Draw main colored text
	draw_string(f, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_CENTER, -1, scaled_size, col)

