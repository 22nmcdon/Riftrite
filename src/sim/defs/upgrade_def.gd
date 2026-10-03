class_name UpgradeDef
extends RefCounted
## One upgrade from the after-fight pick (data/upgrades.json;
## docs/plans/upgrade-pools.md, built in phase 5c step 7): permanent, and a
## kit modifier written against the hero's slots, so it survives a
## transformation. Three layers (docs/plans/rebuild-phase5c-combos.md,
## section 15.3):
##   {"id": "deep_mark", "name": "Deep Mark", "hero": "maren",
##    "text": "...", "mod": {...KitMod...}}                 her pool, always
##   {"id": "steady_hands", "name": "Steady Hands", "path": "deadeye",
##    "taste": true, "text": "...", "mod": {...}, "transformed_mod": {...}}
##                     offered while vowed to the path, until it transforms
##   {"id": "quick_plant", "name": "Quick Plant", "path": "deadeye", ...}
##                     offered once transformed on the path
##   {"id": "keen_talons", "name": "Keen Talons", "apex": "eagle_eye", ...}
##                     offered once its apex is earned (phase 8 part 2)
## A taste card carries on after the transformation with its
## "transformed_mod" (Decision 35), since the taste's piece and the
## transformation's are different parts. A taste or path card only counts
## while its hero is on that path. A stacking card (section 15.4) has no
## mod but "stacks": {"stat": "atk", "pct": 10}: each take locks in that
## share of the hero's stat at the time, as a flat amount (RunContent
## .stack_amount), and it can be taken again. A growing upgrade (phase 5c
## step 4) has "grows" (GrowthDef), with or without a "mod". RunContent
## checks every mod against every kit it can meet.

enum Layer { HERO, TASTE, PATH, APEX }

const LAYER_NAMES: Array[String] = ["hero", "taste", "path", "apex"]
## The stats a stacking card can lock in.
const STACK_STATS: Array[UnitStats.Stat] = [UnitStats.Stat.HP, UnitStats.Stat.ATK, UnitStats.Stat.MGK, UnitStats.Stat.DEF,
	UnitStats.Stat.CRIT, UnitStats.Stat.ATSP]

var id: String
var name: String
## The player's sentence.
var text: String
var layer: Layer
## The hero it's for (a path's upgrade: the path's hero, set by RunContent).
var hero: String = ""
## A taste or path card: the path's id (an apex card: its apex's path, set
## by RunContent).
var path: String = ""
## An apex card: its apex's id (phase 8 part 2).
var apex: String = ""
## Null for a stacking card.
var mod: KitMod
## A taste card's mod once transformed (null: `mod`).
var transformed_mod: KitMod = null
## Null: it doesn't grow.
var grows: GrowthDef = null
## A stacking card: the stat it locks in (-1: not one) and its share
## (percent) of the hero's stat at the time.
var stack_stat: int = -1
var stack_pct: int = 0


static func read(reader: DataReader) -> UpgradeDef:
	var def := UpgradeDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.text = reader.req_string("text")
	if int(reader.has("hero")) + int(reader.has("path")) + int(reader.has("apex")) != 1:
		reader.error("an upgrade is for a hero, a path, or an apex: give one of hero, path, and apex")
	if reader.has("hero"):
		def.layer = Layer.HERO
		def.hero = reader.req_string("hero")
	elif reader.has("apex"):
		def.layer = Layer.APEX
		def.apex = reader.req_string("apex")
	else:
		def.path = reader.opt_string("path", "")
		def.layer = Layer.TASTE if reader.opt_bool("taste", false) else Layer.PATH
	if reader.has("taste") and def.layer == Layer.HERO:
		reader.error("only a path's card can be a taste card")
	if reader.has("stacks"):
		var stacks: DataReader = reader.req_object("stacks")
		if stacks != null:
			var names: Array[String] = []
			for stat: UnitStats.Stat in STACK_STATS:
				names.append(UnitStats.STAT_NAMES[stat])
			var stat_name: String = stacks.req_choice("stat", names)
			def.stack_stat = UnitStats.STAT_NAMES.find(stat_name)
			def.stack_pct = stacks.req_int("pct", 1, 100)
			stacks.finish()
		if def.layer != Layer.HERO or reader.has("mod") or reader.has("grows"):
			reader.error("a stacking card is a hero's, with no mod and no growth")
	if reader.has("grows"):
		var grows_reader: DataReader = reader.req_object("grows")
		if grows_reader != null:
			def.grows = GrowthDef.read(grows_reader)
	if (def.grows == null and def.stack_stat < 0) or reader.has("mod"):
		var mod_reader: DataReader = reader.req_object("mod")
		if mod_reader != null:
			def.mod = KitMod.read(mod_reader)
	if reader.has("transformed_mod"):
		if def.layer != Layer.TASTE:
			reader.error("only a taste card has a transformed_mod")
		var transformed_reader: DataReader = reader.req_object("transformed_mod")
		if transformed_reader != null:
			def.transformed_mod = KitMod.read(transformed_reader)
	reader.finish()
	return def


## The mod a hero on `stage_transformed` takes from this upgrade.
func mod_for(stage_transformed: bool) -> KitMod:
	if stage_transformed and transformed_mod != null:
		return transformed_mod
	return mod


## True for a stacking card (taken again and again, each take locked in).
func stacks() -> bool:
	return stack_stat >= 0


## The mod that locks in `amount` of its stat.
func locked_mod(amount: int) -> KitMod:
	var locked: KitMod = KitMod.make()
	locked.stats_add[stack_stat] = amount
	return locked
