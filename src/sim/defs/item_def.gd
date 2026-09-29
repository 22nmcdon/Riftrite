class_name ItemDef
extends RefCounted
## A thing for a hero's loadout slots (data/items.json;
## docs/plans/rebuild-phase5-run.md, section 6; part 6, sections 2 and 8):
##   {"id": "frost_tipped", "kind": "charm", "name": "Frost-Tipped",
##    "text": "...", "answers": "Answers chargers (Cairn Guardian)",
##    "needs": ["ranged"], "price": 3, "mod": {...KitMod...}}
##   {"id": "plant_feet_item", "kind": "tactic", ..., "tactic": "plant_feet"}
## Kinds: charm (a small change to the kit), tactic (how the hero behaves: a
## TacticDef from tactics.json), sigil (how the signature fires), and graft
## (something new to do; only the Magpie sells them). Any hero can hold any
## item; one that does nothing on a hero shows "no effect on this hero"
## (works_on). "needs" tags what it needs: mana, heals, hops, ranged, melee.
## "answers" is the hand-written line on the fight it's for. Items are
## written against slots, so they survive a transformation.

enum Kind { CHARM, TACTIC, SIGIL, GRAFT }

const KIND_NAMES: Array[String] = ["charm", "tactic", "sigil", "graft"]
const NEEDS: Array[String] = ["mana", "heals", "hops", "ranged", "melee"]

var id: String
var kind: Kind
var name: String
var text: String
var answers: String
var needs: Array[String] = []
var price: int
## Charms, sigils, and grafts.
var mod: KitMod = null
## Tactics: the tactic's id (RunContent checks it and sets `tactic`).
var tactic_id: String = ""
var tactic: TacticDef = null


static func read(reader: DataReader) -> ItemDef:
	var def := ItemDef.new()
	def.id = reader.req_string("id")
	def.kind = maxi(KIND_NAMES.find(reader.req_choice("kind", KIND_NAMES)), 0) as Kind
	def.name = reader.req_string("name")
	def.text = reader.req_string("text")
	def.answers = reader.req_string("answers")
	def.needs = reader.opt_choice_array("needs", NEEDS)
	def.price = reader.req_int("price", 0)
	if def.kind == Kind.TACTIC:
		def.tactic_id = reader.req_string("tactic")
	else:
		var mod_reader: DataReader = reader.req_object("mod")
		if mod_reader != null:
			def.mod = KitMod.read(mod_reader)
	reader.finish()
	return def


## True if it does something on a hero `hero_id` with `kit`: its needs are
## met and (for a mod) it changes the kit, or (for a tactic) the hero can
## take it.
func works_on(kit: UnitDef, hero_id: String) -> bool:
	for need: String in needs:
		if not ItemDef.has_need(kit, need):
			return false
	if mod != null:
		return mod.affects(kit)
	if tactic != null:
		if not tactic.allows(hero_id):
			return false
		return tactic.kind != TacticDef.Kind.SIGNATURE_THRESHOLD or Tactics.can_wait(kit.signature)
	return true


## Whether `kit` has what a need names.
static func has_need(kit: UnitDef, need: String) -> bool:
	match need:
		"mana":
			return kit.mana != null
		"heals":
			return (kit.signature != null and kit.signature.heals()) or kit.basic_attack.heals() \
				or kit.passives.any(func(part: PartDef) -> bool: return part.ability != null and part.ability.heals())
		"hops":
			return kit.hop_cooldown_ticks > 0
		"ranged":
			return kit.stats.get_stat(UnitStats.Stat.RANGE) >= 2
		"melee":
			return kit.stats.get_stat(UnitStats.Stat.RANGE) == 1
	return false
