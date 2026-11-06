class_name KlangCaster
extends GlutCaster
## Runs the Züge of the fighting style Gleichklang (Sense Nachhall) and owns
## its state. Same interface as GlutCaster (the player, HUD and menu talk to
## both the same way); the rules are the style's own:
##  - Takt: Nachhall keeps a beat (100 per minute). Ring around the figure,
##    pulsing Klangloch and a quiet bell show it.
##  - Einklang (0..6): every *different* Zug that hits fills 1; a hit right on
##    the beat (±0.1 s) fills 1 more. J/K hits on the beat fill 1 too (once
##    per beat). At 6 the next Zug is verstärkt and empties the bar.
##  - A hit taken breaks the beat for a moment (ring turns grey) and costs
##    only 1 Einklang. Without hits the bar sinks after 5 s.
##  - Seelenbruch: verstärkte finishers mark the target for 3 s (+25 % damage
##    from everything, brutes lose their armour). Elites and bosses then
##    ignore it for 6 s.
##  - Sweet spot: the outer edge of the scythe hits harder, the shaft weaker.
##  - Nachhall talks: short lines in a bubble at the scythe.
##  - Options (saved): X cycles the Takt-Hilfe (normal, only visual, only
##    sound, wide window ±0.15 s), Y cycles the Klangfarbe (colour set of
##    arcs, rings and Klangloch; the gacha duplicates of the style).

const BEAT := 0.6
const WINDOW := 0.1
const WINDOW_WIDE := 0.15
const MAX_KLANG := 6
const DECAY_AFTER := 5.0
const BREAK_TIME := 3.0
const BREAK_IMMUNE := 6.0
const LOST_TIME := 0.6

const TAKT_MODES := ["Takt: Bild und Ton", "Takt: nur Bild", "Takt: nur Ton", "Takt: großzügig (±0,15 s)"]
## Klangfarben: blue (arcs), pale (rings), white (highlights), violet (accent)
const KLANGFARBEN := [
	{"name": "Blassblau", "blue": "8fd3ff", "pale": "cfeaff", "white": "f4fbff", "violet": "a884f3"},
	{"name": "Mondviolett", "blue": "b48cff", "pale": "e2d2ff", "white": "faf4ff", "violet": "ff8fd8"},
	{"name": "Totenrot", "blue": "ff6a6a", "pale": "ffc7c0", "white": "fff2ee", "violet": "8fd3ff"},
	{"name": "Glockengold", "blue": "ffd27a", "pale": "fff0c8", "white": "fffbef", "violet": "8fd3ff"},
]
const OPTIONS_SAVE := "user://gleichklang.json"
static var takt_mode := 0
static var farbe := 0
static var _options_loaded := false

const LINES := {
	"ready": ["Jetzt!", "Hörst du's?", "Auf die Eins."],
	"beat": ["Sauber.", "Na also.", "Im Takt."],
	"lost": ["Raus aus dem Takt…", "Konzentrier dich!"],
	"hurt": ["Steh auf. Wir sind nicht fertig.", "Rost und Scherben…"],
	"super": ["Zusammen!", "Lass sie klingen."],
	"counter": ["Gehört.", "Zu laut, der da."],
}

var kfx: KlangFx
var klang := 0
var _beat_t := 0.0
var _beat_n := 0
var _beat_pulse := 0.0
var _lost := 0.0
var _idle := 99.0
var _last_zug := ""
var _normal_beat := -1
var _stack := false  # L held *and* full Einklang: +25 % damage
var _say_cd := 0.0
var _immune: Dictionary = {}  # target id -> seconds without Seelenbruch
var _follow := false  # L pressed again during the Zug
var _did_follow := false
var _linger := -1.0
var _air_bounce_used := false
var _missed := false
var _plant := Vector2.ZERO


func setup(p: Player, st: FightingStyle) -> void:
	super.setup(p, st)
	GlutIcons.style_id = st.id
	_load_options()
	_apply_farbe()
	kfx = KlangFx.new()
	kfx.room = world
	world.add_child(kfx)
	world.klang_fx = kfx


# --- options ---------------------------------------------------------------------

static func _load_options() -> void:
	if _options_loaded:
		return
	_options_loaded = true
	var f := FileAccess.open(OPTIONS_SAVE, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		takt_mode = clampi(int(d.get("takt", 0)), 0, TAKT_MODES.size() - 1)
		farbe = clampi(int(d.get("farbe", 0)), 0, KLANGFARBEN.size() - 1)


static func _save_options() -> void:
	var f := FileAccess.open(OPTIONS_SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"takt": takt_mode, "farbe": farbe}))


