class_name RelicDef
extends RefCounted
## A relic (data/relics.json; docs/plans/relics/README.md; phase 5c step 5a,
## docs/plans/rebuild-phase5c-combos.md, section 10): team-wide, kept for the
## run, with no downsides. "text" is the player's line; "flavor" its line of
## flavor; "tier" one of common, rare, epic, legendary, boss. What it does:
##   "mod": {...KitMod...}        every hero's kit (after the loadout)
##   "enemy_mod": {...KitMod...}  every enemy's kit
##   "grows": {...GrowthDef...}   every hero's kit, growing with what the
##                                team does (phase 5c step 4); a growth that
##                                pays shards ("each_shards") pays them instead
##   "at_start": [...EffectDefs...]   run by the sim as each fight starts,
##                                sourced to the relic (phase 5c step 5b): no
##                                trigger; apply_status, shield, heal, or
##                                damage, at all_allies, all_enemies, or
##                                nearest_enemies (with a "count")
##   "salt_circle": true          the first enemy area each fight lands on
##                                nothing
##   "rules": {...SideRules...}   rules of the fight the heroes' side plays by
##                                (phase 5c step 5c)
##   "mod_for": "ranged"          its mod is only for heroes of range 2 or
##                                more (their path's kit; Snaring Shot)
## Run rules (RunFlow and RunContent read them):
##   "slots_add": 1               loadout slots for each hero
##   "always_scout": true         every fight is Scouted
##   "price_add": -1              the Pedlar's prices (never below 1)
##   "pay_add": 3                 shards for each won fight
##   "elite_pay_add": 6           shards for each won elite
##   "wound_price_add": -2        treating a wound
##   "shop_shards": 2             shards as a shop opens
##   "miser": true                as a shop opens, 1 shard per 5 held (up to 6)
##   "free_reroll": true          a shop's first reroll is free
##   "flat_rerolls": true         a shop's rerolls never climb
##   "shop_relics_add": 1         relics a shop shows
##   "wares_add": 1               wares the Pedlar lays out
##   "pick_cards_add": 1          cards on each pick
##   "take_picks_add": 1          cards taken from each pick
##   "streak": {"wins": 3, "shards": 25}   once, for that many won fights in a
##                                row with no hero falling
##   "growth_bp": 20000           growing cards count this much of what's
##                                counted, while it's held
## Worked out from the run at setup (RunContent.relic_mods):
##   "per_relic_bp": 200          the basic stats, +this for each relic held
##   "per_shards": {"per": 5, "bp": 100}   ATK and MGK, +bp for every `per`
##                                shards held
##   "covenant": true             each hero takes the team's highest basic
##                                stats (RunFlow.fight_setup)
##   "doubles_commons": true      every common relic held counts twice: its
##                                mod times(2) where a step could scale it,
##                                its at_start effects' numbers doubled, its
##                                run rules' numbers doubled (Reliquary)
## The run rules are RunFlow's; the mods are applied at setup, so a fight is
## still a pure function of its setup.

enum Tier { COMMON, RARE, EPIC, LEGENDARY, BOSS }

const TIER_NAMES: Array[String] = ["common", "rare", "epic", "legendary", "boss"]
const TIER_LABELS: Array[String] = ["Common", "Rare", "Epic", "Legendary", "Boss"]
## What a relic's at_start effects may do, and at whom.
const START_TYPES: Array[EffectDef.Type] = [EffectDef.Type.APPLY_STATUS, EffectDef.Type.SHIELD, EffectDef.Type.HEAL, EffectDef.Type.DAMAGE]
const START_TARGETS: Array[EffectDef.Target] = [EffectDef.Target.ALL_ALLIES, EffectDef.Target.ALL_ENEMIES, EffectDef.Target.NEAREST_ENEMIES]

var id: String
var name: String
var flavor: String
## The glyph in its icon (art/ui/items/glyphs/; phase 5b): the UI's, never
## read by the sim.
var icon: String
var text: String
var tier: Tier = Tier.COMMON
var mod: KitMod = null
var enemy_mod: KitMod = null
var grows: GrowthDef = null
var slots_add: int = 0
var always_scout: bool = false
var price_add: int = 0
var pay_add: int = 0
var elite_pay_add: int = 0
var wound_price_add: int = 0
var shop_shards: int = 0
var miser: bool = false
var free_reroll: bool = false
var flat_rerolls: bool = false
var shop_relics_add: int = 0
var wares_add: int = 0
var pick_cards_add: int = 0
var take_picks_add: int = 0
## 0: none.
var streak_wins: int = 0
var streak_shards: int = 0
## 0: growth counts as it is.
var growth_bp: int = 0
var per_relic_bp: int = 0
var per_shards: int = 0
var per_shards_bp: int = 0
var covenant: bool = false
var at_start: Array[EffectDef] = []
var salt_circle: bool = false
var doubles_commons: bool = false
var rules: SideRules = null
## Its mod only for ranged heroes (phase 5c step 5c).
var mod_for_ranged: bool = false


