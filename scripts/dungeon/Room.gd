extends Area2D

# Room.gd: Represents one of the 6 specialized functional dungeon rooms.
# 1. Treasury      (Generates/stores Gold)
# 2. Monster Den   (Monster spawning & training grounds)
# 3. Trap Room     (Trap enhancement & maintenance)
# 4. Heart Chamber (Sanctum of the Dungeon Heart)
# 5. Memory Chamber(Arcane repository of invader intelligence)
# 6. Gate Room     (Invader entry threshold)

enum RoomType {
	TREASURY,
	MONSTER_DEN,
	TRAP_ROOM,
	HEART_CHAMBER,
	MEMORY_CHAMBER,
	GATE_ROOM
}

@export var room_type: RoomType = RoomType.GATE_ROOM
@export var room_name: String = "Gate Room"
@export var room_description: String = "Entrance gateway where invaders enter the dungeon."
@export var room_bounds: Rect2 = Rect2(80, 300, 200, 120)

var is_hovered: bool = false
var is_selected: bool = false

func _ready() -> void:
	add_to_group("dungeon_rooms")
	RoomManager.register_room(self)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	queue_redraw()

func _on_mouse_entered() -> void:
	is_hovered = true
	queue_redraw()

func _on_mouse_exited() -> void:
	is_hovered = false
	queue_redraw()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		select_room()

func select_room() -> void:
	is_selected = true
	queue_redraw()
	if room_type == RoomType.MEMORY_CHAMBER:
		# Directly toggle Memory Chamber UI
		EventBus.memory_chamber_toggled.emit(true)

func deselect_room() -> void:
	is_selected = false
	queue_redraw()

func trigger_wave_bonus() -> void:
	match room_type:
		RoomType.TREASURY:
			# Generates bonus gold at the end of each wave
			var bonus_gold = 25
			ResourceManager.add_gold(bonus_gold)
		RoomType.HEART_CHAMBER:
			# Heals Dungeon Heart slightly if damaged
			var hearts = get_tree().get_nodes_in_group("dungeon_heart")
			if hearts.size() > 0:
				var heart = hearts[0]
				heart.current_hp = min(heart.max_hp, heart.current_hp + 5.0)
				EventBus.heart_damaged.emit(heart.current_hp, heart.max_hp, 0.0)

func _draw() -> void:
	var local_rect = Rect2(-room_bounds.size / 2.0, room_bounds.size)
	
	# Floor tint specific to room type
	var tint = Color(0.14, 0.15, 0.18, 0.9)
	var border_color = Color(0.3, 0.35, 0.4, 0.7)
	
	match room_type:
		RoomType.TREASURY:
			tint = Color(0.2, 0.18, 0.12, 0.9)
			border_color = Color(0.85, 0.7, 0.2, 0.8)
		RoomType.MONSTER_DEN:
			tint = Color(0.18, 0.12, 0.12, 0.9)
			border_color = Color(0.8, 0.25, 0.2, 0.8)
		RoomType.TRAP_ROOM:
			tint = Color(0.16, 0.16, 0.2, 0.9)
			border_color = Color(0.5, 0.6, 0.8, 0.8)
		RoomType.HEART_CHAMBER:
			tint = Color(0.22, 0.1, 0.14, 0.9)
			border_color = Color(0.9, 0.2, 0.35, 0.9)
		RoomType.MEMORY_CHAMBER:
			tint = Color(0.16, 0.12, 0.22, 0.9)
			border_color = Color(0.7, 0.4, 0.9, 0.85)
		RoomType.GATE_ROOM:
			tint = Color(0.13, 0.14, 0.16, 0.9)
			border_color = Color(0.4, 0.45, 0.55, 0.8)
	
	if is_hovered or is_selected:
		border_color = border_color.lightened(0.3)
	
	draw_rect(local_rect, tint)
	draw_rect(local_rect, border_color, false, 2.5 if not is_hovered else 3.5)
	
	# Room title
	draw_string(ThemeDB.fallback_font, Vector2(-local_rect.size.x * 0.45, -local_rect.size.y * 0.25), room_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, border_color)
	
	# Room icon / visual thematic glyphs
	match room_type:
		RoomType.TREASURY:
			draw_circle(Vector2(0, 10), 10, Color(0.9, 0.75, 0.2, 0.8))
			draw_circle(Vector2(12, 12), 7, Color(0.8, 0.65, 0.1, 0.8))
			draw_circle(Vector2(-10, 12), 8, Color(0.95, 0.8, 0.2, 0.8))
		RoomType.MONSTER_DEN:
			# Beast claw / eye rune
			draw_circle(Vector2(-6, 8), 4, Color(1.0, 0.2, 0.2, 0.9))
			draw_circle(Vector2(6, 8), 4, Color(1.0, 0.2, 0.2, 0.9))
		RoomType.TRAP_ROOM:
			# Spikes / gear
			draw_line(Vector2(-10, 15), Vector2(-10, 5), Color(0.7, 0.75, 0.8), 2.0)
			draw_line(Vector2(0, 15), Vector2(0, 2), Color(0.7, 0.75, 0.8), 2.0)
			draw_line(Vector2(10, 15), Vector2(10, 5), Color(0.7, 0.75, 0.8), 2.0)
		RoomType.MEMORY_CHAMBER:
			# Arcane eye
			draw_arc(Vector2(0, 8), 10, 0, TAU, 16, Color(0.8, 0.4, 1.0, 0.9), 2.0)
			draw_circle(Vector2(0, 8), 4, Color(1.0, 0.8, 1.0, 0.9))
