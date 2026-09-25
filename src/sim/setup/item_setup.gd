class_name ItemSetup
extends RefCounted
## An item as it sits in a unit's row going into a fight: which item, and
## which essences are socketed in it.

var def: ItemDef
## 0 = C, 1 = B, 2 = A, 3 = S (see TuningDef.TIER_NAMES).
var tier: int = 0
## Socketed essences, in socket order. The first one spills left and the
## second right when an alloy is Resonant, so the order matters.
var essence_ids: Array[String] = []


static func make(item_def: ItemDef, essences: Array[String] = [], item_tier: int = 0) -> ItemSetup:
	var setup := ItemSetup.new()
	setup.def = item_def
	setup.essence_ids = essences
	setup.tier = item_tier
	return setup


## Small items have 1 socket; Medium and Large have 2 (design doc).
func socket_count() -> int:
	return 1 if def.size <= 1 else 2
