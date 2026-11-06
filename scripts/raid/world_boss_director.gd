class_name WorldBossDirector
extends RaidDirector
## Weltenriss: the world boss Donnerhorn with ONE health bar for all players
## (supabase/migrations/0003_world_boss.sql). Everybody fights in their own
## arena; this director collects the own damage, reports it every few
## seconds (cl_world_hit, the server caps damage per second) and polls the
## shared state in between (health, who fights right now, best list).
## When the bar is empty the boss falls for everybody; whoever helped
## enough collects their loot (cl_world_claim). Then the rift closes for a
## while and opens again with more health, the more players took part.
##
## Offline the same fight runs against a local pool (user://weltboss.json).

const BOSS_TYPE := "donnerhorn"
const REPORT_EVERY := 8.0
const POLL_EVERY := 6.0
## Offline / first round: health per fighter (same as cl_world_rules).
const HP_PER_FIGHTER := 60000
const RESPAWN_MIN := 20
const MIN_SHARE := 0.005
const SAVE_PATH := "user://weltboss.json"

var online := false
var boss_id := 0
var max_hp := HP_PER_FIGHTER
## Last known shared health (server) or the local pool (offline).
var server_hp := HP_PER_FIGHTER
## Own damage not yet reported / on its way to the server.
var pending := 0.0
var in_flight := 0.0
var my_damage := 0
var my_rank := 0
var fighters_now := 0
var fighters := 0
var top: Array = []
var status := "laden"  # laden, aktiv, besiegt, geflohen
var next_in := 0.0  # seconds until the rift opens again
var claimable := false
var claimed := false
var last_hit := ""
var last_claim := {}
var _tick := 0.0
var _since_report := 0.0
var _busy := false
var _local := {}
var _panel: WorldBossPanel


func _ready() -> void:
	online = Net.is_online()
	if online:
		_poll()
	else:
		_load_local()
		_apply_local()


# --- shared state ------------------------------------------------------------------------

## Health the bar shows: the shared health minus own hits not reported yet.
func shown_hp() -> float:
	var v := float(server_hp) - pending - in_flight
	if online and status == "aktiv":
		return maxf(1.0, v)  # it only falls when the server says so
	return maxf(0.0, v)


func phase() -> int:
	var f := shown_hp() / maxf(1.0, float(max_hp))
	return 1 if f > 0.66 else (2 if f > 0.33 else 3)


func own_damage() -> int:
	return my_damage + int(pending + in_flight)


func add_damage(amount: float) -> void:
	if status != "aktiv" or amount <= 0.0:
		return
	if online:
		pending += amount
		if shown_hp() <= 1.0 and not _busy:
			_report()  # the bar looks empty: ask the server right away
		return
	var dealt := minf(amount, float(server_hp))
	server_hp -= int(ceil(dealt))
	my_damage += int(ceil(dealt))
	_local.hp = server_hp
	_local.my_damage = my_damage
	if server_hp <= 0:
		server_hp = 0
		status = "besiegt"
		_local.defeated_at = Time.get_unix_time_from_system()
		_save_local()
		if boss != null and is_instance_valid(boss):
			(boss as WorldBoss).fall()


func _physics_process(delta: float) -> void:
	_ensure_bar()
	if _panel == null and world.hud != null:
		_panel = WorldBossPanel.new()
		_panel.director = self
		world.hud.get_parent().add_child(_panel)
	_since_report += delta
	next_in = maxf(0.0, next_in - delta)
	_tick -= delta
	if _tick <= 0.0 and not _busy:
		if online:
			if pending > 0.0 and status == "aktiv":
				_report()
			else:
				_poll()
		elif status != "aktiv" and next_in <= 0.0:
			_new_local()
		_tick = REPORT_EVERY if pending > 0.0 else POLL_EVERY
	if status == "aktiv" and (boss == null or not is_instance_valid(boss)):
		_spawn_boss()
	if boss == null or not is_instance_valid(boss):
		return
	if not _awake:
		if world.player.global_position.x > WAKE_X:
			_wake()
		return
	if boss.state != "dead":
		fight_time += delta