## Writes the chosen Klangfarbe into the style colours (everything reads them).
func _apply_farbe() -> void:
	var set: Dictionary = KLANGFARBEN[farbe]
	var cols: Dictionary = style.data.get("colors", {})
	for k in ["blue", "pale", "white", "violet"]:
		cols[k] = set[k]
	style.data["colors"] = cols
	if kfx != null:
		kfx.beat_col = style.color("blue")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_X:
		takt_mode = (takt_mode + 1) % TAKT_MODES.size()
		_save_options()
		world.toast(TAKT_MODES[takt_mode])
	elif event.physical_keycode == KEY_Y or event.physical_keycode == KEY_Z:
		farbe = (farbe + 1) % KLANGFARBEN.size()
		_apply_farbe()
		_save_options()
		world.toast("Klangfarbe: " + str(KLANGFARBEN[farbe].name))
		kfx.ring(klangloch_pos(), 24.0, style.color("blue"), 0.4, 3.0)


func show_visual() -> bool:
	return takt_mode != 2


func play_sound() -> bool:
	return takt_mode != 1


func stage_color() -> Color:
	return style.color("white") if klang >= MAX_KLANG else style.color("blue")


func trail_color() -> Color:
	if klang >= MAX_KLANG:
		return style.color("white")
	return style.color("blue").lerp(style.color("violet"), 0.3)


func normal_element() -> String:
	return ""


func normal_mul() -> float:
	return 1.0


func blade_heat() -> float:
	return 0.0


# --- beat ------------------------------------------------------------------------

## Seconds to the nearest beat.
func beat_offset() -> float:
	var ph := fmod(_beat_t, BEAT)
	return minf(ph, BEAT - ph)


## 0 right after a beat, 1 right at the next.
func beat_progress() -> float:
	return fmod(_beat_t, BEAT) / BEAT


func on_beat(targets: Array = []) -> bool:
	if _lost > 0.0:
		return false
	var w := WINDOW_WIDE if takt_mode == 3 else WINDOW
	for tg in targets:
		if _easy_target(tg):
			w = WINDOW_WIDE
	return beat_offset() <= w


## Slowed or lifted targets are easier to time (wider window).
func _easy_target(tg: Node2D) -> bool:
	if not is_instance_valid(tg):
		return false
	if tg.get("status") is Dictionary and (tg.status.has("frost") or tg.status.has("seelenbruch")):
		return true
	var gy := GlutHazard.ground_y(tg.global_position.x, tg.global_position.y - 4.0)
	return gy < 9000.0 and tg.global_position.y < gy - 14.0


func active() -> bool:
	return busy() or _idle < 4.0 or klang > 0


func _say(kind: String, force := false) -> void:
	if _say_cd > 0.0 and not force:
		return
	_say_cd = 2.2
	kfx.speech(LINES[kind].pick_random())


func klangloch_pos() -> Vector2:
	var line := blade_now()
	return line[1]


# --- casting -------------------------------------------------------------------

func cast(dir: String) -> bool:
	if busy() or player.in_super:
		return false
	var z := style.zug_in(dir)
	if z == "":
		z = style.zug_in("neutral")
	if z == "" or cooldowns.get(z, 0.0) > 0.0:
		return false
	zug_id = z
	phase = "startup"
	t = 0.0
	frames = style.frames(z).duplicate()
	enhanced = false
	_stack = false
	_decided = false
	params = style.params(z, false)
	_hit_set = {}
	_reported = false
	_step = 0
	_follow = false
	_did_follow = false
	_missed = true
	_linger = -1.0
	_x_start = player.global_position.x
	_y_start = player.global_position.y
	_age = 0.0
	cooldowns[z] = style.cooldown(z)
	player.move = {}
	_bonus = klang >= MAX_KLANG
	if _bonus:
		klang = 0
		enhanced = true
		params = style.params(z, true)
		var c := klangloch_pos()
		kfx.ring(c, 34.0, style.color("white"), 0.4, 4.0)
		kfx.glow(c, Color(style.color("white"), 0.9), 26.0, 0.35)
		kfx.word(c + Vector2(-player.facing * 16.0, -40), "EINKLANG!", style.color("white"), 22)
		Sfx.play("bell_hit", 2.0)
		world.fx.flash(0.12 * FxSettings.factor("flash"), Color(0.7, 0.85, 1.0))
	_on_start()
	return true


func _decide_enhanced() -> void:
	_decided = true
	if not Input.is_action_pressed("special") or not (player.gauge >= 100.0 or player.infinite_aura):
		return
	if not player.infinite_aura:
		player.gauge -= 100.0
	_stack = enhanced
	enhanced = true
	params = style.params(zug_id, true)
	var c := klangloch_pos()
	kfx.ring(c, 26.0, style.color("violet"), 0.3, 3.0)
	kfx.motes(c, 8, 10.0, style.color("pale"))
	kfx.word(c + Vector2(-player.facing * 18.0, -52), "VERSTÄRKT", style.color("pale"), 16, -0.05)
	world.fx.flash(0.12 * FxSettings.factor("flash"), Color(0.7, 0.8, 1.0))


func interrupt() -> void:
	if player.hitstun > 0.0:
		# a hit taken: lose the beat for a moment and one Einklang
		_lost = LOST_TIME
		klang = maxi(0, klang - 1)
		_say("hurt" if player.hp < player.max_hp * 0.35 else "lost")
	zug_id = ""
	phase = ""
	countering = false


