class_name Infusions
extends RefCounted
## Infusion XP and levels (docs/design.md, "Attune").
##
## An infused item gains its xp_per_fire each time it fires (extra fires
## included) and tuning.xp_per_battle when the fight ends. Crossing
## xp_to_attuned / xp_to_resonant levels the infusion up at once, mid-fight,
## which re-derives the holder's row (a new Resonant item starts spilling to
## its neighbors). The fight reports each infusion's XP before and after, so
## the run layer can keep it.

enum Level { BASE, ATTUNED, RESONANT }

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
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.INFUSION_LEVEL, EffectSource.make(holder.id, item.def.id, item.def.name, item.essences[0].id, item.essences[0].name))
	entry.amount = item.infusion_xp
	entry.note = "%s (%d XP%s)" % [LEVEL_NAMES[level], item.infusion_xp, "" if when.is_empty() else ", " + when]
	sim.combat_log.add(entry)
	holder.rederive_items(sim.content)
