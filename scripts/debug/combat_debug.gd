class_name CombatDebug
extends CanvasLayer
## Combat debug view for tuning (key 0): shows every box and the frame data
## of the running move, so you see at once why a follow-up does not link.
##  - red: hitboxes of the player's attacks, orange: enemy attack boxes,
##    green: hurtboxes of targets, blue: the player's hurtbox (white while
##    invulnerable)
##  - over the player: move name, phase and frame, a frame bar
##    (yellow startup, red active, blue recovery) with a cursor, CANCEL when
##    the cancel rules allow a follow-up, and the buffered button
##  - over enemies: state, hitstun left as a bar, juggle hits
##  - last hit: hitstun in frames, frame advantage (+ = you act first) and
##    whether it was a real combo (target still staggered) or had a gap.
## Key 9 cycles slow motion (100 / 50 / 25 / 10 %); it also scales the
## kill slow motion, see TrainingRoom._slowmo.

const SLOW_STEPS := [1.0, 0.5, 0.25, 0.1]
const C_HIT := Color(1.0, 0.25, 0.25)
const C_ENEMY_HIT := Color(1.0, 0.6, 0.15)
const C_HURT := Color(0.3, 1.0, 0.45)
const C_PLAYER := Color(0.35, 0.65, 1.0)
const C_STARTUP := Color("f9c22b")
const C_ACTIVE := Color("ff4b3e")
const C_RECOVERY := Color("4b8bff")

## Kept across scene reloads, so the view stays on while tuning.
static var enabled := false
static var time_factor := 1.0

var room: Node
var _draw_node: Node2D
var _font: Font
## Last hit: {stun_f, adv_f (or null), linked, combo, move, profile, t}
var _last: Dictionary = {}


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS  # also during hit-stop and supers
	_font = ThemeDB.fallback_font
	_draw_node = Node2D.new()
	_draw_node.draw.connect(_on_draw)
	add_child(_draw_node)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_view"):
		enabled = not enabled
		_toast("Kampf-Debug: " + ("an" if enabled else "aus"))
	if Input.is_action_just_pressed("debug_slow"):
		var i := SLOW_STEPS.find(time_factor)
		time_factor = SLOW_STEPS[(i + 1) % SLOW_STEPS.size()]
		Engine.time_scale = time_factor
		_toast("Zeitlupe: %d %%" % int(round(time_factor * 100.0)))
	_draw_node.visible = enabled or time_factor < 1.0
	if _draw_node.visible:
		_draw_node.queue_redraw()


## Called by TrainingRoom.deal_hit with the final hitstun of the hit.
func note_hit(_target: Node, stun: float, linked: bool, combo: int, profile: String) -> void:
	var p: Player = room.player
	var adv = null
	var move_name := ""
	if p != null and not p.move.is_empty():
		var speed: float = p.glut.normal_speed() if p.glut != null else 1.0
		var left := (MoveSet.length(p.move) - p.move_t) * MoveSet.FPS / maxf(0.1, speed)
		adv = int(round(stun * MoveSet.FPS - left))
		move_name = str(p.move.get("name", p.move.get("id", "")))
	_last = {"stun_f": int(round(stun * MoveSet.FPS)), "adv_f": adv, "linked": linked,
		"combo": combo, "move": move_name, "profile": profile, "t": Time.get_ticks_msec()}


func _toast(text: String) -> void:
	if room != null and room.has_method("toast"):
		room.toast(text)


func _on_draw() -> void:
	var xf: Transform2D = _draw_node.get_viewport().get_canvas_transform()
	if enabled:
		_draw_boxes(xf)
		_draw_enemies(xf)
		_draw_player(xf)
	_draw_corner()


func _rect(xf: Transform2D, r: Rect2, col: Color, fill := 0.18) -> void:
	var s := Rect2(xf * r.position, r.size * xf.get_scale())
	_draw_node.draw_rect(s, Color(col, fill))
	_draw_node.draw_rect(s, col, false, 1.0)


func _text(pos: Vector2, text: String, col: Color, size := 12) -> void:
	_draw_node.draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0, 0, 0, 0.85))
	_draw_node.draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_boxes(xf: Transform2D) -> void:
	for t in room.get_tree().get_nodes_in_group("targets"):
		var r: Rect2 = t.get_hurt_rect()
		if r.size.x > 0.0:
			_rect(xf, r, C_HURT, 0.1)
	var p: Player = room.player
	if p != null:
		var inv: bool = p.dash_timer > 0.0 or p.hurt_invuln > 0.0 or p.in_super
		_rect(xf, p.get_hurt_rect(), Color.WHITE if inv else C_PLAYER, 0.12)
	if room.attacks != null:
		for a in room.attacks.get_children():
			if a is Attack and is_instance_valid(a.owner_body) and a.owner_body == p:
				_rect(xf, a.hit_rect(), C_HIT, 0.3)
	for e in room.get_tree().get_nodes_in_group("targets"):
		if e is Enemy and e.debug_rect_t > 0.0:
			_rect(xf, e.debug_rect, C_ENEMY_HIT, 0.3)


