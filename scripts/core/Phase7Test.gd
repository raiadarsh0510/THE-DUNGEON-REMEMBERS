extends Node

# Phase7Test.gd: In-engine automated validation for Phase 7 (Complete Game Loop & Menus)
# Tests Title Screen, Settings Modal, Lore Modal, Pause System, Statistics Tracking,
# and Victory/Defeat screen presentation.

func _ready() -> void:
	print("==========================================")
	print(" RUNNING PHASE 7 TEST SUITE (IN-ENGINE)   ")
	print("==========================================")
	
	_test_1_title_screen_and_modals()
	_test_2_settings_and_lore_modals()
	await _test_3_pause_system_and_hud()
	_test_4_run_statistics_tracking()
	_test_5_victory_defeat_presentation()
	
	print("==========================================")
	print(" ALL PHASE 7 ACCEPTANCE TESTS PASSED (100%)")
	print("==========================================")
	
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0)

func _fail(reason: String) -> void:
	printerr("[FAIL] " + reason)
	get_tree().quit(1)

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] " + message)
	else:
		_fail(message)

var title_instance: Control = null

func _test_1_title_screen_and_modals() -> void:
	print("\n--- TEST 1: Title Screen Instantiation & UI Elements ---")
	var title_scene = load("res://scenes/ui/TitleScreen.tscn")
	_assert(title_scene != null, "TitleScreen.tscn loaded successfully.")
	
	title_instance = title_scene.instantiate()
	add_child(title_instance)
	_assert(title_instance != null, "TitleScreen instantiated into scene tree.")
	
	_assert(title_instance.play_button != null, "AWAKEN DUNGEON play button present.")
	_assert(title_instance.lore_button != null, "LORE & TACTICS button present.")
	_assert(title_instance.settings_button != null, "AUDIO & SETTINGS button present.")
	_assert(title_instance.quit_button != null, "QUIT TO DESKTOP button present.")
	
	# Verify TitleScreen animated draw function
	title_instance._process(0.16)
	_assert(title_instance.anim_time > 0.0, "Background pulse animation active.")

func _test_2_settings_and_lore_modals() -> void:
	print("\n--- TEST 2: Settings & Lore Modals Verification ---")
	var settings = title_instance.settings_modal
	var lore = title_instance.lore_modal
	
	_assert(settings != null, "SettingsModal embedded in TitleScreen.")
	_assert(lore != null, "LoreModal embedded in TitleScreen.")
	
	# Test Settings modal
	settings.open()
	_assert(settings.visible, "Settings modal opened successfully.")
	
	# Test Volume Slider adjustment
	settings._on_volume_changed(75.0)
	_assert(is_equal_approx(AudioManager.master_volume, 0.75), "Master volume updated to 75% via modal.")
	
	# Test Mute toggle
	settings._on_mute_toggled(true)
	_assert(AudioManager.is_muted == true, "Audio muted via modal toggle.")
	settings._on_mute_toggled(false)
	_assert(AudioManager.is_muted == false, "Audio unmuted via modal toggle.")
	
	# Test Screen Shake toggle
	settings._on_shake_toggled(false)
	_assert(GameManager.screen_shake_enabled == false, "Screen shake disabled via modal toggle.")
	settings._on_shake_toggled(true)
	_assert(GameManager.screen_shake_enabled == true, "Screen shake re-enabled via modal toggle.")
	
	settings.close()
	_assert(not settings.visible, "Settings modal closed successfully.")
	
	# Test Lore modal
	lore.open()
	_assert(lore.visible, "Lore modal opened successfully.")
	lore.close()
	_assert(not lore.visible, "Lore modal closed successfully.")
	
	# Clean up title instance before main game test
	title_instance.queue_free()

var main_instance: Node2D = null

func _test_3_pause_system_and_hud() -> void:
	print("\n--- TEST 3: In-Game Pause System & HUD Integration ---")
	var main_scene = load("res://scenes/main/Main.tscn")
	_assert(main_scene != null, "Main.tscn loaded successfully.")
	
	main_instance = main_scene.instantiate()
	add_child(main_instance)
	await get_tree().process_frame
	
	var hud = main_instance.hud
	_assert(hud != null, "HUD present in Main scene.")
	_assert(hud.pause_panel != null, "PausePanel present in HUD.")
	_assert(not hud.pause_panel.visible, "PausePanel is hidden initially.")
	
	# Trigger pause
	GameManager.toggle_pause()
	_assert(get_tree().paused == true, "Game engine paused.")
	_assert(hud.pause_panel.visible == true, "PausePanel visible while paused.")
	
	# Resume pause
	GameManager.toggle_pause()
	_assert(get_tree().paused == false, "Game engine unpaused.")
	_assert(hud.pause_panel.visible == false, "PausePanel hidden upon resumption.")

func _test_4_run_statistics_tracking() -> void:
	print("\n--- TEST 4: Run Statistics Tracking ---")
	GameManager.reset_stats()
	_assert(GameManager.stats_invaders_slain == 0, "Stats reset confirmed.")
	
	# Simulate enemy defeated with gold bounty
	var dummy_enemy = Node2D.new()
	dummy_enemy.set_meta("gold_bounty", 40)
	EventBus.enemy_died.emit(dummy_enemy)
	dummy_enemy.queue_free()
	
	_assert(GameManager.stats_invaders_slain == 1, "Invader slain incremented to 1.")
	_assert(GameManager.stats_gold_harvested == 40, "Gold harvested tracked 40G.")
	
	# Simulate trap trigger at distinct corridor coordinates
	EventBus.trap_triggered.emit("Spike Trap", Vector2(100, 100), null)
	EventBus.trap_triggered.emit("Falling Rock", Vector2(300, 300), null)
	_assert(GameManager.stats_traps_triggered == 2, "Traps triggered incremented to 2.")
	
	# Verify distinct memories were formed from trap triggers
	_assert(GameManager.stats_memories_formed >= 2, "Memories recorded incremented to %d." % GameManager.stats_memories_formed)
	
	# Simulate wave completed
	EventBus.wave_completed.emit(4)
	_assert(GameManager.stats_waves_survived == 4, "Waves survived reached 4.")

func _test_5_victory_defeat_presentation() -> void:
	print("\n--- TEST 5: Victory & Defeat Presentation with Statistics ---")
	var hud = main_instance.hud
	
	# Test Victory presentation
	EventBus.game_over.emit(true)
	_assert(hud.game_over_panel.visible == true, "Game Over panel visible on Victory.")
	_assert(hud.game_over_title.text == "THE DUNGEON ENDURES!", "Victory title text verified.")
	_assert(hud.stats_label != null and hud.stats_label.text.contains("WAVES SURVIVED: 4"), "Stats label reflects Wave 4.")
	_assert(hud.stats_label.text.contains("INVADERS SLAIN: 1"), "Stats label reflects 1 invader slain.")
	_assert(hud.stats_label.text.contains("TOTAL GOLD HARVESTED: 40 G"), "Stats label reflects 40 Gold harvested.")
	_assert(hud.restart_button != null, "Reincarnate button available.")
	_assert(hud.game_over_title_button != null, "Return to Title button available.")
	
	# Test Defeat presentation
	EventBus.game_over.emit(false)
	_assert(hud.game_over_title.text == "THE LIVING NUCLEUS FELL...", "Defeat title text verified.")
	
	# Clean up
	main_instance.queue_free()