func _report() -> void:
	if _busy or boss_id == 0:
		return
	_busy = true
	in_flight = pending
	pending = 0.0
	var secs := maxi(1, int(ceil(_since_report)))
	_since_report = 0.0
	var r: Dictionary = await Net.call_fn("cl_world_hit", {"boss_id": boss_id, "damage": int(in_flight), "seconds": secs})
	if r.ok:
		in_flight = 0.0
		_take(r.data)
	else:
		pending += in_flight  # try again with the next report
		in_flight = 0.0
	_busy = false


func _poll() -> void:
	if _busy:
		return
	_busy = true
	var r: Dictionary = await Net.call_fn("cl_world_state")
	if r.ok:
		_take(r.data)
	elif status == "laden":
		# no server (database not set up yet?): fight offline
		online = false
		_load_local()
		_apply_local()
	_busy = false


func _take(d: Dictionary) -> void:
	var id := int(d.id)
	if id != boss_id and boss_id != 0:
		_drop_boss()  # a new rift opened while we were here
	if id != boss_id:
		won = false
	boss_id = id
	max_hp = int(d.max_hp)
	server_hp = int(d.hp)
	status = str(d.state)
	next_in = float(d.get("next_in", 0))
	my_damage = int(d.my_damage)
	my_rank = int(d.my_rank)
	fighters_now = int(d.fighters_now)
	fighters = int(d.fighters)
	top = d.top if d.top is Array else []
	claimable = bool(d.claimable)
	claimed = bool(d.claimed)
	last_hit = str(d.last_hit) if d.last_hit != null else ""
	if boss != null and is_instance_valid(boss):
		var wb := boss as WorldBoss
		if status == "aktiv":
			wb.sync()
		elif status == "besiegt" and boss.state != "dead":
			wb.fall()
		elif status == "geflohen" and boss.state != "dead":
			world.toast("Donnerhorn ist durch den Riss entkommen")
			boss.queue_free()
			boss = null


# --- boss -----------------------------------------------------------------------------------

func _drop_boss() -> void:
	if boss != null and is_instance_valid(boss):
		boss.queue_free()
	boss = null
	_awake = false

func _spawn_boss() -> void:
	if status != "aktiv":
		return
	var b := WorldBoss.new()
	b.world = world
	b.director = self
	b.type_id = BOSS_TYPE
	b.position = Vector2(BOSS_X, GlutHazard.ground_y(BOSS_X, 255.0))
	b.facing = -1
	boss = b
	world.add_enemy(b)
	b.label = "Donnerhorn · Weltboss"
	b.state = "sleep"
	_awake = false
	won = false
	fight_time = 0.0


func _wake() -> void:
	if _awake or boss == null:
		return
	_awake = true
	boss.state = "spawn"
	boss._st = 0.0
	boss._play("roar", true)
	world.fx.shake(7.0)
	world.fx.punch(0.14)
	world.fx.flash(0.3, Color(0.7, 0.9, 1.0))
	Sfx.play("super_flash", -3.0)
	world.effects.burst(boss.get_hurt_rect().get_center(), Color("7fd8ff"), 34, 220.0, 120.0)
	if world.glut_fx != null:
		world.glut_fx.word(boss.head_position() + Vector2(0, -34), "DONNERHORN", Color("7fd8ff"), 36)
	if world.stage != null:
		world.stage.flash_light(boss.get_hurt_rect().get_center(), Color(0.55, 0.85, 1.0), 2.6, 1.6, 0.5)
	if online and fighters_now > 0:
		world.toast("Weltboss! Gerade kämpfen %d andere gegen ihn" % fighters_now)
	else:
		world.toast("Weltboss! Eine Lebensleiste für alle Spieler")


func spawn_hazard(kind: String, pos: Vector2, dir: float, damage: float) -> BossHazard:
	var h := super.spawn_hazard(kind, pos, dir, damage)
	h.storm = true
	return h


## Knocked out: back to the start; the boss keeps its (shared) health.
func player_down() -> bool:
	if not is_fighting():
		return false
	attempts += 1
	world.fx.flash(0.5, Color("0a1a2a"))
	world.toast("Niedergeschlagen! Dein Schaden zählt weiter")
	if world.glut_fx != null:
		world.glut_fx.word(world.player.global_position + Vector2(0, -70), "NIEDERGESCHLAGEN", Color("ff4b3e"), 26)
	for h in get_tree().get_nodes_in_group("boss_hazards"):
		h.queue_free()
	world.player.global_position = Vector2(110, TrainingRoom.GROUND_Y - 1)
	world.player.velocity = Vector2.ZERO
	return true