func _draw_enemies(xf: Transform2D) -> void:
	for e in room.get_tree().get_nodes_in_group("targets"):
		if not e is Enemy or e.state == "dead":
			continue
		var top: Vector2 = xf * (e.global_position + Vector2(-20, 0)) + Vector2(0, 14)  # under the feet
		var line: String = {"hurt": "getroffen", "idle": "wartet", "move": "läuft", "windup": "holt aus",
			"strike": "greift an", "recover": "erholt sich", "spawn": "taucht auf"}.get(e.state, e.state)
		if e._juggle > 0:
			line += "  J%d  G x%.2f" % [e._juggle, HitFeel.juggle_gravity(e._juggle, e.vel.y)]
		_text(top, line, Color(1, 1, 1, 0.9), 11)
		if e.state == "hurt":
			var left := maxf(0.0, e._stun - e._st)
			var w := 40.0
			var k := clampf(left / maxf(0.01, e._stun), 0.0, 1.0)
			_draw_node.draw_rect(Rect2(top + Vector2(0, 4), Vector2(w, 4)), Color(0, 0, 0, 0.6))
			_draw_node.draw_rect(Rect2(top + Vector2(0, 4), Vector2(w * k, 4)), C_ACTIVE)
			_text(top + Vector2(w + 4, 9), "%df" % int(ceil(left * MoveSet.FPS)) if e.on_ground else "Luft", C_ACTIVE, 10)


func _draw_player(xf: Transform2D) -> void:
	var p: Player = room.player
	if p == null:
		return
	var head: Vector2 = xf * (p.global_position + Vector2(0, -78))
	var x := head.x - 60.0
	var y := head.y
	if not p.move.is_empty():
		var m: Dictionary = p.move
		var f := p.move_t * MoveSet.FPS
		var su := float(m.startup)
		var ac := float(m.active)
		var re := float(m.recovery)
		var total := maxf(1.0, su + ac + re)
		var ph := MoveSet.phase_at(m, p.move_t)
		var ph_name: String = {"startup": "Anlauf", "active": "AKTIV", "recovery": "Erholung"}[ph]
		_text(Vector2(x, y), "%s  %s  %d/%d" % [str(m.get("name", m.get("id", ""))), ph_name, int(f) + 1, int(total)], Color.WHITE, 12)
		# frame bar
		var w := 120.0
		var by := y + 5.0
		_draw_node.draw_rect(Rect2(x, by, w * su / total, 6), C_STARTUP)
		_draw_node.draw_rect(Rect2(x + w * su / total, by, w * ac / total, 6), C_ACTIVE)
		_draw_node.draw_rect(Rect2(x + w * (su + ac) / total, by, w * re / total, 6), C_RECOVERY)
		for i in int(total) + 1:  # frame ticks
			var tx := x + w * float(i) / total
			_draw_node.draw_line(Vector2(tx, by), Vector2(tx, by + 2), Color(0, 0, 0, 0.5), 1.0)
		var cx := x + w * clampf(f / total, 0.0, 1.0)
		_draw_node.draw_line(Vector2(cx, by - 2), Vector2(cx, by + 8), Color.WHITE, 2.0)
		var tags := PackedStringArray()
		if p.move_hit:
			tags.append("TREFFER")
		if p._can_cancel():
			tags.append("CANCEL")
		if p._queued != "":
			tags.append("Puffer: " + _button_name(p._queued))
		if not tags.is_empty():
			_text(Vector2(x, by + 20), "  ".join(tags), Color("7dff8a") if p._can_cancel() else Color("ffe45c"), 11)
	elif p._queued != "":
		_text(Vector2(x, y), "Puffer: " + _button_name(p._queued), Color("ffe45c"), 11)
	# last hit (shown 2 s)
	if not _last.is_empty() and Time.get_ticks_msec() - int(_last.t) < 2000:
		var adv = _last.adv_f
		var adv_txt := "—" if adv == null else ("%+df" % int(adv))
		var col := Color("7dff8a") if adv == null or int(adv) >= 0 else Color("ff6b5e")
		var y2 := y + (40.0 if not p.move.is_empty() else 14.0)
		_text(Vector2(x, y2), "Hitstun %df  Vorteil %s  %s" % [int(_last.stun_f), adv_txt,
			"Kombo x%d" % int(_last.combo) if _last.linked else "Lücke"], col, 11)


func _draw_corner() -> void:
	var lines := PackedStringArray()
	if enabled:
		lines.append("KAMPF-DEBUG [0]   Zeitlupe [9]: %d %%" % int(round(time_factor * 100.0)))
		lines.append("rot Treffer  orange Gegnerangriff  grün Körper  blau du (weiß = unverwundbar)")
	else:
		lines.append("Zeitlupe [9]: %d %%" % int(round(time_factor * 100.0)))
	var y := 320.0
	for l in lines:
		_text(Vector2(12, y), l, Color("ffe45c"), 12)
		y += 16.0


func _button_name(b: String) -> String:
	return {"light": "Leicht", "heavy": "Schwer", "special": "Spezial", "grab": "Griff"}.get(b, b)
