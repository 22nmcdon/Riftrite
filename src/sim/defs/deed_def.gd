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
##   overkill its hits' damage past their target's last HP (phase 5c step
##            5b); with "steps_at_pct": [0, 50, 100], instead one for each
##            of those shares of the target's max HP the overkill reaches,
##            0 being any (so 1 to 3 a kill, whatever the HP; the tuning
##            phase, Decision 7: Overkill Tithe)
## Phase 5c step 6 (the loadout's ranks, section 14.3):
##   casts    its signature's fires, one each (an echo is its own ability,
##            so it doesn't count; a sigil's)
##   ms_standing  how long it stands in the fight, in ms, checked as each
##            tick ends (a tactic's, Decision 32)
## Phase 8 part 2 (apexes):
##   hits     its hits on enemies, one each (Hailstorm)
##   shared   damage its link spread over linked allies (Loomwarden)
##   blocked  enemy shots its walls stop, one each (The Unbroken Gate)
## Phase 8 part 4 (Garrow):
##   pulled   enemies it pulls or hooks, one each that moves (Iron Links);
##            with "by_hexes": true, the hexes they're moved, rounded
##            (Undertow)
##   extended_ms                   the ms of statuses it made last longer
##            (extend_status; phase 8 part 4, Scent and Choke)
##   shield's "above_pct_of_max_hp": 50   only Shield given past that share
##            of its target's max HP (Endless Bulwark)
##   kills takes from_ability too: only kills by those abilities (Eagle
##            Eye, Inquisitor)
##   within_ms_of_hop: 1000        a filter: only what lands within this long
##                                 after the hero's last hop (Windrunner)
## Phase 8 part 6 (Lucan):
##   lost_target  enemies losing their target to Stealth, anyone's Stealth,
##            one each (Night Veil)
##   status_ms    how long the statuses it applies last, in ms (as applied;
##            "statuses" names them; Marionette's controlled)
##   copies: "own" | "allies"     damage or hits: only those its copies of
##                                 itself make, or its copies of allies
##                                 (Thousand Faces, True Reflection)
##   from_stealth: true            damage or hits: only strikes from Stealth
##                                 (LogEntry.from_stealth; Unseen Host)
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
##   vs_keywords: ["rooted"]       damage only: hits on a unit with one of
##                                 these keywords as the tick ends (phase 8
##                                 part 2, Huntmaster)
##   by_allies: true               damage or hits: its allies' hits count
##                                 too (Huntmaster; hits and beyond_hexes,
##                                 where the two stand as it lands, phase 8
##                                 part 4, Windcaller)
##   with_part: "tailwind"         only while its kit holds this part (a
##                                 passive's id; phase 8 part 4: Windcaller's
##                                 hits under Tailwind, which only its vow
##                                 brings)
##   after_rising: true            taken only: once the hero has risen by its
##                                 own kit this fight (phase 8 part 2,
##                                 Undying Oath)
##   from_basic: true              only what its basic attack does (phase 5c
##                                 step 4; Rift-Fed Blades)
##   keywords: ["marked"]          applied only: statuses with these keywords
##   by_stacks: true               applied only: the stacks each one adds,
##                                 not one each (phase 8 part 6, Ilse's Burn)
##   statuses: ["blood_rite"]      applied: only these statuses (on anyone);
##                                 hits by_allies (phase 8 part 5, Blood
##                                 Rite): only hits by an ally holding one
## (Phase 8 part 4, Chorister: "mana_given" counts the whole mana the hero
## gives other units, MANA_GIVEN. Aldous's apexes: "mana_overflow" counts
## the whole mana its side's bars gain past full (Wellspring), and
## "ally_casts" with "within_hexes": 3 its allies' signature fires within
## that reach of it (Grand Chorus).)
## (Phase 8 part 6, Ottilie: "bonus_damage" with "from_part": "reaction"
## (or a list) counts the damage those passives' per-hit auras added to its
## hits, each
## hit's share of its power bonus (LogEntry.part_bonus; Catalyst's deed);
## "shards" counts the shards its effects paid (SHARDS lines, not those
## past its cap; Transmuter's deed, with from_ability).)
## "threshold": 900 is what fills it in a run (phase 5, Decision 6: about
## three fights' worth of what a vowed hero puts in); the sim never reads it.
## Adding a kind or a filter is a code change.

