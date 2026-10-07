extends CanvasLayer

# HUD3D: Dark-fantasy 3D strategic interface for "The Dungeon Remembers"
# Features: Real-time Vitality, Currency counters, Wave state, Defeat/Victory overlays with
# comprehensive run statistics, interactive Memory Chamber modal, Pause modal, Lore & Settings,
# and Bottom Tactical Control Bar (Traps, Minions, Living Dungeon Shift).

@onready var hp_bar: ProgressBar = $TopBar/HeartContainer/VBox/HPBar
@onready var hp_label: Label = $TopBar/HeartContainer/VBox/HPLabel
@onready var gold_label: Label = $TopBar/ResourceContainer/HBox/GoldLabel
@onready var essence_label: Label = $TopBar/ResourceContainer/HBox/EssenceLabel
@onready var energy_label: Label = $TopBar/ResourceContainer/HBox/EnergyLabel
@onready var wave_label: Label = $TopBar/WaveContainer/VBox/WaveLabel
@onready var enemies_label: Label = $TopBar/WaveContainer/VBox/EnemiesLabel

@onready var memory_btn: Button = $TopBar/MemoryBtn
@onready var start_wave_btn: Button = $TopBar/StartWaveBtn
@onready var pause_btn: Button = $TopBar/PauseBtn

@onready var memory_modal: PanelContainer = $MemoryModal
@onready var memory_list_label: Label = $MemoryModal/VBox/Scroll/MemoryListLabel
@onready var adaptation_label: Label = $MemoryModal/VBox/AdaptationStatusLabel
@onready var close_memory_btn: Button = $MemoryModal/VBox/CloseBtn

# Bottom Tactical Control Bar
@onready var build_spike_btn: Button = $BottomBar/HBox/BuildSpikeBtn
@onready var build_rock_btn: Button = $BottomBar/HBox/BuildRockBtn
@onready var build_poison_btn: Button = $BottomBar/HBox/BuildPoisonBtn
@onready var build_illusion_btn: Button = $BottomBar/HBox/BuildIllusionBtn
@onready var summon_goblin_btn: Button = $BottomBar/HBox/SummonGoblinBtn
@onready var summon_shadow_btn: Button = $BottomBar/HBox/SummonShadowBtn
@onready var summon_mimic_btn: Button = $BottomBar/HBox/SummonMimicBtn
@onready var shift_btn: Button = $BottomBar/HBox/ShiftBtn

# Modals & Overlays
@onready var pause_panel: PanelContainer = $PausePanel
@onready var resume_btn: Button = $PausePanel/PauseVBox/ResumeBtn
@onready var pause_lore_btn: Button = $PausePanel/PauseVBox/LoreBtn
@onready var pause_settings_btn: Button = $PausePanel/PauseVBox/SettingsBtn
@onready var pause_restart_btn: Button = $PausePanel/PauseVBox/RestartBtn
@onready var pause_title_btn: Button = $PausePanel/PauseVBox/TitleBtn

@onready var defeat_panel: PanelContainer = $DefeatPanel
@onready var defeat_stats_label: Label = $DefeatPanel/VBox/StatsLabel
@onready var restart_btn_defeat: Button = $DefeatPanel/VBox/HBox/RestartBtn
@onready var title_btn_defeat: Button = $DefeatPanel/VBox/HBox/TitleBtn

@onready var victory_panel: PanelContainer = $VictoryPanel
@onready var victory_stats_label: Label = $VictoryPanel/VBox/StatsLabel
@onready var restart_btn_victory: Button = $VictoryPanel/VBox/HBox/RestartBtn
@onready var title_btn_victory: Button = $VictoryPanel/VBox/HBox/TitleBtn

@onready var lore_modal: PanelContainer = $LoreModal
@onready var settings_modal: PanelContainer = $SettingsModal

