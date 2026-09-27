class_name SpecializationDef
extends RefCounted
## A hero's rank-B specialization from data/specializations.json
## (docs/plans/specializations-in-sim.md). Each hero has three of their own.
## Its power is locked behind a deed (docs/plans/deeds.md): three levels of
## parts, earned in fights once it's picked (see DeedTrackDef). A later part
## with the same "key" replaces the earlier one; a new key adds.
##
## Part kinds ("kind"):
##   aura:           an AuraDef from the hero (targets below)
##   grant:          a GrantDef on the hero's items, numbered from the hero's
##                   stats (not flat like a relic's)
##   ability:        {"name"?, "cooldown_ms"?, "effects": [...]}: a slotless
##                   effect scaled from the hero's stats, firing on its
##                   cooldown (on_fire) or a relic trigger (on_fight_start,
##                   at_time, on_ally_below_hp)
##   basic_attack:   {"basic_attack": {...}} replaces the hero's own. Needs an
##                   auto_attack part (an aura or grant filtered to
##                   {"auto_attack": true}) at the same or an earlier level,
##                   so a basic-attack item doesn't blank the specialization
##   replace_status: {"from": "burn", "to": "golden_flame"}: the hero's items
##                   apply one status as another, like an alloy special
## A hero's innate and calling (HeroDef) and enemy phases (PhaseDef) are
## made of the same parts.

enum Kind { AURA, GRANT, ABILITY, BASIC_ATTACK, REPLACE_STATUS }

const KIND_NAMES: Array[String] = ["aura", "grant", "ability", "basic_attack", "replace_status"]
const AURA_TARGETS: Array[AuraDef.Target] = [
	AuraDef.Target.HOLDER, AuraDef.Target.HOLDER_ITEMS, AuraDef.Target.ROW_ALLIES,
	AuraDef.Target.ALL_ALLIES, AuraDef.Target.ALL_ITEMS,
]


class Part:
	var key: String
	var kind: Kind
	## "1", "2", or "3": the deed level it unlocks at ("" for innates and
	## phases).
	var rank_label: String
	## "Hearthwall 2", for the log.
	var label: String
	var aura: AuraDef = null
	var grant: GrantDef = null
	## ability or basic_attack: the item it becomes.
	var item: ItemDef = null
	var replace_from: String = ""
	var replace_to: String = ""

	## True for an aura or grant aimed at the auto-attack.
	func covers_auto_attack() -> bool:
		if aura != null:
			return aura.filter != null and aura.filter.auto_attack
		if grant != null:
			return grant.filter != null and grant.filter.auto_attack
		return false


var id: String
var hero: String
var name: String
## The specialization's deed and its three levels of unlocks (see
## DeedTrackDef); they replace "parts by rank".
var track: DeedTrackDef


static func read(reader: DataReader) -> SpecializationDef:
	var def := SpecializationDef.new()
	def.id = reader.req_string("id")
	def.hero = reader.req_string("hero")
	def.name = reader.req_string("name")
	def.track = DeedTrackDef.read(reader, def.name, def.id)
	return def


## Reads one part. `label` credits it in the log ("Hearthwall 2", or an
## enemy phase's name); `id_prefix` makes its ability item's id unique.
## Enemy phases use this too (EnemyDef).
static func read_part(reader: DataReader, label: String, id_prefix: String, rank_label: String = "") -> Part:
	var part := Part.new()
	part.key = reader.req_string("key")
	var kind_name: String = reader.req_choice("kind", KIND_NAMES)
	part.kind = maxi(KIND_NAMES.find(kind_name), 0) as Kind
	part.rank_label = rank_label
	part.label = label
	if kind_name.is_empty():
		reader.finish()
		return part
	match part.kind:
		Kind.AURA:
			part.aura = AuraDef.read(reader)
			part.aura.from_part = true
			if not AURA_TARGETS.has(part.aura.target):
				reader.error("a specialization aura can't target %s" % AuraDef.TARGET_NAMES[part.aura.target])
			return part
		Kind.GRANT:
			part.grant = GrantDef.read(reader, true)
			return part
		Kind.ABILITY:
			part.item = _read_ability(id_prefix, part, reader)
		Kind.BASIC_ATTACK:
			var attack_reader: DataReader = reader.req_object("basic_attack")
			if attack_reader != null:
				part.item = ItemDef.read_basic_attack(attack_reader)
		Kind.REPLACE_STATUS:
			part.replace_from = reader.req_string("from")
			part.replace_to = reader.req_string("to")
	reader.finish()
	return part


## An ability as a slotless item that fires from the hero.
static func _read_ability(id_prefix: String, part: Part, reader: DataReader) -> ItemDef:
	var item := ItemDef.new()
	item.id = "%s_%s" % [id_prefix, part.key]
	# The log names the specialization: "Catch (Hearthwall 2)", or just
	# "Hearthwall 2" for an unnamed ability.
	item.name = "%s (%s)" % [reader.req_string("name"), part.label] if reader.has("name") else part.label
	item.is_ability = true
	var fires: bool = false
	for effect_reader: DataReader in reader.opt_object_array("effects"):
		var effect: EffectDef = EffectDef.read(effect_reader, false, true)
		fires = fires or effect.trigger == EffectDef.Trigger.ON_FIRE
		item.effects.append(effect)
	if item.effects.is_empty():
		reader.error("an ability needs effects")
	if fires:
		item.cooldown_ticks = reader.req_ticks("cooldown_ms", FixedMath.MS_PER_TICK)
	else:
		item.triggered_only = true
		item.cooldown_ticks = 1
		if reader.has("cooldown_ms"):
			reader.error("cooldown_ms only matters for on_fire effects")
			reader.req_ticks("cooldown_ms")
	return item


## Every part on every level, for content checks.
func all_parts() -> Array[Part]:
	return track.all_parts()
