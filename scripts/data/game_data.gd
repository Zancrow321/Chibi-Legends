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

# --- Character looks (parts and colors live in assets/characters, see Appearance) ---

## Visual item per gear slot of the starting equipment. Later the inventory
## fills this; the look can override each slot (switchable transmog).
const START_EQUIPMENT := {
	"weapon": "waffe_katana", "top": "oberteil_akademie", "pants": "hose_lang",
	"shoes": "schuhe_stiefel", "accessory": "accessoire_schal",
}

const LOOK_PRESETS := [
	{"hair": "haar_stachelig", "colors": {"skin": "haut_1", "hair": "haar_rot", "eyes": "augen_braun"}},
	{"hair": "haar_lang", "face": "gesicht_entschlossen", "colors": {"skin": "haut_2", "hair": "haar_schwarz", "eyes": "augen_rot"},
		"cosmetics": {"top": "oberteil_shirt"}, "item_colors": {"oberteil_shirt": ["schwarz", "rot"]}},
	{"hair": "haar_zopf", "colors": {"skin": "haut_1", "hair": "haar_rosa", "eyes": "augen_blau"},
		"cosmetics": {"headgear": "kopf_stirnband"}, "item_colors": {"oberteil_akademie": ["blau", "weiss"], "haar_zopf": ["", "gelb"]}},
	{"hair": "haar_wuschel", "colors": {"skin": "haut_3", "hair": "haar_blond", "eyes": "augen_gruen"},
		"cosmetics": {"pants": "hose_kurz", "accessory": "none"}, "item_colors": {"oberteil_akademie": ["gruen", "weiss"]}},
	{"hair": "haar_kurz", "face": "gesicht_entschlossen", "colors": {"skin": "haut_5", "hair": "haar_weiss", "eyes": "augen_violett"},
		"item_colors": {"oberteil_akademie": ["violett", "gelb"], "accessoire_schal": ["schwarz"]}},
]
