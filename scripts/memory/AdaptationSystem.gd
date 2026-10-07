class_name AdaptationSystem
extends RefCounted

# AdaptationSystem: Evaluates invader path utility, danger penalties, and route selection.
# Routes are chosen dynamically using remembered experiences rather than hardcoded paths.

const PROXIMITY_THRESHOLD: float = 4.5

static func get_perceived_danger_at(point: Vector3, enemy_type: String) -> float:
	var memories = MemoryManager.get_memories_for_enemy(enemy_type)
	var max_danger: float = 0.0
	
	for mem in memories:
		var loc: Vector3 = mem["location"]
		var dist = Vector2(loc.x, loc.z).distance_to(Vector2(point.x, point.z))
		if dist <= PROXIMITY_THRESHOLD:
			var danger_influence = mem["danger_score"] * mem["confidence"]
			# Falloff with distance
			var falloff = 1.0 - (dist / PROXIMITY_THRESHOLD) * 0.5
			var effective_danger = danger_influence * falloff
			if effective_danger > max_danger:
				max_danger = effective_danger
				
	return max_danger

static func evaluate_route_danger(waypoints: Array, enemy_type: String) -> float:
	var total_danger: float = 0.0
	for wp in waypoints:
		total_danger += get_perceived_danger_at(wp, enemy_type)
	return total_danger

# Evaluates all available routes and selects the optimal path balancing distance and remembered danger
# available_routes: { "RouteName": Array }
static func select_route(available_routes: Dictionary, enemy_type: String) -> Dictionary:
	var best_route_name: String = ""
	var lowest_cost: float = 999999.0
	var selected_danger: float = 0.0
	var memory_influence_detected: bool = false
	var primary_hazard_desc: String = ""
	
	# Determine direct route baseline
	var direct_route_danger = 0.0
	if available_routes.has("Central"):
		direct_route_danger = evaluate_route_danger(available_routes["Central"], enemy_type)
	
	for route_name in available_routes.keys():
		var waypoints: Array = available_routes[route_name]
		
		# Calculate total path length
		var path_length: float = 0.0
		for i in range(waypoints.size() - 1):
			path_length += waypoints[i].distance_to(waypoints[i + 1])
			
		var danger = evaluate_route_danger(waypoints, enemy_type)
		
		# Utility Cost: Length + Danger Penalty Weight (danger has high psychological deterrent)
		# A danger score of 0.8 adds +40.0 cost units, heavily discouraging paths with known lethal traps
		var utility_cost = path_length + (danger * 50.0)
		
		if utility_cost < lowest_cost:
			lowest_cost = utility_cost
			best_route_name = route_name
			selected_danger = danger
	
	# If direct Central route was dangerous and another route was picked, memory influenced decision
	if direct_route_danger > 0.4 and best_route_name != "Central":
		memory_influence_detected = true
		primary_hazard_desc = "Remembered Spike Trap danger (score: %.1f) -> Diverting via %s" % [direct_route_danger, best_route_name]
	
	return {
		"route_name": best_route_name,
		"waypoints": available_routes.get(best_route_name, []),
		"perceived_danger": selected_danger,
		"memory_influenced": memory_influence_detected,
		"adaptation_reason": primary_hazard_desc
	}
