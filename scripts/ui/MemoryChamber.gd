extends Control

# MemoryChamber.gd: Inspects what the invaders have learned and how they are adapting.
# "The dungeon remembers what the enemy learned."

@onready var memory_list: VBoxContainer = %MemoryListContainer
@onready var empty_label: Label = %EmptyStateLabel
@onready var close_button: Button = %CloseButton

func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	EventBus.memory_created.connect(_on_memory_changed)
	EventBus.memory_updated.connect(_on_memory_changed)
	EventBus.memory_decayed.connect(_on_memory_changed)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_M:
			toggle()
		elif event.keycode == KEY_ESCAPE and visible:
			close()

func toggle() -> void:
	visible = not visible
	if visible:
		refresh_memories()
	EventBus.memory_chamber_toggled.emit(visible)

func open() -> void:
	visible = true
	refresh_memories()
	EventBus.memory_chamber_toggled.emit(true)

func close() -> void:
	visible = false
	EventBus.memory_chamber_toggled.emit(false)

func _on_memory_changed(_mem: Dictionary) -> void:
	if visible:
		refresh_memories()

func refresh_memories() -> void:
	# Clear existing dynamic items
	for child in memory_list.get_children():
		child.queue_free()
	
	var all_mems = MemoryManager.get_all_memories()
	
	if all_mems.is_empty():
		empty_label.visible = true
		return
	
	empty_label.visible = false
	
	for mem in all_mems:
		var card = _create_memory_card(mem)
		memory_list.add_child(card)

func _create_memory_card(mem: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.13, 0.17, 0.95)
	style.border_color = Color(0.5, 0.35, 0.7, 0.8)
	style.border_width_left = 3
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	
	# Header line: Invader type + Event type
	var header = HBoxContainer.new()
	var title = Label.new()
	title.text = "[%s] %s" % [mem.get("enemy_type", "Warrior").to_upper(), mem.get("event_type", "EVENT").replace("_", " ")]
	title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	title.add_theme_font_size_override("font_size", 14)
	header.add_child(title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	var encounters = Label.new()
	encounters.text = "Encounters: %d" % mem.get("encounter_count", 1)
	encounters.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	encounters.add_theme_font_size_override("font_size", 12)
	header.add_child(encounters)
	vbox.add_child(header)
	
	# Location and details
	var loc_label = Label.new()
	var loc = mem.get("location", Vector2.ZERO)
	loc_label.text = "Hazard Location: (%d, %d) | Recorded Wave: %d" % [int(loc.x), int(loc.y), mem.get("created_wave", 1)]
	loc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	loc_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(loc_label)
	
	# Confidence bar
	var conf_box = HBoxContainer.new()
	var conf_text = Label.new()
	var conf_val = mem.get("confidence", 1.0)
	conf_text.text = "Memory Confidence: %d%%" % int(conf_val * 100.0)
	conf_text.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	conf_text.add_theme_font_size_override("font_size", 12)
	conf_box.add_child(conf_text)
	
	var conf_bar = ProgressBar.new()
	conf_bar.custom_minimum_size = Vector2(160, 14)
	conf_bar.max_value = 1.0
	conf_bar.value = conf_val
	conf_bar.show_percentage = false
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.2, 0.8, 0.4) if conf_val >= 0.7 else (Color(0.9, 0.7, 0.2) if conf_val >= 0.4 else Color(0.9, 0.3, 0.3))
	conf_bar.add_theme_stylebox_override("fill", bar_fill)
	conf_box.add_child(conf_bar)
	vbox.add_child(conf_box)
	
	# Adaptation impact
	var adapt_label = Label.new()
	adapt_label.text = "Strategic Adaptation: Enemies remember this hazard and divert path via bypass corridors."
	adapt_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))
	adapt_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(adapt_label)
	
	return panel
