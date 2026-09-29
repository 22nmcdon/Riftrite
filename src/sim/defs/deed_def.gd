class_name DeedDef
extends RefCounted
## A path's deed (docs/plans/rebuild-phase4-paths.md, section 3): one thing
## its hero does in fights, counted in every fight whatever path the hero is
## on (Deeds). The deed's taste is what makes it possible, so without the
## vow it barely moves.
##   {"text": "Damage dealt from beyond 4 hexes", "counts": "damage",
##    "beyond_hexes": 4}
## What it counts ("counts"), always the hero's own:
##   damage   damage its hits deal (not damage over time): each hit's full
##            amount, Shield included
##   healing  HP restored
##   shield   Shield given
##   extra_hits  enemies an attack hits beyond its own target: each hit
##            (from_ability's) on a unit that isn't the target of that
##            ability's latest fire (Split Shot, Brand, the Mace's cleave)
##   rooted_ms   how long the Roots it applies last, in ms (as applied;
##            Trapper)
##   guarded  damage it takes for allies (Guard; Hearthwall)
## Filters (each optional):
##   from_ability: ["split_shot"]  only what these abilities or passives do
##                                 (ids in the hero's kits: base, vowed, or
##                                 transformed)
##   beyond_hexes: 4               damage only: the hit left from farther than
##                                 this many hexes from its target (a shot:
##                                 where it was fired from and where the
##                                 target stood then; anything else: where
##                                 the two stand as it lands)
##   off_target: true              only what lands on a unit that isn't the
##                                 target of that ability's latest fire
##                                 (Kindle's heal beside Mend's target)
##   while_below_pct: 30           damage only: the hero is below this share
##                                 of max HP (as the tick it lands ends)
## Adding a kind or a filter is a code change.

enum Counts { DAMAGE, HEALING, SHIELD, EXTRA_HITS, ROOTED_MS, GUARDED }

const COUNT_NAMES: Array[String] = ["damage", "healing", "shield", "extra_hits", "rooted_ms", "guarded"]
const COUNT_LABELS: Array[String] = ["damage", "healing", "Shield", "extra hits", "ms rooted", "damage guarded"]

## The player's line: "Damage dealt from 5 or more hexes away".
var text: String
var counts: Counts
var from_ability: Array[String] = []
## Plane units: the hit must leave from farther than this (0: any distance).
var from_range: int = 0
## Basis points of max HP (0: any HP).
var while_below_bp: int = 0
var off_target: bool = false


static func read(reader: DataReader) -> DeedDef:
	var def := DeedDef.new()
	def.text = reader.req_string("text")
	def.counts = maxi(COUNT_NAMES.find(reader.req_choice("counts", COUNT_NAMES)), 0) as Counts
	if reader.has("from_ability"):
		def.from_ability = reader.req_string_array("from_ability")
		if def.from_ability.is_empty():
			reader.error("from_ability needs at least one id")
	if reader.has("beyond_hexes"):
		def.from_range = reader.req_int("beyond_hexes", 1, 20) * HexGrid.HEX
	def.off_target = reader.opt_bool("off_target", false)
	if reader.has("while_below_pct"):
		def.while_below_bp = reader.req_int("while_below_pct", 1, 99) * 100
	if def.counts != Counts.DAMAGE and (def.from_range > 0 or def.while_below_bp > 0):
		reader.error("beyond_hexes and while_below_pct only filter damage")
	if (def.counts == Counts.ROOTED_MS or def.counts == Counts.GUARDED) and not def.from_ability.is_empty():
		reader.error("%s counts every one, so it takes no from_ability" % COUNT_NAMES[def.counts])
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
		Counts.EXTRA_HITS:
			if kind != LogEntry.Kind.DAMAGE:
				return false
		Counts.ROOTED_MS:
			return kind == LogEntry.Kind.STATUS_APPLIED
		Counts.GUARDED:
			return kind == LogEntry.Kind.GUARD
	return from_ability.is_empty() or from_ability.has(ability_id)
