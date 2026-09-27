class_name Infusions
extends RefCounted
## Infusion XP and levels (docs/design.md, "Attune"; docs/plans/infusion-rework.md).
##
## An infused item gains its xp_per_fire each time it fires (extra fires
## included) and tuning.xp_per_battle when the fight ends. Crossing
## xp_to_attuned / xp_to_resonant levels the infusion up at once, mid-fight,
## which re-derives every item: a new Resonant single starts spilling to its
## holder's items that share a keyword, and a new Resonant alloy or pure
## double awakens (its special switches on). The fight reports each
## infusion's XP before and after, so the run layer can keep it.

enum Level { BASE, ATTUNED, RESONANT }

## An item's infusion holds one essence, or two fused into an alloy or pure
## double. Never a third.
const MAX_ESSENCES: int = 2

const LEVEL_NAMES: Array[String] = ["Base", "Attuned", "Resonant"]


static func level_for(xp: int, tuning: TuningDef) -> int:
	if xp >= tuning.xp_to_resonant:
		return Level.RESONANT
	if xp >= tuning.xp_to_attuned:
		return Level.ATTUNED
	return Level.BASE


static func gain_xp(sim: CombatSim, item: ItemState, amount: int, when: String = "") -> void:
	if item.essences.is_empty() or amount <= 0:
		return
	item.infusion_xp += amount
	var level: int = level_for(item.infusion_xp, sim.tuning)
	if level == item.infusion_level:
		return
	item.infusion_level = level
	var holder: UnitState = sim.owner_of(item)
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.INFUSION_LEVEL, EffectSource.make(holder.id, item.def.id, item.def.name, item.essences[0].id, item.infusion_name()))
	entry.amount = item.infusion_xp
	var awakens: String = " and awakens" if item.awakened() else ""
	entry.note = "%s%s (%d XP%s)" % [LEVEL_NAMES[level], awakens, item.infusion_xp, "" if when.is_empty() else ", " + when]
	sim.combat_log.add(entry)
	sim.rederive_all()
