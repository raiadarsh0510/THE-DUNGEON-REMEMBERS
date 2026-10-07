extends Node

# ResourceManager manages Gold, Essence, and Heart Energy.
# Follows locked MVP scope: strictly 3 resources.

const STARTING_GOLD: int = 100
const STARTING_ESSENCE: int = 25
const STARTING_HEART_ENERGY: int = 50

var gold: int = STARTING_GOLD
var essence: int = STARTING_ESSENCE
var heart_energy: int = STARTING_HEART_ENERGY

func _ready() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)
	emit_resource_update()

func reset_resources() -> void:
	gold = STARTING_GOLD
	essence = STARTING_ESSENCE
	heart_energy = STARTING_HEART_ENERGY
	emit_resource_update()

func add_gold(amount: int) -> void:
	gold += amount
	emit_resource_update()

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		emit_resource_update()
		return true
	return false

func add_essence(amount: int) -> void:
	essence += amount
	emit_resource_update()

func spend_essence(amount: int) -> bool:
	if essence >= amount:
		essence -= amount
		emit_resource_update()
		return true
	return false

func add_heart_energy(amount: int) -> void:
	heart_energy += amount
	emit_resource_update()

func spend_heart_energy(amount: int) -> bool:
	if heart_energy >= amount:
		heart_energy -= amount
		emit_resource_update()
		return true
	return false

func emit_resource_update() -> void:
	EventBus.resources_changed.emit(gold, essence, heart_energy)

func _on_enemy_died(_enemy: Node) -> void:
	# Gold and essence bounty from defeated invaders
	add_gold(30)
	add_essence(5)
