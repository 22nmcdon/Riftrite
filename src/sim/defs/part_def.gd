class_name PartDef
extends RefCounted
## A passive: always on, part of a unit's kit (docs/plans/rebuild-phase1-arena-sim.md,
## section 2). Every passive has an id and a name, which the log credits.
##   {"id": "war_cry", "name": "War Cry", "kind": "aura",
##    "aura": {"target": "all_allies", "stat": "atk_bp", "value": 12000, "window": {"until_ms": 5000}}}
##       an AuraDef: while the unit stands (and its window is open), it
##       boosts the unit or all its allies
##   {"id": "spite", "name": "Spite", "kind": "ability",
##    "effects": [{"trigger": "on_hit_taken", "every": 3, "type": "damage", "amount": 5, "target": "hit_target"}]}
##       effects on event triggers (EffectDef), which run when the unit does
##       something (Events). They land at once, never as a shot.
##   {"id": "embers", "name": "Embers", "kind": "replace_status", "from": "burn", "to": "poison"}
##       statuses the unit applies as `from` land as `to`
## Adding a kind is a code change; say so when you make one.

enum Kind { AURA, ABILITY, REPLACE_STATUS }

const KIND_NAMES: Array[String] = ["aura", "ability", "replace_status"]

var id: String
var name: String
var kind: Kind
var aura: AuraDef = null
## ability: its effects, as an ability with no cooldown and no shot.
var ability: AbilityDef = null
var from_status: String = ""
var to_status: String = ""


static func read(reader: DataReader) -> PartDef:
	var def := PartDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	var kind_name: String = reader.req_choice("kind", KIND_NAMES)
	def.kind = maxi(KIND_NAMES.find(kind_name), 0) as Kind
	if kind_name.is_empty():
		reader.finish()
		return def
	match def.kind:
		Kind.AURA:
			var aura_reader: DataReader = reader.req_object("aura")
			def.aura = AuraDef.read(aura_reader) if aura_reader != null else null
		Kind.ABILITY:
			def.ability = AbilityDef.new()
			def.ability.id = def.id
			def.ability.name = def.name
			def.ability.shot = 0
			var effect_readers: Array[DataReader] = reader.opt_object_array("effects")
			if effect_readers.is_empty():
				reader.error("an ability passive needs effects")
			for effect_reader: DataReader in effect_readers:
				var effect: EffectDef = EffectDef.read(effect_reader)
				if EffectDef.MOVES_SELF.has(effect.type):
					effect_reader.error("a passive can't leap or charge")
				elif not EffectDef.EVENT_TRIGGERS.has(effect.trigger):
					effect_reader.error("a passive's effects need an event trigger (%s)" % ", ".join(EffectDef.event_trigger_names()))
				def.ability.effects.append(effect)
		Kind.REPLACE_STATUS:
			def.from_status = reader.req_string("from")
			def.to_status = reader.req_string("to")
	reader.finish()
	return def
