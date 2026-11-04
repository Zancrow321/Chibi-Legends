class_name BollwerkWall
extends Node2D
## Schutzwand des Schildprotokolls: steht vor der Figur, hält `hp` Schaden
## oder `life` Sekunden. BollwerkCaster.guard_hit leitet Treffer von der
## anderen Seite hierher (Nahkampf zählt doppelt). Mit 3 Zellen Einsatz-
## energie lädt sie beim Zerfall den Schild der Figur auf.

const HEIGHT := 46.0

var caster: BollwerkCaster
var hp := 300.0
var hp_max := 300.0
var life := 6.0
var recharge := false
var dir := 1

var _t := 0.0
var _hit_k := 0.0
var _gone := false


func _ready() -> void:
	hp_max = hp


func alive() -> bool:
	return not _gone and hp > 0.0 and _t < life


func absorb(dmg: float) -> void:
	hp -= dmg
	_hit_k = 1.0
	var c := global_position + Vector2(0, -HEIGHT * 0.5)
	caster.bfx.zap(c + Vector2(dir * 2.0, randf_range(-14, 14)), 16.0, 2, caster.style.color("shield"))
	if caster.world.numbers != null:
		caster.world.numbers.spawn_number(c + Vector2(0, -24), int(dmg), caster.style.color("shield"), get_instance_id(), false)
	Sfx.play("bw_shield_hit", -3.0)
	if hp <= 0.0:
		collapse()


func collapse() -> void:
	if _gone:
		return
	_gone = true
	var c := global_position + Vector2(0, -HEIGHT * 0.5)
	caster.bfx.shards(c, -PI / 2.0, PI, 16, 160.0, caster.style.color("shield"))
	caster.bfx.ring(c, 24.0, caster.style.color("shield"), 0.3, 3.0)
	if recharge and is_instance_valid(caster.player):
		caster.shield = caster.shield_max
		caster.bfx.word(caster.player.global_position + Vector2(0, -54), "SCHILD VOLL", caster.style.color("shield"), 15)
		caster.bfx.ring(caster._center(), 30.0, caster.style.color("shield"), 0.4, 3.0)
	Sfx.play("bw_shield_break", -4.0)
	queue_free()


func _physics_process(delta: float) -> void:
	if caster == null:
		queue_free()
		return
	_t += delta
	_hit_k = maxf(0.0, _hit_k - delta * 4.0)
	if _t >= life:
		collapse()
		return
	var grow := minf(1.0, _t / 0.15)
	var fade := minf(1.0, (life - _t) / 0.6)
	var flick := 1.0 if (life - _t) > 1.2 or fmod(_t * 10.0, 1.0) < 0.6 else 0.4
	var k := (0.55 + 0.45 * hp / maxf(1.0, hp_max) + _hit_k * 0.6) * fade * flick
	caster.bfx.wall(global_position.x, global_position.y, HEIGHT * grow, k, dir)