func _on_start() -> void:
	match zug_id:
		"fallende_sichel":
			if player.is_on_floor():
				player.velocity.y = -330.0
			else:
				frames[0] = 5
		"seelenlauschen":
			frames[1] = int(round(float(params.get("stance", 0.5)) * 60.0))
		"sicheltakt":
			Sfx.play("swing_light")


# --- per frame ----------------------------------------------------------------

func tick(delta: float) -> void:
	for z in cooldowns:
		cooldowns[z] = maxf(0.0, cooldowns[z] - delta)
	invuln = maxf(0.0, invuln - delta)
	_say_cd = maxf(0.0, _say_cd - delta)
	_lost = maxf(0.0, _lost - delta)
	for id in _immune.keys():
		_immune[id] -= delta
		if _immune[id] <= 0.0:
			_immune.erase(id)
	_tick_beat(delta)
	_idle += delta
	if _idle > DECAY_AFTER and klang > 0 and fmod(_idle - DECAY_AFTER, 1.0) < delta:
		klang -= 1
	if player.is_on_floor():
		_air_bounce_used = false
	_draw_partner()
	if _linger > 0.0:
		_linger -= delta
		if _linger <= 0.0:
			_linger_hit()
	if not busy():
		return
	t += delta
	_age += delta
	if not _decided and _age >= 0.15:
		_decide_enhanced()
	if phase != "startup" and Input.is_action_just_pressed("special"):
		_follow = true
	match zug_id:
		"sicheltakt":
			_tick_sicheltakt()
		"seelensichel":
			_tick_seelensichel()
		"himmelsreigen":
			_tick_himmelsreigen()
		"seelenlauschen":
			_tick_lauschen()
		"sichelschritt":
			_tick_schritt()
		"fallende_sichel":
			_tick_fall()


func _tick_beat(delta: float) -> void:
	var before := int(_beat_t / BEAT)
	_beat_t += delta
	_beat_pulse = maxf(0.0, _beat_pulse - delta * 4.0)
	if int(_beat_t / BEAT) != before:
		_beat_n += 1
		_beat_pulse = 1.0
		if active() and _lost <= 0.0 and not player.in_super and play_sound():
			Sfx.play("bell_tick")


## Beat ring, Klangloch and the bubble anchor, every frame.
func _draw_partner() -> void:
	if not player.sprite.visible:
		return
	var hole := klangloch_pos()
	kfx.speech_anchor(hole)
	var full := klang >= MAX_KLANG
	var s := clampf(_beat_pulse * 0.7 + float(klang) / MAX_KLANG * 0.4, 0.0, 1.0)
	if full:
		s = 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.02)
	kfx.klangloch(hole, s, style.color("white") if full else style.color("blue"))
	if not show_visual():
		s = float(klang) / MAX_KLANG * 0.5  # Klangloch shows only the Einklang
	if active() and not player.in_super and show_visual():
		kfx.beat_ring(player.global_position + Vector2(0, -20), beat_progress(), _lost > 0.0, takt_mode == 3)
	if full and randf() < 0.15:
		kfx.motes(hole, 1, 4.0, style.color("white"), 0.5)


# --- hits, Einklang, Leiste -----------------------------------------------------

func on_zug_hit(zid: String, targets: Array) -> void:
	if targets.is_empty():
		return
	_missed = false
	_idle = 0.0
	player.add_gauge(6.0 if zid == zug_id and not _reported else 1.5)
	if zid == zug_id and _reported:
		return
	if zid == zug_id:
		_reported = true
	var gain := 1 if zid != _last_zug else 0
	_last_zug = zid
	if on_beat(targets):
		gain += 1
		_beat_hit(targets)
	_add_klang(gain)


func _beat_hit(targets: Array) -> void:
	var tg: Node2D = targets[0]
	var c: Vector2 = tg.get_hurt_rect().get_center()
	kfx.ring(c, 26.0, style.color("pale"), 0.3, 3.0)
	kfx.note(c + Vector2(randf_range(-8, 8), -24))
	kfx.word(c + Vector2(0, -36), "KLANG!", style.color("pale"), 18)
	Sfx.play("bell_hit")
	if randf() < 0.35:
		_say("beat")


func _add_klang(gain: int) -> void:
	if gain <= 0 or klang >= MAX_KLANG:
		return
	klang = mini(MAX_KLANG, klang + gain)
	var c := klangloch_pos()
	kfx.glow(c, Color(style.color("blue"), 0.8), 8.0 + klang * 2.0, 0.25)
	kfx.motes(c, 2 + klang, 6.0, style.color("pale"), 0.5)
	if klang >= MAX_KLANG:
		kfx.ring(c, 30.0, style.color("white"), 0.4, 4.0)
		kfx.word(c + Vector2(-player.facing * 16.0, -46), "EINKLANG", style.color("white"), 20)
		Sfx.play("bell_hit", 3.0)
		_say("ready", true)


