# THE DUNGEON REMEMBERS

**"You don't control the dungeon. You ARE the dungeon."**

An adaptive dungeon-defense strategy game created for the **RRR Game Jam** (*"Rewind. Reimagine. Reconnect."*).

---

## 1. Concept & Inspiration
- **Rewind**: Inspired by the 1997 classic *Dungeon Keeper*.
- **Reimagine**: The player is not an external manager watching over a dungeon—the player **IS** the living dungeon body and conscious heart.
- **Reconnect**: Invaders do not mindlessly path; they explore, learn from traps and defenders, remember outcomes, and adapt over successive waves.

---

## 2. Implementation Status

### Phase 1: Core Prototype [COMPLETED]
- [x] Godot 4.7.2 project architecture and configuration (`GL Compatibility` rendering)
- [x] Handcrafted dungeon layout with modular chambers
- [x] Living **Dungeon Heart** with animated organic pulsing, progressive heartbeat scaling
- [x] **Warrior** frontline invader with NavigationAgent2D pathfinding, attack cycles, health bars
- [x] Physical **Spike Trap** with detection triggers, puncture damage, extension/retraction animations
- [x] Centralized **EventBus** autoload decoupling signals across gameplay systems
- [x] **ResourceManager** managing the 3 locked currencies: Gold, Essence, and Heart Energy
- [x] **WaveManager** orchestrating wave spawning, wave completion, and transition cycles
- [x] **GameManager** coordinating global game state, pause, and scene restart
- [x] Dark fantasy **HUD** featuring Heart HP bar, wave indicator, resource counters, and defeat overlay

### Phase 2: Memory & Adaptation [COMPLETED]
- [x] **MemoryManager** autoload recording collective enemy experiences across waves
- [x] Memory schema tracking `enemy_type`, `event_type`, `location`, `severity`, `confidence`, and `encounter_count`
- [x] Memory confidence decay across unreinforced waves and encounter reinforcement
- [x] Multi-route branching dungeon architecture (North Flank, Central Hall, South Flank)
- [x] Dynamic Utility Route Scoring AI in `Warrior.gd` evaluating danger penalties and path lengths
- [x] Real-time tactical path diversion: Warriors detect remembered spike traps and divert through bypass corridors
- [x] Clear overhead visual adaptation alerts (`[!] ADAPTING: AVOIDING SPIKES!`) so the player clearly understands *why* enemies adapt
- [x] **Memory Chamber UI** modal ([M] key or HUD button) inspecting invader knowledge, confidence bars, and behavioral impact
### Phase 3: Dungeon System [COMPLETED]
- [x] All 6 locked Room types implemented: **Treasury**, **Monster Den**, **Trap Room**, **Heart Chamber**, **Memory Chamber**, **Gate Room**
- [x] **RoomManager** autoload tracking room registrations and automated wave bonuses
- [x] **Treasury** economy generation yielding +25 Gold revenue at the end of each completed wave
- [x] Real-time **Dungeon Shift** mechanic: player spends 15 Essence to raise an impassable living barrier across the North Flank corridor
- [x] Dynamic navigation mesh re-baking upon Dungeon Shift, forcing invading enemies to reroute on the fly
- [x] Enemy reaction AI to Dungeon Shift: warriors heading toward North Flank detect the shifted wall and dynamically divert south or central (`SHIFT DETECTED! REROUTING`)
- [x] Bottom Control Bar on HUD integrating `Build Spike Trap (40G)`, `DUNGEON SHIFT (15E)`, and `Memory Chamber [M]`
- [x] Interactive Room selection and inspection
- [x] Automated in-engine test suite for Phase 3 (`Phase3TestScene.tscn`)

