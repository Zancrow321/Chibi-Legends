class_name TowerDirector
extends RaidDirector
## Turm der Prüfungen (Endloser Turm, solo): floor after floor of enemies
## that get stronger, every fifth floor a Turmwache (a smaller Essenwächter
## with Wucht-Leiste and, from floor 15, one shield phase). Each cleared
## floor pays Splitter, every fifth floor a piece of gear whose item level
## climbs with the floor. A knock-out ends the run; the best floor is kept
## overall and per week (user://turm.json) for the later leaderboard.

const START_X := 300.0
const GUARD_EVERY := 5
const SPAWN_X := [600.0, 760.0, 900.0, 1080.0, 1200.0]
## Enemy pool: [type, first floor it shows up]
const POOL := [["moosling", 1], ["rindenwicht", 1], ["sumpfdorn", 2], ["glutigel", 3], ["saebeltiger", 4], ["moosgolem", 7]]
const SAVE_PATH := "user://turm.json"
const PAUSE := 2.2
const RESTART := 3.0

var floor_no := 0
var state := "wait"  # wait, fight, cleared, over
var alive: Array = []
var best := 0
var week_best := 0
var run_splitter := 0
var run_items := 0
var _t := 0.0


func _ready() -> void:
	_load()


## Base strength of a floor: +18 % HP and +7 % damage per floor.
static func hp_mult(n: int) -> float:
	return 1.0 + 0.18 * float(n - 1)


static func dmg_mult(n: int) -> float:
	return 1.0 + 0.07 * float(n - 1)


static func is_guard_floor(n: int) -> bool:
	return n % GUARD_EVERY == 0


static func enemy_count(n: int) -> int:
	return 2 + mini(n / 2, 4)


static func pool_for(n: int) -> Array:
	return POOL.filter(func(p): return n >= int(p[1])).map(func(p): return String(p[0]))


static func week_no() -> int:
	return int((Time.get_unix_time_from_system() + 3.0 * 86400.0) / 604800.0)


func _physics_process(delta: float) -> void:
	_ensure_bar()
	_t += delta
	match state:
		"wait":
			if world.player.global_position.x > START_X:
				_start_floor(1)
		"fight":
			fight_time += delta
			alive = alive.filter(func(e): return is_instance_valid(e) and e.state != "dead")
			if alive.is_empty():
				_floor_cleared()
		"cleared":
			if _t >= PAUSE:
				_start_floor(floor_no + 1)
		"over":
			if _t >= RESTART:
				_reset_run()


func _start_floor(n: int) -> void:
	floor_no = n
	state = "fight"
	_t = 0.0
	alive.clear()
	var guard := is_guard_floor(n)
	if guard:
		_spawn_guard(n)
	else:
		var pool := pool_for(n)
		for i in enemy_count(n):
			_spawn_enemy(pool[randi() % pool.size()], SPAWN_X[i % SPAWN_X.size()] + 30.0 * float(i / SPAWN_X.size()), n)
	var label := "ETAGE %d" % n
	world.toast(("Etage %d · Turmwache!" if guard else "Etage %d") % n)
	if world.glut_fx != null:
		world.glut_fx.word(world.player.global_position + Vector2(0, -80), label, Color("c49bff"), 30 if guard else 26)
	Sfx.play("super_flash", -8.0 if guard else -12.0)


func _spawn_enemy(type: String, x: float, n: int) -> Enemy:
	var e := Enemy.new()
	e.world = world
	e.type_id = type
	e.hp_mult = hp_mult(n)
	e.dmg_mult = dmg_mult(n)
	e.position = Vector2(x, GlutHazard.ground_y(x, 255.0))
	e.facing = -1 if world.player.global_position.x < x else 1
	world.add_enemy(e)
	alive.append(e)
	world.dust.land(e.position, 1.3)
	world.effects.burst(e.position + Vector2(0, -6), Color("a46bff"), 14, 90.0, 260.0)
	world.effects.ring(e.position + Vector2(0, -4), 26.0, Color("c49bff"))
	return e


## Turmwache: the Essenwächter's body with less HP and Wucht; one shield
## phase from floor 15 on.
func _spawn_guard(n: int) -> void:
	boss = Boss.new()
	boss.world = world
	boss.director = self
	boss.type_id = BOSS_ID
	boss.hp_mult = 0.35 * hp_mult(n)
	boss.dmg_mult = 0.8 * dmg_mult(n)
	boss.wucht_mult = 0.6
	boss.shield_at = [0.5] if n >= 15 else []
	boss.position = Vector2(BOSS_X, GlutHazard.ground_y(BOSS_X, 255.0))
	boss.facing = -1
	world.add_enemy(boss)
	boss.label = "Turmwache"
	alive.append(boss)
	_awake = false
	_wake()