## J/K: keep the combo alive; a hit on the beat fills 1 (once per beat).
func on_normal_hit() -> void:
	_idle = 0.0
	if on_beat() and _normal_beat != _beat_n:
		_normal_beat = _beat_n
		var c := player.global_position + Vector2(player.facing * 26.0, -30.0)
		kfx.note(c)
		kfx.ring(c, 16.0, style.color("pale"), 0.25, 2.0)
		Sfx.play("bell_hit", -4.0)
		_add_klang(1)


## Damage with the sweet spot: outer edge +15 %, shaft (too close) -30 %.
func _hit(rect: Rect2, dmg: float, kb: float, profile := "", launch := 0.0, hit_set = null, reach := 0.0, from_x := INF) -> Array:
	var out: Array = []
	var fx_x := player.global_position.x if from_x == INF else from_x
	for tg in world.get_tree().get_nodes_in_group("targets"):
		if hit_set != null and hit_set.has(tg.get_instance_id()):
			continue
		if not rect.intersects(tg.get_hurt_rect()):
			continue
		if hit_set != null:
			hit_set[tg.get_instance_id()] = true
		var d := dmg * (1.25 if _stack else 1.0)
		var tip := false
		if reach > 0.0:
			var dist := absf(tg.get_hurt_rect().get_center().x - player.global_position.x)
			if dist > reach * 0.55:
				d *= 1.15
				tip = true
			elif dist < reach * 0.22 and not params.get("short", false):
				d *= 0.7
		world.deal_hit(tg, d, "seele", fx_x, kb, profile, launch)
		if tip:
			var c: Vector2 = tg.get_hurt_rect().get_center()
			kfx.shards(c, 0.0 if player.facing > 0 else PI, 0.5, 4, 260.0)
		out.append(tg)
	on_zug_hit(zug_id, out)
	return out


## Seelenbruch on the targets of a verstärkter finisher.
func _break(targets: Array) -> void:
	if not enhanced:
		return
	for tg in targets:
		if not is_instance_valid(tg) or not (tg.get("status") is Dictionary):
			continue
		var id: int = tg.get_instance_id()
		if _immune.has(id):
			continue
		var fresh: bool = not tg.status.has("seelenbruch")
		tg.status["seelenbruch"] = BREAK_TIME
		var tough: bool = tg.has_method("is_elite") and tg.is_elite()
		if tough:
			_immune[id] = BREAK_TIME + BREAK_IMMUNE
		if fresh:
			var c: Vector2 = tg.get_hurt_rect().get_center()
			kfx.ring(c, 30.0, style.color("violet"), 0.45, 4.0)
			kfx.ring(c, 18.0, style.color("red"), 0.3, 2.0)
			kfx.word(c + Vector2(0, -44), "SEELENBRUCH", style.color("violet"), 18)


# --- geometry helpers -------------------------------------------------------------

func _center() -> Vector2:
	return player.global_position + Vector2(0, -20)


## Angle in front of the figure: 0 = straight ahead, negative = up.
func _fa(a: float) -> float:
	return a if player.facing > 0 else PI - a


func _sweep(r: float, a0: float, a1: float, w: float, col: Color, life := 0.24, at := Vector2.INF) -> void:
	var c := _center() if at == Vector2.INF else at
	kfx.arc(c, r, _fa(a0), _fa(a1), w, col, life)


## J/K swing with the scythe: a PixelLab arc along the hitbox in the
## Klangfarbe (replaces the Glutatem katana arcs of the base class).
func on_swing(move: Dictionary, center: Vector2, width: float) -> void:
	if kfx == null or not show_visual():
		return
	var ang := float(move.get("angle", 0.0))
	var id := "schnitt_quer"
	var rot := 0.0
	if str(move.get("draw", "")) == "sweep" or str(move.get("draw", "")) == "spin":
		id = "schnitt_wirbel"
	elif ang < -30.0 or float(move.get("launch", 0.0)) > 150.0:
		id = "schnitt_hoch"
	elif ang > 30.0:
		rot = 0.5 * player.facing
	var heavy: bool = move.get("button", "") == "heavy"
	var col := trail_color().lerp(Color.WHITE, 0.5)
	kfx.klang_burst(id, center, clampf(width * (1.7 if heavy else 1.4), 44.0, 120.0), 0.22 if not heavy else 0.28, rot, player.facing < 0, col, 0.7)


func _swing_sound(heavy: bool) -> void:
	Sfx.play("swing_heavy" if heavy else "swing_light")


# --- Sicheltakt -------------------------------------------------------------------