var trap_cycle_index: int = 0
var minion_cycle_index: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	defeat_panel.visible = false
	victory_panel.visible = false
	memory_modal.visible = false
	pause_panel.visible = false
	lore_modal.visible = false
	settings_modal.visible = false
	
	EventBus.heart_damaged.connect(_on_heart_damaged)
	EventBus.heart_destroyed.connect(_on_heart_destroyed)
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.enemy_adapted.connect(_on_enemy_adapted)
	EventBus.dungeon_shifted.connect(_on_dungeon_shifted)
	EventBus.memory_created.connect(func(_m): update_memory_display())
	EventBus.memory_updated.connect(func(_m): update_memory_display())
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_over.connect(_on_game_over)
	
	# Top bar buttons
	memory_btn.pressed.connect(toggle_memory_chamber)
	close_memory_btn.pressed.connect(toggle_memory_chamber)
	start_wave_btn.pressed.connect(_on_start_wave_pressed)
	pause_btn.pressed.connect(func(): GameManager.toggle_pause())
	
	# Pause buttons
	resume_btn.pressed.connect(func(): GameManager.toggle_pause())
	pause_lore_btn.pressed.connect(func(): lore_modal.open())
	pause_settings_btn.pressed.connect(func(): settings_modal.open())
	pause_restart_btn.pressed.connect(func(): EventBus.request_game_restart.emit())
	pause_title_btn.pressed.connect(func(): GameManager.return_to_title())
	
	# Game Over buttons
	restart_btn_defeat.pressed.connect(func(): EventBus.request_game_restart.emit())
	title_btn_defeat.pressed.connect(func(): GameManager.return_to_title())
	restart_btn_victory.pressed.connect(func(): EventBus.request_game_restart.emit())
	title_btn_victory.pressed.connect(func(): GameManager.return_to_title())
	
	# Tactical construction buttons
	build_spike_btn.pressed.connect(func(): _place_trap("spike", 40))
	build_rock_btn.pressed.connect(func(): _place_trap("rock", 60))
	build_poison_btn.pressed.connect(func(): _place_trap("poison", 50))
	build_illusion_btn.pressed.connect(func(): _place_trap("illusion", 35))
	
	summon_goblin_btn.pressed.connect(func(): _place_minion("goblin", 40))
	summon_shadow_btn.pressed.connect(func(): _place_minion("shadow", 70))
	summon_mimic_btn.pressed.connect(func(): _place_minion("mimic", 60))
	
	shift_btn.pressed.connect(func(): EventBus.dungeon_shift_requested.emit())
	
	_on_resources_changed(ResourceManager.gold, ResourceManager.essence, ResourceManager.heart_energy)
	update_heart_display(100.0, 100.0)
	update_memory_display()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_M:
			toggle_memory_chamber()
		elif event.keycode == KEY_SPACE and start_wave_btn.visible:
			_on_start_wave_pressed()

func _on_start_wave_pressed() -> void:
	var main = get_tree().get_first_node_in_group("main")
	if not main:
		main = get_parent()
	if main and main.has_method("start_next_wave"):
		main.start_next_wave()
		start_wave_btn.visible = false

func _place_trap(type_name: String, cost: int) -> void:
	if ResourceManager.spend_gold(cost):
		var dungeon = get_tree().get_first_node_in_group("dungeon")
		if dungeon and dungeon.has_method("spawn_trap"):
			var positions = [
				Vector3(0.0, 0.0, 3.0),
				Vector3(6.5, 0.0, 3.0),
				Vector3(-6.5, 0.0, 3.0),
				Vector3(0.0, 0.0, 6.0),
				Vector3(0.0, 0.0, -1.0)
			]
			var pos = positions[trap_cycle_index % positions.size()]
			trap_cycle_index += 1
			dungeon.spawn_trap(type_name, pos)
			AudioManager.play_sfx("place_item")

func _place_minion(type_name: String, cost: int) -> void:
	if ResourceManager.spend_gold(cost):
		var dungeon = get_tree().get_first_node_in_group("dungeon")
		if dungeon and dungeon.has_method("spawn_defender"):
			var positions = [
				Vector3(2.5, 0.0, 2.0),
				Vector3(-2.5, 0.0, 2.0),
				Vector3(0.0, 0.0, -3.0),
				Vector3(5.0, 0.0, 0.0),
				Vector3(-5.0, 0.0, 0.0)
			]
			var pos = positions[minion_cycle_index % positions.size()]
			minion_cycle_index += 1
			dungeon.spawn_defender(type_name, pos)
			AudioManager.play_sfx("place_item")

func _on_dungeon_shifted(is_shifted: bool) -> void:
	if is_shifted:
		shift_btn.text = "LIVING SHIFT: [BARRIER RAISED]"
		shift_btn.modulate = Color(1.0, 0.4, 0.3, 1.0)
	else:
		shift_btn.text = "DUNGEON SHIFT (15E)"
		shift_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)

func toggle_memory_chamber() -> void:
	memory_modal.visible = not memory_modal.visible
	if memory_modal.visible:
		update_memory_display()
	EventBus.memory_chamber_toggled.emit(memory_modal.visible)

