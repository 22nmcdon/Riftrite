class_name ItemDef
extends RefCounted
## A thing for a hero's loadout slots (data/items.json; the loadout pool,
## docs/plans/loadout/ and docs/plans/rebuild-phase5c-combos.md, section 14):
##   {"id": "ember_tipped", "kind": "charm", "name": "Ember-Tipped",
##    "icon": "ember_heart", "text": "...", "ranks": [{...KitMod...}, {...}, {...}]}
##   {"id": "plant_feet_orders", "kind": "tactic", ..., "tactic": "plant_feet"}
## Kinds: charm (a small change to the kit), tactic (how the hero behaves: a
## TacticDef from tactics.json), sigil (how the signature fires), and gambit
## (a placement or fight-start rule; one per hero). Every item has three
## ranks: a charm's, sigil's, or gambit's "ranks" are three whole kit mods
## (rank II's payoff bigger, rank III's with a twist); a tactic's ranks are
## its TacticDef's. What ranks one up, and what each kind costs, is the
## act's (ActDef.item_ranks, item_prices). Any hero can hold any item, and
## one that does nothing on its hero shows nothing (loadout rule 2). Items
## are written against slots, so they survive a transformation. "icon" names
## the glyph drawn in its kind's frame (art/ui/items/glyphs/; phase 5b): the
## UI's, never read by the sim.

enum Kind { CHARM, TACTIC, SIGIL, GAMBIT }

const KIND_NAMES: Array[String] = ["charm", "tactic", "sigil", "gambit"]
const RANKS: int = 3
const RANK_NAMES: Array[String] = ["I", "II", "III"]

var id: String
var kind: Kind
var name: String
## The glyph in its icon (RunContent checks it exists).
var icon: String
var text: String
## Charms, sigils, and gambits: each rank's mod (rank I first).
var ranks: Array[KitMod] = []
## Tactics: the tactic's id (RunContent checks it and sets `tactic`).
var tactic_id: String = ""
var tactic: TacticDef = null


static func read(reader: DataReader) -> ItemDef:
	var def := ItemDef.new()
	def.id = reader.req_string("id")
	def.kind = maxi(KIND_NAMES.find(reader.req_choice("kind", KIND_NAMES)), 0) as Kind
	def.name = reader.req_string("name")
	def.icon = reader.req_string("icon")
	def.text = reader.req_string("text")
	if def.kind == Kind.TACTIC:
		def.tactic_id = reader.req_string("tactic")
	else:
		for rank_reader: DataReader in reader.opt_object_array("ranks"):
			def.ranks.append(KitMod.read(rank_reader))
		if def.ranks.size() != RANKS:
			reader.error("ranks: an item has three ranks")
	reader.finish()
	return def


## Its mod at `rank` (1 to 3), or null (a tactic).
func mod_at(rank: int) -> KitMod:
	if ranks.is_empty():
		return null
	return ranks[clampi(rank, 1, ranks.size()) - 1]
