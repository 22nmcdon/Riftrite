class_name AbilityDef
extends RefCounted
## One of a unit's abilities (docs/plans/rebuild-phase1-arena-sim.md, sections
## 2 and 5): its basic attack, or its signature.
##   basic attack: {"id": "bite", "name": "Bite", "cooldown_ms": 1200,
##                  "effects": [{"type": "damage", "amount": 4, "target": "target", "scaling": {"atk": 6000}}]}
##   signature:    {"id": "mend", "name": "Mend", "trigger": {"kind": "mana"},
##                  "targeting": "nearest", "max_range": 3, "cast_ms": 500,
##                  "effects": [...]}
## Its on_fire effects run when it fires; every hit a damage effect lands then
## runs its on_hit effects (and on_crit ones on a crit). An ability used from
## 2 or more hexes away fires a shot that flies to its target, unless it says
## "shot": false (a beam, say).
##
## A signature has no cooldown: it fires on its trigger (TriggerDef). It picks
## a fresh target each time it fires, by its own rule (Targeting.RULES; its
## nearest is by straight line, since it fires from where the unit stands),
## among units within max_range hexes (default: the unit's own reach, half a
## hex for a melee unit).
## An optional "text" is the player's sentence for it (docs/plans/rebuild-phase3-fight-sandbox.md,
## section 7); the sim never reads it.
## cast_ms (mana signatures only): the unit stands
## still that long before it lands; a Stun cancels the cast, and the
## signature keeps its mana.

## What an ability's effects can be set off by.
const TRIGGERS: Array[EffectDef.Trigger] = [EffectDef.Trigger.ON_FIRE, EffectDef.Trigger.ON_HIT, EffectDef.Trigger.ON_CRIT]


var id: String
var name: String
## What it does, for the player (optional; the UI shows it).
var text: String = ""
var cooldown_ticks: int
var effects: Array[EffectDef] = []
## Added to the unit's own crit chance (from CRIT).
var crit_chance_bp: int = 0
## -1: decided by reach (a shot from 2 hexes up); 0: never a shot; 1: always.
var shot: int = -1
## Some effect runs on_hit or on_crit (worked out as it's read).
var has_hit_effects: bool = false
## Signatures only (null on a basic attack).
var trigger: TriggerDef = null
var targeting: String = "nearest"
## In hexes; 0: the unit's own range.
var max_range: int = 0
var cast_ticks: int = 0
## Signatures, from a sigil (KitMod; phase 5): extra triggers it also fires
## on, free of mana (TriggerDef.ALSO_KINDS).
var also: Array[TriggerDef] = []
## Signatures, from a sigil (KitMod's echo): after each fire it fires this
## weaker copy echo_ticks later, at a fresh target (null: no echo).
var echo: AbilityDef = null
var echo_ticks: int = 0
## A signature's: the enemies it picks among first, when any is in reach
## (phase 5c step 7b: an upgrade's mod, Brand the Marked; null: its rule
## alone).
var prefer: UnitCondition = null


static func read(reader: DataReader) -> AbilityDef:
	var def := AbilityDef.new()
	def._read_common(reader)
	def.cooldown_ticks = reader.req_ticks("cooldown_ms", FixedMath.MS_PER_TICK)
	if def.moves_self():
		reader.error("leap and charge are for signatures, not basic attacks")
	reader.finish()
	return def


static func read_signature(reader: DataReader) -> AbilityDef:
	var def := AbilityDef.new()
	def._read_common(reader)
	var trigger_reader: DataReader = reader.req_object("trigger")
	def.trigger = TriggerDef.read(trigger_reader) if trigger_reader != null else TriggerDef.new()
	def.targeting = reader.opt_string_choice("targeting", "nearest", Targeting.RULES)
	def.max_range = reader.opt_int("max_range", 0, 1)
	def.cast_ticks = reader.opt_ticks("cast_ms", 0)
	if def.cast_ticks > 0 and def.trigger.kind != TriggerDef.Kind.MANA:
		reader.error("cast_ms: only a mana signature can have a cast")
	reader.finish()
	return def


func _read_common(reader: DataReader) -> void:
	id = reader.req_string("id")
	name = reader.req_string("name")
	text = reader.opt_string("text", "")
	crit_chance_bp = reader.opt_int("crit_chance_bp", 0, 0, FixedMath.BP_ONE)
	if reader.has("shot"):
		shot = 1 if reader.opt_bool("shot", true) else 0
	var fires: bool = false
	for effect_reader: DataReader in reader.opt_object_array("effects"):
		var effect: EffectDef = EffectDef.read(effect_reader)
		if not TRIGGERS.has(effect.trigger):
			effect_reader.error("an ability's effects can only use on_fire, on_hit, or on_crit")
		fires = fires or effect.trigger == EffectDef.Trigger.ON_FIRE
		has_hit_effects = has_hit_effects or effect.trigger != EffectDef.Trigger.ON_FIRE
		effects.append(effect)
	if not fires:
		reader.error("an ability needs at least one on_fire effect")


func is_signature() -> bool:
	return trigger != null


## True if any of its effects heals (an area's or zone's own included):
## what Wait to heal needs (phase 4, Decision 4).
func heals() -> bool:
	for effect: EffectDef in effects:
		if effect.type == EffectDef.Type.HEAL:
			return true
		for nested: EffectDef in effect.area_effects:
			if nested.type == EffectDef.Type.HEAL:
				return true
	return false


## True if this ability, used from `reach` hexes, fires a shot. One that
## leaps or charges never does: the unit closes the distance itself.
func is_shot(reach: int) -> bool:
	if moves_self():
		return false
	return shot == 1 or (shot == -1 and reach >= 2)


## It leaps or charges.
func moves_self() -> bool:
	for effect: EffectDef in effects:
		if EffectDef.MOVES_SELF.has(effect.type):
			return true
	return false


## Its leap effect, or null.
## True if it moves its unit to its target (a leap or a charge; phase 5c
## step 6b, Braced's on_charged).
func moves_itself() -> bool:
	return effects.any(func(effect: EffectDef) -> bool: return effect.type == EffectDef.Type.LEAP or effect.type == EffectDef.Type.CHARGE)


func leap_effect() -> EffectDef:
	for effect: EffectDef in effects:
		if effect.type == EffectDef.Type.LEAP:
			return effect
	return null


## How far it reaches, in hexes, for a unit with range `unit_range`.
func reach_for(unit_range: int) -> int:
	return max_range if max_range > 0 else unit_range
