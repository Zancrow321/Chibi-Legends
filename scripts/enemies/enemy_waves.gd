class_name EnemyWaves
extends Node
## Wave director for the first enemies in the training forest. The fight
## zone starts behind the dummies: walking past x = START_X calls the first
## wave; a wave ends when all its enemies are down, the next one follows
## after a short pause. After the last wave the cycle starts again, a bit
## bigger each round.

const START_X := 760.0
const PAUSE := 2.2
## Each wave: [type, x]. Enemies rise out of the ground at x.
const WAVES := [
	[["moosling", 880.0], ["moosling", 950.0], ["moosling", 1080.0]],
	[["sumpfdorn", 960.0], ["sumpfdorn", 1150.0], ["rindenwicht", 880.0]],
	[["glutigel", 1100.0], ["saebeltiger", 940.0], ["moosling", 870.0], ["moosling", 1180.0]],
	[["moosgolem", 980.0], ["rindenwicht", 1150.0], ["moosling", 880.0]],
]

## Test hook: the first wave to call (0 = from the start).
static var first_wave := 0

var world: TrainingRoom
var wave := -1
var round_no := 0
var alive: Array = []
var _started := false
var _pause := -1.0
var _spawn_queue: Array = []
var _spawn_t := 0.0


func _physics_process(delta: float) -> void:
	if not _started:
		if world.player.global_position.x > START_X:
			_started = true
			_pause = 0.4
			wave = first_wave - 1
		return
	if _pause >= 0.0:
		_pause -= delta
		if _pause < 0.0:
			_next_wave()
		return
	if not _spawn_queue.is_empty():
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			_spawn_t = 0.35
			_spawn(_spawn_queue.pop_front())
		return
	alive = alive.filter(func(e): return is_instance_valid(e) and e.state != "dead")
	if alive.is_empty():
		_pause = PAUSE
		if wave >= 0:
			world.toast("Welle %d geschafft!" % (wave + 1 + round_no * WAVES.size()))
			if world.glut_fx != null:
				world.glut_fx.word(world.player.global_position + Vector2(0, -80), "GESCHAFFT!", Color("ffd25c"), 24)


## Enemies of the current wave that have not risen yet.
func pending() -> int:
	return _spawn_queue.size()


func _next_wave() -> void:
	wave += 1
	if wave >= WAVES.size():
		wave = 0
		round_no += 1
	_spawn_queue = (WAVES[wave] as Array).duplicate()
	if round_no > 0:
		_spawn_queue.append(["moosling", 940.0 + 40.0 * round_no])
	_spawn_t = 0.0
	var n := wave + 1 + round_no * WAVES.size()
	world.toast("Welle %d" % n)
	if world.glut_fx != null:
		world.glut_fx.word(world.player.global_position + Vector2(0, -80), "WELLE %d!" % n, Color("ff9a2a"), 26)
	Sfx.play("super_flash", -10.0)


func _spawn(entry: Array) -> void:
	var e := Enemy.new()
	e.world = world
	e.type_id = entry[0]
	var x: float = entry[1]
	e.position = Vector2(x, GlutHazard.ground_y(x, 255.0))  # on the ground, not on a platform
	e.facing = -1 if world.player.global_position.x < x else 1
	world.add_enemy(e)
	alive.append(e)
	# rises out of the ground with a puff of leaves and dirt
	world.dust.land(e.position, 1.3)
	world.effects.burst(e.position + Vector2(0, -6), Color("6aa84a"), 12, 90.0, 260.0)
	world.effects.ring(e.position + Vector2(0, -4), 26.0, Color("8fd94a"))
