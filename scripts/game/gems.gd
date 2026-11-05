class_name Gems
extends RefCounted
## Edelsteine for the sockets of gear. Six kinds, one stat each, three
## tiers (Roh, Geschliffen, Strahlend). They drop from enemies (elites more
## often and better) and live in a pouch next to the bag, saved in
## user://edelsteine.json. Setting a gem into a free socket works anywhere;
## taking it out again and fusing 3 of a tier into 1 of the next tier is
## work for Schmiedin Hino in the courtyard and costs Splitter.
## Never sold for money: gems only come from playing (no pay-to-win).
##
## A gem id is "<kind>_<tier>", e.g. "rubin_2".

const SAVE := "user://edelsteine.json"
const KINDS := {
	"rubin": {"name": "Rubin", "stat": "atk", "color": Color("e83b3b")},
	"smaragd": {"name": "Smaragd", "stat": "hp", "color": Color("1ebc73")},
	"topas": {"name": "Topas", "stat": "crit", "color": Color("f9c22b")},
	"saphir": {"name": "Saphir", "stat": "gauge", "color": Color("4d9be6")},
	"amethyst": {"name": "Amethyst", "stat": "critdmg", "color": Color("a884f3")},
	"onyx": {"name": "Onyx", "stat": "def", "color": Color("8b93af")},
}
const ORDER := ["rubin", "smaragd", "topas", "saphir", "amethyst", "onyx"]
const TIER_NAMES := ["", "Roh", "Geschliffen", "Strahlend"]
## Gem value = the stat's upper base range x this.
const TIER_POWER := [0.0, 0.7, 1.4, 2.4]
const MAX_TIER := 3
const FUSE_COUNT := 3

static var pouch := {}  # gem id -> count
static var _loaded := false
static var _tex := {}


static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	pouch = {}
	var f := FileAccess.open(SAVE, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		for g in d.get("pouch", {}):
			if valid(str(g)):
				pouch[str(g)] = int(d.pouch[g])


static func save() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"pouch": pouch}))


static func reset() -> void:
	pouch = {}
	_loaded = true
	save()


static func make_id(kind: String, tier: int) -> String:
	return "%s_%d" % [kind, tier]


static func kind_of(gem: String) -> String:
	return gem.rsplit("_", true, 1)[0]


static func tier_of(gem: String) -> int:
	return int(gem.rsplit("_", true, 1)[1]) if "_" in gem else 0


static func valid(gem: String) -> bool:
	return KINDS.has(kind_of(gem)) and tier_of(gem) >= 1 and tier_of(gem) <= MAX_TIER


static func stat_of(gem: String) -> String:
	return str(KINDS.get(kind_of(gem), {}).get("stat", ""))


static func color(gem: String) -> Color:
	return KINDS.get(kind_of(gem), {}).get("color", Color.WHITE)


## "Geschliffener Rubin"
static func display_name(gem: String) -> String:
	var t := tier_of(gem)
	var adj: String = ["", "Roher", "Geschliffener", "Strahlender"][t]
	return "%s %s" % [adj, KINDS[kind_of(gem)].name]


## The stat a gem adds (fraction). Fixed per tier, no item-level scaling,
## so a good gem stays useful when the item around it is replaced.
static func value(gem: String) -> float:
	if not valid(gem):
		return 0.0
	return snappedf(float(Loot.STATS[stat_of(gem)].max) * TIER_POWER[tier_of(gem)], 0.001)


static func line(gem: String) -> String:
	return Loot.stat_line(stat_of(gem), value(gem))


static func count(gem: String) -> int:
	ensure()
	return int(pouch.get(gem, 0))


static func total() -> int:
	ensure()
	var n := 0
	for g in pouch:
		n += int(pouch[g])
	return n


static func add(gem: String, n := 1) -> void:
	ensure()
	if not valid(gem):
		return
	pouch[gem] = count(gem) + n
	save()


static func take(gem: String) -> bool:
	ensure()
	if count(gem) <= 0:
		return false
	pouch[gem] = count(gem) - 1
	if pouch[gem] <= 0:
		pouch.erase(gem)
	save()
	return true


## Gems in the pouch, best first (tier, then the fixed kind order).
static func owned() -> Array:
	ensure()
	var out: Array = pouch.keys().filter(func(g): return int(pouch[g]) > 0)
	out.sort_custom(func(a, b):
		if tier_of(a) != tier_of(b):
			return tier_of(a) > tier_of(b)
		return ORDER.find(kind_of(a)) < ORDER.find(kind_of(b)))
	return out


## A drop: elites find more and better gems. "" = nothing.
static func roll_drop(elite := false) -> String:
	var chance := 0.45 if elite else 0.08
	if randf() >= chance:
		return ""
	var r := randf()
	var tier := 1
	if elite:
		tier = 3 if r < 0.06 else (2 if r < 0.35 else 1)
	elif r < 0.08:
		tier = 2
	return make_id(ORDER[randi() % ORDER.size()], tier)


## Splitter for fusing 3 gems of a tier into one of the next.
static func fuse_cost(gem: String) -> int:
	return 40 * tier_of(gem)


static func can_fuse(gem: String) -> bool:
	return valid(gem) and tier_of(gem) < MAX_TIER and count(gem) >= FUSE_COUNT


## Fuses 3 of a gem into one of the next tier (Splitter paid by the caller
## via Profile). Returns the new gem id or "".
static func fuse(gem: String) -> String:
	if not can_fuse(gem):
		return ""
	pouch[gem] = count(gem) - FUSE_COUNT
	if pouch[gem] <= 0:
		pouch.erase(gem)
	var up := make_id(kind_of(gem), tier_of(gem) + 1)
	pouch[up] = count(up) + 1
	save()
	return up


## Splitter for taking a gem back out of a socket.
static func unsocket_cost(gem: String) -> int:
	return 15 * tier_of(gem)


## PixelLab icon assets/items/gems/<id>.png (tools/items/gen_extra.py).
static func texture(gem: String) -> Texture2D:
	if not _tex.has(gem):
		var p := "res://assets/items/gems/%s.png" % gem
		_tex[gem] = load(p) if ResourceLoader.exists(p) else null
	return _tex[gem]


## Draws a gem (PixelLab icon, or a drawn stand-in) centred at c, size px.
static func draw(ci: CanvasItem, c: Vector2, gem: String, size: float) -> void:
	var t := texture(gem)
	if t != null:
		ci.draw_texture_rect(t, Rect2(c - Vector2(size, size) * 0.5, Vector2(size, size)), false)
		return
	var col := color(gem)
	var r := size * (0.22 + 0.06 * tier_of(gem))
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	ci.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	ci.draw_polyline(pts, ItemIcon.INK, maxf(1.0, size * 0.06))
	ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.22, Color(1, 1, 1, 0.85))
