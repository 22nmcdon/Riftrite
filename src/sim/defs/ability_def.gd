class_name AbilityDef
extends RefCounted
## One of a unit's abilities (docs/plans/rebuild-phase1-arena-sim.md, sections
## 2 and 5): for now its basic attack; signatures add a trigger, a targeting
## rule, and a cast time in step 4.
##   {"id": "bite", "name": "Bite", "cooldown_ms": 1200,
##    "effects": [{"type": "damage", "amount": 4, "target": "target", "scaling": {"atk": 6000}}]}
## Its on_fire effects run when it fires; every hit a damage effect lands then
## runs its on_hit effects (and on_crit ones on a crit). An attack from 2 or
## more hexes away fires a shot that flies to its target, unless the ability
## says "shot": false (a beam, say).

## What a basic attack's effects can be set off by.
const TRIGGERS: Array[EffectDef.Trigger] = [EffectDef.Trigger.ON_FIRE, EffectDef.Trigger.ON_HIT, EffectDef.Trigger.ON_CRIT]

var id: String
var name: String
var cooldown_ticks: int
var effects: Array[EffectDef] = []
## Added to the unit's own crit chance (from CRIT).
var crit_chance_bp: int = 0
## -1: decided by reach (a shot from 2 hexes up); 0: never a shot; 1: always.
var shot: int = -1


static func read(reader: DataReader) -> AbilityDef:
	var def := AbilityDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.cooldown_ticks = reader.req_ticks("cooldown_ms", FixedMath.MS_PER_TICK)
	def.crit_chance_bp = reader.opt_int("crit_chance_bp", 0, 0, FixedMath.BP_ONE)
	if reader.has("shot"):
		def.shot = 1 if reader.opt_bool("shot", true) else 0
	var fires: bool = false
	for effect_reader: DataReader in reader.opt_object_array("effects"):
		var effect: EffectDef = EffectDef.read(effect_reader)
		if not TRIGGERS.has(effect.trigger):
			effect_reader.error("an attack's effects can only use on_fire, on_hit, or on_crit")
		fires = fires or effect.trigger == EffectDef.Trigger.ON_FIRE
		def.effects.append(effect)
	if not fires:
		reader.error("an ability needs at least one on_fire effect")
	reader.finish()
	return def


## True if this ability, used from `reach` hexes, fires a shot.
func is_shot(reach: int) -> bool:
	return shot == 1 or (shot == -1 and reach >= 2)
