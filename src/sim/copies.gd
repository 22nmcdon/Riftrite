class_name Copies
extends RefCounted
## Copying a signature (phase 8 part 3, docs/plans/rebuild-phase8-act3.md,
## section 4; the Mirrorwight, a copy passive: PartDef's header). A fight
## without a copier never reaches this.
##
##   - Events reads each hero's signature fire (a FIRE of its kit's
##     signature, not an echo) and calls saw.
##   - Each standing copier that has none yet (or replaces, Greedy) takes it
##     if it's copyable: its effects, nested in areas too, are only damage,
##     heals, Shields, statuses, and cleanses.
##   - The copy becomes the copier's signature: the hero's ability, named
##     "<name> (copied from <hero>)", on the copier's own trigger (its mana
##     bar), cast with the copier's stats; targeting and areas count sides
##     from the copier, so the sides turn. Twinned: it's cast twice, each at
##     twice_bp, the second half a second later (an echo). Its mana is left
##     as it was.
##   - Logged as COPIED (source: the copier's passive; target: the hero).
##   - A Queen (share) gives each copy she takes to every other standing
##     copier of her side too (COPIED noted "shared"), whatever they had.

## The effect types a copyable signature may have.
const COPYABLE: Array[EffectDef.Type] = [EffectDef.Type.DAMAGE, EffectDef.Type.HEAL, EffectDef.Type.SHIELD, EffectDef.Type.APPLY_STATUS,
	EffectDef.Type.CLEANSE, EffectDef.Type.AREA]
## How long after the first a Twinned copy's second cast comes.
const TWIN_TICKS: int = 10


## True if `ability` can be copied (see the top).
static func copyable(ability: AbilityDef) -> bool:
	return _all_copyable(ability.effects)


static func _all_copyable(effects: Array[EffectDef]) -> bool:
	for effect: EffectDef in effects:
		if not COPYABLE.has(effect.type):
			return false
		if effect.type == EffectDef.Type.AREA and not _all_copyable(effect.area_effects):
			return false
	return true


## `hero` fired its signature: each copier that takes it does.
static func saw(sim: CombatSim, hero: UnitState) -> void:
	var ability: AbilityDef = hero.signature.def
	if not copyable(ability):
		return
	for unit: UnitState in sim.copiers:
		if not unit.alive or unit.side == hero.side or unit.signature == null:
			continue
		if not unit.copied.is_empty() and not unit.copy_part.copy_replace:
			continue
		if unit.copied == ability.id:
			continue
		take(sim, unit, ability, hero, false)
		if unit.copy_part.copy_share:
			for ally: UnitState in sim.copiers:
				if ally != unit and ally.alive and ally.side == unit.side and ally.signature != null:
					take(sim, ally, ability, hero, true)


## `unit` takes `ability` (of `hero`) as its signature, and it's logged.
static func take(sim: CombatSim, unit: UnitState, ability: AbilityDef, hero: UnitState, shared: bool) -> void:
	var part: PartDef = unit.copy_part
	var name: String = "%s (copied from %s)" % [ability.name, hero.id]
	var copy: AbilityDef
	if part.copy_twice_bp > 0:
		copy = KitMod.make_echo(ability, part.copy_twice_bp)
		copy.echo = KitMod.make_echo(ability, part.copy_twice_bp)
		copy.echo.id = "%s_copy_twin" % ability.id
		copy.echo.name = name + " (twin)"
		copy.echo_ticks = TWIN_TICKS
	else:
		copy = DefCopy.shallow(ability) as AbilityDef
		copy.echo = null
		copy.echo_ticks = 0
	copy.id = "%s_copy" % ability.id
	copy.name = name
	copy.trigger = unit.def.signature.trigger
	copy.also = []
	var state: AbilityState = AbilityState.make(copy, unit.id)
	unit.signature = state
	unit.copied = ability.id
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.COPIED, EffectSource.make(unit.id, part.id, part.name))
	entry.target = hero.id
	entry.note = ability.name
	entry.shape = "shared" if shared else ""
	sim.combat_log.add(entry)
