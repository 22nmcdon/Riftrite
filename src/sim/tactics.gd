class_name Tactics
extends RefCounted
## What a hero's tactic does in a fight (docs/plans/rebuild-phase3b-tactics.md,
## section 2; TacticDef is the data). A unit without one never reaches this
## code, so a fight without tactics is exactly what it was.
##   prefer_target        Targeting.update asks preferred() first: the
##                        nearest enemy (by path, as nearest) of the tactic's
##                        archetypes; with none standing or reachable, the
##                        unit picks by its own rule. Targets stay sticky.
##   hold_ground          from the start (logged), the unit doesn't walk. Each
##                        update, check_release() lets it go for good once an
##                        enemy stands within release_range (center to center,
##                        logged, naming the enemy). While it holds, stay()
##                        turns it to the nearest enemy in reach when its
##                        target is out of reach (unless Taunted), and keeps it
##                        from walking. A push, pull, or leap still moves it,
##                        and it still leaves crumbling ground.
##   signature_threshold  hurt_enough() gates its mana signature: the ally
##                        lowest on HP within the signature's reach must be
##                        below below_bp of max HP, or the full bar waits
##                        (logged once a bar). Any signature that heals on
##                        mana can wait (can_wait; phase 4, Decision 4), so
##                        Night Lantern and Sunfall wait like Mend.
## Every line is a TACTIC entry sourced to the unit and its tactic (rule 4).
## Payoffs (round 2, section 9), only while the behavior applies, each named
## in the log line it changes ("+20% from Casters first"):
##   prefer_target        damage_bonus_bp(): its own basic attack's and
##                        signature's hits on its archetypes deal more
##                        (EffectRunner.deal_hit, before DEF)
##   hold_ground          its attack cooldown runs faster while it holds
##                        (CombatSim)
##   signature_threshold  every fire of its signature has passed
##                        hurt_enough(), so EffectRunner.fire heals more on
##                        each (its heals only, an area's or zone's
##                        included; a shot keeps the number it left with)


## Logs what a unit's tactic did (`note`), about `about` if it names a unit.
static func log_tactic(sim: CombatSim, unit: UnitState, note: String, about: String = "") -> void:
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.TACTIC, EffectSource.make(unit.id, unit.tactic.id, unit.tactic.name))
	entry.target = about
	entry.note = note
	sim.combat_log.add(entry)


## At the fight's start (and as a summon joins, though none has a tactic):
## a unit that holds its ground says so.
static func start(sim: CombatSim, unit: UnitState) -> void:
	if unit.holding:
		var payoff: String = " (+%d%% attack speed while it holds)" % (unit.tactic.atsp_bp / 100) if unit.tactic.atsp_bp > 0 else ""
		log_tactic(sim, unit, "holds its ground" + payoff)


## How a payoff reads in the line it changes: "+20% from Casters first".
static func bonus_note(bonus_bp: int, tactic: TacticDef) -> String:
	return "+%d%% from %s" % [bonus_bp / 100, tactic.name]


## prefer_target's payoff on one hit: the extra damage (basis points) when
## the attacker's own basic attack or signature hits one of its archetypes;
## 0 otherwise.
static func damage_bonus_bp(sim: CombatSim, source: EffectSource, target: UnitState) -> int:
	var attacker: UnitState = sim.unit_by_id(source.unit_id)
	if attacker == null or attacker.tactic == null or attacker.tactic.damage_vs_bp <= 0 or not attacker.tactic.archetypes.has(target.def.archetype):
		return 0
	var own: bool = source.ability_id == attacker.attack.def.id or (attacker.signature != null and source.ability_id == attacker.signature.def.id)
	return attacker.tactic.damage_vs_bp if own else 0


## prefer_target: the nearest enemy of the tactic's archetypes, or null.
static func preferred(sim: CombatSim, unit: UnitState) -> UnitState:
	var wanted: Array[String] = unit.tactic.archetypes
	var candidates: Array[UnitState] = sim.targetable_enemies_of(unit).filter(func(enemy: UnitState) -> bool: return wanted.has(enemy.def.archetype))
	if candidates.is_empty():
		return null
	return Targeting.nearest_of(sim, unit, candidates, false)


## hold_ground: lets the unit go for good once an enemy is within reach of
## its tactic's release_range.
static func check_release(sim: CombatSim, unit: UnitState) -> void:
	var release: int = unit.tactic.release_range
	for enemy: UnitState in sim.standing_enemies_of(unit):
		if ArenaPlane.length_sq(enemy.pos - unit.pos) <= release * release:
			unit.holding = false
			log_tactic(sim, unit, "moves out: %s came within %d hexes" % [enemy.id, release / HexGrid.HEX], enemy.id)
			return


## hold_ground, when the unit's target is out of reach: it turns to the
## nearest enemy in reach, if any (not while Taunted). CombatSim then keeps
## it from walking (a holder never starts a walk, so it has none to stop).
static func stay(sim: CombatSim, unit: UnitState) -> void:
	if unit.statuses.is_empty() or Statuses.taunter(sim, unit) == null:
		var near: UnitState = Targeting.pick(sim, unit, "nearest", unit.reach_sq)
		if near != null and near != unit.target:
			Targeting.set_target(sim, unit, near, unit.tactic.name)


## signature_threshold: true if the ally lowest on HP within its signature's
## reach is hurt enough to heal now; otherwise the bar waits, logged once
## per bar.
static func hurt_enough(sim: CombatSim, unit: UnitState) -> bool:
	var reach: int = unit.reach_of(unit.signature.def)
	var ally: UnitState = Targeting.pick(sim, unit, "lowest_hp_ally", reach * reach)
	if ally != null and ally.hp * FixedMath.BP_ONE < ally.max_hp * unit.tactic.below_bp:
		unit.tactic_waiting = false
		return true
	if not unit.tactic_waiting:
		unit.tactic_waiting = true
		log_tactic(sim, unit, "%s waits: no ally within %d hexes below %d%%" % [unit.signature.def.name,
			unit.reach_of(unit.signature.def) / HexGrid.HEX, unit.tactic.below_bp / 100])
	return false


## True if a signature_threshold tactic can hold this signature: it fires on
## mana and heals (phase 4, Decision 4).
static func can_wait(signature: AbilityDef) -> bool:
	return signature != null and signature.trigger != null and signature.trigger.kind == TriggerDef.Kind.MANA and signature.heals()