func _tick_sicheltakt() -> void:
	var dmg: Array = params.get("damage", [6, 6, 12])
	var n := dmg.size()
	var reach: float = float(params.get("reach", 50))
	var arc: float = float(params.get("arc", 1.0))
	var heavy: bool = params.get("heavy", false)
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
	elif phase == "active":
		var due := int(t / maxf(0.001, _f(1)) * n) + 1
		while _step < mini(due, n):
			var i := _step
			_step += 1
			var last := _step == n
			var down := i % 2 == 0
			var a0 := -1.9 if down else 1.0
			var a1 := 0.9 if down else -1.7
			if last:
				a0 = -2.2
				a1 = 1.1
			var r := reach * 0.62
			var col := style.color("white") if last and enhanced else style.color("blue")
			_sweep(r, a0, a1, (9.0 if last else 6.0) * (1.3 if heavy else 1.0) * sqrt(arc), col, 0.24 if last else 0.18)
			var h := 44.0 * arc
			var rect := Rect2(player.global_position.x if player.facing > 0 else player.global_position.x - reach, player.global_position.y - 20 - h / 2.0, reach, h)
			var kb := 150.0 if last else (110.0 if heavy else 40.0)
			var tg := _hit(rect, float(dmg[i]), kb, "heavy" if last or heavy else "light", 0.0, {}, reach)
			if last:
				_break(tg)
				_swing_sound(true)
				kfx.klang_burst("sicheltakt", player.global_position + Vector2(player.facing * reach * 0.6, -26.0), 64.0, 0.3, 0.0, player.facing < 0)
				if not tg.is_empty():
					kfx.word(player.global_position + Vector2(player.facing * reach * 0.8, -50), "SHING!", style.color("white"), 22)
					world.fx.shake(3.0 * FxSettings.factor("shake"), player.facing)
				if params.get("linger", false):
					_linger = 0.15
			else:
				_swing_sound(false)
		if t >= _f(1):
			_next_phase()
	elif phase == "recovery" and t >= _f(2):
		_next_phase()


## Verstärkt: the last arc stays for a moment and cuts once more.
func _linger_hit() -> void:
	var reach: float = float(params.get("reach", 50)) * 1.1
	kfx.arc(_center(), reach * 0.62, _fa(-2.2), _fa(1.1), 12.0, style.color("white"), 0.4)
	kfx.contour(_center(), reach * 0.62, minf(_fa(-2.2), _fa(1.1)), maxf(_fa(-2.2), _fa(1.1)), 0.35)
	var rect := Rect2(player.global_position.x if player.facing > 0 else player.global_position.x - reach, player.global_position.y - 46, reach, 52)
	var hs := {}
	var tg := GlutHazard.strike(world, rect, 8.0, player.global_position.x, 120.0, "heavy", 0.0, hs, "seele")
	if not tg.is_empty():
		player.add_gauge(3.0)
		kfx.word(player.global_position + Vector2(player.facing * reach * 0.7, -56), "KLANG!", style.color("pale"), 20)


# --- Seelensichel ------------------------------------------------------------------

func _tick_seelensichel() -> void:
	var reach: float = float(params.get("reach", 62))
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
			_swing_sound(true)
			if params.get("wave", false):
				_spawn_wave(player.global_position + Vector2(player.facing * 20.0, -22.0), player.facing, 213.0 * (1.5 if enhanced else 1.0), float(params.damage), false)
				kfx.word(player.global_position + Vector2(player.facing * 30.0, -50), "SWISH!", style.color("pale"), 20)
				kfx.klang_burst("seelensichel", player.global_position + Vector2(player.facing * 40.0, -24.0), 70.0, 0.45, 0.0, player.facing < 0, Color.WHITE, 0.5, Vector2(player.facing * 420.0, 0))
				return
			var soul: bool = params.get("soul", false)
			var r := reach * 0.6
			_sweep(r, -0.9, 0.7, 8.0, style.color("blue"), 0.24)
			kfx.klang_burst("seelensichel", player.global_position + Vector2(player.facing * reach * 0.55, -24.0), 76.0 if not soul else 92.0, 0.32, 0.0, player.facing < 0, Color.WHITE, 0.6)
			if soul:
				_sweep(reach * 0.75, -0.8, 0.6, 14.0, style.color("violet"), 0.36)
				kfx.contour(_center(), reach * 0.75, minf(_fa(-0.8), _fa(0.6)), maxf(_fa(-0.8), _fa(0.6)), 0.3)
			var rect := Rect2(player.global_position.x if player.facing > 0 else player.global_position.x - reach, player.global_position.y - 46, reach, 46)
			var tg := _hit(rect, float(params.damage), 120.0, "heavy", 0.0, _hit_set, reach)
			_break(tg)
			if not tg.is_empty():
				kfx.word(player.global_position + Vector2(player.facing * reach * 0.7, -50), "SHING!", style.color("white"), 22)
	elif phase == "active":
		if t >= _f(1):
			_next_phase()
	elif phase == "recovery":
		if _follow and params.get("pull", false) and not _did_follow:
			_did_follow = true
			phase = "back"
			t = 0.0
			_hit_set = {}
			_reported = true  # the return cut belongs to the same Zug
			_swing_sound(false)
			_sweep(reach * 0.6, 0.7, -0.9, 7.0, style.color("pale"), 0.22)
			var rect2 := Rect2(player.global_position.x if player.facing > 0 else player.global_position.x - reach, player.global_position.y - 46, reach, 46)
			# from_x behind the targets: the knockback pulls them in
			_hit(rect2, 10.0, 90.0, "light", 0.0, _hit_set, reach, player.global_position.x + player.facing * (reach + 40.0))
			kfx.word(player.global_position + Vector2(player.facing * 30.0, -50), "SWISH!", style.color("pale"), 18)
		elif t >= _f(2):
			_next_phase()
	elif phase == "back" and t >= 0.25:
		_next_phase()


