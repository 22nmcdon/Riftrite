class_name TriggerDef
extends RefCounted
## What fires a signature (docs/plans/rebuild-phase1-arena-sim.md, section 5):
##   {"kind": "mana"}                                the bar is full (the unit needs "mana")
##   {"kind": "hp_below", "threshold_bp": 3000}      once, the first time it's below 30% HP
##   {"kind": "fight_start"}                         once, on the first tick
##   {"kind": "at_time", "at_ms": 8000}              once, at 8s
##   {"kind": "count", "event": "on_hit_taken", "every": 5}
##                                                   on every 5th such event (EffectDef's
##                                                   event triggers, but on_ability)
##   {"kind": "would_fall"}                          once, the first time it would fall: it's
##                                                   left at 1 HP instead
##   {"kind": "ally_falls"}                          each time an ally falls (phase 5's
##                                                   sigils)
##   {"kind": "ally_fires", "ability": "pounce"}     once, when an ally's ability of
##                                                   that id fires: at that fire's
##                                                   target, wherever it is (phase 5,
##                                                   the Hound Alpha's Hunt)
## A signature may also fire on extra triggers (AbilityDef.also, from a
## sigil's KitMod): hp_below or ally_falls, free of mana.
## A stunned unit can't fire a mana signature; every other trigger still fires.

enum Kind { MANA, HP_BELOW, FIGHT_START, AT_TIME, COUNT, WOULD_FALL, ALLY_FALLS, ALLY_FIRES }

const KIND_NAMES: Array[String] = ["mana", "hp_below", "fight_start", "at_time", "count", "would_fall", "ally_falls", "ally_fires"]
## The kinds an extra trigger (AbilityDef.also) can be.
const ALSO_KINDS: Array[Kind] = [Kind.HP_BELOW, Kind.ALLY_FALLS]

var kind: Kind
var threshold_bp: int = 0
var at_ticks: int = 0
## count: the event counted, and how many make it fire.
var event: EffectDef.Trigger = EffectDef.Trigger.ON_HIT_TAKEN
var every: int = 1
## ally_fires: the ally's ability id.
var ability: String = ""


static func read(reader: DataReader) -> TriggerDef:
	var def := TriggerDef.new()
	var kind_name: String = reader.req_choice("kind", KIND_NAMES)
	def.kind = maxi(KIND_NAMES.find(kind_name), 0) as Kind
	if kind_name.is_empty():
		reader.finish()
		return def
	match def.kind:
		Kind.HP_BELOW:
			def.threshold_bp = reader.req_int("threshold_bp", 1, FixedMath.BP_ONE - 1)
		Kind.AT_TIME:
			def.at_ticks = reader.req_ticks("at_ms", FixedMath.MS_PER_TICK)
		Kind.COUNT:
			var event_name: String = reader.req_choice("event", EffectDef.event_trigger_names())
			if not event_name.is_empty():
				def.event = EffectDef.TRIGGER_NAMES.find(event_name) as EffectDef.Trigger
			if def.event == EffectDef.Trigger.ON_ABILITY:
				reader.error("event: a signature can't count on_ability (the unit's only other ability is its basic attack: count on_basic_attack)")
			def.every = reader.opt_int("every", 1, 1)
		Kind.ALLY_FIRES:
			def.ability = reader.req_string("ability")
	reader.finish()
	return def


## What the log says fired it (a FIRE entry's note, for extra triggers).
func reason() -> String:
	match kind:
		Kind.HP_BELOW:
			return "below %d%% HP" % (threshold_bp / 100)
		Kind.ALLY_FALLS:
			return "an ally fell"
	return ""


## Triggers that fire once a fight.
func is_once() -> bool:
	return kind == Kind.HP_BELOW or kind == Kind.FIGHT_START or kind == Kind.AT_TIME or kind == Kind.WOULD_FALL or kind == Kind.ALLY_FIRES
