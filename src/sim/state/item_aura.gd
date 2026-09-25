class_name ItemAura
extends RefCounted
## Everything auras (and relic grants) currently do to one item, gathered by
## CombatSim.rederive_all() and folded in by ItemState.derive(). CombatSim
## also keeps one per side for the side's relic effects, which only
## side-wide boosts reach.


## A relic grant on this item, with the relic's name for the log.
class Grant:
	var def: GrantDef
	var relic_name: String
	## Row slots of a pair synergy's other items (see SourcedEffect).
	var partner_slots: Array[int] = []


## Output-kind multipliers, indexed by the output stats of AuraDef.Stat
## (DAMAGE_BP, HEAL_BP, SHIELD_BP, OVER_TIME_BP).
var outputs: Array[Array] = [[], [], [], []]
## The part of `outputs` from auras that boost everything on the side
## (AuraDef.covers_everything): the only boosts flat relic numbers get.
var everything_outputs: Array[Array] = [[], [], [], []]
var grants: Array[Grant] = []
var crit_add_bp: int = 0
var cooldown_add_bp: int = 0


func add(aura: AuraDef, label: String) -> void:
	match aura.stat:
		AuraDef.Stat.CRIT_CHANCE_BP:
			crit_add_bp += aura.value
		AuraDef.Stat.COOLDOWN_BP:
			cooldown_add_bp += aura.value
		AuraDef.Stat.DAMAGE_BP, AuraDef.Stat.HEAL_BP, AuraDef.Stat.SHIELD_BP, AuraDef.Stat.OVER_TIME_BP:
			var multiplier: ValueBreakdown.Multiplier = ValueBreakdown.multiplier(label, aura.value)
			outputs[aura.stat].append(multiplier)
			if aura.covers_everything():
				everything_outputs[aura.stat].append(multiplier)


func add_grant(grant: GrantDef, relic_name: String, partner_slots: Array[int] = []) -> void:
	var entry := Grant.new()
	entry.def = grant
	entry.relic_name = relic_name
	entry.partner_slots = partner_slots
	grants.append(entry)


## Multipliers for an effect of this output kind ("" for none).
## `everything_only`: just the side-wide ones (for flat relic numbers).
func multipliers_for(kind: String, everything_only: bool = false) -> Array[ValueBreakdown.Multiplier]:
	var result: Array[ValueBreakdown.Multiplier] = []
	var index: int = -1
	match kind:
		"":
			return result
		"damage":
			index = AuraDef.Stat.DAMAGE_BP
		"heal":
			index = AuraDef.Stat.HEAL_BP
		"shield":
			index = AuraDef.Stat.SHIELD_BP
		_:
			index = AuraDef.Stat.OVER_TIME_BP
	result.assign(everything_outputs[index] if everything_only else outputs[index])
	return result
