class_name RelicDef
extends RefCounted
## A relic from data/relics.json. The guild holds any number of relics, with
## no board, slots, adjacency, or sockets (docs/design.md, "Relics"). Enemy
## teams can carry relics too. A relic has any of:
##   auras:   continuous boosts to every item (all_items) or hero
##            (all_allies) on its side, usually narrowed by a filter
##   grants:  an extra effect on every matching item (see GrantDef)
##   effects: relic triggers (see EffectDef): on_fire (every cooldown_ms),
##            on_fight_start, at_time, on_ally_below_hp
## Relic numbers are flat: they don't scale from stats.

const AURA_TARGETS: Array[AuraDef.Target] = [AuraDef.Target.ALL_ITEMS, AuraDef.Target.ALL_ALLIES]

var id: String
var name: String
var rarity: String
var enemy_only: bool = false
var auras: Array[AuraDef] = []
var grants: Array[GrantDef] = []
var effects: Array[EffectDef] = []
## For on_fire effects; 0 if the relic has none.
var cooldown_ticks: int = 0


static func read(reader: DataReader) -> RelicDef:
	var def := RelicDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.rarity = reader.req_choice("rarity", ItemDef.RARITIES)
	def.enemy_only = reader.opt_bool("enemy_only", false)
	read_bonus(reader, def, AURA_TARGETS, "a relic")
	reader.finish()
	return def


## Reads "auras", "grants", "effects", and "cooldown_ms" into `def`. Shared
## with synergies, whose bonuses work like relics. `what` names the owner
## in errors ("a relic"); `required`: at least one of the three is needed.
static func read_bonus(reader: DataReader, def: RelicDef, aura_targets: Array[AuraDef.Target], what: String, required: bool = true) -> void:
	for aura_reader: DataReader in reader.opt_object_array("auras"):
		var aura: AuraDef = AuraDef.read(aura_reader)
		if not aura_targets.has(aura.target):
			var names: Array[String] = []
			for target: AuraDef.Target in aura_targets:
				names.append(AuraDef.TARGET_NAMES[target])
			aura_reader.error("%s aura can only target %s" % [what, " or ".join(names)])
		def.auras.append(aura)
	for grant_reader: DataReader in reader.opt_object_array("grants"):
		def.grants.append(GrantDef.read(grant_reader))
	var fires: bool = false
	for effect_reader: DataReader in reader.opt_object_array("effects"):
		var effect: EffectDef = EffectDef.read(effect_reader, true)
		fires = fires or effect.trigger == EffectDef.Trigger.ON_FIRE
		def.effects.append(effect)
	if fires:
		def.cooldown_ticks = reader.req_ticks("cooldown_ms", FixedMath.MS_PER_TICK)
	elif reader.has("cooldown_ms"):
		reader.error("cooldown_ms only matters for on_fire effects")
		reader.req_ticks("cooldown_ms")
	if required and def.auras.is_empty() and def.grants.is_empty() and def.effects.is_empty():
		reader.error("%s needs auras, grants, or effects" % what)