func _spawn_wave(pos: Vector2, dir: float, dist: float, dmg: float, ground: bool) -> void:
	var w := KlangWave.new()
	w.world = world
	w.kfx = kfx
	w.caster = self
	w.zug_id = zug_id
	w.dir = dir
	w.dist = dist
	w.damage = dmg
	w.ground = ground
	w.col = style.color("white") if enhanced else style.color("blue")
	w.global_position = pos
	world.attacks.add_child(w)


# --- Himmelsreigen -----------------------------------------------------------------

func _tick_himmelsreigen() -> void:
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
			_swing_sound(true)
			var dmg: float = float(params.get("damage", 11))
			if params.get("overhead", false):
				_sweep(30.0, -2.6, -0.4, 10.0, style.color("blue"), 0.26)
				var r0 := Rect2(player.global_position.x - 34, player.global_position.y - 92, 68, 56)
				var tg0 := _hit(r0, dmg, 160.0, "heavy", 0.0, _hit_set)
				_break(tg0)
				kfx.klang_burst("himmelsreigen", player.global_position + Vector2(player.facing * 12.0, -56.0), 96.0, 0.4, 0.0, player.facing < 0)
				if not tg0.is_empty():
					kfx.word(player.global_position + Vector2(0, -96), "KLANG!", style.color("white"), 22)
				return
			var wide: bool = params.get("wide", false)
			var w := 88.0 if wide else 52.0
			_sweep(34.0 if not wide else 44.0, 1.1, -1.8, 9.0, style.color("blue"), 0.26)
			kfx.klang_burst("himmelsreigen", player.global_position + Vector2(player.facing * w * 0.4, -46.0), 100.0 if not wide else 120.0, 0.36, 0.0, player.facing < 0)
			var rect := Rect2(player.global_position.x + (0.0 if player.facing > 0 else -w), player.global_position.y - 70, w, 70)
			var tg := _hit(rect, dmg, 30.0, "heavy", float(params.get("launch", 330)), _hit_set, w)
			_break(tg)
			if not tg.is_empty():
				kfx.word(player.global_position + Vector2(player.facing * 30.0, -70), "SWISH!", style.color("pale"), 20)
				kfx.motes(player.global_position + Vector2(player.facing * 24.0, -40), 6, 12.0)
	elif phase == "active":
		if t >= _f(1):
			_next_phase()
	elif phase == "recovery":
		if _follow and params.get("follow", true) and not _did_follow:
			# follow the lifted target with a jump
			_did_follow = true
			player.velocity = Vector2(player.facing * 90.0, -420.0)
			kfx.ring(player.global_position + Vector2(0, -4), 16.0, style.color("pale"), 0.25, 2.0)
			_next_phase()
		elif t >= _f(2):
			_next_phase()


# --- Seelenlauschen -------------------------------------------------------------------

func _tick_lauschen() -> void:
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
			countering = true
			# the souls around become visible as pale outlines
			for tg in world.get_tree().get_nodes_in_group("targets"):
				if absf(tg.global_position.x - player.global_position.x) < 260.0:
					kfx.ring_in(tg.get_hurt_rect().get_center(), 26.0, style.color("violet"), 0.45, 1.5)
			kfx.ring_in(_center(), 30.0, style.color("pale"), 0.35, 2.0)
	elif phase == "active":
		var perfect: float = float(params.get("perfect", 0.2))
		countering = t <= perfect
		var c := _center()
		var pulse := 0.5 + 0.5 * sin(t * 24.0)
		kfx.glow(c, Color(style.color("blue"), 0.12 + 0.12 * pulse), 22.0, 0.05)
		if randf() < 0.12:
			kfx.note(klangloch_pos() + Vector2(randf_range(-4, 4), -6), style.color("pale"))
		if t >= _f(1):
			countering = false
			_next_phase()
	elif phase == "counter":
		if _step == 0 and t >= 0.1:
			_step = 1
			var dmg: float = float(params.get("counter_damage", 16))
			if dmg > 0.0:
				_sweep(36.0, -2.0, 1.0, 11.0, style.color("white"), 0.28)
				var rect := Rect2(player.global_position.x if player.facing > 0 else player.global_position.x - 62, player.global_position.y - 48, 62, 50)
				var tg := _hit(rect, dmg, 220.0, "heavy", 80.0, _hit_set, 62.0)
				if params.get("break", false):
					_break(tg)
				kfx.word(player.global_position + Vector2(player.facing * 30.0, -56), "SHING!", style.color("white"), 24)
				kfx.klang_burst("sicheltakt", player.global_position + Vector2(player.facing * 34.0, -26.0), 80.0, 0.35, 0.0, player.facing < 0)
		if t >= 0.32:
			_next_phase()
	elif phase == "recovery" and t >= _f(2) * 0.6:
		_next_phase()


