class_name Reactions
extends RefCounted
## Element reaction rules. Pure logic on a status dictionary
## (status name -> remaining seconds), reusable by the future game server.

const STATUS_DURATION := 4.0
const SHOCK_BONUS := 1.2
## Seelenbruch (Gleichklang): every hit on the marked target does more.
const SOUL_BREAK_BONUS := 1.25
## Aus dem Gleichgewicht (Spannkraft): a reeling target takes more.
const TAUMEL_BONUS := 1.2


static func _has(status: Dictionary, key: String) -> bool:
	return status.get(key, 0.0) > 0.0


## Resolves one hit. Mutates `status` (consumes / applies statuses) and returns
## {damage, reaction, aoe_damage, aoe_radius, spread_status}.
static func resolve(status: Dictionary, element: String, base: float) -> Dictionary:
	var r := {"damage": base, "reaction": "", "aoe_damage": 0.0, "aoe_radius": 0.0, "spread_status": ""}
	var brand := _has(status, "brand")
	var frost := _has(status, "frost")
	var schock := _has(status, "schock")

	if (element == "feuer" and frost) or (element == "frost" and brand):
		r.reaction = "dampfexplosion"
		r.aoe_damage = 24.0
		r.aoe_radius = 70.0
		status.erase("brand")
		status.erase("frost")
	elif (element == "feuer" and schock) or (element == "blitz" and brand):
		r.reaction = "ueberladung"
		r.aoe_damage = 28.0
		r.aoe_radius = 80.0
		status.erase("brand")
		status.erase("schock")
	elif (element == "frost" and schock) or (element == "blitz" and frost):
		r.reaction = "kristallbruch"
		r.damage = base * 2.5
		status.erase("frost")
		status.erase("schock")
	elif element == "wind" and brand:
		r.reaction = "feuersturm"
		r.aoe_damage = 10.0
		r.aoe_radius = 110.0
		r.spread_status = "brand"

	if _has(status, "seelenbruch"):
		r.damage *= SOUL_BREAK_BONUS
	if _has(status, "taumel"):
		r.damage *= TAUMEL_BONUS
	if r.reaction == "":
		if schock:
			r.damage = r.damage * SHOCK_BONUS
		if GameData.STATUS_OF.has(element):
			status[GameData.STATUS_OF[element]] = STATUS_DURATION
	return r


## Ticks status timers down and removes expired statuses.
static func tick(status: Dictionary, delta: float) -> void:
	for key in status.keys():
		status[key] = status[key] - delta
		if status[key] <= 0.0:
			status.erase(key)
