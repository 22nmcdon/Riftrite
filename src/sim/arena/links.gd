class_name Links
extends RefCounted
## Linked Shields (phase 8 part 2, Loomwarden; docs/plans/rebuild-phase8-apexes.md,
## section 3): a unit with a link passive (PartDef kind "link") links every
## ally holding one of its Shields (UnitState.woven_by, set as the Shield is
## given). A hit on a linked unit while its Shield holds spreads `share_bp`
## of what got through evenly over every linked ally still holding one of
## those Shields (itself too): each other ally's part is a SHARED line from
## the link, landing on it as damage (Shield first). Every `per_shared` the
## link has moved gives each linked ally a stack of its status (Iron Loom's
## DEF), for the fight. A code change (no effect can move damage between
## units); a fight without a link never reaches it.


## What of `dealt` stays on `target` once its link has spread its share
## (all of it when it isn't linked, or no other ally is).
static func split(sim: CombatSim, target: UnitState, dealt: int, source: EffectSource) -> int:
	var linker: UnitState = target.woven_by
	if linker == null or linker.link == null or target.shield <= 0 or dealt <= 0:
		return dealt
	var linked: Array[UnitState] = []
	for ally: UnitState in (sim.heroes if target.side == EffectSource.Team.HEROES else sim.enemies):
		if ally.alive and ally.woven_by == linker and ally.shield > 0:
			linked.append(ally)
	if linked.size() < 2:
		return dealt
	# Each part rounds up, so a small share of a small hit still moves.
	var parts: int = linked.size()
	var each: int = mini((FixedMath.apply_bp(dealt, linker.link.share_bp) + parts - 1) / parts, dealt / parts)
	if each <= 0:
		return dealt
	var link_source: EffectSource = EffectSource.make(linker.id, linker.link.id, linker.link.name)
	var moved: int = 0
	for ally: UnitState in linked:
		if ally == target:
			continue
		var entry: LogEntry = sim.new_entry(LogEntry.Kind.SHARED, link_source)
		entry.target = ally.id
		entry.note = target.id
		entry.amount = each
		entry.absorbed = sim.apply_damage(ally, each)
		if source.relic_side < 0 and source.unit_id != ally.id:
			ally.last_attacker = source.unit_id
			ally.last_hit_source = source
		sim.combat_log.add(entry)
		moved += each
	_grow(sim, linker, linked, moved, link_source)
	return dealt - moved


## Iron Loom: a stack of the link's status on each linked ally for every
## `per_shared` moved so far.
static func _grow(sim: CombatSim, linker: UnitState, linked: Array[UnitState], moved: int, source: EffectSource) -> void:
	var link: PartDef = linker.link
	linker.link_shared += moved
	if link.per_shared <= 0 or link.link_status.is_empty():
		return
	while linker.link_shared >= link.per_shared * (linker.link_steps + 1):
		linker.link_steps += 1
		for ally: UnitState in linked:
			if ally.alive:
				Statuses.apply(sim, ally, link.link_status, 1, 0, source)
