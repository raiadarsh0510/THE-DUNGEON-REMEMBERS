extends Node2D

# Dungeon.gd: Represents the living body of the dungeon.
# Features a branching 3-route layout (North Flank, Central Hall, South Flank)
# specifically architected for enemy memory, route evaluation, and adaptation.

@export var spike_trap_scene: PackedScene = preload("res://scenes/traps/SpikeTrap.tscn")
@export var falling_rock_scene: PackedScene = preload("res://scenes/traps/FallingRockTrap.tscn")
@export var poison_fog_scene: PackedScene = preload("res://scenes/traps/PoisonFogTrap.tscn")
@export var illusion_trap_scene: PackedScene = preload("res://scenes/traps/IllusionTrap.tscn")

@export var goblin_scene: PackedScene = preload("res://scenes/monsters/Goblin.tscn")
@export var shadow_beast_scene: PackedScene = preload("res://scenes/monsters/ShadowBeast.tscn")
@export var mimic_scene: PackedScene = preload("res://scenes/monsters/Mimic.tscn")

@onready var nav_region: NavigationRegion2D = $NavigationRegion
@onready var enemies_container: Node2D = $Enemies
@onready var traps_container: Node2D = $Traps
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var heart: Node2D = $Heart
@onready var shift_barrier: Node2D = $ShiftBarrier

var monsters_container: Node2D = null
var can_build_traps: bool = true
var is_north_flank_blocked: bool = false
var selected_build_item: String = "Spike Trap"

# Route waypoints for navigation scoring
const ROUTE_WEST_JUNCTION = Vector2(340, 360)
const ROUTE_NORTH_WAYPOINT = Vector2(580, 200)
const ROUTE_CENTRAL_WAYPOINT = Vector2(580, 360)
const ROUTE_SOUTH_WAYPOINT = Vector2(580, 520)
const ROUTE_EAST_JUNCTION = Vector2(820, 360)

var torch_time: float = 0.0

const TORCH_POSITIONS: Array[Vector2] = [
	Vector2(200, 302), Vector2(200, 418),
	Vector2(440, 162), Vector2(680, 162),
	Vector2(440, 302), Vector2(680, 302),
	Vector2(440, 418), Vector2(680, 418),
	Vector2(440, 482), Vector2(680, 482),
	Vector2(860, 260), Vector2(860, 460)
]

func _ready() -> void:
	add_to_group("dungeon")
	if has_node("Monsters"):
		monsters_container = $Monsters
	else:
		monsters_container = Node2D.new()
		monsters_container.name = "Monsters"
		add_child(monsters_container)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.dungeon_shifted.connect(_on_dungeon_shifted)
	bake_navigation_mesh()
	queue_redraw()

func _process(delta: float) -> void:
	torch_time += delta
	queue_redraw()

func _on_dungeon_shifted(is_shifted: bool) -> void:
	is_north_flank_blocked = is_shifted
	bake_navigation_mesh()
	queue_redraw()
	
	# Instruct all living enemies to immediately re-evaluate navigation
	for enemy in enemies_container.get_children():
		if enemy.has_method("_evaluate_routes_and_adapt"):
			enemy._evaluate_routes_and_adapt()

func bake_navigation_mesh() -> void:
	if not nav_region:
		return
	
	var nav_poly = NavigationPolygon.new()
	var verts = PackedVector2Array()
	
	# Aligned grid rectangles with EXACT shared y-coordinates [160, 240, 300, 420, 480, 560]
	# to eliminate all T-junctions and guarantee 100% connected navigation:
	var rects: Array[Rect2] = [
		# West Hall (Entrance)
		Rect2(80, 300, 220, 120),
		
		# West Junction Column [x: 300..380]
		Rect2(300, 160, 80, 80),   # connects to North Flank
		Rect2(300, 240, 80, 60),   # junction vertical link
		Rect2(300, 300, 80, 120),  # connects to West Hall & Central Hall
		Rect2(300, 420, 80, 60),   # junction vertical link
		Rect2(300, 480, 80, 80),   # connects to South Flank
		
		# Central Hall Corridor (Main route with spike trap)
		Rect2(380, 300, 400, 120),
		# South Flank Corridor
		Rect2(380, 480, 400, 80),
		
		# East Junction Column [x: 780..860]
		Rect2(780, 160, 80, 80),   # connects from North Flank
		Rect2(780, 240, 80, 60),   # junction vertical link
		Rect2(780, 300, 80, 120),  # connects from Central Hall
		Rect2(780, 420, 80, 60),   # junction vertical link
		Rect2(780, 480, 80, 80),   # connects from South Flank
		
		# Heart Sanctum [x: 860..1160]
		Rect2(860, 160, 300, 80),
		Rect2(860, 240, 300, 60),
		Rect2(860, 300, 300, 120),
		Rect2(860, 420, 300, 60),
		Rect2(860, 480, 300, 80)
	]
	
	# Only include North Flank corridor if not blocked by Dungeon Shift
	if not is_north_flank_blocked:
		rects.append(Rect2(380, 160, 400, 80))
	
	for i in range(rects.size()):
		var r = rects[i]
		var base_idx = verts.size()
		verts.append(r.position)
		verts.append(Vector2(r.end.x, r.position.y))
		verts.append(r.end)
		verts.append(Vector2(r.position.x, r.end.y))
		nav_poly.add_polygon(PackedInt32Array([base_idx, base_idx + 1, base_idx + 2, base_idx + 3]))
	
	nav_poly.vertices = verts
	nav_region.navigation_polygon = nav_poly

