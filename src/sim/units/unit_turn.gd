class_name UnitTurn
extends RefCounted
## One standing unit's turn in a tick, for CombatSim.step
## (docs/plans/phases/rebuild-phase1-arena-sim.md, section 3): mana, its
## signature, Stun, its attack's cooldown, its target, then attacking or
## walking (and firing on the move). Every function takes the fight it acts on
## (the clean-up, docs/plans/phases/cleanup-and-layout.md).


## Statuses.kinds' bits for the kinds a turn asks about.
const SILENCED: int = 1 << StatusDef.Kind.SILENCE
const HELD: int = (1 << StatusDef.Kind.ROOT) | (1 << StatusDef.Kind.STUN)
const STUNNED: int = 1 << StatusDef.Kind.STUN
const SLOWED: int = 1 << StatusDef.Kind.SLOW
const TAUNTED: int = 1 << StatusDef.Kind.TAUNT
const CONFUSED: int = 1 << StatusDef.Kind.CONFUSED


## One unit's update this tick. It runs for every unit every tick, so it's
## written for speed: the common checks are inlined.
static func act(sim: CombatSim, unit: UnitState) -> void:
	if unit.tactic != null and (unit.tactic.regen_bp > 0 or unit.tactic.ally_def_add > 0):
		Tactics.tick(sim, unit)
	var has_statuses: bool = not unit.statuses.is_empty()
	# Which kinds of status it carries (Statuses.kinds), worked out again
	# wherever its statuses may have changed.
	var kinds: int = Statuses.kinds(unit) if has_statuses else 0
	# Mana regen (Mana), unless Silenced.
	# Shackle Engine (the tuning phase): a held enemy gains none.
	if unit.mana_regen > 0 and unit.mana < maxi(unit.mana_cap, unit.mana_store) and kinds & SILENCED == 0 \
			and not (kinds & HELD != 0 and sim.hero_rules.held_no_mana and unit.side != EffectSource.Team.HEROES):
		var regen_before: int = unit.mana
		var regen: int = unit.mana_regen
		if unit.aura_bp[AuraDef.Stat.MANA_GAIN_BP] != FixedMath.BP_ONE:
			regen = FixedMath.apply_bp(regen, Passives.factor(unit, AuraDef.Stat.MANA_GAIN_BP))
		unit.mana = mini(unit.mana + regen, maxi(unit.mana_cap, unit.mana_store))
		if not sim.overflow_counters.is_empty():
			Mana.count_overflow(sim, unit, regen_before)
	# Landing from a leap: it can't act.
	if sim.tick < unit.landing_until:
		return
	var casting: bool = false
	var signature: AbilityState = unit.signature
	if signature != null and (signature.pending > 0 or signature.cast_ends_at >= 0 \
			or (signature.mana_trigger and (unit.mana >= unit.mana_cap or unit.aura_bp[AuraDef.Stat.SIGNATURE_COST_BP] != FixedMath.BP_ONE and Mana.is_full(unit))) or (signature.once_trigger and not signature.fired) or signature.above_trigger \
			or signature.also_waiting or signature.echo_at >= 0 or signature.again_at >= 0 or (signature.every_ticks > 0 and sim.tick % signature.every_ticks == 0)):
		casting = Signatures.act(sim, unit)
		has_statuses = not unit.statuses.is_empty()
		kinds = Statuses.kinds(unit) if has_statuses else 0
		if sim.tick < unit.landing_until:
			return
	# A grip (phase 8 part 4, the Garrote) ends, or lands its effects.
	if unit.grip_target != null:
		Grips.tick(sim, unit)
		has_statuses = not unit.statuses.is_empty()
		kinds = Statuses.kinds(unit) if has_statuses else 0
	if kinds & STUNNED != 0:
		if unit.leg_active:
			Movement.halt(sim, unit, "stunned")
		return
	# An inert unit (phase 5: a totem) never attacks, targets, or walks.
	if unit.inert:
		return
	var attack: AbilityState = unit.attack
	if attack.progress_bp < attack.needed:
		var rate: int = unit.attack_rate_bp
		if unit.holding and unit.tactic.atsp_bp > 0:
			rate = FixedMath.apply_bp(rate, FixedMath.BP_ONE + unit.tactic.atsp_bp)
		elif unit.tactic != null and unit.tactic.keep_bp > 0 and unit.tactic.kind == TacticDef.Kind.HOLD_GROUND:
			# Hold your ground's twist: part of it stays after letting go.
			rate = FixedMath.apply_bp(rate, FixedMath.BP_ONE + FixedMath.apply_bp(unit.tactic.atsp_bp, unit.tactic.keep_bp))
		if kinds & SLOWED != 0:
			var slow: int = Statuses.slow_bp(unit)
			if slow != 0:
				rate = FixedMath.apply_bp(rate, FixedMath.BP_ONE - slow)
		attack.progress_bp = mini(attack.progress_bp + rate, attack.needed)
	if casting:
		if unit.leg_active:
			Movement.halt(sim, unit, "casting")
		return
	if unit.holding:
		Tactics.check_release(sim, unit)
	var target: UnitState = unit.target
	# Its statuses haven't changed since kinds was worked out: nothing since
	# changes them (setting a target doesn't either).
	if has_statuses:
		var taunter: UnitState = Statuses.taunter(sim, unit) if kinds & TAUNTED != 0 else null
		if taunter != null and taunter != target:
			Targeting.set_target(sim, unit, taunter, "taunted")
			target = taunter
		elif taunter == null and kinds & Statuses.FOCUS_BIT != 0:
			# Dance of Strings (phase 8 part 6): its setter's target.
			var focus: UnitState = Statuses.focus_target(sim, unit)
			if focus != null and focus != target:
				Targeting.set_target(sim, unit, focus, "focus")
				target = focus
		# Confused (phase 8 part 6, Night Veil): the nearest other unit of its
		# own side; once it ends, a target on its own side is dropped.
		if taunter == null and kinds & CONFUSED != 0:
			var turned_on: UnitState = Targeting.straight_nearest(unit, sim.standing_allies_of(unit))
			if turned_on != null and turned_on != target:
				Targeting.set_target(sim, unit, turned_on, "confused")
				target = turned_on
				unit.turned = true
	if unit.turned and kinds & CONFUSED == 0:
		# Only the target confusion chose (a healer's own may be an ally).
		unit.turned = false
		if target != null and target.side == unit.side:
			Targeting.lose(sim, unit, "no longer confused")
			target = null
	if target != null and target.alive and target.side != unit.side and (target.submerged or (not target.statuses.is_empty() and Statuses.has_kind(target, StatusDef.Kind.STEALTH))) \
			and unit.aura_bp[AuraDef.Stat.SEES_STEALTH] <= 0:
		var lost: LogEntry = Targeting.lose(sim, unit, "%s is %s" % [target.id, "submerged" if target.submerged else "stealthed"])
		target = null
		# A taunted unit drawn back to a hidden taunter every tick isn't
		# losing a target it chose (phase 8 part 6, Night Veil).
		if kinds & TAUNTED == 0:
			lost.lost_to_stealth = true
			if sim.lost_target_listeners:
				Events.lost_target(sim, unit)
	if target == null or not target.alive:
		Targeting.update(sim, unit)
		target = unit.target
	var engagers: Array[UnitState] = sim._enemy_engagers if unit.side == EffectSource.Team.HEROES else sim._hero_engagers
	if not unit.engagements.is_empty():
		Engage.update(sim, unit, engagers)
	if target == null:
		Movement.wait(sim, unit, "no target")
		return
	if unit.def.hop_cooldown_ticks > 0 and sim.tick >= unit.hop_ready_at and Displacement.hop_away(sim, unit, engagers):
		return
	var dx: int = target.pos.x - unit.pos.x
	var dy: int = target.pos.y - unit.pos.y
	if dx * dx + dy * dy <= unit.reach_sq:
		# A flier in the air lands on a free spot before it attacks.
		if unit.airborne and not Movement.settle(sim, unit, target):
			return
		# Keep your distance (phase 5c step 6c): between attacks, it backs off.
		if unit.tactic != null and unit.tactic.kind == TacticDef.Kind.KITE and attack.progress_bp < attack.needed and Tactics.kite(sim, unit, target):
			return
		if unit.leg_active:
			Movement.halt(sim, unit, "in reach")
		if attack.progress_bp >= attack.needed and (unit.def.plant_ticks == 0 or sim.tick - unit.moved_at >= unit.def.plant_ticks):
			EffectRunner.basic_attack(sim, unit)
		return
	# About to walk: a unit that would reach its target once planted (phase 4,
	# Steady) stops there and plants instead.
	if unit.plant_reach_sq > 0 and dx * dx + dy * dy <= unit.plant_reach_sq:
		Movement.wait(sim, unit, "planting")
		return
	# About to walk: a unit gripping an enemy (Grips) doesn't.
	if unit.grip_target != null:
		Movement.wait(sim, unit, "gripping")
		return
	# About to walk: a unit holding its ground (Tactics) doesn't.
	if unit.holding:
		Tactics.stay(sim, unit)
		Movement.wait(sim, unit, "")
		return
	# About to walk: a unit planting its feet (Tactics) stays near an enemy.
	if unit.tactic != null and unit.tactic.kind == TacticDef.Kind.STOP_NEAR and Tactics.planted(sim, unit):
		Movement.wait(sim, unit, "planted its feet")
		return
	# About to walk: a unit staying with its tank (Tactics) may go to it instead.
	if unit.tactic != null and unit.tactic.kind == TacticDef.Kind.LEASH and Tactics.leash(sim, unit, target):
		return
	# About to walk: an engager next to it may hold it.
	if unit.engagements.is_empty() and not engagers.is_empty():
		Engage.update(sim, unit, engagers)
	if not unit.engagements.is_empty() and Engage.holds(unit):
		if unit.leg_active:
			Movement.halt(sim, unit, "engaged")
		return
	Movement.walk(sim, unit)
	if unit.fires_moving and attack.progress_bp >= attack.needed:
		_fire_on_the_move(sim, unit)


## A walking unit with fires_moving (phase 4) looses its basic attack at the
## nearest enemy in reach, if any, without stopping (and keeps its target).
static func _fire_on_the_move(sim: CombatSim, unit: UnitState) -> void:
	var nearest: UnitState = Targeting.pick(sim, unit, "nearest", unit.reach_sq)
	if nearest == null:
		return
	EffectRunner.fire(sim, unit, unit.attack, nearest, unit.stats.get_stat(UnitStats.Stat.RANGE))
	unit.attack.spend()
	Mana.on_attack(sim, unit)
