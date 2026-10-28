extends Node
## Player settings stored in user://settings.cfg. Every option is read by a system.

const PATH := "user://settings.cfg"

const DEFAULTS := {
	# Graphics
	"quality": 1,               # 0 low, 1 medium, 2 high
	"shadows": true,
	"particles": true,
	"effects": true,
	"fps_limit": 60,            # 30 / 60
	"battery_saver": false,
	# Audio
	"vol_master": 0.9,
	"vol_music": 0.7,
	"vol_sfx": 0.9,
	"vol_voice": 0.9,
	"vibration": true,
	# Controls
	"button_scale": 1.0,        # 0.85 / 1.0 / 1.2
	"confirm_important": true,
	"hud_left_handed": false,
	# Accessibility
	"text_scale": 1.0,          # 0.9 / 1.0 / 1.15 / 1.3
	"high_contrast": false,
	"reduce_flashes": false,
	"reduce_shake": false,
	"limit_animations": false,
	"sound_indicators": false,
	# Gameplay
	"language": "fr",
	"tutorials": true,
	"damage_numbers": true,
	"range_indicators": true,
	"confirm_spend": true,
	# Notifications (in-game badges; Android system notifications are not implemented)
	"notif_rewards": true,
	"notif_events": true,
	"notif_progress": true,
}

var values := DEFAULTS.duplicate()


func _ready() -> void:
	load_settings()
	apply()


func get_v(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_v(key: String, value: Variant, save := true) -> void:
	values[key] = value
	apply()
	if save:
		save_settings()
	EventBus.settings_changed.emit()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in DEFAULTS.keys():
		if cfg.has_section_key("settings", k):
			var v = cfg.get_value("settings", k)
			if typeof(v) == typeof(DEFAULTS[k]) or (typeof(DEFAULTS[k]) == TYPE_FLOAT and typeof(v) == TYPE_INT):
				values[k] = v


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in values.keys():
		cfg.set_value("settings", k, values[k])
	cfg.save(PATH)


func reset_defaults() -> void:
	values = DEFAULTS.duplicate()
	apply()
	save_settings()
	EventBus.settings_changed.emit()


func apply() -> void:
	# Audio buses
	_set_bus("Master", values.vol_master)
	_set_bus("Music", values.vol_music)
	_set_bus("SFX", values.vol_sfx)
	_set_bus("Voice", values.vol_voice)
	# Frame rate / battery
	var fps: int = 30 if values.battery_saver else int(values.fps_limit)
	Engine.max_fps = fps
	# Language
	TranslationServer.set_locale(str(values.language))


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))


# ------------------------------------------------------------- derived values
func effective_quality() -> int:
	return 0 if values.battery_saver else int(values.quality)


func shadows_enabled() -> bool:
	return bool(values.shadows) and effective_quality() > 0


func particle_amount(base: int) -> int:
	if not values.particles or values.limit_animations:
		return 0
	return maxi(1, int(base * [0.35, 0.7, 1.0][effective_quality()]))


func shake_scale() -> float:
	return 0.0 if values.reduce_shake else 1.0


func flash_scale() -> float:
	return 0.3 if values.reduce_flashes else 1.0


func vibrate(ms: int) -> void:
	if values.vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
