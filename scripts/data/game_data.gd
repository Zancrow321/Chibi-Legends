class_name GameData
extends RefCounted
## Static game data: elements, skills, reactions, character looks.
## Pure data with no scene dependencies, so the headless server can use it later.

const ELEMENTS := {
	"feuer": {"name": "Feuer", "color": Color("ff7a3d")},
	"frost": {"name": "Frost", "color": Color("7fd8ff")},
	"blitz": {"name": "Blitz", "color": Color("ffe45c")},
	"wind": {"name": "Wind", "color": Color("9cf2b4")},
	"": {"name": "Physisch", "color": Color("ffffff")},
}

## Which status an element leaves on a target when no reaction happens.
const STATUS_OF := {"feuer": "brand", "frost": "frost", "blitz": "schock"}

const STATUS := {
	"brand": {"name": "Brand", "color": Color("ff7a3d")},
	"frost": {"name": "Frost", "color": Color("7fd8ff")},
	"schock": {"name": "Schock", "color": Color("ffe45c")},
}

const SKILLS := {
	"flammenschnitt": {
		"name": "Flammenschnitt", "style": "Krieger", "element": "feuer",
		"kind": "melee", "damage": 18.0, "cost": 15.0, "cooldown": 1.2,
		"size": Vector2(46, 38), "knockback": 140.0,
		"desc": "Brennender Bogenhieb nach vorn. Setzt Brand.",
	},
	"frostlanze": {
		"name": "Frostlanze", "style": "Elementar", "element": "frost",
		"kind": "projectile", "damage": 11.0, "cost": 12.0, "cooldown": 1.0,
		"size": Vector2(26, 8), "speed": 430.0, "life": 0.9, "pierce": true, "knockback": 40.0,
		"desc": "Schnelle, durchschlagende Eislanze. Setzt Frost.",
	},
	"kettenblitz": {
		"name": "Kettenblitz", "style": "Elementar", "element": "blitz",
		"kind": "chain", "damage": 12.0, "cost": 18.0, "cooldown": 2.0,
		"range": 240.0, "jump_range": 150.0, "jumps": 3,
		"desc": "Springt auf bis zu vier Ziele. Setzt Schock.",
	},
	"sturmklinge": {
		"name": "Sturmklinge", "style": "Krieger", "element": "wind",
		"kind": "projectile", "damage": 10.0, "cost": 12.0, "cooldown": 1.4,
		"size": Vector2(18, 34), "speed": 300.0, "life": 1.0, "pierce": true, "knockback": 260.0,
		"desc": "Windsichel mit starkem Rückstoß. Verbreitet Brand als Feuersturm.",
	},
}

const START_BUILD := ["flammenschnitt", "frostlanze", "kettenblitz", "sturmklinge"]

const REACTIONS := {
	"dampfexplosion": {"name": "Dampfexplosion", "color": Color("f0f6ff"), "recipe": "Feuer + Frost"},
	"ueberladung": {"name": "Überladung", "color": Color("ffb347"), "recipe": "Feuer + Blitz"},
	"kristallbruch": {"name": "Kristallbruch", "color": Color("b9f3ff"), "recipe": "Frost + Blitz"},
	"feuersturm": {"name": "Feuersturm", "color": Color("ff9a4d"), "recipe": "Wind auf Brand"},
}

## Basic attack combo of the starting katana.
const COMBO_DAMAGE := [8.0, 8.0, 14.0]

# --- Character looks (customization comes in phase 2; C cycles presets) ---
const HAIR_STYLES := ["Stachelig", "Lang", "Zopf", "Kurz", "Wuschel"]
const HAIR_COLORS := [Color("e8553a"), Color("2b2233"), Color("f4dc5c"), Color("e8eef2"), Color("4a7bf0"), Color("ff8fc8"), Color("7b4a2e"), Color("55d18a")]
const SKIN_TONES := [Color("ffe2c9"), Color("f4c7a1"), Color("d99c6c"), Color("a8693f"), Color("6e4127")]
const EYE_COLORS := [Color("7a3b2e"), Color("3b6fe0"), Color("d23b3b"), Color("2fae5f"), Color("8a4fd6")]
const TOP_COLORS := [Color("f2f0e6"), Color("2f5fd0"), Color("2b2b38"), Color("d8423c"), Color("3aa86b"), Color("8b45c8")]
const PANTS_COLORS := [Color("5b4a3a"), Color("2c2a40"), Color("3b4a6b"), Color("6b2c2c")]

const LOOK_PRESETS := [
	{"hair_style": 0, "hair_color": 0, "skin": 0, "eyes": 0, "top": 0, "pants": 0},
	{"hair_style": 1, "hair_color": 1, "skin": 1, "eyes": 2, "top": 2, "pants": 1},
	{"hair_style": 2, "hair_color": 5, "skin": 0, "eyes": 1, "top": 1, "pants": 2},
	{"hair_style": 4, "hair_color": 2, "skin": 2, "eyes": 3, "top": 4, "pants": 0},
	{"hair_style": 3, "hair_color": 3, "skin": 3, "eyes": 4, "top": 5, "pants": 3},
	{"hair_style": 0, "hair_color": 4, "skin": 4, "eyes": 0, "top": 3, "pants": 1},
]
