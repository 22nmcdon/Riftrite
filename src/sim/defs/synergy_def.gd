class_name SynergyDef
extends RefCounted
## A synergy from data/synergies.json (docs/plans/synergies-in-sim.md).
## Five layers, each with its own condition:
##   pair:           "items": two items on the same fielded hero
##   transformation: "item" with "essence" socketed; "item_effects" replace
##                   the item's own effects
##   signature:      "item" on the fielded hero "hero"
##   resonance:      "essence", with "tiers" by essence count (fielded and
##                   backup heroes' items)
##   class_trait:    "class", with "tiers" by fielded heroes of that class
## What a synergy does works like a relic (see RelicDef.read_bonus):
## "auras", "grants", and relic-trigger "effects". Tiered layers put those
## in each tier; only the highest tier reached applies. Item layers may aim
## auras at matched_items or the holder, and their grants reach only the
## matched items.

enum Layer { PAIR, TRANSFORMATION, SIGNATURE, RESONANCE, CLASS_TRAIT }

const LAYER_NAMES: Array[String] = ["pair", "transformation", "signature", "resonance", "class_trait"]
const ITEM_LAYER_AURA_TARGETS: Array[AuraDef.Target] = [
	AuraDef.Target.MATCHED_ITEMS, AuraDef.Target.HOLDER, AuraDef.Target.ALL_ITEMS, AuraDef.Target.ALL_ALLIES,
]
const SIDE_AURA_TARGETS: Array[AuraDef.Target] = [AuraDef.Target.ALL_ITEMS, AuraDef.Target.ALL_ALLIES]


class Tier:
	var count: int
	var bonus: RelicDef


var id: String
var name: String
var layer: Layer
## pair: both items; transformation and signature: the one item.
var items: Array[String] = []
## signature: the hero's id.
var hero: String = ""
## transformation and resonance.
var essence: String = ""
## class_trait.
var unit_class: String = ""
## pair, transformation, signature: what the synergy does.
var bonus: RelicDef = null
## transformation: the item's new effects.
var item_effects: Array[EffectDef] = []
## resonance and class_trait, lowest count first.
var tiers: Array[Tier] = []


static func read(reader: DataReader) -> SynergyDef:
	var def := SynergyDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	var layer_name: String = reader.req_choice("layer", LAYER_NAMES)
	def.layer = maxi(LAYER_NAMES.find(layer_name), 0) as Layer
	if layer_name.is_empty():
		reader.finish()
		return def
	match def.layer:
		Layer.PAIR:
			def.items = reader.req_string_array("items")
			if def.items.size() != 2 or def.items[0] == def.items[1]:
				reader.error("a pair needs two different items")
		Layer.TRANSFORMATION:
			def.items = [reader.req_string("item")]
			def.essence = reader.req_string("essence")
			for effect_reader: DataReader in reader.opt_object_array("item_effects"):
				def.item_effects.append(EffectDef.read(effect_reader))
			if def.item_effects.is_empty():
				reader.error("a transformation needs item_effects (the item's new effects)")
		Layer.SIGNATURE:
			def.hero = reader.req_string("hero")
			def.items = [reader.req_string("item")]
		Layer.RESONANCE:
			def.essence = reader.req_string("essence")
		Layer.CLASS_TRAIT:
			def.unit_class = reader.req_choice("class", HeroDef.CLASSES)
	if def.is_tiered():
		_read_tiers(def, reader)
	else:
		def.bonus = _bonus(def, def.name)
		RelicDef.read_bonus(reader, def.bonus, ITEM_LAYER_AURA_TARGETS, "a synergy", def.layer != Layer.TRANSFORMATION)
	reader.finish()
	return def


static func _read_tiers(def: SynergyDef, reader: DataReader) -> void:
	for tier_reader: DataReader in reader.opt_object_array("tiers"):
		var tier := Tier.new()
		tier.count = tier_reader.req_int("count", 1)
		if not def.tiers.is_empty() and tier.count <= def.tiers[-1].count:
			tier_reader.error("tier counts must go up (%d after %d)" % [tier.count, def.tiers[-1].count])
		tier.bonus = _bonus(def, "%s (%d)" % [def.name, tier.count])
		RelicDef.read_bonus(tier_reader, tier.bonus, SIDE_AURA_TARGETS, "a synergy tier")
		tier_reader.finish()
		def.tiers.append(tier)
	if def.tiers.is_empty():
		reader.error("a %s needs tiers" % LAYER_NAMES[def.layer])


## A synergy's bonus is a RelicDef, so it runs through the relic code.
static func _bonus(def: SynergyDef, bonus_name: String) -> RelicDef:
	var bonus := RelicDef.new()
	bonus.id = def.id
	bonus.name = bonus_name
	return bonus


func is_tiered() -> bool:
	return layer == Layer.RESONANCE or layer == Layer.CLASS_TRAIT


## The highest tier reached with `count`, or null.
func tier_for(count: int) -> Tier:
	var reached: Tier = null
	for tier: Tier in tiers:
		if count >= tier.count:
			reached = tier
	return reached


## Every bonus, for checks that look at all of them.
func all_bonuses() -> Array[RelicDef]:
	var result: Array[RelicDef] = []
	if bonus != null:
		result.append(bonus)
	for tier: Tier in tiers:
		result.append(tier.bonus)
	return result