func try_counter(from_x: float, projectile: Node = null) -> bool:
	if zug_id != "seelenlauschen" or phase != "active":
		return false
	if not countering:
		# late: the stance still holds, but the beat is gone
		_lost = LOST_TIME
		invuln = 0.2
		kfx.ring(_center(), 20.0, Color(0.6, 0.6, 0.7), 0.25, 2.0)
		kfx.word(_center() + Vector2(0, -34), "GEHALTEN", style.color("pale"), 16)
		Sfx.play("block")
		return true
	countering = false
	invuln = 0.45
	phase = "counter"
	t = 0.0
	_step = 0
	_hit_set = {}
	player.facing = 1 if from_x >= player.global_position.x else -1
	var c := _center()
	kfx.ring(c, 34.0, style.color("white"), 0.4, 4.0)
	kfx.shards(c, -PI / 2.0, PI, 14, 240.0, style.color("pale"))
	kfx.word(c + Vector2(0, -44), "KONTER!", style.color("white"), 28)
	kfx.klang_burst("seelenlauschen", c, 72.0, 0.5, 0.0, false, Color.WHITE, 0.3)
	world.fx.flash(0.2 * FxSettings.factor("flash"), Color(0.75, 0.88, 1.0))
	world.fx.freeze(0.1 * FxSettings.factor("stop"))
	world.fx.shake(5.0 * FxSettings.factor("shake"))
	Sfx.play("bell_hit", 2.0)
	player.add_gauge(15.0)
	_idle = 0.0
	var gain := int(params.get("klang_gain", 0))
	if gain > 0:
		_add_klang(gain)
		kfx.word(c + Vector2(0, -62), "+%d EINKLANG" % gain, style.color("pale"), 16)
	_say("counter")
	if projectile != null and projectile.has_method("burn"):
		projectile.burn()
	return true


# --- Sichelschritt ------------------------------------------------------------------------

func _tick_schritt() -> void:
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
			_x_start = player.global_position.x
			_plant = player.global_position + Vector2(player.facing * 14.0, 0)
			kfx.glow(_plant, Color(style.color("blue"), 0.7), 12.0, 0.25)
			kfx.ring(_plant + Vector2(0, -2), 12.0, style.color("pale"), 0.25, 2.0)
			if params.get("vault", false):
				player.velocity.y = -440.0
			elif player.is_on_floor():
				player.velocity.y = -150.0
			invuln = float(params.get("iframes", 0.0))
			if params.get("ring", false):
				kfx.ring(_plant + Vector2(0, -12), 46.0, style.color("blue"), 0.4, 4.0)
				var rect := Rect2(_plant - Vector2(46, 40), Vector2(92, 46))
				var tg := GlutHazard.strike(world, rect, 4.0, _plant.x, 20.0, "heavy", 0.0, {}, "seele")
				if not tg.is_empty():
					on_zug_hit(zug_id, tg)
			kfx.word(player.global_position + Vector2(0, -50), "SWISH!", style.color("pale"), 18)
			kfx.klang_burst("sichelschritt", player.global_position + Vector2(player.facing * 30.0, -22.0), 90.0, 0.3, 0.0, player.facing < 0, Color.WHITE, 0.6, Vector2(player.facing * 240.0, 0))
	elif phase == "active":
		_ghost_t -= get_physics_process_delta_time()
		if _ghost_t <= 0.0:
			_ghost_t = 0.04
			player.world.afterimages.add(player.sprite.snapshot(), Color(0.6, 0.8, 1.6, 0.5))
		if _follow and not _did_follow:
			_follow_cut()
		if t >= _f(1) or player.is_on_wall():
			if params.get("pass", false) and not _did_follow:
				player.facing = -player.facing
				_follow_cut()
			_next_phase()
	elif phase == "recovery":
		if _follow and not _did_follow:
			_follow_cut()
		if t >= _f(2):
			_next_phase()


func _follow_cut() -> void:
	_did_follow = true
	_follow = false
	_swing_sound(false)
	_sweep(30.0, -0.4, 1.4, 8.0, style.color("blue"), 0.22)
	var rect := Rect2(player.global_position.x if player.facing > 0 else player.global_position.x - 56, player.global_position.y - 44, 56, 44)
	var tg := _hit(rect, float(params.get("damage", 10)), 120.0, "heavy", 0.0, {}, 56.0)
	_break(tg)
	if not tg.is_empty():
		kfx.word(player.global_position + Vector2(player.facing * 30.0, -50), "SHING!", style.color("white"), 20)


# --- Fallende Sichel ------------------------------------------------------------------------

