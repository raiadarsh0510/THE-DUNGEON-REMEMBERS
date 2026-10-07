extends Node3D

# DamageNumber3D: Floating combat text in 3D world space.
# Pops up upon damage impact, drifts upwards, and fades out.

@onready var label: Label3D = $Label3D

func setup(amount: float, is_critical: bool = false, custom_color: Color = Color.WHITE) -> void:
	if not label:
		label = $Label3D
		
	var dmg_int = int(amount)
	label.text = "-%d" % dmg_int
	
	if is_critical:
		label.text = "-%d CRIT!" % dmg_int
		label.modulate = Color(1.0, 0.85, 0.2, 1.0) # Bright gold
		label.font_size = 32
	elif custom_color != Color.WHITE:
		label.modulate = custom_color
	else:
		label.modulate = Color(1.0, 0.25, 0.2, 1.0) # Crimson impact
		
	var tw = create_tween()
	tw.tween_property(self, "position:y", position.y + 1.6, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.15)
	tw.tween_callback(queue_free)
