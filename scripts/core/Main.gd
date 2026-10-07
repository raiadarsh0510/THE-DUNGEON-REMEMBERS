extends Node2D

# Main.gd: Master scene tying together Dungeon, WaveManager, HUD, Camera, Screen Shake & Polish.

@onready var dungeon: Node2D = $Dungeon
@onready var wave_manager: Node = $WaveManager
@onready var hud: CanvasLayer = $HUD
@onready var camera: Camera2D = $Camera2D

const FloatingTextScript = preload("res://scripts/ui/FloatingText.gd")

# Camera controls
var camera_speed: float = 500.0
var zoom_speed: float = 0.1
var min_zoom: float = 0.6
var max_zoom: float = 1.8

# Screen Shake state
var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0

var floating_text_container: Node2D

func _ready() -> void:
	floating_text_container = Node2D.new()
	floating_text_container.name = "FloatingTextContainer"
	add_child(floating_text_container)
	
	wave_manager.setup(dungeon)
	hud.setup(wave_manager)
	
	# Center camera over dungeon layout
	camera.position = Vector2(640, 360)
	
	_connect_polish_events()

func _process(delta: float) -> void:
	# Camera movement with WASD or arrow keys
	var move_vec = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_vec.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_vec.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_vec.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_vec.x += 1
	
	if move_vec != Vector2.ZERO:
		camera.position += move_vec.normalized() * (camera_speed / camera.zoom.x) * delta
		# Clamp camera position to reasonable bounds
		camera.position.x = clamp(camera.position.x, 200, 1100)
		camera.position.y = clamp(camera.position.y, 150, 600)
	
	# Handle screen shake
	if shake_timer > 0.0:
		shake_timer -= delta
		var pct = shake_timer / max(0.001, shake_duration)
		var cur_shake = shake_intensity * pct
		camera.offset = Vector2(randf_range(-cur_shake, cur_shake), randf_range(-cur_shake, cur_shake))
		if shake_timer <= 0.0:
			camera.offset = Vector2.ZERO
			shake_intensity = 0.0

func shake_camera(intensity: float, duration: float) -> void:
	if not GameManager.screen_shake_enabled:
		return
	shake_intensity = max(shake_intensity, intensity)
	shake_duration = duration
	shake_timer = duration

func spawn_floating_text(pos: Vector2, text: String, color: Color = Color.WHITE, size: int = 14, duration: float = 0.75) -> void:
	if floating_text_container == null:
		return
	var ft = FloatingTextScript.new()
	ft.position = pos
	floating_text_container.add_child(ft)
	ft.setup(text, color, size, duration)

func _connect_polish_events() -> void:
	EventBus.heart_damaged.connect(func(_cur, _max, dmg):
		if dmg > 0.0:
			shake_camera(clamp(dmg * 0.7, 5.0, 22.0), 0.35)
			spawn_floating_text(Vector2(640, 310), "-%.0f HP" % dmg, Color(1.0, 0.15, 0.25), 18, 0.9)
	)
	
	EventBus.boss_phase_changed.connect(func(_p):
		shake_camera(18.0, 0.65)
		spawn_floating_text(Vector2(640, 260), "ZEALOT'S WRATH! (+50% SPD & ATK)", Color(1.0, 0.45, 0.1), 22, 1.6)
	)
	
	EventBus.dungeon_shifted.connect(func(shifted):
		if shifted:
			shake_camera(8.0, 0.45)
			spawn_floating_text(Vector2(640, 220), "DUNGEON SHIFTED: ROUTE CLOSED", Color(0.3, 0.85, 1.0), 16, 1.2)
	)
	
	EventBus.trap_triggered.connect(func(type, pos, target):
		match type:
			"Falling Rock":
				shake_camera(6.5, 0.25)
				if is_instance_valid(target):
					spawn_floating_text(target.global_position + Vector2(0, -20), "STUNNED!", Color(1.0, 0.75, 0.2), 14, 0.8)
			"Poison Fog":
				if is_instance_valid(target):
					spawn_floating_text(target.global_position + Vector2(0, -20), "POISONED!", Color(0.4, 0.95, 0.4), 14, 0.8)
			"Illusion Trap":
				if is_instance_valid(target):
					spawn_floating_text(target.global_position + Vector2(0, -20), "CONFUSED!", Color(0.85, 0.4, 1.0), 14, 0.8)
	)
	
	EventBus.enemy_damaged.connect(func(enemy, amount, _cur_hp):
		if is_instance_valid(enemy):
			var col = Color(1.0, 0.3, 0.3)
			if amount >= 30.0:
				col = Color(1.0, 0.85, 0.1) # Critical burst
			spawn_floating_text(enemy.global_position + Vector2(0, -18), "-%.0f" % amount, col, 14, 0.7)
	)
	
	EventBus.enemy_died.connect(func(enemy):
		if is_instance_valid(enemy):
			var bounty_str = "+Gold"
			if "gold_bounty" in enemy:
				bounty_str = "+%d G" % enemy.gold_bounty
			spawn_floating_text(enemy.global_position + Vector2(0, -28), bounty_str, Color(1.0, 0.88, 0.2), 16, 0.9)
	)
	
	EventBus.enemy_adapted.connect(func(enemy, reason):
		if is_instance_valid(enemy):
			spawn_floating_text(enemy.global_position + Vector2(0, -32), "ADAPTED: " + reason, Color(0.75, 0.55, 1.0), 12, 1.2)
	)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var target_zoom = camera.zoom + Vector2(zoom_speed, zoom_speed)
			camera.zoom = target_zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var target_zoom = camera.zoom - Vector2(zoom_speed, zoom_speed)
			camera.zoom = target_zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))