enum CopiesBy { ANY, OWN, ALLIES }
enum Counts { DAMAGE, HEALING, SHIELD, EXTRA_HITS, ROOTED_MS, GUARDED, APPLIED, TAKEN, MS_BELOW, KILLS, CRITS, OVERKILL, CASTS, MS_STANDING, HITS, SHARED, BLOCKED, PULLED, EXTENDED_MS, MANA_GIVEN, MANA_OVERFLOW, ALLY_CASTS, MAX_HP_GAINED, HP_SPENT, LIFESTEAL, TITHE, TITHE_FLAWLESS, BONUS_DAMAGE, SHARDS, TRANSMUTED, SUMMONED,
	LOST_TARGET, STATUS_MS }

const COUNT_NAMES: Array[String] = ["damage", "healing", "shield", "extra_hits", "rooted_ms", "guarded", "applied", "taken", "ms_below", "kills", "crits", "overkill", "casts", "ms_standing", "hits", "shared", "blocked", "pulled", "extended_ms", "mana_given", "mana_overflow", "ally_casts", "max_hp_gained", "hp_spent", "lifesteal", "tithe", "tithe_flawless", "bonus_damage", "shards", "transmuted", "summoned",
	"lost_target", "status_ms"]
const COUNT_LABELS: Array[String] = ["damage", "healing", "Shield", "extra hits", "ms rooted", "damage guarded", "applied", "damage taken", "ms below", "kills", "crits", "overkill", "casts", "ms standing", "enemies hit", "damage shared", "attacks blocked", "enemies pulled", "ms extended", "mana given", "mana past full", "ally signatures near", "max HP gained", "HP spent", "healed by lifesteal", "shards from Tithe", "shards from flawless fights", "extra damage", "shards", "items transmuted", "summons joined",
	"targets lost to Stealth", "ms"]
## The kinds read from where the hero is the target, or from the tick, not
## from what the hero does.
const NOT_ITS_OWN: Array[Counts] = [Counts.TAKEN, Counts.MS_BELOW, Counts.KILLS, Counts.CASTS, Counts.MS_STANDING, Counts.BLOCKED,
	Counts.MANA_OVERFLOW, Counts.ALLY_CASTS, Counts.TITHE, Counts.TITHE_FLAWLESS, Counts.TRANSMUTED, Counts.LOST_TARGET]
