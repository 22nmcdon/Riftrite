class_name SourcedEffect
extends RefCounted
## An effect on an item together with where it came from (the item itself,
## infusion "", or a socketed essence) and its computed value for this fight.

var effect: EffectDef
var infusion_id: String = ""
var infusion_name: String = ""
## The effect's amount (or stacks) after stat scaling and multipliers.
## Effects without an amount (like amount_bp_of_damage shields) have 0.
var value: ValueBreakdown


static func make(effect_def: EffectDef, infusion: String = "", infusion_label: String = "") -> SourcedEffect:
	var sourced := SourcedEffect.new()
	sourced.effect = effect_def
	sourced.infusion_id = infusion
	sourced.infusion_name = infusion_label
	return sourced


func final_amount() -> int:
	return value.final if value != null else effect.base_value()
