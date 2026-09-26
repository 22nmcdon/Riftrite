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
## The infusion's XP going into the fight (decides Base/Attuned/Resonant).
var infusion_xp: int = 0
## A Devourer's trace (see LegendaryDef): +this share of its own numbers.
var trace_bp: int = 0


static func make(item_def: ItemDef, essences: Array[String] = [], item_tier: int = 0, xp: int = 0, trace: int = 0) -> ItemSetup:
	var setup := ItemSetup.new()
	setup.def = item_def
	setup.essence_ids = essences
	setup.tier = item_tier
	setup.infusion_xp = xp
	setup.trace_bp = trace
	return setup


## Sockets depend on rarity, not size (see TuningDef.socket_count).
func socket_count(tuning: TuningDef) -> int:
	return tuning.socket_count(def)
