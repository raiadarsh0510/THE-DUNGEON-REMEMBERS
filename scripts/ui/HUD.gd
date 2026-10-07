extends CanvasLayer

# HUD.gd: Displays vital Dungeon stats, resources, wave status, bottom build bar,
# pause menu, settings/lore modals, and victory/defeat screens.

@onready var heart_bar: ProgressBar = %HeartBar
@onready var heart_label: Label = %HeartLabel
@onready var gold_label: Label = %GoldLabel
@onready var essence_label: Label = %EssenceLabel
@onready var energy_label: Label = %EnergyLabel
@onready var wave_label: Label = %WaveLabel
@onready var state_label: Label = %StateLabel
@onready var start_wave_button: Button = %StartWaveButton
@onready var memory_button: Button = %MemoryButton
@onready var memory_chamber: Control = %MemoryChamber
@onready var shift_button: Button = %ShiftButton
@onready var spike_button: Button = %SpikeButton
@onready var rock_button: Button = %RockButton
@onready var poison_button: Button = %PoisonButton
@onready var illusion_button: Button = %IllusionButton
@onready var goblin_button: Button = %GoblinButton
@onready var shadow_button: Button = %ShadowButton
@onready var mimic_button: Button = %MimicButton

@onready var pause_button: Button = %PauseButton
@onready var pause_panel: PanelContainer = %PausePanel
@onready var resume_button: Button = %ResumeButton
@onready var pause_lore_button: Button = %PauseLoreButton
@onready var pause_settings_button: Button = %PauseSettingsButton
@onready var pause_restart_button: Button = %PauseRestartButton
@onready var pause_title_button: Button = %PauseTitleButton

@onready var boss_banner: PanelContainer = %BossBanner
@onready var boss_title: Label = %BossTitle
@onready var boss_hp_bar: ProgressBar = %BossHPBar

@onready var game_over_panel: PanelContainer = %GameOverPanel
@onready var game_over_title: Label = %GameOverTitle
@onready var game_over_subtitle: Label = %GameOverSubtitle
@onready var stats_label: Label = %StatsLabel
@onready var restart_button: Button = %RestartButton
@onready var game_over_title_button: Button = %GameOverTitleButton
@onready var hint_label: Label = %HintLabel

@onready var lore_modal: PanelContainer = %LoreModal
@onready var settings_modal: PanelContainer = %SettingsModal

