class_name RelicDef
extends RefCounted
## A relic (data/relics.json; docs/plans/rebuild-phase5-run.md, section 8;
## part 4, section 7): team-wide, kept for the run, and every one has a
## cost. "boon" and "cost" are the player's lines; "flavor" is its line of
## flavor. What it does:
##   "mod": {...KitMod...}        every hero's kit (after the loadout)
##   "enemy_mod": {...KitMod...}  every enemy's kit
##   "rest_mod": {...KitMod...}   every hero's kit for the fight after a Rest
##   "slots_add": 1               loadout slots for each hero
##   "wound_bp_add": 500          what each wound takes, on top of tuning's
##   "always_scout": true         every fight is Scouted
##   "price_add": 1               the Pedlar's prices
##   "pay_add": 2                 shards for each won fight
##   "pick_cards": 2              at most this many cards on a pick
##   "grows": {...GrowthDef...}   every hero's kit, growing with what the
##                                team does (phase 5c step 4)
## The run rules are RunFlow's; the mods are applied at setup, so a fight is
## still a pure function of its setup.

var id: String
var name: String
var flavor: String
## The glyph in its icon (art/ui/items/glyphs/; phase 5b): the UI's, never
## read by the sim.
var icon: String
var boon: String
var cost: String
var mod: KitMod = null
var enemy_mod: KitMod = null
var rest_mod: KitMod = null
var slots_add: int = 0
var wound_bp_add: int = 0
var always_scout: bool = false
var price_add: int = 0
var pay_add: int = 0
## 0: no limit.
var pick_cards: int = 0
var grows: GrowthDef = null


static func read(reader: DataReader) -> RelicDef:
	var def := RelicDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.icon = reader.req_string("icon")
	def.flavor = reader.req_string("flavor")
	def.boon = reader.req_string("boon")
	def.cost = reader.req_string("cost")
	def.mod = _opt_mod(reader, "mod")
	def.enemy_mod = _opt_mod(reader, "enemy_mod")
	def.rest_mod = _opt_mod(reader, "rest_mod")
	def.slots_add = reader.opt_int("slots_add", 0, 0, 2)
	def.wound_bp_add = reader.opt_int("wound_bp_add", 0, -1000, 2000)
	def.always_scout = reader.opt_bool("always_scout", false)
	def.price_add = reader.opt_int("price_add", 0, -3, 5)
	def.pay_add = reader.opt_int("pay_add", 0, -5, 10)
	def.pick_cards = reader.opt_int("pick_cards", 0, 0, 3)
	if reader.has("grows"):
		var grows_reader: DataReader = reader.req_object("grows")
		if grows_reader != null:
			def.grows = GrowthDef.read(grows_reader)
	if def.grows == null and def.mod == null and def.enemy_mod == null and def.rest_mod == null and def.slots_add == 0 and def.wound_bp_add == 0 \
			and not def.always_scout and def.price_add == 0 and def.pay_add == 0 and def.pick_cards == 0:
		reader.error("a relic needs to do something")
	reader.finish()
	return def


static func _opt_mod(reader: DataReader, key: String) -> KitMod:
	if not reader.has(key):
		return null
	var mod_reader: DataReader = reader.req_object(key)
	return KitMod.read(mod_reader) if mod_reader != null else null
