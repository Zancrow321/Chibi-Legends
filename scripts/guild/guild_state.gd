class_name GuildState
extends RefCounted
## What the game needs to know about the player's guild outside the guild
## screen: its level for the small boni (filled by GuildScreen and on login).

const EXP_PER_LEVEL := 0.01  # +1 % EXP per guild level
const MARK_BONUS_LEVEL := 5  # from here: +1 Raid-Mark per Essenwächter (server side)

static var level := 0  # 0 = no guild / offline
static var name := ""
static var tag := ""


static func set_from(g) -> void:
	if g is Dictionary:
		level = int(g.get("level", 1))
		name = str(g.get("name", ""))
		tag = str(g.get("tag", ""))
	else:
		level = 0
		name = ""
		tag = ""


static func exp_factor() -> float:
	return 1.0 + EXP_PER_LEVEL * float(level)


static func bonus_text(lv: int) -> String:
	var t := "Gildenbonus: +%d %% EXP" % lv
	if lv >= MARK_BONUS_LEVEL:
		t += ", +1 Raid-Marke pro Essenwächter"
	else:
		t += " (ab Stufe %d: +1 Raid-Marke pro Essenwächter)" % MARK_BONUS_LEVEL
	return t