func _tick_fall() -> void:
	if phase == "startup":
		var spin := t / maxf(0.001, _f(0))
		if _step == 0 and spin > 0.3:
			_step = 1
			kfx.arc(_center(), 22.0, 0.0, TAU * 0.85 * (1.0 if player.facing > 0 else -1.0), 6.0, style.color("blue"), 0.25)
		if t >= _f(0):
			phase = "fall"
			t = 0.0
			_hit_set = {}
			_swing_sound(true)
	elif phase == "fall":
		_ghost_t -= get_physics_process_delta_time()
		if _ghost_t <= 0.0:
			_ghost_t = 0.035
			player.world.afterimages.add(player.sprite.snapshot(), Color(0.6, 0.8, 1.6, 0.45))
		var wide: bool = params.get("wide", false)
		var w := 70.0 if wide else 44.0
		var rect := Rect2(player.global_position + Vector2(-w / 2.0 + player.facing * 10.0, -34), Vector2(w, 40))
		if wide and fmod(t, 0.12) < get_physics_process_delta_time():
			_hit_set = {}
			_sweep(28.0, -2.8, 0.6, 6.0, style.color("blue"), 0.16)
		var tg := _hit(rect, float(params.get("damage", 14)) * (0.5 if wide else 1.0), 60.0, "heavy", -200.0 if params.get("steep", false) else 0.0, _hit_set, w)
		if not tg.is_empty():
			if params.get("bounce", false) and not _air_bounce_used and not player.is_on_floor():
				_air_bounce_used = true
				player.velocity = Vector2(-player.facing * 80.0, -300.0)
				kfx.ring(player.global_position + Vector2(0, -10), 18.0, style.color("pale"), 0.25, 2.0)
				kfx.word(player.global_position + Vector2(0, -50), "KLANG!", style.color("pale"), 18)
				_next_phase()
				return
		if player.is_on_floor() and t > 0.02:
			_land()
			_next_phase()
			if _missed:
				frames[2] = int(frames[2]) + 6  # open after a whiff
		elif t > 0.9:
			_next_phase()
	elif phase == "recovery" and t >= _f(2):
		_next_phase()


func _land() -> void:
	var p := player.global_position
	_sweep(34.0, -1.6, 0.9, 10.0, style.color("blue"), 0.24, p + Vector2(0, -16))
	kfx.ring(p + Vector2(0, -4), 34.0, style.color("pale"), 0.3, 3.0)
	kfx.shards(p + Vector2(player.facing * 10.0, -2), -PI / 2.0, 1.1, 10, 220.0, style.color("pale"))
	kfx.word(p + Vector2(0, -52), "KLANG!", style.color("white"), 26)
	kfx.klang_burst("fallende_sichel", p + Vector2(player.facing * 8.0, -44.0), 96.0, 0.45, 0.0, player.facing < 0)
	world.fx.shake(5.0 * FxSettings.factor("shake"))
	world.fx.punch(0.03)
	var hs := {}
	var tg := GlutHazard.strike(world, Rect2(p.x - 36, p.y - 30, 72, 32), float(params.get("damage", 14)) * 0.5, p.x, 140.0, "heavy", 0.0, hs, "seele")
	if not tg.is_empty():
		on_zug_hit(zug_id, tg)
		_break(tg)
	if params.get("wave", false):
		for d in [-1.0, 1.0]:
			_spawn_wave(p + Vector2(d * 8.0, -10.0), d, 150.0, 8.0, true)


# --- movement & pose for the player --------------------------------------------

func drive_velocity(v: Vector2, delta: float, on_floor: bool) -> Vector2:
	match zug_id:
		"seelensichel":
			if phase == "startup":
				return Vector2(player.facing * float(params.get("step", 26)) / maxf(0.01, _f(0)), minf(v.y + Player.GRAVITY * delta, Player.MAX_FALL))
		"sichelschritt":
			if phase == "active":
				return Vector2(player.facing * float(params.get("dist", 92)) / maxf(0.01, _f(1)), minf(v.y + Player.GRAVITY * delta, Player.MAX_FALL))
		"fallende_sichel":
			if phase == "fall":
				var steep: bool = params.get("steep", false)
				var wide: bool = params.get("wide", false)
				var vx := 40.0 if steep else (60.0 if wide else 130.0)
				return Vector2(player.facing * vx, float(params.get("fall", 620)))
			if phase == "startup":
				return Vector2(v.x * 0.9, minf(v.y + Player.GRAVITY * 0.8 * delta, 120.0))
		"seelenlauschen":
			if phase == "counter" and t < 0.08:
				return Vector2(-player.facing * 160.0, minf(v.y + Player.GRAVITY * delta, Player.MAX_FALL))
			if phase == "counter":
				return Vector2(player.facing * 120.0, minf(v.y + Player.GRAVITY * delta, Player.MAX_FALL))
			return Vector2(0.0, minf(v.y + Player.GRAVITY * delta, Player.MAX_FALL))
		"himmelsreigen":
			if phase == "recovery" and _did_follow:
				return Vector2(v.x, minf(v.y + Player.GRAVITY * delta, Player.MAX_FALL))
	return super.drive_velocity(v, delta, on_floor)
