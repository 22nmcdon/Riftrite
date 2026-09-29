class_name DeedDef
extends RefCounted
## A path's deed (docs/plans/rebuild-phase4-paths.md, section 3): one thing
## its hero does in fights, counted in every fight whatever path the hero is
## on (Deeds). The deed's taste is what makes it possible, so without the
## vow it barely moves.
##   {"text": "Damage dealt from 5 or more hexes away", "counts": "damage",
##    "from_hexes": 5}
## What it counts ("counts"), always the hero's own:
##   damage   damage its hits deal (not damage over time): each hit's full
##            amount, Shield included
##   healing  HP restored
##   shield   Shield given
## Filters (each optional):
##   from_ability: ["split_shot"]  only what these abilities or passives do
##                                 (ids in the hero's kits: base, vowed, or
##                                 transformed)
##   from_hexes: 5                 damage only: the hit left from at least
##                                 this many hexes from its target (a shot:
##                                 where it was fired from and where the
##                                 target stood then; anything else: where
##                                 the two stand as it lands)
##   while_below_pct: 30           damage only: the hero is below this share
##                                 of max HP (as the tick it lands ends)
## Adding a kind or a filter is a code change; the waves add theirs
## (extra hits, time rooted, damage taken for allies).

enum Counts { DAMAGE, HEALING, SHIELD }

const COUNT_NAMES: Array[String] = ["damage", "healing", "shield"]
const COUNT_LABELS: Array[String] = ["damage", "healing", "Shield"]

## The player's line: "Damage dealt from 5 or more hexes away".
var text: String
var counts: Counts
var from_ability: Array[String] = []
## Plane units (0: any distance).
var from_range: int = 0
## Basis points of max HP (0: any HP).
var while_below_bp: int = 0


static func read(reader: DataReader) -> DeedDef:
	var def := DeedDef.new()
	def.text = reader.req_string("text")
	def.counts = maxi(COUNT_NAMES.find(reader.req_choice("counts", COUNT_NAMES)), 0) as Counts
	if reader.has("from_ability"):
		def.from_ability = reader.req_string_array("from_ability")
		if def.from_ability.is_empty():
			reader.error("from_ability needs at least one id")
	if reader.has("from_hexes"):
		def.from_range = reader.req_int("from_hexes", 1, 20) * HexGrid.HEX
	if reader.has("while_below_pct"):
		def.while_below_bp = reader.req_int("while_below_pct", 1, 99) * 100
	if def.counts != Counts.DAMAGE and (def.from_range > 0 or def.while_below_bp > 0):
		reader.error("from_hexes and while_below_pct only filter damage")
	reader.finish()
	return def


## Whether an entry of this kind, from this ability, counts toward it (the
## filters on distance and HP aside).
func counts_kind(kind: LogEntry.Kind, ability_id: String) -> bool:
	match counts:
		Counts.DAMAGE:
			if kind != LogEntry.Kind.DAMAGE:
				return false
		Counts.HEALING:
			if kind != LogEntry.Kind.HEAL:
				return false
		Counts.SHIELD:
			if kind != LogEntry.Kind.SHIELD:
				return false
	return from_ability.is_empty() or from_ability.has(ability_id)
