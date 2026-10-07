extends Node3D

# Elevated / Isometric Strategic 3D Camera Controller for "The Dungeon Remembers"
# Controls pan (WASD), zoom (Wheel), and provides ray projection for 3D selection.

@export var pan_speed: float = 24.0
@export var zoom_speed: float = 2.5
@export var min_zoom: float = 8.0
@export var max_zoom: float = 34.0
@export var pan_smoothing: float = 12.0

@export var pan_bounds_min: Vector3 = Vector3(-25.0, 0.0, -25.0)
@export var pan_bounds_max: Vector3 = Vector3(25.0, 0.0, 30.0)

@onready var camera_pitch: Node3D = $CameraPitch
@onready var camera: Camera3D = $CameraPitch/Camera3D

var target_position: Vector3 = Vector3.ZERO
var current_zoom: float = 18.0
var target_zoom: float = 18.0

# Screen shake variables
var shake_intensity: float = 0.0
var shake_timer: float = 0.0

func _ready() -> void:
	target_position = global_position
	current_zoom = camera.position.z
	target_zoom = current_zoom
	EventBus.heart_damaged.connect(func(_hp, _max, dmg):
		if dmg > 0.0:
			trigger_shake(clamp(dmg * 0.15, 0.2, 1.2), 0.3)
	)

func _process(delta: float) -> void:
	handle_pan_input(delta)
	handle_zoom(delta)
	handle_shake(delta)

func handle_pan_input(delta: float) -> void:
	var input_dir = Vector3.ZERO
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_dir.z += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_dir.z -= 1.0
		
	if input_dir.length_squared() > 0.0:
		input_dir = input_dir.normalized()
		target_position += input_dir * pan_speed * delta
		target_position.x = clamp(target_position.x, pan_bounds_min.x, pan_bounds_max.x)
		target_position.z = clamp(target_position.z, pan_bounds_min.z, pan_bounds_max.z)
	
	global_position = global_position.lerp(target_position, delta * pan_smoothing)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				target_zoom = clamp(target_zoom - zoom_speed, min_zoom, max_zoom)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				target_zoom = clamp(target_zoom + zoom_speed, min_zoom, max_zoom)

func handle_zoom(delta: float) -> void:
	current_zoom = lerp(current_zoom, target_zoom, delta * 10.0)
	camera.position.z = current_zoom

func handle_shake(delta: float) -> void:
	if shake_timer > 0.0:
		shake_timer -= delta
		var offset = Vector3(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity),
			0.0
		)
		camera.h_offset = offset.x
		camera.v_offset = offset.y
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		shake_intensity = 0.0

func trigger_shake(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_timer = duration

# Projects a ray from mouse coordinate into 3D world, returning plane intersection at height Y
func raycast_ground(mouse_pos: Vector2, ground_y: float = 0.0) -> Vector3:
	var from = camera.project_ray_origin(mouse_pos)
	var dir = camera.project_ray_normal(mouse_pos)
	if abs(dir.y) < 0.0001:
		return from
	var t = (ground_y - from.y) / dir.y
	return from + dir * t
