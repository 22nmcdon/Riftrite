class_name EffectSource
extends RefCounted
## Who caused an effect: the unit, the item, and (if it came from an
## infusion) the essence; or a relic, which has no unit. An effect a relic
## granted to an item names both. Every log line and status stack carries one, so
## every number in a fight can be traced back (CLAUDE.md rule 4).

var unit_id: String = ""
var item_id: String = ""
var item_name: String = ""
## Essence id, or "" if the effect is the item's own.
var infusion_id: String = ""
var infusion_name: String = ""
## The relic that granted the item this effect, or "".
var granted_by: String = ""
## For a relic's own effects: the side holding it (UnitSetup.Side); -1 if
## the source is a unit. item_id / item_name are then the relic's.
var relic_side: int = -1


static func make(unit: String, item: String, item_label: String, infusion: String = "", infusion_label: String = "") -> EffectSource:
	var source := EffectSource.new()
	source.unit_id = unit
	source.item_id = item
	source.item_name = item_label
	source.infusion_id = infusion
	source.infusion_name = infusion_label
	return source


static func relic(relic_def: RelicDef, side: UnitSetup.Side) -> EffectSource:
	var source := EffectSource.new()
	source.item_id = relic_def.id
	source.item_name = relic_def.name
	source.relic_side = side
	return source


func same_as(other: EffectSource) -> bool:
	return unit_id == other.unit_id and item_id == other.item_id and infusion_id == other.infusion_id \
		and granted_by == other.granted_by and relic_side == other.relic_side


## "warden · Rust Cleaver", "warden · Rust Cleaver [Ember]",
## "warden · Rust Cleaver (Cinder Crown)", "relic · Warding Knot", or
## "enemy relic · Gloam Totem".
func describe() -> String:
	var text: String = "%s · %s" % [unit_id, item_name] if not unit_id.is_empty() else item_name
	if relic_side >= 0:
		text = "%s · %s" % ["relic" if relic_side == UnitSetup.Side.HEROES else "enemy relic", item_name]
	if not granted_by.is_empty():
		text += " (%s)" % granted_by
	if not infusion_name.is_empty():
		text += " [%s]" % infusion_name
	return text