var wave_manager_ref: Node = null
var current_selected_item: String = "Spike Trap"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	EventBus.heart_damaged.connect(_on_heart_damaged)
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_over.connect(_on_game_over)
	EventBus.dungeon_shifted.connect(_on_dungeon_shifted)
	
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_damaged.connect(_on_boss_damaged)
	EventBus.boss_phase_changed.connect(_on_boss_phase_changed)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	
	start_wave_button.pressed.connect(_on_start_wave_pressed)
	memory_button.pressed.connect(_on_memory_button_pressed)
	shift_button.pressed.connect(_on_shift_button_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	game_over_title_button.pressed.connect(func(): GameManager.return_to_title())
	
	pause_button.pressed.connect(func(): GameManager.toggle_pause())
	resume_button.pressed.connect(func(): GameManager.toggle_pause())
	pause_lore_button.pressed.connect(func(): lore_modal.open())
	pause_settings_button.pressed.connect(func(): settings_modal.open())
	pause_restart_button.pressed.connect(func(): GameManager.restart_game())
	pause_title_button.pressed.connect(func(): GameManager.return_to_title())
	
	spike_button.pressed.connect(func(): _select_item("Spike Trap", "Spike Trap (40G): High puncture damage when stepped on."))
	rock_button.pressed.connect(func(): _select_item("Falling Rock", "Falling Rock (60G): Massive area crush damage + 1.2s stun."))
	poison_button.pressed.connect(func(): _select_item("Poison Fog", "Poison Fog (50G): Toxic gas cloud dealing damage over time."))
	illusion_button.pressed.connect(func(): _select_item("Illusion Trap", "Illusion Trap (35G): Injects false high-danger memory to scare enemies!"))
	
	goblin_button.pressed.connect(func(): _select_item("Goblin", "Goblin (40G, 5E): Melee minion interceptor."))
	shadow_button.pressed.connect(func(): _select_item("Shadow Beast", "Shadow Beast (70G, 10E): Swift stalker with lethal pounce attacks."))
	mimic_button.pressed.connect(func(): _select_item("Mimic", "Mimic (60G, 15E): Disguised chest that springs lethal ambush surprise!"))
	
	_select_item("Spike Trap", "Click floor corridor to place Spike Trap (40G).")
	
	game_over_panel.visible = false
	pause_panel.visible = false
	_update_resources(ResourceManager.gold, ResourceManager.essence, ResourceManager.heart_energy)

func _select_item(item_name: String, desc: String) -> void:
	current_selected_item = item_name
	var dungeons = get_tree().get_nodes_in_group("dungeon")
	if dungeons.size() > 0 and dungeons[0].has_method("set_selected_build_item"):
		dungeons[0].set_selected_build_item(item_name)
	
	hint_label.text = "[Selected: %s] %s" % [item_name, desc]
	
	# Visual highlight on selected button
	var buttons = {
		"Spike Trap": spike_button,
		"Falling Rock": rock_button,
		"Poison Fog": poison_button,
		"Illusion Trap": illusion_button,
		"Goblin": goblin_button,
		"Shadow Beast": shadow_button,
		"Mimic": mimic_button
	}
	for b_name in buttons:
		if buttons[b_name]:
			if b_name == item_name:
				buttons[b_name].modulate = Color(1.3, 1.3, 0.8)
			else:
				buttons[b_name].modulate = Color(1.0, 1.0, 1.0)

func _on_shift_button_pressed() -> void:
	EventBus.dungeon_shift_requested.emit()

func _on_dungeon_shifted(is_shifted: bool) -> void:
	if is_shifted:
		shift_button.text = "SHIFT ACTIVE (10s)"
		shift_button.modulate = Color(1.0, 0.4, 1.0)
		hint_label.text = "LIVING DUNGEON SHIFT ACTIVE: North Flank blocked! Invaders forced to reroute."
	else:
		shift_button.text = "DUNGEON SHIFT (15E)"
		shift_button.modulate = Color(1.0, 1.0, 1.0)
		hint_label.text = "Dungeon Shift normalized. Corridors reopened."

func _on_memory_button_pressed() -> void:
	if memory_chamber:
		memory_chamber.toggle()

func setup(wave_mgr: Node) -> void:
	wave_manager_ref = wave_mgr
	update_wave_info(wave_manager_ref.current_wave, "PREPARATION")

func _on_heart_damaged(current_hp: float, max_hp: float, damage: float) -> void:
	heart_bar.max_value = max_hp
	heart_bar.value = current_hp
	heart_label.text = "HEART HP: %d / %d" % [int(current_hp), int(max_hp)]
	if damage > 0:
		heart_bar.modulate = Color(2.0, 0.4, 0.4)
		var tween = create_tween()
		tween.tween_property(heart_bar, "modulate", Color.WHITE, 0.3)

func _on_resources_changed(gold: int, essence: int, energy: int) -> void:
	_update_resources(gold, essence, energy)

func _update_resources(gold: int, essence: int, energy: int) -> void:
	gold_label.text = "Gold: %d" % gold
	essence_label.text = "Essence: %d" % essence
	energy_label.text = "Energy: %d" % energy

func _on_wave_started(wave_number: int) -> void:
	update_wave_info(wave_number, "COMBAT IN PROGRESS")
	start_wave_button.disabled = true
	start_wave_button.text = "Wave %d Active" % wave_number
	hint_label.text = "Watch the invaders navigate towards the Heart!"

func _on_wave_completed(wave_number: int) -> void:
	update_wave_info(wave_number + 1, "PREPARATION")
	start_wave_button.disabled = false
	start_wave_button.text = "Start Wave %d" % (wave_number + 1)
	hint_label.text = "Prep: Select and place Traps or Minions on floor corridors. Press [M] for Memory Chamber. [Esc] to Pause."

func update_wave_info(wave: int, state_str: String) -> void:
	wave_label.text = "WAVE: %d / 5" % wave
	state_label.text = "STATE: %s" % state_str

func _on_game_state_changed(new_state: String) -> void:
	state_label.text = "STATE: %s" % new_state

func _on_start_wave_pressed() -> void:
	if wave_manager_ref:
		wave_manager_ref.start_next_wave()

func _on_restart_pressed() -> void:
	GameManager.restart_game()

func _on_game_paused(is_paused: bool) -> void:
	pause_panel.visible = is_paused

func _on_game_over(victory: bool) -> void:
	game_over_panel.visible = true
	if victory:
		game_over_title.text = "THE DUNGEON ENDURES!"
		game_over_title.modulate = Color(0.2, 0.95, 0.35)
		if game_over_subtitle:
			game_over_subtitle.text = "The Grand Inquisitor has fallen. Your living halls stand unconquered!"
	else:
		game_over_title.text = "THE LIVING NUCLEUS FELL..."
		game_over_title.modulate = Color(0.95, 0.2, 0.2)
		if game_over_subtitle:
			game_over_subtitle.text = "The invaders breached your Heart. Reincarnate your living dungeon to adapt."
	
	if stats_label:
		stats_label.text = "WAVES SURVIVED: %d / 5   |   INVADERS SLAIN: %d\nTRAPS TRIGGERED: %d   |   MEMORIES RECORDED: %d\nTOTAL GOLD HARVESTED: %d G" % [
			GameManager.stats_waves_survived,
			GameManager.stats_invaders_slain,
			GameManager.stats_traps_triggered,
			GameManager.stats_memories_formed,
			GameManager.stats_gold_harvested
		]

func _on_boss_spawned(boss: Node2D) -> void:
	boss_banner.visible = true
	boss_hp_bar.max_value = boss.max_hp
	boss_hp_bar.value = boss.current_hp
	boss_title.text = "THE GRAND INQUISITOR AURELIUS (PHASE 1)"
	boss_title.modulate = Color(1.0, 0.85, 0.25)
	hint_label.text = "FINAL INVASION: The Grand Inquisitor has breached the dungeon! Defend the Heart!"

func _on_boss_damaged(current_val: float, _max_val: float) -> void:
	boss_hp_bar.value = current_val

func _on_boss_phase_changed(phase: int) -> void:
	if phase == 2:
		boss_title.text = "ZEALOT'S WRATH: THE INQUISITOR UNLEASHED (PHASE 2)"
		boss_title.modulate = Color(1.0, 0.3, 0.2)
		hint_label.text = "CRITICAL: The Inquisitor has entered Fanatic Rage! Move speed and attack damage increased!"

func _on_boss_defeated() -> void:
	boss_banner.visible = false
	hint_label.text = "VICTORY! The Grand Inquisitor has fallen! The living dungeon remembers all!"
