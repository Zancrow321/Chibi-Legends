class_name HitFeel
## Shared hit-feel rules (own numbers, principles from platform fighters):
##  - Hitstun grows with the strength of the hit: knockback and launch add
##    frames, heavy targets shrug a little off. A strong hit always gives
##    time for a follow-up, a light poke only links into the chain.
##  - Ground combos end by hitstun decay (from the 9th hit, at most -45 %).
##  - Juggles end by gravity decay instead: every air hit makes the target a
##    bit heavier until it lands, so the end of an air combo is visible
##    (it sinks faster) instead of a hidden timer. Near the top of its arc a
##    juggled target hangs a moment, so air hits are easy to read and land.

const FPS := 60.0
## Hitstun in frames = STUN_BASE + knockback * STUN_PER_KB + |launch| * STUN_PER_LAUNCH,
## divided by sqrt(weight). Knockback 50 -> 15 f, 200 -> 26 f, 340 -> 36 f.
const STUN_BASE := 12.0
const STUN_PER_KB := 0.07
const STUN_PER_LAUNCH := 0.04
## Hitstun decay on long ground combos.
const DECAY_FROM := 8
const DECAY_PER_HIT := 0.03
const DECAY_MIN := 0.55
## Juggle: gravity factor per air hit since the last landing (capped), the
## hang near the apex and the lift a hit in the air gives.
const JUGGLE_GRAVITY_STEP := 0.07
const JUGGLE_GRAVITY_MAX := 1.6
const APEX_SPEED := 70.0
const APEX_GRAVITY := 0.6
const AIR_LIFT_BASE := 110.0
const AIR_LIFT_PER_KB := 0.2
const AIR_LIFT_MAX := 190.0


## Hitstun in seconds from the force of a hit.
static func stun_from_force(knockback: float, launch: float, weight := 1.0) -> float:
	var f := STUN_BASE + absf(knockback) * STUN_PER_KB + absf(launch) * STUN_PER_LAUNCH
	return f / sqrt(maxf(0.3, weight)) / FPS


## Final hitstun: the longer of the link time the attacker asked for and the
## force stun; grounded targets lose some of it late in a long combo.
static func final_stun(link: float, knockback: float, launch: float, weight: float, combo: int, airborne: bool) -> float:
	var s := maxf(link, stun_from_force(knockback, launch, weight))
	if not airborne:
		s *= maxf(DECAY_MIN, 1.0 - DECAY_PER_HIT * maxi(0, combo - DECAY_FROM))
	return s


## Gravity multiplier of a juggled target after `juggle` air hits.
static func juggle_gravity(juggle: int, vel_y: float) -> float:
	var g := minf(JUGGLE_GRAVITY_MAX, 1.0 + JUGGLE_GRAVITY_STEP * float(juggle))
	if juggle > 0 and absf(vel_y) < APEX_SPEED:
		g *= APEX_GRAVITY
	return g


## Upward speed a hit gives a target that is already in the air.
static func air_lift(knockback: float, juggle: int) -> float:
	var lift := minf(AIR_LIFT_MAX, AIR_LIFT_BASE + absf(knockback) * AIR_LIFT_PER_KB)
	return lift * maxf(0.15, 1.0 - 0.12 * float(juggle - 1))
