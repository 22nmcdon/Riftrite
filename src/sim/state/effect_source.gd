class_name EffectSource
extends RefCounted
## Who caused an effect: the unit and its ability; or a relic, which has no
## unit. Every log line and status stack carries one, so every number in a
## fight can be traced back (CLAUDE.md rule 4).

## Which side holds a relic (EffectSource.relic_side).
enum Team { HEROES, ENEMIES }

var unit_id: String = ""
var ability_id: String = ""
var ability_name: String = ""
## For a relic's own effects: the side holding it (Team); -1 if the source
## is a unit. ability_id / ability_name are then the relic's.
var relic_side: int = -1
## A duo bond's own effect (credited like a relic, as "bond · Name").
var synergy: bool = false
## A Rift Tear's own effect (phase 5c step 8b: Reinforcements; credited like
## an enemy relic, as "rift · Name").
var rift: bool = false
## What made its numbers bigger, for the log ("+30% from Wait to heal"; a
## tactic's payoff), or "".
var bonus: String = ""


static func make(unit: String, ability: String, ability_label: String) -> EffectSource:
	var source := EffectSource.new()
	source.unit_id = unit
	source.ability_id = ability
	source.ability_name = ability_label
	return source


## A relic's own effect, held by `side`.
static func relic(relic_id: String, relic_name: String, side: Team) -> EffectSource:
	var source := EffectSource.new()
	source.ability_id = relic_id
	source.ability_name = relic_name
	source.relic_side = side
	return source


## A Rift Tear's own effect (phase 5c step 8b), on the enemies' side.
static func rift_effect(modifier_id: String, modifier_name: String) -> EffectSource:
	var source: EffectSource = relic(modifier_id, modifier_name, Team.ENEMIES)
	source.rift = true
	return source


## A copy with `note` as its bonus (Tactics: a payoff on one fire).
func with_bonus(note: String) -> EffectSource:
	var copy: EffectSource = EffectSource.make(unit_id, ability_id, ability_name)
	copy.relic_side = relic_side
	copy.synergy = synergy
	copy.rift = rift
	copy.bonus = note
	return copy


func same_as(other: EffectSource) -> bool:
	return unit_id == other.unit_id and ability_id == other.ability_id \
		and relic_side == other.relic_side and synergy == other.synergy and rift == other.rift


## "brannoc · Hold the Line", "relic · Warding Knot",
## "enemy relic · Gloam Totem", or "bond · Light and Iron".
func describe() -> String:
	var text: String = "%s · %s" % [unit_id, ability_name] if not unit_id.is_empty() else ability_name
	if relic_side >= 0:
		var kind: String = "relic" if relic_side == Team.HEROES else "enemy relic"
		if synergy:
			kind = "bond"
		elif rift:
			kind = "rift"
		text = "%s · %s" % [kind, ability_name]
	return text
