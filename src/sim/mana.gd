class_name Mana
extends RefCounted
## Mana (docs/plans/rebuild-phase1-arena-sim.md, section 5), for units with a
## mana bar (UnitDef.mana). It's kept in hundredths, so "1 per 10 damage
## taken" stays an integer; the data gives whole mana.
##   - It comes from each basic attack that fires (per_attack, or
##     per_far_attack at a far enough target: phase 4), damage taken,
##     Shield included (per_10_damage_taken), regen (regen_per_s), and start.
##   - Silence blocks every source; Stun doesn't.
##   - The bar stops at max; a full bar fires the mana signature and empties.
##   - mana_drain takes it away (logged). A unit without a bar ignores both
##     Silence and drains.
## Regen runs in CombatSim's unit update: it's every tick, so it's inlined
## there (UnitState.mana_regen), and it sets off no on_mana_gained. A unit's
## own gains aren't logged (mana given to another unit is: MANA_GIVEN): each comes from something that is (an attack firing,
## a hit landing, time passing), so the bar can be rebuilt from the log.

const SCALE: int = 100


static func on_attack(sim: CombatSim, unit: UnitState) -> void:
	var mana: ManaDef = unit.def.mana
	if mana == null:
		return
	var per: int = mana.per_attack
	if mana.far_hexes > 0 and unit.target != null:
		var far: int = mana.far_hexes * HexGrid.HEX
		if ArenaPlane.length_sq(unit.target.pos - unit.pos) >= far * far:
			per = mana.per_far_attack
	gain(sim, unit, per * SCALE)


static func on_damage_taken(sim: CombatSim, unit: UnitState, damage: int) -> void:
	if unit.def.mana != null and unit.def.mana.per_10_damage_taken > 0:
		@warning_ignore("integer_division")
		gain(sim, unit, FixedMath.apply_bp(damage * unit.def.mana.per_10_damage_taken * SCALE / 10, unit.def.mana.taken_bp))


## Adds `hundredths` of mana, up to a full bar, unless the unit is Silenced;
## returns what it added. A unit with on_mana_gained passives (phase 8 part
## 4, Chorister) runs them at once with what it gained, unless the gain came
## from one of them (no gain sets off another).
static func gain(sim: CombatSim, unit: UnitState, hundredths: int) -> int:
	if unit.def.mana == null or hundredths <= 0:
		return 0
	if not unit.statuses.is_empty() and Statuses.has_kind(unit, StatusDef.Kind.SILENCE):
		return 0
	if sim.hero_rules.held_no_mana and unit.side != EffectSource.Team.HEROES and not unit.statuses.is_empty() and SideRules.is_held(unit):
		# Shackle Engine (the tuning phase, T-1): a held enemy gains none.
		return 0
	if unit.aura_bp[AuraDef.Stat.MANA_GAIN_BP] != FixedMath.BP_ONE:
		# More from every source (phase 8 part 4, Grand Chorus).
		hundredths = FixedMath.apply_bp(hundredths, Passives.factor(unit, AuraDef.Stat.MANA_GAIN_BP))
	var before: int = unit.mana
	unit.mana = mini(unit.mana + hundredths, maxi(unit.def.mana.max * SCALE, unit.mana_store))
	var gained: int = maxi(unit.mana - before, 0)
	if not sim.overflow_counters.is_empty():
		count_overflow(sim, unit, before)
	if gained > 0 and unit.hears_mana and not sim.sharing_mana:
		sim.sharing_mana = true
		Passives.on_event(sim, unit, EffectDef.Trigger.ON_MANA_GAINED, null, gained, "")
		sim.sharing_mana = false
	return gained


## What the unit's bar went past full, for its side's units counting it
## (the deed count mana_overflow; phase 8 part 4, Wellspring).
static func count_overflow(sim: CombatSim, unit: UnitState, before: int) -> void:
	var over: int = unit.mana - maxi(before, unit.mana_cap)
	if over <= 0 or unit.mana_cap <= 0:
		return
	for counter: UnitState in sim.overflow_counters:
		if counter.side == unit.side:
			Deeds.add_overflow(counter.deeds, over)


## Gives the unit the bar `mana` describes, at its start (null: no bar).
static func set_bar(unit: UnitState, mana: ManaDef) -> void:
	if mana == null:
		unit.mana = 0
		unit.mana_cap = 0
		unit.mana_regen = 0
		return
	unit.mana = mana.start * SCALE
	unit.mana_cap = mana.max * SCALE
	@warning_ignore("integer_division")
	unit.mana_regen = mana.regen_per_s * SCALE / FixedMath.TICKS_PER_SECOND


static func is_full(unit: UnitState) -> bool:
	return unit.def.mana != null and unit.mana >= unit.def.mana.max * SCALE


## A mana_drain effect: takes `amount` whole mana (as much as there is).
static func drain(sim: CombatSim, unit: UnitState, amount: int, source: EffectSource) -> void:
	var drained: int = mini(amount * SCALE, unit.mana)
	unit.mana -= drained
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.MANA_DRAIN, source)
	entry.target = unit.id
	entry.amount = drained
	if unit.def.mana == null:
		entry.note = "no mana"
	sim.combat_log.add(entry)


## "12.5" for 1250 hundredths, "12" for 1200.
static func text(hundredths: int) -> String:
	@warning_ignore("integer_division")
	var whole: String = str(hundredths / SCALE)
	var rest: int = hundredths % SCALE
	if rest == 0:
		return whole
	return "%s.%s" % [whole, ("%02d" % rest).rstrip("0")]