static func read(reader: DataReader) -> RelicDef:
	var def := RelicDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.icon = reader.req_string("icon")
	def.flavor = reader.req_string("flavor")
	def.text = reader.req_string("text")
	def.tier = maxi(TIER_NAMES.find(reader.req_choice("tier", TIER_NAMES)), 0) as Tier
	def.mod = _opt_mod(reader, "mod")
	def.enemy_mod = _opt_mod(reader, "enemy_mod")
	if reader.has("grows"):
		var grows_reader: DataReader = reader.req_object("grows")
		if grows_reader != null:
			def.grows = GrowthDef.read(grows_reader)
	def.slots_add = reader.opt_int("slots_add", 0, 0, 2)
	def.always_scout = reader.opt_bool("always_scout", false)
	def.price_add = reader.opt_int("price_add", 0, -3, 5)
	def.pay_add = reader.opt_int("pay_add", 0, 0, 20)
	def.elite_pay_add = reader.opt_int("elite_pay_add", 0, 0, 30)
	def.wound_price_add = reader.opt_int("wound_price_add", 0, -10, 0)
	def.shop_shards = reader.opt_int("shop_shards", 0, 0, 20)
	def.miser = reader.opt_bool("miser", false)
	def.free_reroll = reader.opt_bool("free_reroll", false)
	def.flat_rerolls = reader.opt_bool("flat_rerolls", false)
	def.shop_relics_add = reader.opt_int("shop_relics_add", 0, 0, 2)
	def.wares_add = reader.opt_int("wares_add", 0, 0, 4)
	def.pick_cards_add = reader.opt_int("pick_cards_add", 0, 0, 3)
	def.take_picks_add = reader.opt_int("take_picks_add", 0, 0, 2)
	if reader.has("streak"):
		var streak: DataReader = reader.req_object("streak")
		if streak != null:
			def.streak_wins = streak.req_int("wins", 1)
			def.streak_shards = streak.req_int("shards", 1)
			streak.finish()
	def.growth_bp = reader.opt_int("growth_bp", 0, FixedMath.BP_ONE + 1, 10 * FixedMath.BP_ONE)
	def.per_relic_bp = reader.opt_int("per_relic_bp", 0, 1, FixedMath.BP_ONE)
	if reader.has("per_shards"):
		var shards: DataReader = reader.req_object("per_shards")
		if shards != null:
			def.per_shards = shards.req_int("per", 1)
			def.per_shards_bp = shards.req_int("bp", 1, FixedMath.BP_ONE)
			shards.finish()
	def.covenant = reader.opt_bool("covenant", false)
	for effect_reader: DataReader in reader.opt_object_array("at_start"):
		if effect_reader.has("trigger"):
			effect_reader.error("a relic's at_start effects run as the fight starts, so they take no trigger")
		var effect: EffectDef = EffectDef.read(effect_reader, true)
		if not START_TYPES.has(effect.type) or not START_TARGETS.has(effect.target):
			effect_reader.error("at_start: apply_status, shield, heal, or damage, at all_allies, all_enemies, or nearest_enemies")
		def.at_start.append(effect)
	def.salt_circle = reader.opt_bool("salt_circle", false)
	def.doubles_commons = reader.opt_bool("doubles_commons", false)
	if reader.has("rules"):
		var rules_reader: DataReader = reader.req_object("rules")
		if rules_reader != null:
			def.rules = SideRules.read(rules_reader)
			if not def.rules.any():
				reader.error("rules: name at least one")
	if reader.has("mod_for"):
		def.mod_for_ranged = reader.req_choice("mod_for", ["ranged"]) == "ranged"
		if def.mod == null:
			reader.error("mod_for says who its mod is for, so it needs a mod")
	if not def.does_something():
		reader.error("a relic needs to do something")
	reader.finish()
	return def


func does_something() -> bool:
	return grows != null or mod != null or enemy_mod != null or slots_add != 0 or always_scout or price_add != 0 or pay_add != 0 \
		or elite_pay_add != 0 or wound_price_add != 0 or shop_shards != 0 or miser or free_reroll or flat_rerolls or shop_relics_add != 0 \
		or wares_add != 0 or pick_cards_add != 0 or take_picks_add != 0 or streak_wins > 0 or growth_bp > 0 or per_relic_bp > 0 \
		or per_shards > 0 or covenant or not at_start.is_empty() or salt_circle or doubles_commons or rules != null


## Whether its mod is for a hero whose path's kit is `kit` (null: any).
func mod_fits(kit: UnitDef) -> bool:
	return not mod_for_ranged or kit == null or kit.stats.get_stat(UnitStats.Stat.RANGE) >= 2


static func _opt_mod(reader: DataReader, key: String) -> KitMod:
	if not reader.has(key):
		return null
	var mod_reader: DataReader = reader.req_object(key)
	return KitMod.read(mod_reader) if mod_reader != null else null
