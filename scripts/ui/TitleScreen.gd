extends Control

# TitleScreen.gd: Main Menu presenting title, game jam context, lore guide, and audio settings.

@onready var play_button: Button = %PlayButton
@onready var lore_button: Button = %LoreButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton

@onready var lore_modal: PanelContainer = %LoreModal
@onready var settings_modal: PanelContainer = %SettingsModal

var anim_time: float = 0.0

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	lore_button.pressed.connect(func(): lore_modal.open())
	settings_button.pressed.connect(func(): settings_modal.open())
	quit_button.pressed.connect(_on_quit_pressed)

func _process(delta: float) -> void:
	anim_time += delta
	queue_redraw()

func _on_play_pressed() -> void:
	AudioManager.play_sfx("heartbeat", 2.0, 1.1)
	GameManager.start_new_game()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _draw() -> void:
	# Subtle living ambient background pulse
	var pulse = (sin(anim_time * 2.2) + 1.0) * 0.5
	var center = Vector2(640, 240)
	
	# Concentric runic arcs
	var col_outer = Color(0.65, 0.1, 0.2, 0.12 + pulse * 0.08)
	var col_inner = Color(0.9, 0.2, 0.3, 0.18 + pulse * 0.12)
	draw_arc(center, 130.0 + pulse * 12.0, 0, TAU, 48, col_outer, 2.5)
	draw_arc(center, 90.0 + pulse * 8.0, 0, TAU, 36, col_inner, 2.0)
	draw_arc(center, 50.0 + pulse * 4.0, 0, TAU, 24, Color(1.0, 0.4, 0.5, 0.25 + pulse * 0.15), 1.5)
