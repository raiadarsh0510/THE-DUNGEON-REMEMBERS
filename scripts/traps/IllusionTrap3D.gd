extends Node3D

# IllusionTrap3D: Arcane phantom lure.
# Mechanics: Shimmering treasure chest distraction. Stuns warriors/rogues for 2.5s.
# Mages dispel it immediately. Injects false memory of safety into the memory network.

@export var stun_duration: float = 2.5
@export var trap_cost: int = 35
@export var trap_type: String = "Illusion Trap"

@onready var trigger_area: Area3D = $TriggerArea
@onready var chest_visual: Node3D = $PhantomChest
@onready var aura_light: OmniLight3D = $AuraLight

var is_triggered: bool = false

func _ready() -> void:
	add_to_group("traps")
	trigger_area.body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if not is_triggered and chest_visual:
		chest_visual.rotate_y(0.8 * delta)

func _on_body_entered(body: Node3D) -> void:
	if is_triggered:
		return
	if body.is_in_group("enemies"):
		trigger_trap(body)

func trigger_trap(target_enemy: Node3D) -> void:
	is_triggered = true
	EventBus.trap_triggered.emit(trap_type, global_position, target_enemy)
	
	if target_enemy.has_method("get_enemy_type") and target_enemy.get_enemy_type() == "Mage":
		# Mage dispels illusion
		AudioManager.play_sfx("spell_cast", 0.0, 1.4)
		_dispel_effect(true)
	else:
		# Warrior or Rogue is entranced
		AudioManager.play_sfx("gold_chime", 0.0, 0.9)
		if target_enemy.has_method("apply_stun"):
			target_enemy.apply_stun(stun_duration)
			
		# Synthesize false memory of safe treasure
		MemoryManager.record_event(
			target_enemy.get_enemy_type() if target_enemy.has_method("get_enemy_type") else "Warrior",
			"FALSE_TREASURE",
			global_position,
			0.1,
			"Phantom riches inspected; area perceived as benign"
		)
		_dispel_effect(false)

func _dispel_effect(dispelled_by_mage: bool) -> void:
	var tw = create_tween()
	if dispelled_by_mage:
		tw.tween_property(aura_light, "light_energy", 4.0, 0.15)
		tw.tween_property(chest_visual, "scale", Vector3.ZERO, 0.25)
		tw.parallel().tween_property(aura_light, "light_energy", 0.0, 0.25)
	else:
		tw.tween_property(chest_visual, "scale", Vector3.ZERO, 0.8)
		tw.parallel().tween_property(aura_light, "light_energy", 0.0, 0.8)
	tw.tween_callback(func(): queue_free())
