extends Node

# AudioManager.gd: Procedural Audio Synthesis Engine for "The Dungeon Remembers".
# Generates 100% self-contained, programmatic AudioStreamWAV assets in pure GDScript.
# No external sound files or internet downloads required.
# Offline-first and game jam competition compliant.

var sound_cache: Dictionary = {}
var player_pool: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 12

var sfx_volume_db: float = -4.0

func _ready() -> void:
	# Create pool of AudioStreamPlayer instances
	for i in range(POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		player_pool.append(p)
	
	_synthesize_all_sfx()
	_connect_event_bus()

func _synthesize_all_sfx() -> void:
	# 1. Heartbeat Thrum (Low resonant pulse)
	sound_cache["heartbeat"] = _generate_wav(func(t: float, dur: float) -> float:
		var freq = lerp(60.0, 32.0, t / dur)
		var env = pow(1.0 - (t / dur), 1.8)
		return sin(TAU * freq * t) * env
	, 0.24)
	
	# 2. Spike Trap Thrust (Sharp puncture click + slash)
	sound_cache["spike_trap"] = _generate_wav(func(t: float, dur: float) -> float:
		var env = pow(1.0 - (t / dur), 3.0)
		var noise = randf_range(-0.4, 0.4)
		var tone = sin(TAU * 820.0 * t)
		return (tone * 0.6 + noise * 0.4) * env
	, 0.16)
	
	# 3. Boulder Crash (Heavy sub-bass impact rumble)
	sound_cache["boulder_crash"] = _generate_wav(func(t: float, dur: float) -> float:
		var env = pow(1.0 - (t / dur), 1.5)
		var rumble = sin(TAU * 50.0 * t) + sin(TAU * 80.0 * t) * 0.5
		var noise = randf_range(-0.5, 0.5)
		return (rumble * 0.5 + noise * 0.5) * env
	, 0.45)
	
	# 4. Poison Hiss (Toxic boiling gas)
	sound_cache["poison_fog"] = _generate_wav(func(t: float, dur: float) -> float:
		var env = sin((t / dur) * PI)
		var hiss = randf_range(-0.6, 0.6)
		var bubble = sin(TAU * (320.0 + sin(t * 35.0) * 80.0) * t) * 0.3
		return (hiss * 0.7 + bubble * 0.3) * env
	, 0.38)
	
	# 5. Illusion Whisper (Mystical shimmering spectral tone)
	sound_cache["illusion"] = _generate_wav(func(t: float, dur: float) -> float:
		var env = sin((t / dur) * PI)
		var vibrato = sin(t * 14.0) * 30.0
		var s1 = sin(TAU * (460.0 + vibrato) * t)
		var s2 = sin(TAU * (580.0 - vibrato) * t) * 0.65
		return (s1 + s2) * 0.5 * env
	, 0.55)
	
	# 6. Gold Bounty Chime (Bright resonant coin chime arpeggio)
	sound_cache["gold_chime"] = _generate_wav(func(t: float, dur: float) -> float:
		var env = pow(1.0 - (t / dur), 2.2)
		var t_step = int(t * 30.0) % 3
		var freq = 1046.0 if t_step == 0 else (1318.0 if t_step == 1 else 1568.0)
		return sin(TAU * freq * t) * env * 0.65
	, 0.28)
	
	# 7. Dungeon Shift (Deep resonant tectonic grinding pulse)
	sound_cache["dungeon_shift"] = _generate_wav(func(t: float, dur: float) -> float:
		var env = sin((t / dur) * PI)
		var tectonic = sin(TAU * 58.0 * t) + sin(TAU * 88.0 * t) * 0.4 + randf_range(-0.25, 0.25)
		return tectonic * env * 0.75
	, 0.60)
	
	# 8. Boss War Horn / Herald (Solemn brass fanfare)
	sound_cache["boss_horn"] = _generate_wav(func(t: float, dur: float) -> float:
		var env = pow(1.0 - (t / dur), 1.2)
		var brass = sin(TAU * 220.0 * t) + sin(TAU * 440.0 * t) * 0.5 + sin(TAU * 660.0 * t) * 0.25
		return brass * env * 0.7
	, 0.75)
	
	# 9. Boss Wrath Roar (Aggressive explosive surge)
	sound_cache["boss_wrath"] = _generate_wav(func(t: float, dur: float) -> float:
		var env = pow(1.0 - (t / dur), 1.3)
		var sweep = lerp(180.0, 90.0, t / dur)
		var noise = randf_range(-0.4, 0.4)
		return (sin(TAU * sweep * t) * 0.6 + noise * 0.4) * env
	, 0.65)
	
	# 10. Trap Placed (Subtle crisp stone placement click)
	sound_cache["place_item"] = _generate_wav(func(t: float, dur: float) -> float:
		var env = pow(1.0 - (t / dur), 4.0)
		return sin(TAU * 520.0 * t) * env * 0.5
	, 0.10)
	
	# 11. Minion Attack (Sharp slash / bite snap)
	sound_cache["minion_attack"] = _generate_wav(func(t: float, dur: float) -> float:
		var env = pow(1.0 - (t / dur), 3.0)
		var noise = randf_range(-0.5, 0.5)
		var tone = sin(TAU * 650.0 * t)
		return (tone * 0.4 + noise * 0.6) * env * 0.7
	, 0.14)
	
	# 12. Enemy Hit (Impact punch thud)
	sound_cache["enemy_hit"] = _generate_wav(func(t: float, dur: float) -> float:
		var env = pow(1.0 - (t / dur), 2.5)
		var thud = sin(TAU * 120.0 * t)
		return thud * env * 0.5
	, 0.12)
	
	# 13. Spell Cast (Arcane ascending glissando chime)
	sound_cache["spell_cast"] = _generate_wav(func(t: float, dur: float) -> float:
		var env = sin((t / dur) * PI)
		var freq = lerp(400.0, 950.0, t / dur)
		var trem = sin(t * 30.0) * 0.2
		return sin(TAU * freq * t) * (env + trem) * 0.5
	, 0.35)
	
	# 14. Victory Fanfare (Triumphant harmonic chord)
	sound_cache["victory_fanfare"] = _generate_wav(func(t: float, dur: float) -> float:
		var env = pow(1.0 - (t / dur), 1.1)
		var c = sin(TAU * 523.25 * t) + sin(TAU * 659.25 * t) * 0.8 + sin(TAU * 783.99 * t) * 0.7 + sin(TAU * 1046.5 * t) * 0.6
		return c * env * 0.3
	, 1.2)
	
	# 15. Defeat Bell (Somber tolling cathedral bell)
	sound_cache["defeat_bell"] = _generate_wav(func(t: float, dur: float) -> float:
		var env = pow(1.0 - (t / dur), 1.4)
		var toll = sin(TAU * 110.0 * t) + sin(TAU * 220.0 * t) * 0.6 + sin(TAU * 330.0 * t) * 0.3
		return toll * env * 0.6
	, 1.5)

var ambient_heartbeat_timer: float = 0.0
var ambient_pulse_interval: float = 2.5
var ambient_enabled: bool = true

func _process(delta: float) -> void:
	if not ambient_enabled:
		return
	ambient_heartbeat_timer += delta
	if ambient_heartbeat_timer >= ambient_pulse_interval:
		ambient_heartbeat_timer = 0.0
		play_sfx("heartbeat", -10.0, 0.95)

func _generate_wav(sample_fn: Callable, duration: float, sample_rate: int = 22050) -> AudioStreamWAV:
	var total_samples = int(duration * sample_rate)
	var byte_array = PackedByteArray()
	byte_array.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var sample_val: float = sample_fn.call(t, duration)
		var int_val = int(clamp(sample_val, -1.0, 1.0) * 32760.0)
		var byte_idx = i * 2
		byte_array[byte_idx] = int_val & 0xFF
		byte_array[byte_idx + 1] = (int_val >> 8) & 0xFF
	
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = byte_array
	return wav

var current_music_state: String = "PEACE"

func set_music_state(new_state: String) -> void:
	current_music_state = new_state
	match current_music_state:
		"PEACE":
			ambient_pulse_interval = 2.8
		"WAVE":
			ambient_pulse_interval = 1.4
			play_sfx("heartbeat", -2.0, 1.1)
		"BOSS":
			ambient_pulse_interval = 0.9
			play_sfx("boss_horn", 2.0, 1.0)

func _connect_event_bus() -> void:
	EventBus.trap_triggered.connect(_on_trap_triggered)
	EventBus.trap_placed.connect(func(_type, _pos): play_sfx("place_item", -2.0, 1.1))
	EventBus.monster_placed.connect(func(_type, _pos): play_sfx("place_item", -1.0, 0.9))
	EventBus.wave_started.connect(func(w_num):
		if w_num >= 5:
			set_music_state("BOSS")
		else:
			set_music_state("WAVE")
	)
	EventBus.wave_completed.connect(func(_w): set_music_state("PEACE"))
	EventBus.heart_damaged.connect(func(cur, max_hp, _dmg):
		var ratio = clamp(cur / max_hp, 0.1, 1.0)
		ambient_pulse_interval = lerp(0.85, 2.5, ratio)
		play_sfx("heartbeat", 2.0, 1.2)
	)
	EventBus.heart_destroyed.connect(func(): play_sfx("defeat_bell", 4.0))
	EventBus.dungeon_shifted.connect(func(is_s): if is_s: play_sfx("dungeon_shift", 1.0))
	EventBus.boss_spawned.connect(func(_b): 
		set_music_state("BOSS")
		play_sfx("boss_horn", 2.0)
	)
	EventBus.boss_phase_changed.connect(func(_p): play_sfx("boss_wrath", 3.0))
	EventBus.boss_defeated.connect(func(): 
		set_music_state("PEACE")
		play_sfx("victory_fanfare", 3.0)
	)
	EventBus.enemy_damaged.connect(func(_e, _a, _c): play_sfx("enemy_hit", -5.0))
	EventBus.enemy_died.connect(func(_e): play_sfx("gold_chime", -1.0))

func _on_trap_triggered(trap_type: String, _pos: Variant, _target: Node) -> void:
	match trap_type:
		"Spike Trap":
			play_sfx("spike_trap")
		"Falling Rock":
			play_sfx("boulder_crash", 2.0)
		"Poison Fog":
			play_sfx("poison_fog", 0.0)
		"Illusion Trap":
			play_sfx("illusion", 1.0)
		_:
			play_sfx("spike_trap")

func play_sfx(sfx_name: String, volume_offset: float = 0.0, pitch_mult: float = 1.0) -> void:
	if not sound_cache.has(sfx_name):
		return
	
	var wav: AudioStreamWAV = sound_cache[sfx_name]
	var player = _get_available_player()
	if player:
		player.stream = wav
		player.volume_db = sfx_volume_db + volume_offset
		player.pitch_scale = pitch_mult * randf_range(0.95, 1.05)
		player.play()

func _get_available_player() -> AudioStreamPlayer:
	for p in player_pool:
		if not p.playing:
			return p
	# Steal first player if pool exhausted
	return player_pool[0] if player_pool.size() > 0 else null

var is_muted: bool = false
var master_volume: float = 1.0

func set_master_volume(linear_vol: float) -> void:
	master_volume = clamp(linear_vol, 0.0, 1.0)
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		if master_volume <= 0.001:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, is_muted)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(master_volume))
	EventBus.settings_changed.emit()

func toggle_mute() -> bool:
	is_muted = not is_muted
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, is_muted)
	EventBus.settings_changed.emit()
	return is_muted

func set_muted(muted: bool) -> void:
	is_muted = muted
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, is_muted)
	EventBus.settings_changed.emit()

