class_name GrantDef
extends RefCounted
## A relic's grant: every matching item on the relic's side gains an extra
## effect for the fight, fired by the item's own triggers:
##   {"filter": {"tag": "weapon"},
##    "effect": {"trigger": "on_hit", "type": "apply_status", "status": "burn", "stacks": 1, "target": "hit_target"}}
## The number is flat (no "scaling"): only side-wide boosts change it (see
## AuraDef.covers_everything), never the item's tier, stats, or other auras.
## Essences don't convert it, and it never spills. The log credits the item
## and names the relic: "wren · Rust Hook (Cinder Crown)".

## Which items gain the effect, or null for every item on the side.
var filter: AuraFilter = null
var effect: EffectDef


static func read(reader: DataReader) -> GrantDef:
	var def := GrantDef.new()
	if reader.has("filter"):
		var filter_reader: DataReader = reader.req_object("filter")
		if filter_reader != null:
			def.filter = AuraFilter.read(filter_reader, true)
	var effect_reader: DataReader = reader.req_object("effect")
	if effect_reader != null:
		def.effect = EffectDef.read(effect_reader)
		if def.effect.scaling.any(func(ratio: int) -> bool: return ratio != 0):
			effect_reader.error("relic numbers are flat, so a grant can't have \"scaling\"")
	else:
		def.effect = EffectDef.new()
	reader.finish()
	return def


func matches(item: ItemState) -> bool:
	return filter == null or filter.matches_item(item)
