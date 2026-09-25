class_name SourcedEffect
extends RefCounted
## An effect on an item together with where it came from: the item itself
## (infusion "") or a socketed essence.

var effect: EffectDef
var infusion_id: String = ""
var infusion_name: String = ""


static func make(effect_def: EffectDef, infusion: String = "", infusion_label: String = "") -> SourcedEffect:
	var sourced := SourcedEffect.new()
	sourced.effect = effect_def
	sourced.infusion_id = infusion
	sourced.infusion_name = infusion_label
	return sourced
