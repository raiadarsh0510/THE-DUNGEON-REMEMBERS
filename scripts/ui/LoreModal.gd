extends PanelContainer

# LoreModal.gd: Comprehensive guide explaining game lore, mechanics, and jam context.

@onready var close_button: Button = %CloseButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if close_button:
		close_button.pressed.connect(close)

func open() -> void:
	visible = true

func close() -> void:
	visible = false