### Phase 4: Combat + Content [COMPLETED]
- [x] **All 4 Traps Implemented & Balanced**:
  - **Spike Trap (40G)**: Physical puncture damage, triggers on step.
  - **Falling Rock Trap (60G)**: Heavy stone slab with crushing AoE impact (55 dmg) + 1.2s stun.
  - **Poison Fog Trap (50G)**: Lingering toxic gas cloud with DoT damage ticks (6 dmg) + 35% movement slow.
  - **Illusion Trap (35G)**: Memory manipulation hazard. Deals 0 physical damage; projects frightening phantom apparition that plants high-threat false memories into invader intelligence.
- [x] **All 3 Invader Classes**:
  - **Warrior**: Sturdy frontline tank (70 HP, 12 melee dmg); remembers traps, adapts routes, susceptible to illusions.
  - **Rogue**: Swift, cautious scout (45 HP, 135 speed, 8 dmg); highly sensitive to danger scores, flees from illusions.
  - **Mage**: Strategic ranged caster (40 HP, 95 speed, 14 arcane dmg at 190px range); dispels illusions and records counter-intelligence.
- [x] **All 3 Minion Defenders**:
  - **Goblin (40G, 5E)**: Cheap, loyal melee interceptor (50 HP, 10 club damage, 115 speed).
  - **Shadow Beast (70G, 10E)**: Agile predatory stalker (65 HP, 160 speed, 18 damage leap pounces).
  - **Mimic (60G, 15E)**: Deceptive ambush predator (80 HP); rests disguised as a gold-trimmed treasure chest, springs open with a 45 damage surprise ambush bite when intruders draw near.
- [x] **Dynamic Wave Progression**:
  - Wave 1: 3 Warriors
  - Wave 2: 2 Warriors + 2 Rogues
  - Wave 3: 2 Warriors + 2 Rogues + 2 Mages
  - Wave 4: Combined-arms 8-invader battalion
- [x] **Tactical HUD Selection Bar**:
  - Interactive selectors for Traps (Spike, Rock, Poison, Illusion) and Minions (Goblin, Shadow Beast, Mimic) with real-time Gold and Essence checking.
- [x] **Automated in-engine test suite for Phase 4 (`Phase4TestScene.tscn`) passing 100%**.

