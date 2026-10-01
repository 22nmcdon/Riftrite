class_name Guards
extends RefCounted
## Guard (docs/plans/rebuild-phase4-paths.md, section 5, P9; Hearthwall
## Brannoc): a unit with a guard passive (PartDef) takes a share of the hits
## on its allies.
##   - Only an enemy's hit (EffectRunner.deal_hit), not damage over time or
##     Rift Collapse, and never a hit on the guard itself.
##   - It covers an ally within its reach; "behind" only one on the far side
##     of it from its target (with no target, any in reach). The first
##     guard in the fight's order that covers the ally takes it.
##   - Its share of the hit (after a Mark on the ally, before DEF) goes to the
##     guard, which takes it as if hit: its own DEF, then its Shield and HP
##     (the ally's DEF cuts only the rest). It counts as damage the guard
##     takes, for mana. The ally's DAMAGE line
##     shows what it took; a GUARD line, sourced to the guard's passive, what
##     the guard took for it.


## The guard that takes a share of `source`'s hit on `target`, or null.
static func covering(sim: CombatSim, source: EffectSource, target: UnitState) -> UnitState:
	if source.relic_side >= 0 or source.unit_id.is_empty():
		return null
	var attacker: UnitState = sim.unit_by_id(source.unit_id)
	if attacker == null or attacker.side == target.side:
		return null
	for guard: UnitState in sim.guards:
		if not guard.alive or guard == target or guard.side != target.side:
			continue
		var part: PartDef = guard.guard
		var offset: Vector2i = target.pos - guard.pos
		if ArenaPlane.length_sq(offset) > part.guard_range * part.guard_range:
			continue
		if part.behind_only and guard.target != null and guard.target.alive:
			var ahead: Vector2i = guard.target.pos - guard.pos
			if offset.x * ahead.x + offset.y * ahead.y >= 0:
				continue
		return guard
	return null


## `guard` takes `amount` of `source`'s hit on `ally`: logged (GUARD), then
## dealt to it.
static func take(sim: CombatSim, guard: UnitState, ally: UnitState, amount: int, source: EffectSource) -> void:
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.GUARD, EffectSource.make(guard.id, guard.guard.id, guard.guard.name))
	entry.target = ally.id
	entry.amount = amount
	entry.absorbed = sim.apply_damage(guard, amount)
	guard.last_hit_chain = entry.chain
	guard.last_hit_source = source
	guard.last_hit_status = ""
	guard.last_attacker = source.unit_id
	sim.combat_log.add(entry)
