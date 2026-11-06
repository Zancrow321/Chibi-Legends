class_name ThemeOutfits
extends RefCounted
## Themen-Kollektionen im Character Creator, die über Spielfortschritt frei werden.
## Frostnorden: Spielerstufen (LEVEL). Cyberpunk: neue Bestmarken im Turm der Prüfungen (Etage -> Teil). Ein Outfit
## schaltet Oberteil, Hose und Schuhe zusammen frei; "hair" ist ein Kopfteil.
## Hinweistexte stehen in catalog.json unter slots.<slot>.unlock.

const TOWER := {
	5: ["outfit", "datenhoodie"],
	10: ["outfit", "neonlaeufer"],
	15: ["hair", "neonkamm"],
	20: ["outfit", "synthidol"],
	25: ["outfit", "chromsoeldner"],
	30: ["hair", "neonvisier"],
	40: ["outfit", "strassenklinge"],
	50: ["outfit", "konzern"],
}


## Frostnorden (und zwei Steampunk-Teile): Spielerstufen (Stufe -> Teil), frei beim Stufenaufstieg.
const LEVEL := {
	3: ["outfit", "nordwanderer"],
	6: ["outfit", "runenschild"],
	9: ["hair", "flechtbart"],
	12: ["outfit", "eisjaeger"],
	15: ["outfit", "frostseherin"],
	18: ["hair", "hoernerhelm"],
	22: ["outfit", "baerenhaut"],
	# Steampunk-Werkstatt
	26: ["outfit", "zahnradtechniker"],
	30: ["outfit", "dampfdame"],
}


## Unlocks a part; slot "outfit" = top, pants and shoes. Returns the display name.
static func give(slot: String, id: String) -> String:
	if slot == "outfit":
		for s in ["top", "pants", "shoes"]:
			CreatorUnlocks.unlock(s, id)
		return CreatorCatalog.item_name("top", id)
	CreatorUnlocks.unlock(slot, id)
	return CreatorCatalog.item_name(slot, id)


## Floor n of the tower cleared for the first time: returns a toast text or "".
static func tower_floor(n: int) -> String:
	if not TOWER.has(n):
		return ""
	var p: Array = TOWER[n]
	var check_slot := "top" if p[0] == "outfit" else str(p[0])
	if CreatorUnlocks.is_unlocked(check_slot, str(p[1])):
		return ""
	return "Neon-Belohnung: %s, im Creator (O) wählbar" % give(str(p[0]), str(p[1]))


## Level reached: unlocks every Frostnorden part up to this level that is still locked
## (also catches up older saves). Returns the toast texts.
static func on_level(lv: int) -> Array:
	var out: Array = []
	for n in LEVEL:
		if int(n) > lv:
			continue
		var p: Array = LEVEL[n]
		var check_slot := "top" if p[0] == "outfit" else str(p[0])
		if not CreatorUnlocks.is_unlocked(check_slot, str(p[1])):
			out.append("Neue Kleidung: %s, im Creator (O) wählbar" % give(str(p[0]), str(p[1])))
	return out
