class_name WorldBoss
extends Boss
## Weltboss (Weltenriss): a Boss with ONE health bar for all players. Every
## hit only goes to the WorldBossDirector, which reports it to the server
## and knows the shared health (Supabase, or offline a local pool). The
## boss here only shows that health; it falls when the shared bar is empty.
## No shield phases: the phases come from the shared health (66 % / 33 %).

var _phase_shown := 1


func _ready() -> void:
	shield_at = []
	super._ready()
	var wb := director as WorldBossDirector
	max_hp = float(wb.max_hp)
	hp = wb.shown_hp()
	phase = wb.phase()
	_phase_shown = phase


func apply_damage(amount: float) -> void:
	if state == "dead":
		return
	var wb := director as WorldBossDirector
	wb.add_damage(amount)
	sync()
	_hp_shown = 3.0


## Takes the shared health from the director (also called after each poll).
func sync() -> void:
	if state == "dead":
		return
	var wb := director as WorldBossDirector
	max_hp = float(wb.max_hp)
	hp = wb.shown_hp()
	phase = wb.phase()
	if phase > _phase_shown:
		_phase_shown = phase
		phase_changed.emit(phase)
		world.fx.shake(6.0)
		world.fx.flash(0.25, Color(0.6, 0.85, 1.0))
		Sfx.play("super_flash", -4.0)
		if world.glut_fx != null:
			world.glut_fx.word(head_position() + Vector2(0, -30), "DONNERHORN TOBT!", Color("7fd8ff"), 28)
		world.toast("Phase %d: Donnerhorn wird schneller und stürmt los" % phase)


## The shared bar is empty and the server agrees: the boss falls.
func fall() -> void:
	if state == "dead":
		return
	hp = 0.0
	_die()