func _on_wave_started(_wave: int) -> void:
	can_build_traps = false

func _on_wave_completed(_wave: int) -> void:
	can_build_traps = true

func set_selected_build_item(item_name: String) -> void:
	selected_build_item = item_name

func spawn_selected_item_at(pos: Vector2) -> bool:
	match selected_build_item:
		"Spike Trap", "Falling Rock", "Poison Fog", "Illusion Trap":
			return spawn_trap_by_name(selected_build_item, pos)
		"Goblin", "Shadow Beast", "Mimic":
			return spawn_monster_by_name(selected_build_item, pos)
		_:
			return spawn_trap_by_name("Spike Trap", pos)

func spawn_spike_trap_at(pos: Vector2) -> bool:
	return spawn_trap_by_name("Spike Trap", pos)

func spawn_trap_by_name(t_name: String, pos: Vector2) -> bool:
	if not can_build_traps:
		return false
	if not is_position_on_walkable_floor(pos):
		return false
	
	var cost = 40
	var scene_to_spawn = spike_trap_scene
	match t_name:
		"Spike Trap":
			cost = 40
			scene_to_spawn = spike_trap_scene
		"Falling Rock":
			cost = 60
			scene_to_spawn = falling_rock_scene
		"Poison Fog":
			cost = 50
			scene_to_spawn = poison_fog_scene
		"Illusion Trap":
			cost = 35
			scene_to_spawn = illusion_trap_scene
		_:
			cost = 40
			scene_to_spawn = spike_trap_scene
	
	if not ResourceManager.spend_gold(cost):
		return false
	
	var trap_inst = scene_to_spawn.instantiate()
	trap_inst.position = pos
	traps_container.add_child(trap_inst)
	EventBus.trap_placed.emit(t_name, pos)
	return true

func spawn_monster_by_name(m_name: String, pos: Vector2) -> bool:
	if not can_build_traps:
		return false
	if not is_position_on_walkable_floor(pos):
		return false
	
	var gold_cost = 40
	var essence_cost = 5
	var scene_to_spawn = goblin_scene
	match m_name:
		"Goblin":
			gold_cost = 40
			essence_cost = 5
			scene_to_spawn = goblin_scene
		"Shadow Beast":
			gold_cost = 70
			essence_cost = 10
			scene_to_spawn = shadow_beast_scene
		"Mimic":
			gold_cost = 60
			essence_cost = 15
			scene_to_spawn = mimic_scene
		_:
			gold_cost = 40
			essence_cost = 5
			scene_to_spawn = goblin_scene
	
	if ResourceManager.gold < gold_cost or ResourceManager.essence < essence_cost:
		return false
	
	ResourceManager.spend_gold(gold_cost)
	ResourceManager.spend_essence(essence_cost)
	
	var monster_inst = scene_to_spawn.instantiate()
	monster_inst.position = pos
	if monsters_container:
		monsters_container.add_child(monster_inst)
	else:
		add_child(monster_inst)
	EventBus.monster_placed.emit(m_name, pos)
	return true

func is_position_on_walkable_floor(pos: Vector2) -> bool:
	# Check whether pos lies within any corridor or chamber
	var in_west = (pos.x >= 80 and pos.x <= 380 and pos.y >= 300 and pos.y <= 420)
	var in_north = (pos.x >= 300 and pos.x <= 860 and pos.y >= 160 and pos.y <= 240)
	var in_central = (pos.x >= 300 and pos.x <= 860 and pos.y >= 300 and pos.y <= 420)
	var in_south = (pos.x >= 300 and pos.x <= 860 and pos.y >= 480 and pos.y <= 560)
	var in_w_junc = (pos.x >= 300 and pos.x <= 380 and pos.y >= 160 and pos.y <= 560)
	var in_e_junc = (pos.x >= 780 and pos.x <= 860 and pos.y >= 160 and pos.y <= 560)
	var in_heart = (pos.x >= 860 and pos.x <= 1160 and pos.y >= 200 and pos.y <= 520)
	return in_west or in_north or in_central or in_south or in_w_junc or in_e_junc or in_heart

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if can_build_traps:
			spawn_selected_item_at(get_global_mouse_position())

