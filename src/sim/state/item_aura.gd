class_name ItemAura
extends RefCounted
## Everything auras currently do to one item, gathered by
## CombatSim.rederive_all() and folded in by ItemState.derive().

## Output-kind multipliers, indexed by the output stats of AuraDef.Stat
## (DAMAGE_BP, HEAL_BP, SHIELD_BP, OVER_TIME_BP).
var outputs: Array[Array] = [[], [], [], []]
var crit_add_bp: int = 0
var cooldown_add_bp: int = 0


func add(aura: AuraDef, label: String) -> void:
	match aura.stat:
		AuraDef.Stat.CRIT_CHANCE_BP:
			crit_add_bp += aura.value
		AuraDef.Stat.COOLDOWN_BP:
			cooldown_add_bp += aura.value
		AuraDef.Stat.DAMAGE_BP, AuraDef.Stat.HEAL_BP, AuraDef.Stat.SHIELD_BP, AuraDef.Stat.OVER_TIME_BP:
			outputs[aura.stat].append(ValueBreakdown.multiplier(label, aura.value))


## Multipliers for an effect of this output kind ("" for none).
func multipliers_for(kind: String) -> Array[ValueBreakdown.Multiplier]:
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
	result.assign(outputs[index])
	return result
