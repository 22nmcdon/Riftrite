class_name SourcedEffect
extends RefCounted
## An effect on an item together with where it came from (the item itself,
## infusion "", or an essence) and its computed value for this fight.
## Essence effects keep their exact value and carry fractions between uses,
## so a 1.5-stack Slow lands 1, then 2, then 1, ...

var effect: EffectDef
var infusion_id: String = ""
var infusion_name: String = ""
## The relic that granted this effect (see GrantDef), or "".
var granted_by: String = ""
## A specialization's grant: numbered from the holder's stats (not flat).
var grant_scaled: bool = false
## The transformation this effect comes from (the item's own effects, as
## transformed), or "". Only for the log; it's numbered like the item's own.
var transformed_by: String = ""
## For a pair synergy's grant: the row slots of the pair's other items
## (charge's partner_items). Slots, not ItemStates, to avoid a reference
## cycle (see ItemState.owner_index).
var partner_slots: Array[int] = []
## The effect's amount (or stacks) after stat scaling and multipliers.
## Effects without an amount (like amount_bp_of_damage shields) have 0.
var value: ValueBreakdown
var _carry_bp: int = 0


static func make(effect_def: EffectDef, infusion: String = "", infusion_label: String = "") -> SourcedEffect:
	var sourced := SourcedEffect.new()
	sourced.effect = effect_def
	sourced.infusion_id = infusion
	sourced.infusion_name = infusion_label
	return sourced


func final_amount() -> int:
	return value.final if value != null else effect.base_value()


## The amount to use for one application of this effect.
func take_amount() -> int:
	if infusion_id.is_empty() or value == null:
		return final_amount()
	_carry_bp += value.final_bp
	@warning_ignore("integer_division")
	var amount: int = _carry_bp / FixedMath.BP_ONE
	_carry_bp -= amount * FixedMath.BP_ONE
	return amount