func _draw() -> void:
	# Dark void
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.06, 0.06, 0.08, 1.0))
	
	# Draw corridors and chambers
	# 1. North Flank
	_draw_dungeon_room(Rect2(300, 160, 560, 80), "North Flank")
	# 2. Central Hall (Main Trap Corridor)
	_draw_dungeon_room(Rect2(300, 300, 560, 120), "Central Hall")
	# 3. South Flank
	_draw_dungeon_room(Rect2(300, 480, 560, 80), "South Flank")
	# 4. West Hall & Junction
	_draw_dungeon_room(Rect2(80, 300, 300, 120), "West Entrance")
	_draw_dungeon_room(Rect2(300, 160, 80, 400), "")
	# 5. East Junction
	_draw_dungeon_room(Rect2(780, 160, 80, 400), "")
	# 6. Heart Sanctum
	_draw_dungeon_room(Rect2(860, 200, 300, 320), "Heart Sanctum")
	
	# Invader Gate
	draw_circle(spawn_point.position, 28.0, Color(0.4, 0.2, 0.6, 0.35))
	draw_circle(spawn_point.position, 16.0, Color(0.6, 0.3, 0.9, 0.5))
	draw_string(ThemeDB.fallback_font, spawn_point.position + Vector2(-40, -36), "INVADER GATE", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.8, 0.7, 1.0, 0.9))
	
	# Route corridor labels for clear player visibility
	draw_string(ThemeDB.fallback_font, Vector2(520, 150), "[ NORTH FLANK - ALTERNATE ROUTE ]", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.5, 0.7, 0.8, 0.75))
	draw_string(ThemeDB.fallback_font, Vector2(520, 292), "[ CENTRAL HALL - DIRECT ROUTE ]", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.8, 0.5, 0.4, 0.75))
	draw_string(ThemeDB.fallback_font, Vector2(520, 574), "[ SOUTH FLANK - ALTERNATE ROUTE ]", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.5, 0.7, 0.8, 0.75))
	
	# Heart Chamber aura & runes
	draw_arc(heart.position, 72.0, 0, TAU, 32, Color(0.8, 0.1, 0.2, 0.4), 2.0)
	draw_arc(heart.position, 94.0, 0, TAU, 32, Color(0.6, 0.05, 0.15, 0.25), 1.5)
	draw_string(ThemeDB.fallback_font, heart.position + Vector2(-60, -84), "HEART CHAMBER", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(1.0, 0.4, 0.5, 0.9))
	
	# Draw animated ambient wall torches
	_draw_torches()

func _draw_torches() -> void:
	for i in range(TORCH_POSITIONS.size()):
		var pos = TORCH_POSITIONS[i]
		var flicker = sin(torch_time * 6.5 + float(i) * 1.8) * 0.25 + sin(torch_time * 12.0 + float(i) * 2.7) * 0.1
		var radius_glow = 24.0 + flicker * 6.0
		var radius_flame = 6.0 + flicker * 2.0
		
		# Warm amber radial halo
		draw_circle(pos, radius_glow, Color(1.0, 0.62, 0.18, 0.15 + flicker * 0.05))
		draw_circle(pos, radius_flame + 2.5, Color(1.0, 0.78, 0.25, 0.38 + flicker * 0.1))
		# Iron wall sconce bracket
		draw_rect(Rect2(pos.x - 2, pos.y - 1, 4, 6), Color(0.2, 0.17, 0.15, 0.95))
		# Dancing flame core
		draw_circle(pos + Vector2(0, -2), radius_flame * 0.55, Color(1.0, 0.92, 0.55, 0.9))

func _draw_dungeon_room(rect: Rect2, _label: String) -> void:
	draw_rect(rect, Color(0.14, 0.15, 0.18, 1.0))
	var step = 40.0
	var col_lines = Color(0.18, 0.2, 0.24, 0.6)
	var x = rect.position.x
	while x <= rect.end.x:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), col_lines, 1.0)
		x += step
	var y = rect.position.y
	while y <= rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), col_lines, 1.0)
		y += step
	draw_rect(rect, Color(0.28, 0.3, 0.36, 1.0), false, 2.5)