## The kinds the run counts, not the fight (phase 8 part 5, Tithe-Collector
## and Collector of Debts: shards from Tithe, all of them or a flawless
## fight's): RunFlow.record adds them; Deeds never matches them.
## Phase 8 part 6 (Grand Transmutation): "transmuted", items the hero's
## transmuting turned into other items (RunFlow.transmute_into).
const BY_THE_RUN: Array[Counts] = [Counts.TITHE, Counts.TITHE_FLAWLESS, Counts.TRANSMUTED]

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
## taken (phase 8 part 2): only after the hero has risen by its own kit.
var after_rising: bool = false
## ally_casts: how near it the ally must fire (plane units; phase 8 part 4).
var near_range: int = 0
## Only while its kit holds a part with this id ("": always; phase 8 part 4).
var with_part: String = ""
## bonus_damage: the passives whose added damage it counts (phase 8 part 6;
## "from_part" names one or several).
var from_parts: Array[String] = []
## pulled: count the hexes moved, not the enemies (phase 8 part 4).
var by_hexes: bool = false
## shield: only what's given past this share of the target's max HP (0: all).
var above_bp: int = 0
## damage (phase 8 part 2): only hits on units with these keywords, and
## allies' hits count too.
var vs_keywords: Array[String] = []
## overkill: the shares of the target's max HP (in bp) that each count one
## (empty: count the overkill itself).
var overkill_steps_bp: Array[int] = []
var by_allies: bool = false
## Only what lands within this long after the hero's last hop (phase 8 part
## 2, Windrunner; "within_ms_of_hop"). 0: any time.
var after_hop_ticks: int = 0
## applied: only statuses carrying one of these keywords (empty: any).
var keywords: Array[String] = []
## applied (phase 8 part 2): only these statuses, on any unit (an ally's
## boost too; "statuses"). Empty: any status on an enemy.
var statuses: Array[String] = []
## applied (phase 8 part 6, Ilse): count the stacks each adds, not one each.
var by_stacks: bool = false
## Damage or hits by its copies only (phase 8 part 6, Lucan): of itself
## (OWN) or of its allies (ALLIES).
var copies: CopiesBy = CopiesBy.ANY
## Damage or hits: only strikes from Stealth (phase 8 part 6, Unseen Host).
var from_stealth: bool = false
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
	def.after_rising = reader.opt_bool("after_rising", false)
	def.by_hexes = reader.opt_bool("by_hexes", false)
	if def.by_hexes and def.counts != Counts.PULLED:
		reader.error("by_hexes counts pulled hexes (\"counts\": \"pulled\")")
	if reader.has("above_pct_of_max_hp"):
		def.above_bp = reader.req_int("above_pct_of_max_hp", 1, 1000) * 100
		if def.counts != Counts.SHIELD:
			reader.error("above_pct_of_max_hp filters Shield given (\"counts\": \"shield\")")
	if reader.has("steps_at_pct"):
		for pct: int in reader.req_int_array("steps_at_pct"):
			if pct < 0 or pct > 1000:
				reader.error("steps_at_pct: each share is 0 to 1000")
			def.overkill_steps_bp.append(pct * 100)
		if def.counts != Counts.OVERKILL:
			reader.error("steps_at_pct counts overkill (\"counts\": \"overkill\")")
	def.vs_keywords = reader.opt_choice_array("vs_keywords", Keywords.NAMES)
	def.by_allies = reader.opt_bool("by_allies", false)
	if def.counts != Counts.DAMAGE and not def.vs_keywords.is_empty():
		reader.error("vs_keywords only filter damage")
	if def.by_allies and def.counts != Counts.DAMAGE and def.counts != Counts.HITS:
		reader.error("by_allies only counts damage or hits")
	def.by_stacks = reader.opt_bool("by_stacks", false)
	if def.by_stacks and def.counts != Counts.APPLIED:
		reader.error("by_stacks counts the stacks applied (\"counts\": \"applied\")")
	def.with_part = reader.opt_string("with_part", "")
	if reader.is_array("from_part"):
		def.from_parts = reader.req_string_array("from_part")
	elif reader.has("from_part"):
		def.from_parts = [reader.req_string("from_part")] as Array[String]
	if (def.counts == Counts.BONUS_DAMAGE) != not def.from_parts.is_empty():
		reader.error("bonus_damage names the passive it counts (\"from_part\"), and only it does")
	if def.counts == Counts.ALLY_CASTS:
		def.near_range = reader.req_int("within_hexes", 1, 10) * HexGrid.HEX
	if def.by_allies and not def.from_ability.is_empty():
		reader.error("by_allies counts every ally's hits, so it takes no from_ability")
	if def.after_rising and def.counts != Counts.TAKEN:
		reader.error("after_rising only filters taken")
	def.after_hop_ticks = reader.opt_ticks("within_ms_of_hop", 0)
	def.keywords = reader.opt_choice_array("keywords", Keywords.NAMES)
	if reader.has("statuses"):
		def.statuses = reader.req_string_array("statuses")
		# Phase 8 part 5 (Blood Rite): an ally's hits by_allies counts only
		# while that ally holds one of them; phase 8 part 6 (Wild Hunt): its
		# damage too.
		if def.counts != Counts.APPLIED and def.counts != Counts.STATUS_MS and not (def.by_allies and (def.counts == Counts.HITS or def.counts == Counts.DAMAGE)):
			reader.error("statuses only filter applied, or hits or damage by_allies")
	match reader.opt_string_choice("copies", "", ["own", "allies"]):
		"own":
			def.copies = CopiesBy.OWN
		"allies":
			def.copies = CopiesBy.ALLIES
	def.from_stealth = reader.opt_bool("from_stealth", false)
	if (def.copies != CopiesBy.ANY or def.from_stealth) and def.counts != Counts.DAMAGE and def.counts != Counts.HITS:
		reader.error("copies and from_stealth only filter damage or hits")
	if def.counts == Counts.STATUS_MS and def.statuses.is_empty():
		reader.error("status_ms names the statuses it counts (\"statuses\")")
	def.threshold = reader.opt_int("threshold", 0, 1)
	if def.counts != Counts.DAMAGE and (def.while_undying or (def.from_range > 0 and not (def.by_allies and def.counts == Counts.HITS))):
		reader.error("beyond_hexes and while_undying only filter damage")
	if def.counts != Counts.DAMAGE and def.counts != Counts.MS_BELOW and def.while_below_bp > 0:
		reader.error("while_below_pct can only filter damage (or set what ms_below counts)")
	if def.counts == Counts.MS_BELOW and def.while_below_bp == 0:
		reader.error("ms_below needs while_below_pct")
	if def.counts != Counts.APPLIED and not def.keywords.is_empty():
		reader.error("keywords only filter applied")
	# Kills may name the abilities that land them (phase 8 part 2): the
	# fallen's last hit says which.
	if NOT_ITS_OWN.has(def.counts) and (def.from_basic or (not def.from_ability.is_empty() and def.counts != Counts.KILLS) or def.off_target):
		reader.error("%s isn't something an ability does, so it takes no from_ability, from_basic, or off_target" % COUNT_NAMES[def.counts])
	if (def.counts == Counts.ROOTED_MS or def.counts == Counts.GUARDED) and not def.from_ability.is_empty():
		reader.error("%s counts every one, so it takes no from_ability" % COUNT_NAMES[def.counts])
	reader.finish()
	return def


