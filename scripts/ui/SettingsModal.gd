extends PanelContainer

# SettingsModal.gd: Manages master audio volume, mute, and camera screen shake toggles.

@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_label: Label = %VolumeLabel
@onready var mute_check: CheckBox = %MuteCheck
@onready var shake_check: CheckBox = %ShakeCheck
@onready var close_button: Button = %CloseButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if close_button:
		close_button.pressed.connect(close)
	if volume_slider:
		volume_slider.value_changed.connect(_on_volume_changed)
	if mute_check:
		mute_check.toggled.connect(_on_mute_toggled)
	if shake_check:
		shake_check.toggled.connect(_on_shake_toggled)
	
	_refresh_controls()

func open() -> void:
	_refresh_controls()
	visible = true

func close() -> void:
	visible = false

func _refresh_controls() -> void:
	if volume_slider:
		var vol_pct = int(AudioManager.master_volume * 100.0)
		volume_slider.value = vol_pct
		if volume_label:
			volume_label.text = "%d%%" % vol_pct
	if mute_check:
		mute_check.button_pressed = AudioManager.is_muted
	if shake_check:
		shake_check.button_pressed = GameManager.screen_shake_enabled

func _on_volume_changed(val: float) -> void:
	var linear = val / 100.0
	AudioManager.set_master_volume(linear)
	if volume_label:
		volume_label.text = "%d%%" % int(val)

func _on_mute_toggled(is_muted: bool) -> void:
	AudioManager.set_muted(is_muted)

func _on_shake_toggled(enabled: bool) -> void:
	GameManager.set_screen_shake_enabled(enabled)