### Phase 5: Boss Wave (The Inquisitor / Adaptive General) [COMPLETED]
- [x] **The Grand Inquisitor Boss** ([`Inquisitor.gd`](file:///d:/Users/HP/THE%20DUNGEON%20REMEMBERS/scripts/boss/Inquisitor.gd) / [`Inquisitor.tscn`](file:///d:/Users/HP/THE%20DUNGEON%20REMEMBERS/scenes/boss/Inquisitor.tscn)):
  - Climax boss arriving on Wave 5 with 400 base HP, golden inquisitorial plate armor, glowing halo, and inquisitor warhammer.
  - **Royal Vanguard Escorts**: Arrives with 2 elite royal guard warriors to escort him.
- [x] **Collective Memory Synthesis**:
  - The Inquisitor synthesizes memory records from ALL fallen warriors, rogues, and mages across waves 1-4.
  - Selects the path that minimizes remembered danger or counters the player's primary trap layout.
- [x] **Cleansing Ward & Boss Tenacity**:
  - Emits a periodic cleansing aura that purges slows and stuns on himself and escorts.
  - Takes 25% reduced trap damage from spikes and falling rocks (`is_warded`).
  - Immune to illusion deception; reveals and dispels illusion traps without panicking.
- [x] **Dual-Phase Transition (Zealot's Wrath)**:
  - When reduced below 50% HP (<= 200 HP), enters **Phase 2 Fanatic Rage**.
  - Blazing crimson fire aura, movement speed surges to 125.0, attack damage surges to 38.0, and attack interval accelerates to 0.75s.
- [x] **Dedicated Boss UI**:
  - Gilded top Boss Health Bar banner on HUD with dynamic phase titles and phase 2 alerts.
- [x] **Victory Condition Trigger**:
  - Defeating the Inquisitor on Wave 5 triggers Dungeon Victory (`EventBus.game_over(true)`).
- [x] **Automated in-engine test suite for Phase 5 (`Phase5TestScene.tscn`) passing 100%**.

### Phase 6: Audio & Visual Polish [COMPLETED]
- [x] **Procedural Audio Engine** ([`AudioManager.gd`](file:///d:/Users/HP/THE%20DUNGEON%20REMEMBERS/scripts/core/AudioManager.gd)):
  - 100% self-contained, pure GDScript mathematical waveform synthesis generating PCM 16-bit `AudioStreamWAV` buffers.
  - Zero external sound files or asset downloads required; fully offline-first and competition compliant.
  - Pre-allocated 12-channel `AudioStreamPlayer` pool with voice-stealing safety.
  - **15 Unique Synthesized Audio Cues**:
    1. *Heartbeat*: Low-frequency resonant living pulse.
    2. *Spike Trap*: Sharp puncture transient with metal scrape.
    3. *Boulder Crash*: Heavy sub-bass earthquake rumble.
    4. *Poison Fog*: Toxic boiling vapor hiss.
    5. *Illusion Whisper*: Ethereal shimmering dual-harmonic tone.
    6. *Gold Chime*: High-pitched melodic triad arpeggio.
    7. *Dungeon Shift*: Tectonic subterranean grinding hum.
    8. *Boss Herald*: Solemn brass fanfare.
    9. *Boss Wrath Roar*: Explosive downward frequency sweep.
    10. *Item Placed*: Stone-click placement feedback.
    11. *Minion Attack*: Slashing bite/claw swipe transient.
    12. *Enemy Hit*: Solid blunt impact thud.
    13. *Spell Cast*: Ascending arcane chime glissando.
    14. *Victory Fanfare*: Harmonized multi-octave triumphant chord.
    15. *Defeat Bell*: Low somber cathedral bell toll.
  - **Dynamic Living Pulse Ambiance**: Ambient heartbeat thrum throughout corridors whose tempo dynamically quickens as Heart HP is lost.
- [x] **Dynamic Camera Screen Shake**:
  - Procedural directional camera offset vibration in `Main.gd` with quadratic falloff.
  - Automatic triggers upon heavy impacts: Heart damage (5–22px), Zealot's Wrath transition (18px), Boulder crushes (6.5px), and Dungeon Shifts (8px).
- [x] **Floating Combat & Bounty Indicators** ([`FloatingText.gd`](file:///d:/Users/HP/THE%20DUNGEON%20REMEMBERS/scripts/ui/FloatingText.gd)):
  - World-space rising animated text with scale pop, deceleration drag, and smooth alpha fadeout.
  - Color-coded feedback for damage numbers (Crimson), critical strikes (Amber), gold bounties (Gold), status afflictions (Green/Orange), and adaptation alerts (Purple).
- [x] **Atmospheric Visual Polish**:
  - Animated flickering torchlight sconces placed along corridor walls in `Dungeon.gd` with dual-layer amber halos and iron mounts.
  - Health bar flash reaction tweens on the HUD.
- [x] **Automated in-engine test suite for Phase 6 (`Phase6TestScene.tscn`) passing 100%**.

### Phase 7: Complete Game Loop & Menus [COMPLETED]
- [x] **Main Menu / Title Screen** ([`TitleScreen.tscn`](file:///d:/Users/HP/THE%20DUNGEON%20REMEMBERS/scenes/ui/TitleScreen.tscn) / [`TitleScreen.gd`](file:///d:/Users/HP/THE%20DUNGEON%20REMEMBERS/scripts/ui/TitleScreen.gd)):
  - Atmospheric dark-fantasy presentation with pulsing living runic background.
  - Buttons for **AWAKEN DUNGEON** (Start Game), **LORE & TACTICS** (Game Jam Guide), **AUDIO & SETTINGS** (Options), and **QUIT TO DESKTOP**.
  - Configured as the default startup scene (`run/main_scene`) in `project.godot`.
- [x] **Lore & Tactics Guide Modal** ([`LoreModal.tscn`](file:///d:/Users/HP/THE%20DUNGEON%20REMEMBERS/scenes/ui/LoreModal.tscn) / [`LoreModal.gd`](file:///d:/Users/HP/THE%20DUNGEON%20REMEMBERS/scripts/ui/LoreModal.gd)):
  - Scrollable in-game guide detailing the RRR Game Jam theme, Dungeon Keeper (1997) inspiration, all 4 traps, all 3 minions, Memory Chamber mechanics, Living Dungeon Shift, and the Wave 5 Climax Boss.
- [x] **Audio & Visual Settings Modal** ([`SettingsModal.tscn`](file:///d:/Users/HP/THE%20DUNGEON%20REMEMBERS/scenes/ui/SettingsModal.tscn) / [`SettingsModal.gd`](file:///d:/Users/HP/THE%20DUNGEON%20REMEMBERS/scripts/ui/SettingsModal.gd)):
  - Master Audio Volume Slider (0% to 100%).
  - Mute Audio Toggle with master audio bus integration.
  - Camera Screen Shake toggle.
- [x] **In-Game Pause System**:
  - `Escape` key and top bar `PAUSE` button toggling the pause menu.
  - Seamless pause overlay supporting `Resume`, `Lore & Tactics`, `Audio & Settings`, `Restart Run`, and `Return to Title`.
- [x] **Comprehensive Run Statistics Tracking** ([`GameManager.gd`](file:///d:/Users/HP/THE%20DUNGEON%20REMEMBERS/scripts/core/GameManager.gd)):
  - Tracks Waves Survived, Invaders Slain, Traps Triggered, Memories Recorded, and Total Gold Harvested.
- [x] **Victory & Defeat Screens**:
  - **Victory**: "THE DUNGEON ENDURES!" with full run performance stats, Reincarnate, and Return to Title options.
  - **Defeat**: "THE LIVING NUCLEUS FELL..." with full run performance stats, immediate Reincarnation, and Return to Title.
- [x] **Automated in-engine test suite for Phase 7 (`Phase7TestScene.tscn`) passing 100%**.

### Phase 8: Final Review & Delivery [COMPLETED]
- [x] **Master Test Suite Runner** ([`MasterTestSuite.tscn`](file:///d:/Users/HP/THE%20DUNGEON%20REMEMBERS/scenes/main/MasterTestSuite.tscn) / [`MasterTestSuite.gd`](file:///d:/Users/HP/THE%20DUNGEON%20REMEMBERS/scripts/core/MasterTestSuite.gd)):
  - Validates all 7 development phases in a single consolidated pass.
- [x] **Automated Regression Test Script** ([`test_all.ps1`](file:///d:/Users/HP/THE%20DUNGEON%20REMEMBERS/test_all.ps1)):
  - Executes all 8 test scenes headlessly in sequence, verifying zero exit errors.
- [x] **Export Configuration** ([`export_presets.cfg`](file:///d:/Users/HP/THE%20DUNGEON%20REMEMBERS/export_presets.cfg)):
  - Windows Desktop release export preset configured.
- [x] **100% Game Jam Compliance Verified**:
  - *Rewind*: Dungeon Keeper (1997) DNA preserved.
  - *Reimagine*: Player IS the living dungeon.
  - *Reconnect*: Invaders remember hazards and adapt.
  - *Offline-First*: Zero external asset dependencies; 15 procedurally synthesized sound effects and self-contained procedural graphics.

---

## 3. Controls
| Action | Key / Input |
|---|---|
| **Camera Pan** | `W`, `A`, `S`, `D` or Arrow Keys |
| **Camera Zoom** | Mouse Wheel Up / Down |
| **Select Trap / Minion** | Click buttons on the bottom bar |
| **Place Selected Item** | Left Click on any valid corridor floor |
| **Dungeon Shift** | Click "DUNGEON SHIFT (15E)" button |
| **Memory Chamber** | `M` or click "Memory Chamber [M]" |
| **Start Next Wave** | Click "Start Wave" button |
| **Pause / Resume** | `Esc` or Click "PAUSE" button |
| **Reincarnate / Restart** | `R` (on Game Over) or Click "Reincarnate Dungeon" |

---

## 4. How to Run
### Running the Game
```powershell
& "C:\Users\Adarsh\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --path "d:\Users\HP\THE DUNGEON REMEMBERS"
```

### Running the Full Master Regression Suite
Run all test suites across all phases with a single command:
```powershell
powershell -ExecutionPolicy Bypass -File "d:\Users\HP\THE DUNGEON REMEMBERS\test_all.ps1"
```

### Running Individual Automated Test Suites
- **Phase 1 Test Suite (Core 3D Prototype)**:
  ```powershell
  & "C:\Users\Adarsh\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "d:\Users\HP\THE DUNGEON REMEMBERS" "res://scenes/main/Phase1TestScene3D.tscn"
  ```
- **Phase 2 Test Suite (Memory & Adaptation)**:
  ```powershell
  & "C:\Users\Adarsh\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "d:\Users\HP\THE DUNGEON REMEMBERS" "res://scenes/main/Phase2TestScene3D.tscn"
  ```
- **Phase 3 Test Suite (Dungeon System & Living Shift)**:
  ```powershell
  & "C:\Users\Adarsh\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "d:\Users\HP\THE DUNGEON REMEMBERS" "res://scenes/main/Phase3TestScene3D.tscn"
  ```
- **Phase 4 Test Suite (Traps, Minions & Combined Arms)**:
  ```powershell
  & "C:\Users\Adarsh\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "d:\Users\HP\THE DUNGEON REMEMBERS" "res://scenes/main/Phase4TestScene3D.tscn"
  ```
- **Phase 5 Test Suite (Boss Wave - The Grand Inquisitor)**:
  ```powershell
  & "C:\Users\Adarsh\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "d:\Users\HP\THE DUNGEON REMEMBERS" "res://scenes/main/Phase5TestScene3D.tscn"
  ```
- **Phase 6 Test Suite (Audio & Visual Polish)**:
  ```powershell
  & "C:\Users\Adarsh\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "d:\Users\HP\THE DUNGEON REMEMBERS" "res://scenes/main/Phase6TestScene3D.tscn"
  ```
- **Phase 7 Test Suite (Complete Game Loop & Menus)**:
  ```powershell
  & "C:\Users\Adarsh\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "d:\Users\HP\THE DUNGEON REMEMBERS" "res://scenes/main/Phase7TestScene3D.tscn"
  ```
- **Master Test Suite (All Phases)**:
  ```powershell
  & "C:\Users\Adarsh\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "d:\Users\HP\THE DUNGEON REMEMBERS" "res://scenes/main/MasterTestSuite.tscn"
  ```

---

## 5. Automated Test Verification Summary

| Suite / Phase | Test Description | Exit Code | Result |
|---|---|:---:|:---:|
| **Phase 1** | Core 3D Prototype (EventBus, 3D Heart, Traps, Warriors, Wave Lifecycle) | `0` | **PASS (100%)** |
| **Phase 2** | Memory & Adaptation (MemoryManager, 3D Route Utility Scoring, Decay) | `0` | **PASS (100%)** |
| **Phase 3** | Dungeon System (6 3D Rooms, Treasury Bonus, Living Dungeon Shift) | `0` | **PASS (100%)** |
| **Phase 4** | Combat & Content (4 Traps, 3 Invaders, 3 Minions, 3D Combat) | `0` | **PASS (100%)** |
| **Phase 5** | Boss Wave (The Grand Inquisitor, 3D Habit Adaptation, Zealot's Wrath) | `0` | **PASS (100%)** |
| **Phase 6** | Audio & Visual Polish (Procedural Audio Synth, Screen Shake, Damage VFX) | `0` | **PASS (100%)** |
| **Phase 7** | Complete Game Loop & Menus (Title Screen, Settings, 5-Wave Campaign, Stats) | `0` | **PASS (100%)** |
| **Master** | Consolidated End-to-End Test Runner across all 7 3D development phases | `0` | **PASS (100%)** |