func _wake() -> void:
	if _awake or boss == null:
		return
	_awake = true
	boss.state = "spawn"
	boss._st = 0.0
	boss._play("roar", true)
	world.fx.shake(5.0)
	world.fx.punch(0.1)
	world.effects.burst(boss.get_hurt_rect().get_center(), Color("a46bff"), 26, 200.0, 120.0)
	if world.glut_fx != null:
		world.glut_fx.word(boss.head_position() + Vector2(0, -34), "TURMWACHE", Color("c49bff"), 30)


func is_fighting() -> bool:
	return state == "fight" and boss != null and is_instance_valid(boss) and boss.state != "dead"


func _floor_cleared() -> void:
	state = "cleared"
	_t = 0.0
	boss = null
	_awake = false
	for h in get_tree().get_nodes_in_group("boss_hazards"):
		h.queue_free()
	var reward := 5 * floor_no
	Profile.add_splitter(reward)
	run_splitter += reward
	var at := world.player.global_position + Vector2(40, -40)
	if is_guard_floor(floor_no):
		# gear whose item level climbs with the tower, at least rare
		var lv := Profile.level + floor_no / GUARD_EVERY
		var item := Loot.roll(lv, maxi(2, Loot.roll_rarity(true)), "", world.player.style.id)
		world._spawn_drop(item, at)
		run_items += 1
		SeasonPass.track("boss")
	if floor_no > best:
		best = floor_no
	if floor_no > week_best:
		week_best = floor_no
	_save()
	world.toast("Etage %d geschafft! +%d Splitter" % [floor_no, reward])
	if world.glut_fx != null:
		world.glut_fx.word(world.player.global_position + Vector2(0, -90), "ETAGE GESCHAFFT!", Color("fff4d0"), 28)


## Guard defeated: the floor ends through the normal enemy count.
func boss_defeated(_b: Boss) -> void:
	world.fx.flash(0.35, Color("e8d8ff"))
	world.fx.shake(8.0)


## A knock-out ends the run: the record stays, the tower starts over.
func player_down() -> bool:
	if state != "fight":
		return false
	attempts += 1
	state = "over"
	_t = 0.0
	world.fx.flash(0.5, Color("1a0a2a"))
	var secs := int(fight_time)
	world.toast("Lauf vorbei auf Etage %d (%d:%02d) · Rekord: Etage %d" % [floor_no, secs / 60, secs % 60, best])
	if world.glut_fx != null:
		world.glut_fx.word(world.player.global_position + Vector2(0, -70), "LAUF VORBEI", Color("ff4b3e"), 28)
	for h in get_tree().get_nodes_in_group("boss_hazards"):
		h.queue_free()
	for c in get_tree().get_nodes_in_group("crystals"):
		c.queue_free()
	for e in alive:
		if is_instance_valid(e):
			e.queue_free()
	alive.clear()
	boss = null
	world.player.global_position = Vector2(110, TrainingRoom.GROUND_Y - 1)
	world.player.velocity = Vector2.ZERO
	_save()
	return true


func _reset_run() -> void:
	state = "wait"
	floor_no = 0
	fight_time = 0.0
	run_splitter = 0
	run_items = 0
	world.toast("Der Turm wartet. Lauf nach rechts für Etage 1")


## Line for the HUD notice at the top.
func notice() -> String:
	match state:
		"wait":
			return "Turm der Prüfungen  ·  Rekord: Etage %d  →" % best
		"fight":
			var left := alive.filter(func(e): return is_instance_valid(e) and e.state != "dead").size()
			if is_guard_floor(floor_no):
				return "Etage %d  ·  Turmwache  ·  Rekord %d" % [floor_no, best]
			return "Etage %d  ·  %d Gegner  ·  Rekord %d" % [floor_no, left, best]
		"cleared":
			return "Etage %d geschafft!  ·  nächste kommt…" % floor_no
	return "Lauf vorbei  ·  Rekord: Etage %d" % best


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		best = int(d.get("best", 0))
		if int(d.get("week", -1)) == week_no():
			week_best = int(d.get("week_best", 0))


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"best": best, "week": week_no(), "week_best": week_best}))
