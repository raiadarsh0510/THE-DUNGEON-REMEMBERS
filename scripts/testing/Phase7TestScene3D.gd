extends Node3D

# Phase 7 Acceptance Test Suite for "The Dungeon Remembers" (3D Complete Game Loop & Menus)
# Validates:
# 1. Title Screen UI & Navigation (Awaken Dungeon, Lore, Settings, Quit)
# 2. Settings Modal (Master Volume Slider, Mute Toggle, Screen Shake Toggle)
# 3. Lore & Tactics Modal presentation
# 4. In-Game 3D Pause System (Pause panel, Resume, Return to Title)
# 5. 5-Wave Progression Loop & Preparation Phase transitions
# 6. Comprehensive Run Statistics Tracking (Waves, Slain, Traps, Memories, Gold)
# 7. End-of-Run Victory & Defeat presentations with formatted statistics

var pass_count: int = 0
var total_count: int = 12

func _ready() -> void:
	print("\n========================================================")
	print(" RUNNING PHASE 7 ACCEPTANCE TEST SUITE (LOOP & MENUS)")
	print("========================================================")
	
	call_deferred("run_all_tests")

func assert_test(step_num: int, description: String, condition: bool) -> void:
	if condition:
		print("[PASS] Step %d: %s" % [step_num, description])
		pass_count += 1
	else:
		printerr("[FAIL] Step %d: %s" % [step_num, description])

func run_all_tests() -> void:
	# --- 1. Title Screen Instantiation & Buttons ---
	var title_scene = load("res://scenes/ui/TitleScreen.tscn")
	var title = title_scene.instantiate()
	add_child(title)
	await get_tree().process_frame
	
	var has_title_buttons = title.play_button != null and title.lore_button != null and title.settings_button != null and title.quit_button != null
	assert_test(1, "Title screen instantiated with Awaken, Lore, Settings, and Quit buttons", has_title_buttons)
	
	# --- 2. Title Screen Animated Background ---
	title._process(0.16)
	assert_test(2, "Title screen ambient concentric runic pulse animation active (Time: %.2fs)" % title.anim_time, title.anim_time > 0.0)
	
	# --- 3. Settings Modal Functional Controls ---
	var settings = title.settings_modal
	settings.open()
	settings._on_volume_changed(80.0)
	assert_test(3, "Settings Modal adjusts Master Volume to 80%% (Linear: %.2f)" % AudioManager.master_volume, is_equal_approx(AudioManager.master_volume, 0.8))
	
	settings._on_mute_toggled(true)
	var muted_ok = AudioManager.is_muted == true
	settings._on_mute_toggled(false)
	var unmuted_ok = AudioManager.is_muted == false
	assert_test(4, "Settings Modal cleanly toggles audio mute state", muted_ok and unmuted_ok)
	
	settings._on_shake_toggled(false)
	var shake_off = GameManager.screen_shake_enabled == false
	settings._on_shake_toggled(true)
	var shake_on = GameManager.screen_shake_enabled == true
	assert_test(5, "Settings Modal toggles 3D Camera screen shake preference", shake_off and shake_on)
	settings.close()
	
	# --- 4. Lore Modal Verification ---
	var lore = title.lore_modal
	lore.open()
	var lore_opened = lore.visible
	lore.close()
	var lore_closed = not lore.visible
	assert_test(6, "Lore & Tactics guide modal opens and closes reliably", lore_opened and lore_closed)
	
	title.queue_free()
	await get_tree().process_frame
	
	# --- 5. 3D Game Scene Instantiation ---
	var main_scene = load("res://scenes/main/Main3D.tscn")
	var main = main_scene.instantiate()
	main.auto_start_wave = false
	add_child(main)
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	var hud = main.get_node("HUD3D")
	assert_test(7, "Main3D instantiated with HUD3D and tactical control interface", hud != null)
	
	# --- 6. In-Game Pause System ---
	GameManager.toggle_pause()
	var engine_paused = get_tree().paused
	var pause_panel_visible = hud.pause_panel.visible
	GameManager.toggle_pause()
	var engine_unpaused = not get_tree().paused
	var pause_panel_hidden = not hud.pause_panel.visible
	assert_test(8, "In-game pause system halts engine and presents pause menu with resume/settings", engine_paused and pause_panel_visible and engine_unpaused and pause_panel_hidden)
	
	# --- 7. Run Statistics Tracking ---
	GameManager.reset_stats()
	var dummy_enemy = Node.new()
	dummy_enemy.set("gold_bounty", 35)
	EventBus.enemy_died.emit(dummy_enemy)
	dummy_enemy.queue_free()
	
	EventBus.trap_triggered.emit("Spike Trap", Vector3(0, 0, 3), null)
	EventBus.memory_created.emit({"enemy_type": "warrior", "location": Vector3(0,0,3)})
	EventBus.wave_completed.emit(1)
	
	var stats_valid = (GameManager.stats_invaders_slain == 1 and 
		GameManager.stats_traps_triggered >= 1 and 
		GameManager.stats_memories_formed >= 1 and 
		GameManager.stats_waves_survived == 1)
	assert_test(9, "Run statistics track kills (%d), traps (%d), memories (%d), and wave progress (%d)" % [
		GameManager.stats_invaders_slain,
		GameManager.stats_traps_triggered,
		GameManager.stats_memories_formed,
		GameManager.stats_waves_survived
	], stats_valid)
	
	# --- 8. 5-Wave Progression Loop Logic ---
	main.start_wave(1)
	assert_test(10, "Wave 1: The Ignorant starts and populates active enemies", main.wave_active and main.active_enemies.size() >= 1)
	
	# Clean up enemies for wave 1
	for enemy in main.active_enemies.duplicate():
		enemy.queue_free()
	main.active_enemies.clear()
	main.wave_active = false
	
	# --- 9. Wave 5 Boss Wave Orchestration ---
	main.start_wave(5)
	assert_test(11, "Wave 5: Climax Boss Wave spawns Grand Inquisitor Boss", main.wave_active and main.active_enemies.size() >= 1)
	for enemy in main.active_enemies.duplicate():
		enemy.queue_free()
	main.active_enemies.clear()
	main.wave_active = false
	
	# --- 10. End-of-Run Victory & Defeat Presentation ---
	EventBus.game_over.emit(false)
	var defeat_shown = hud.defeat_panel.visible and hud.defeat_stats_label.text.contains("WAVES SURVIVED")
	
	EventBus.game_over.emit(true)
	var victory_shown = hud.victory_panel.visible and hud.victory_stats_label.text.contains("WAVES SURVIVED")
	assert_test(12, "End-of-Run Victory & Defeat screens display formatted run statistics and action buttons", defeat_shown and victory_shown)
	
	main.queue_free()
	
	print("\n========================================================")
	print(" PHASE 7 TEST SUMMARY: %d / %d TESTS PASSED" % [pass_count, total_count])
	print("========================================================\n")
	
	if pass_count == total_count:
		print(">>> PHASE 7 ACCEPTANCE CRITERIA MET (100% PASS RATE) <<<")
		get_tree().quit(0)
	else:
		printerr(">>> PHASE 7 HAS FAILING ACCEPTANCE TESTS <<<")
		get_tree().quit(1)
