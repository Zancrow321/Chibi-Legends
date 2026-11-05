class_name GameSettings
extends RefCounted
## Player options (menu "Optionen"), saved in user://optionen.json:
## volume (all / effects), effect strength (FxSettings level), damage numbers, screen shake and fullscreen.

const SAVE := "user://optionen.json"

static var master := 0.8  # 0..1
static var sfx := 1.0
static var numbers := true
static var shake := true
static var fullscreen := false
static var _loaded := false


static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(SAVE, FileAccess.READ)
	if f != null:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			master = clampf(float(d.get("master", master)), 0.0, 1.0)
			sfx = clampf(float(d.get("sfx", sfx)), 0.0, 1.0)
			numbers = bool(d.get("numbers", numbers))
			shake = bool(d.get("shake", shake))
			fullscreen = bool(d.get("fullscreen", fullscreen))
			FxSettings.level = clampi(int(d.get("fx", FxSettings.level)), 0, FxSettings.LEVELS.size() - 1)
	apply()


static func save() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"master": master, "sfx": sfx, "numbers": numbers, "shake": shake, "fullscreen": fullscreen, "fx": FxSettings.level}))


static func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master, 0.0001)))
	AudioServer.set_bus_mute(0, master <= 0.001)
	if DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and (fullscreen or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
			DisplayServer.window_set_mode(want)


## Extra dB for sound effects (Sfx adds it to every sound).
static func sfx_db() -> float:
	return linear_to_db(maxf(sfx, 0.0001))


## Factor for camera shake (0 when switched off).
static func shake_factor() -> float:
	return 1.0 if shake else 0.0