func update_memory_display() -> void:
	var memories = MemoryManager.get_all_memories()
	if memories.is_empty():
		memory_list_label.text = "No invader memories recorded yet.\nInvaders remain in ignorance."
		adaptation_label.text = "ADAPTATION STATE: IGNORANCE (Direct Pathing)"
		return
		
	var text_lines: Array[String] = []
	for mem in memories:
		var loc = mem["location"]
		var loc_str = "(%d, %d)" % [int(loc.x), int(loc.z)] if loc is Vector3 else "(%d, %d)" % [int(loc.x), int(loc.y)]
		var conf_pct = int(mem["confidence"] * 100.0)
		var danger_pct = int(mem.get("danger_score", 0.85) * 100.0)
		
		text_lines.append("ENEMY: %s" % mem["enemy_type"].to_upper())
		text_lines.append("  Memory: \"%s\"" % mem.get("description", "Hazard detected"))
		text_lines.append("  Location: %s | Danger: %d%% | Confidence: %d%%" % [loc_str, danger_pct, conf_pct])
		text_lines.append("  Encounter Count: %d | Last Wave: %d" % [mem["encounter_count"], mem["last_wave"]])
		text_lines.append("--------------------------------------------------")
		
	memory_list_label.text = "\n".join(text_lines)
	
	if not MemoryManager.last_adaptation_event.is_empty():
		var ad = MemoryManager.last_adaptation_event
		adaptation_label.text = "ADAPTATION DECISION: [!] %s\nSelecting: %s (Danger Score: %.1f)" % [
			ad.get("reason", "Rerouted based on remembered trap"),
			ad.get("route", "Alternate Flank").to_upper(),
			ad.get("danger", 0.0)
		]
	else:
		adaptation_label.text = "ADAPTATION STATE: ACTIVE MEMORY SYNTHESIS"

func _on_enemy_adapted(_enemy: Node, reason: String) -> void:
	adaptation_label.text = "LAST ADAPTATION: " + reason
	if memory_modal.visible:
		update_memory_display()

func update_heart_display(curr_hp: float, max_hp: float) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = curr_hp
	hp_label.text = "HEART CORE: %d / %d" % [int(curr_hp), int(max_hp)]

func _on_heart_damaged(curr_hp: float, max_hp: float, _dmg: float) -> void:
	update_heart_display(curr_hp, max_hp)

func _on_heart_destroyed() -> void:
	update_heart_display(0.0, 100.0)

func _on_resources_changed(gold: int, essence: int, energy: int) -> void:
	gold_label.text = "GOLD: %d" % gold
	essence_label.text = "ESSENCE: %d" % essence
	energy_label.text = "ENERGY: %d" % energy

func _on_wave_started(wave_num: int) -> void:
	var titles = ["IGNORANCE", "RECOGNITION", "ADAPTATION", "PREDICTION", "DUNGEON BREAKER"]
	var title = titles[wave_num - 1] if wave_num <= titles.size() else "ASSAULT"
	wave_label.text = "WAVE %d: %s" % [wave_num, title]
	enemies_label.text = "ENEMIES: INCOMING"
	start_wave_btn.visible = false

func _on_wave_completed(wave_num: int) -> void:
	wave_label.text = "WAVE %d CLEARED" % wave_num
	enemies_label.text = "ENEMIES: 0"
	if wave_num < 5:
		start_wave_btn.text = "START WAVE %d" % (wave_num + 1)
		start_wave_btn.visible = true

func update_enemies_count(count: int) -> void:
	enemies_label.text = "ENEMIES: %d" % count

func _on_game_paused(is_paused: bool) -> void:
	pause_panel.visible = is_paused

func _on_game_over(victory: bool) -> void:
	var stats_str = "WAVES SURVIVED: %d\nINVADERS SLAIN: %d\nTRAPS TRIGGERED: %d\nMEMORIES FORMED: %d\nTOTAL GOLD HARVESTED: %d G" % [
		GameManager.stats_waves_survived,
		GameManager.stats_invaders_slain,
		GameManager.stats_traps_triggered,
		GameManager.stats_memories_formed,
		GameManager.stats_gold_harvested
	]
	
	if victory:
		victory_stats_label.text = stats_str
		victory_panel.visible = true
	else:
		defeat_stats_label.text = stats_str
		defeat_panel.visible = true
