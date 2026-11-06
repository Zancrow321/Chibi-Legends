class_name ThemeOutfits
extends RefCounted
## Themen-Kollektionen im Character Creator, die über Spielfortschritt frei werden.
## Cyberpunk: neue Bestmarken im Turm der Prüfungen (Etage -> Teil). Ein Outfit
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