## True if the run counts it, not the fight (phase 8 part 5).
func by_the_run() -> bool:
	return BY_THE_RUN.has(counts)


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
		Counts.EXTRA_HITS, Counts.CRITS, Counts.OVERKILL, Counts.HITS:
			if kind != LogEntry.Kind.DAMAGE:
				return false
		Counts.ROOTED_MS, Counts.STATUS_MS:
			return kind == LogEntry.Kind.STATUS_APPLIED
		Counts.GUARDED:
			return kind == LogEntry.Kind.GUARD
		Counts.SHARED:
			return kind == LogEntry.Kind.SHARED
		Counts.PULLED:
			if kind != LogEntry.Kind.PUSH:
				return false
		Counts.EXTENDED_MS:
			if kind != LogEntry.Kind.STATUS_EXTENDED:
				return false
		Counts.MANA_GIVEN:
			if kind != LogEntry.Kind.MANA_GIVEN:
				return false
		Counts.MAX_HP_GAINED:
			# Max HP its own passive or ability added (phase 8 part 5, Engorge).
			if kind != LogEntry.Kind.MAX_HP_UP:
				return false
		Counts.HP_SPENT:
			# HP its signature cost (phase 8 part 5, Hemomancer).
			if kind != LogEntry.Kind.HP_SPENT:
				return false
		Counts.LIFESTEAL:
			# HP its lifesteal healed (phase 8 part 5, Old Thirst): LIFESTEAL
			# lines, and lifesteal that heals (Blood Communion's HEAL lines
			# marked lifesteal; Deeds checks the mark).
			if kind != LogEntry.Kind.LIFESTEAL and kind != LogEntry.Kind.HEAL:
				return false
		Counts.APPLIED:
			if kind != LogEntry.Kind.STATUS_APPLIED:
				return false
		Counts.BONUS_DAMAGE:
			if kind != LogEntry.Kind.DAMAGE:
				return false
		Counts.SHARDS:
			if kind != LogEntry.Kind.SHARDS:
				return false
		Counts.SUMMONED:
			# Each summon the unit (or its companion) brings onto the field,
			# a companion returning too (phase 8 part 6, Pack Lore).
			if kind != LogEntry.Kind.SUMMON:
				return false
		Counts.TAKEN, Counts.MS_BELOW, Counts.KILLS, Counts.CASTS, Counts.MS_STANDING, Counts.BLOCKED, Counts.MANA_OVERFLOW, Counts.ALLY_CASTS, \
				Counts.TITHE, Counts.TITHE_FLAWLESS, Counts.TRANSMUTED, Counts.LOST_TARGET:
			return false
	return from_ability.is_empty() or from_ability.has(ability_id)
