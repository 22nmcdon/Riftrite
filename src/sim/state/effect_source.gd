class_name EffectSource
extends RefCounted
## Who caused an effect: the unit, the item, and (if it came from an
## infusion) the essence. Every log line and status stack carries one, so
## every number in a fight can be traced back (CLAUDE.md rule 4).

var unit_id: String = ""
var item_id: String = ""
var item_name: String = ""
## Essence id, or "" if the effect is the item's own.
var infusion_id: String = ""
var infusion_name: String = ""


static func make(unit: String, item: String, item_label: String, infusion: String = "", infusion_label: String = "") -> EffectSource:
	var source := EffectSource.new()
	source.unit_id = unit
	source.item_id = item
	source.item_name = item_label
	source.infusion_id = infusion
	source.infusion_name = infusion_label
	return source


func same_as(other: EffectSource) -> bool:
	return unit_id == other.unit_id and item_id == other.item_id and infusion_id == other.infusion_id


## "warden · Rust Cleaver" or "warden · Rust Cleaver [Ember]".
func describe() -> String:
	var text: String = "%s · %s" % [unit_id, item_name] if not unit_id.is_empty() else item_name
	if not infusion_name.is_empty():
		text += " [%s]" % infusion_name
	return text
