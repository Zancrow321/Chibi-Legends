class_name RaidDirector
extends Node
## Runs a raid area (first one: the Glutschmiede with the Essenwächter).
## Wakes the boss when the player steps in, places shield crystals and
## danger zones for the boss, handles a knock-out (new attempt) and the
## victory (loot). The boss itself lives in Boss, its bar in RaidBossBar.

const BOSS_ID := "essenwaechter"
const BOSS_X := 760.0
const WAKE_X := 300.0
## Crystal spots: the floating platforms, nearest to the middle first.
const SPOT_ORDER := [1, 2, 0, 3]

var world: TrainingRoom
var boss: Boss
var attempts := 1
var won := false
var fight_time := 0.0
var _awake := false
var _respawn := -1.0
var _bar: RaidBossBar


func _ready() -> void:
	_spawn_boss()


func _spawn_boss() -> void:
	boss = Boss.new()
	boss.world = world
	boss.director = self
	boss.type_id = BOSS_ID
	boss.position = Vector2(BOSS_X, GlutHazard.ground_y(BOSS_X, 255.0))
	boss.facing = -1
	world.add_enemy(boss)
	boss.state = "sleep"
	_awake = false
	fight_time = 0.0


func _physics_process(delta: float) -> void:
	if _bar == null and world.hud != null:
		_bar = RaidBossBar.new()
		_bar.director = self
		world.hud.get_parent().add_child(_bar)
	if _respawn >= 0.0:
		_respawn -= delta
		if _respawn < 0.0:
			_spawn_boss()
		return
	if won or boss == null or not is_instance_valid(boss):
		return
	if not _awake:
		if world.player.global_position.x > WAKE_X:
			_wake()
		return
	if boss.state != "dead":
		fight_time += delta


func _wake() -> void:
	if _awake:
		return
	_awake = true
	boss.state = "spawn"
	boss._st = 0.0
	boss._play("roar", true)
	world.fx.shake(6.0)
	world.fx.punch(0.12)
	Sfx.play("super_flash", -4.0)
	world.effects.burst(boss.get_hurt_rect().get_center(), Color("ff8a2a"), 30, 200.0, 120.0)
	if world.glut_fx != null:
		world.glut_fx.word(boss.head_position() + Vector2(0, -34), "ESSENWÄCHTER", Color("ffd25c"), 34)
	world.toast("Der Essenwächter erwacht! Leere seine Wucht-Leiste")


func is_fighting() -> bool:
	return _awake and not won and boss != null and is_instance_valid(boss) and boss.state != "dead"


## Spots for n shield crystals (floor positions on the platforms).
func crystal_spots(n: int) -> Array:
	var out: Array = []
	for i in mini(n, SPOT_ORDER.size()):
		var p: Array = TrainingRoom.PLATFORMS[SPOT_ORDER[i]]
		out.append(Vector2(p[0] + p[2] * 0.5, p[1]))
	return out


func spawn_hazard(kind: String, pos: Vector2, dir: float, damage: float) -> BossHazard:
	var h := BossHazard.new()
	h.world = world
	h.kind = kind
	h.dir = dir
	h.damage = damage
	h.source = boss
	h.position = Vector2.ZERO if kind == "flood" else pos
	h.add_to_group("boss_hazards")
	world.add_child(h)
	return h


## The player fell (Player.receive_hit at 0 HP). Returns true when the raid
## takes care of it: new attempt with a fresh boss.
func player_down() -> bool:
	if not is_fighting():
		return false
	attempts += 1
	world.fx.flash(0.5, Color("2a0a0a"))
	world.toast("Niedergeschlagen! Versuch %d beginnt" % attempts)
	if world.glut_fx != null:
		world.glut_fx.word(world.player.global_position + Vector2(0, -70), "NIEDERGESCHLAGEN", Color("ff4b3e"), 26)
	for h in get_tree().get_nodes_in_group("boss_hazards"):
		h.queue_free()
	for c in get_tree().get_nodes_in_group("crystals"):
		c.queue_free()
	boss.queue_free()
	boss = null
	world.player.global_position = Vector2(110, TrainingRoom.GROUND_Y - 1)
	world.player.velocity = Vector2.ZERO
	_respawn = 1.5
	return true


func boss_defeated(b: Boss) -> void:
	won = true
	var at := b.global_position
	world.fx.flash(0.5, Color("fff4d0"))
	world.fx.shake(10.0)
	if world.glut_fx != null:
		world.glut_fx.word(at + Vector2(0, -140), "RAID GESCHAFFT!", Color("ffd25c"), 40)
	var secs := int(fight_time)
	world.toast("Essenwächter besiegt in %d:%02d (Versuch %d)" % [secs / 60, secs % 60, attempts])
	SeasonPass.track("boss")
	# personal loot: two good pieces on top of the normal elite drop
	for i in 2:
		var item := Loot.roll(Profile.level, maxi(2, Loot.roll_rarity(true)), "", world.player.style.id)
		world._spawn_drop(item, at + Vector2(-26 + 52 * i, -40))
	var gem := ""
	while gem == "":
		gem = Gems.roll_drop(true)
	world._spawn_drop({"gem": gem, "rarity": Gems.tier_of(gem)}, at + Vector2(0, -60))
