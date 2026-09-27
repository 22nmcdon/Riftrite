class_name TriggerDef
extends RefCounted
## What fires a signature (docs/plans/rebuild-phase1-arena-sim.md, section 5):
##   {"kind": "mana"}                                the bar is full (the unit needs "mana")
##   {"kind": "hp_below", "threshold_bp": 3000}      once, the first time it's below 30% HP
##   {"kind": "fight_start"}                         once, on its first turn
##   {"kind": "at_time", "at_ms": 8000}              once, at 8s
##   {"kind": "count", "event": "on_hit_taken", "every": 5}
##                                                   on every 5th such event (EffectDef's
##                                                   event triggers, but on_ability)
##   {"kind": "would_fall"}                          once, the first time it would fall: it's
##                                                   left at 1 HP instead
## A stunned unit can't fire a mana signature; every other trigger still fires.

enum Kind { MANA, HP_BELOW, FIGHT_START, AT_TIME, COUNT, WOULD_FALL }

const KIND_NAMES: Array[String] = ["mana", "hp_below", "fight_start", "at_time", "count", "would_fall"]

var kind: Kind
var threshold_bp: int = 0
var at_ticks: int = 0
## count: the event counted, and how many make it fire.
var event: EffectDef.Trigger = EffectDef.Trigger.ON_HIT_TAKEN
var every: int = 1


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
	reader.finish()
	return def


## Triggers that fire once a fight.
func is_once() -> bool:
	return kind == Kind.HP_BELOW or kind == Kind.FIGHT_START or kind == Kind.AT_TIME or kind == Kind.WOULD_FALL
