class_name ItemSetup
extends RefCounted
## An item as it sits in a unit's row going into a fight: which item, and
## which essences are socketed in it.

var def: ItemDef
## Socketed essences, in socket order. The first one spills left and the
## second right when an alloy is Resonant, so the order matters.
var essence_ids: Array[String] = []


static func make(item_def: ItemDef, essences: Array[String] = []) -> ItemSetup:
	var setup := ItemSetup.new()
	setup.def = item_def
	setup.essence_ids = essences
	return setup


## Small items have 1 socket; Medium and Large have 2 (design doc).
func socket_count() -> int:
	return 1 if def.size <= 1 else 2