func boss_defeated(b: Boss) -> void:
	won = true
	var at := b.global_position
	world.fx.flash(0.6, Color(0.85, 0.95, 1.0))
	world.fx.shake(12.0)
	if world.glut_fx != null:
		world.glut_fx.word(at + Vector2(0, -150), "WELTBOSS BESIEGT!", Color("7fd8ff"), 40)
	SeasonPass.track("boss")
	if online:
		_claim(at)
	else:
		_offline_loot(at)


func _claim(at: Vector2) -> void:
	# the last report may still be on its way
	while _busy:
		await get_tree().process_frame
	if pending > 0.0:
		await _report()
	var r: Dictionary = await Net.call_fn("cl_world_claim", {"boss_id": boss_id, "level": Profile.level})
	if not r.ok:
		world.toast("Weltboss besiegt! Keine Beute: %s" % r.error.trim_prefix("400 "))
		return
	var d: Dictionary = r.data
	last_claim = d
	claimed = true
	claimable = false
	Profile.marks = int(d.total_marks)
	Profile.save()
	world.toast("Platz %d · %d %% Anteil · +%d Raid-Marken%s" % [int(d.rank), int(round(float(d.share) * 100.0)), int(d.marks), " · letzter Schlag!" if d.last_hit else ""])
	var i := 0
	for drop in d.drops:
		world._spawn_drop(Net.build_item(drop, world.player.style.id), at + Vector2(-26 + 52 * i, -40))
		i += 1
	_spawn_gem(at)
	GodItems.try_roll("world", str(boss_id))


func _offline_loot(at: Vector2) -> void:
	var share := float(my_damage) / maxf(1.0, float(max_hp))
	var marks := 4 + int(round(minf(share, 0.5) * 8.0)) + 2
	Profile.marks += marks
	Profile.save()
	last_claim = {"marks": marks, "rank": 1, "share": share, "last_hit": true}
	world.toast("Weltboss besiegt! +%d Raid-Marken" % marks)
	world._spawn_drop(Loot.roll(Profile.level, maxi(Loot.EPIC, Loot.roll_rarity(true)), "", world.player.style.id), at + Vector2(-26, -40))
	world._spawn_drop(Loot.roll(Profile.level, maxi(Loot.RARE, Loot.roll_rarity(true)), "", world.player.style.id), at + Vector2(26, -40))
	_spawn_gem(at)


# --- offline pool -----------------------------------------------------------------------

func _load_local() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f != null:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			_local = d
	if _local.is_empty():
		_new_local()


func _new_local() -> void:
	_drop_boss()
	_local = {"id": int(_local.get("id", 0)) + 1, "hp": HP_PER_FIGHTER, "max_hp": HP_PER_FIGHTER, "my_damage": 0, "defeated_at": 0.0}
	_save_local()
	_apply_local()


func _apply_local() -> void:
	boss_id = int(_local.id)
	max_hp = int(_local.max_hp)
	server_hp = int(_local.hp)
	my_damage = int(_local.my_damage)
	var dead_at := float(_local.get("defeated_at", 0.0))
	if dead_at > 0.0:
		status = "besiegt"
		next_in = maxf(0.0, dead_at + RESPAWN_MIN * 60.0 - Time.get_unix_time_from_system())
	else:
		status = "aktiv"
		next_in = 0.0
	top = [{"name": "Du", "damage": my_damage, "me": true}] if my_damage > 0 else []
	my_rank = 1 if my_damage > 0 else 0


func _save_local() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_local))


## Saves the offline pool when leaving the rift.
func _exit_tree() -> void:
	if not online and not _local.is_empty():
		_save_local()


## Line for the HUD notice at the top when no fight is on.
func notice() -> String:
	match status:
		"laden":
			return "Weltenriss  ·  verbinde…"
		"besiegt":
			return "Donnerhorn besiegt!  ·  Der Riss öffnet sich wieder in %d:%02d" % [int(next_in) / 60, int(next_in) % 60]
		"geflohen":
			return "Donnerhorn ist entkommen  ·  neuer Riss in %d:%02d" % [int(next_in) / 60, int(next_in) % 60]
	return "Weltenriss  ·  Donnerhorn wartet  →"
