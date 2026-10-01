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
## Phase 5c step 4 (growing cards count the way deeds do; docs/plans/
## rebuild-phase5c-combos.md, section 9.4):
##   applied  statuses it applies to enemies, one each (keywords: only those
##            carrying one of them; Notched Bow's Marks)
##   taken    damage enemies deal it: their hits and damage over time, Shield
##            included (not Rift Collapse's; Weathered)
##   ms_below how long it spends below while_below_pct, in ms, checked as
##            each tick ends (Borrowed Time)
##   kills    enemies it's credited with felling: the last to hit them
##            (Collector's Chain)
##   crits    its hits that crit, one each (phase 5c step 5a; Lucky Strike)
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
##   while_undying: true           damage only: the hero can't fall (it has
##                                 an Undying status as the tick it lands
##                                 ends; Last Watch)
##   from_basic: true              only what its basic attack does (phase 5c
##                                 step 4; Rift-Fed Blades)
##   keywords: ["marked"]          applied only: statuses with these keywords
## "threshold": 900 is what fills it in a run (phase 5, Decision 6: about
## three fights' worth of what a vowed hero puts in); the sim never reads it.
## Adding a kind or a filter is a code change.

enum Counts { DAMAGE, HEALING, SHIELD, EXTRA_HITS, ROOTED_MS, GUARDED, APPLIED, TAKEN, MS_BELOW, KILLS, CRITS }

const COUNT_NAMES: Array[String] = ["damage", "healing", "shield", "extra_hits", "rooted_ms", "guarded", "applied", "taken", "ms_below", "kills", "crits"]
const COUNT_LABELS: Array[String] = ["damage", "healing", "Shield", "extra hits", "ms rooted", "damage guarded", "applied", "damage taken", "ms below", "kills", "crits"]
## The kinds read from where the hero is the target, or from the tick, not
## from what the hero does.
const NOT_ITS_OWN: Array[Counts] = [Counts.TAKEN, Counts.MS_BELOW, Counts.KILLS]

## The player's line: "Damage dealt from 5 or more hexes away".
var text: String
var counts: Counts
var from_ability: Array[String] = []
## Plane units: the hit must leave from farther than this (0: any distance).
var from_range: int = 0
## Basis points of max HP (0: any HP).
var while_below_bp: int = 0
var off_target: bool = false
var while_undying: bool = false
var from_basic: bool = false
## applied: only statuses carrying one of these keywords (empty: any).
var keywords: Array[String] = []
## What fills the deed in a run (0: none given; RunContent requires one).
var threshold: int = 0


## `needs_text`: a path's deed has the player's line; a growing card's count
## (GrowthDef) doesn't, since the card has its own.
static func read(reader: DataReader, needs_text: bool = true) -> DeedDef:
	var def := DeedDef.new()
	def.text = reader.req_string("text") if needs_text else reader.opt_string("text", "")
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
	def.while_undying = reader.opt_bool("while_undying", false)
	def.from_basic = reader.opt_bool("from_basic", false)
	def.keywords = reader.opt_choice_array("keywords", Keywords.NAMES)
	def.threshold = reader.opt_int("threshold", 0, 1)
	if def.counts != Counts.DAMAGE and (def.from_range > 0 or def.while_undying):
		reader.error("beyond_hexes and while_undying only filter damage")
	if def.counts != Counts.DAMAGE and def.counts != Counts.MS_BELOW and def.while_below_bp > 0:
		reader.error("while_below_pct can only filter damage (or set what ms_below counts)")
	if def.counts == Counts.MS_BELOW and def.while_below_bp == 0:
		reader.error("ms_below needs while_below_pct")
	if def.counts != Counts.APPLIED and not def.keywords.is_empty():
		reader.error("keywords only filter applied")
	if NOT_ITS_OWN.has(def.counts) and (def.from_basic or not def.from_ability.is_empty() or def.off_target):
		reader.error("%s isn't something an ability does, so it takes no from_ability, from_basic, or off_target" % COUNT_NAMES[def.counts])
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
		Counts.EXTRA_HITS, Counts.CRITS:
			if kind != LogEntry.Kind.DAMAGE:
				return false
		Counts.ROOTED_MS:
			return kind == LogEntry.Kind.STATUS_APPLIED
		Counts.GUARDED:
			return kind == LogEntry.Kind.GUARD
		Counts.APPLIED:
			if kind != LogEntry.Kind.STATUS_APPLIED:
				return false
		Counts.TAKEN, Counts.MS_BELOW, Counts.KILLS:
			return false
	return from_ability.is_empty() or from_ability.has(ability_id)
