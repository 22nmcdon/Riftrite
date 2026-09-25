class_name Conversions
extends RefCounted
## The essence conversion rule (docs/plans/essence-rework.md).
##
## Output kinds come in two families. Direct: damage, shield, heal. Over time:
## damage-over-time statuses (burn, poison, bleed). Whenever an item's own
## effect produces output, each socketed essence that "adds" a kind adds that
## kind, sized from the output:
##   same kind:                 folded in at fight start as a x1.5 multiplier
##                              on the item's matching effects (see ItemState)
##   same family, other kind:   convert_same_family_bp of the output
##   direct -> over time:       convert_direct_to_over_time_bp
##   over time -> direct:       convert_over_time_to_direct_bp
## Fractions carry over between outputs, so 5% of a 30-damage hit (1.5) adds
## 1, then the next one adds 2, and nothing is lost to rounding.
##
## Where added output goes:
##   damage / over time: the enemy the output landed on; if the output didn't
##       land on an enemy (a heal or shield item), the enemy directly across
##       from the holder (placeholder until per-item designs exist).
##   shield, heal: the item's holder.
## Added output never triggers on_hit effects or further conversions.


## One essence's running conversion on one item.
class Conversion:
	var essence_id: String
	## Label for the log, e.g. "Ember, Attuned" or "Ember spill from Sword".
	var essence_name: String
	var adds: String
	var crit_only: bool
	## Scales the conversion rate (infusion level, or spill share).
	var strength_bp: int = FixedMath.BP_ONE
	## Leftover fraction, in basis points of one unit.
	var carry_bp: int = 0


static func make(app: EssenceApplication) -> Conversion:
	var conversion := Conversion.new()
	conversion.essence_id = app.essence.id
	conversion.essence_name = app.label
	conversion.adds = app.essence.adds
	conversion.crit_only = app.essence.adds_on_crit_only
	conversion.strength_bp = app.strength_bp
	return conversion


## The output kind an effect produces, or "" (for example, Slow or Blind).
static func output_kind(effect: EffectDef, content: ContentDb) -> String:
	match effect.type:
		EffectDef.Type.DAMAGE:
			return "damage"
		EffectDef.Type.SHIELD:
			return "shield"
		EffectDef.Type.HEAL:
			return "heal"
		EffectDef.Type.APPLY_STATUS:
			if content.is_output_kind(effect.status_id):
				return effect.status_id
	return ""


static func is_direct(kind: String) -> bool:
	return EssenceDef.DIRECT_KINDS.has(kind)


static func rate_bp(from_kind: String, to_kind: String, tuning: TuningDef) -> int:
	if from_kind == to_kind:
		return tuning.convert_same_kind_bp
	if is_direct(from_kind) == is_direct(to_kind):
		return tuning.convert_same_family_bp
	if is_direct(from_kind):
		return tuning.convert_direct_to_over_time_bp
	return tuning.convert_over_time_to_direct_bp


## Called after an item's own effect produces `amount` of `kind` on `target`.
static func on_output(sim: CombatSim, item: ItemState, kind: String, amount: int, target: UnitState, crit: bool) -> void:
	if amount <= 0:
		return
	for conversion: Conversion in item.conversions:
		if conversion.adds == kind or (conversion.crit_only and not crit):
			continue
		conversion.carry_bp += amount * FixedMath.apply_bp(rate_bp(kind, conversion.adds, sim.tuning), conversion.strength_bp)
		@warning_ignore("integer_division")
		var added: int = conversion.carry_bp / FixedMath.BP_ONE
		conversion.carry_bp -= added * FixedMath.BP_ONE
		if added > 0:
			_deliver(sim, item, conversion, added, target)


static func _deliver(sim: CombatSim, item: ItemState, conversion: Conversion, amount: int, output_target: UnitState) -> void:
	var holder: UnitState = sim.owner_of(item)
	var source := EffectSource.make(holder.id, item.def.id, item.def.name, conversion.essence_id, conversion.essence_name)
	match conversion.adds:
		"shield":
			EffectRunner.give_shield(sim, holder, amount, source)
		"heal":
			EffectRunner.heal(sim, holder, amount, source, item)
		_:
			var enemy: UnitState = output_target
			if enemy == null or enemy.side == holder.side or not enemy.is_standing():
				var across: Array[UnitState] = Targeting.pick(EffectDef.Target.ENEMY_FRONT, holder, null, sim)
				enemy = across[0] if not across.is_empty() else null
			if enemy == null:
				return
			if conversion.adds == "damage":
				EffectRunner.deal_hit(sim, source, enemy, amount, false)
			else:
				Statuses.apply(sim, enemy, item.replaced_status(conversion.adds), amount, source)
