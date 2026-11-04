class_name FxSettings
extends RefCounted
## Combat feel tuning: hit profiles (hit-stop, shake, spark size, flash) and
## a global intensity level the player can switch (V key, later in Optionen).
## All values in one place so the feel can be tuned without touching code.

## Intensity levels. Each factor scales the matching value of a hit profile.
const LEVELS := [
## bloom = glow strength, hdr = brightness of effects (above 1 glows, see Bloom).
	{"name": "Dezent", "stop": 0.45, "shake": 0.45, "spark": 0.75, "flash": 0.35, "bloom": 0.45, "hdr": 1.25},
	{"name": "Kräftig", "stop": 1.0, "shake": 1.0, "spark": 1.15, "flash": 1.0, "bloom": 1.0, "hdr": 1.7},
	{"name": "Maximal", "stop": 1.6, "shake": 1.7, "spark": 1.5, "flash": 1.5, "bloom": 1.6, "hdr": 2.3},
]

## Hit profiles: stop = hit-stop seconds (whole world freezes, sparks keep
## playing), shake = camera shake in pixels, spark = spark size factor,
## flash = white screen flash strength (0..1), zoom = camera punch.
const HIT := {
	"light": {"stop": 0.045, "shake": 2.0, "spark": 0.8, "flash": 0.0, "zoom": 0.0},
	"heavy": {"stop": 0.085, "shake": 4.5, "spark": 1.15, "flash": 0.0, "zoom": 0.02},
	"reaction": {"stop": 0.14, "shake": 7.0, "spark": 1.6, "flash": 0.22, "zoom": 0.05},
	"super": {"stop": 0.0, "shake": 2.5, "spark": 0.9, "flash": 0.0, "zoom": 0.0},
	"super_final": {"stop": 0.24, "shake": 12.0, "spark": 2.2, "flash": 0.7, "zoom": 0.1},
}

static var level := 1


static func factor(key: String) -> float:
	return LEVELS[level][key]


## Brightness factor for effect nodes (values above 1 bloom).
static func boost() -> float:
	return LEVELS[level].hdr


static func level_name() -> String:
	return LEVELS[level].name


static func cycle() -> void:
	level = (level + 1) % LEVELS.size()
