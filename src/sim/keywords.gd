class_name Keywords
extends RefCounted
## Keywords (docs/plans/rebuild-phase5c-combos.md, step 3; part 7, section
## 1): names for a unit's state that any card can refer to. A status carries
## its keyword ("keyword" in data/statuses.json); Shielded is the one that
## isn't a status (a Shield above 0). Keywords are team-wide by nature: they
## are the unit's state, whoever put it there.
##   marked     a Marked status
##   rooted     a Root
##   burning    Burn stacks
##   stealthed  Stealth, or submerged (phase 8 part 3; Water)
##   shielded   its Shield is above 0

const SHIELDED: String = "shielded"
const NAMES: Array[String] = ["marked", "rooted", "burning", "stealthed", SHIELDED]
## How a card names each ("Marked", ...), in NAMES' order.
const LABELS: Array[String] = ["Marked", "Rooted", "Burning", "Stealthed", "Shielded"]


## True if `unit` has `keyword` now.
static func has(unit: UnitState, keyword: String) -> bool:
	if keyword == SHIELDED:
		return unit.shield > 0
	if unit.submerged and keyword == "stealthed":
		# Submerged (phase 8 part 3) is Stealthed to every card.
		return true
	for state: StatusState in unit.statuses:
		if state.def.keyword == keyword and (state.def.is_timed() or state.total_stacks() > 0):
			return true
	return false


static func label(keyword: String) -> String:
	var index: int = NAMES.find(keyword)
	return LABELS[index] if index >= 0 else keyword
