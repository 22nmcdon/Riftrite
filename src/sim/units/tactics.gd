class_name Tactics
extends RefCounted
## What a hero's tactic does in a fight (docs/plans/rebuild-phase3b-tactics.md,
## section 2; TacticDef is the data). A unit without one never reaches this
## code, so a fight without tactics is exactly what it was.
##   prefer_target        Targeting.update asks preferred() first: the
##                        nearest enemy (by path, as nearest) of the tactic's
##                        archetypes; with none standing or reachable, the
##                        unit picks by its own rule. Targets stay sticky.
##   hold_ground          from the start (logged), the unit doesn't walk. Each
##                        update, check_release() lets it go for good once an
##                        enemy stands within release_range (center to center,
##                        logged, naming the enemy). While it holds, stay()
##                        turns it to the nearest enemy in reach when its
##                        target is out of reach (unless Taunted), and keeps it
##                        from walking. A push, pull, or leap still moves it,
##                        and it still leaves crumbling ground.
##   signature_threshold  hurt_enough() gates its mana signature: the ally
##                        lowest on HP within the signature's reach must be
##                        below below_bp of max HP, or the full bar waits
##                        (logged once a bar). Any signature that heals on
##                        mana can wait (can_wait; phase 4, Decision 4), so
##                        Night Lantern and Sunfall wait like Mend.
##   stop_near            planted(): about to walk, the unit stays (as
##                        hold_ground's stay()) while an enemy stands within
##                        stop_range, center to center; it logs when it plants
##                        its feet (naming the enemy) and when it closes in
##                        again.
##   guard_ally           Targeting asks preferred(): the nearest enemy whose
##                        target is its ally lowest on HP (another than
##                        itself); with none, its own rule
##   kite                 in reach with its attack not ready, it steps back
##                        a hex while its target is nearer than its reach
##                        less a hex (only a unit that reaches farther than
##                        a hex)
##   leash                about to walk, it walks to its ally with the most
##                        DEF while that ally is farther than leash_range,
##                        and waits rather than walk away from it at the edge
##   signature_crowd      crowd_ready() gates its mana signature with an
##                        area: enough enemies in the area, or max_wait over
##   signature_finish     finish_ready() gates its mana signature that deals
##                        damage: its target below below_bp
##   prefer_target        also by "prefers" (a UnitCondition) or "pick"
##                        (lowest_hp_in_reach, most_def, farthest)
## The loadout's payoffs and rank III twists (phase 5c step 6c, section
## 14.6): stat payoffs are an aura on its kit while applies() holds
## (kit_with_payoff); on_hit() puts first_hit on each enemy once and
## stretches Marks on crits; on_kill() gives kill_mana, restarts Dive's
## window, and refunds the bar; tick() regenerates and watches over the
## guarded ally. can_follow() says whether a kit can follow a tactic.
## Every line is a TACTIC entry sourced to the unit and its tactic (rule 4).
## Payoffs (round 2, section 9), only while the behavior applies, each named
## in the log line it changes ("+20% from Casters first"):
##   prefer_target        damage_bonus_bp(): its own basic attack's and
##                        signature's hits on its archetypes deal more
##                        (EffectRunner.deal_hit, before DEF)
##   hold_ground          its attack cooldown runs faster while it holds
##                        (CombatSim)
##   signature_threshold  every fire of its signature has passed
##                        hurt_enough(), so EffectRunner.fire heals more on
##                        each (its heals only, an area's or zone's
##                        included; a shot keeps the number it left with)


## Logs what a unit's tactic did (`note`), about `about` if it names a unit.
static func log_tactic(sim: CombatSim, unit: UnitState, note: String, about: String = "") -> void:
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.TACTIC, EffectSource.make(unit.id, unit.tactic.id, unit.tactic.name))
	entry.target = about
	entry.note = note
	sim.combat_log.add(entry)


## At the fight's start (and as a summon joins, though none has a tactic):
## a unit that holds its ground says so.
static func start(sim: CombatSim, unit: UnitState) -> void:
	if unit.tactic.window_ticks > 0:
		unit.dive_until = sim.tick + unit.tactic.window_ticks
	if unit.holding:
		var payoff: String = " (+%d%% attack speed while it holds)" % (unit.tactic.atsp_bp / 100) if unit.tactic.atsp_bp > 0 else ""
		log_tactic(sim, unit, "holds its ground" + payoff)


## How a payoff reads in the line it changes: "+20% from Casters first".
static func bonus_note(bonus_bp: int, tactic: TacticDef) -> String:
	return "+%d%% from %s" % [bonus_bp / 100, tactic.name]


## The payoff on one hit: the extra damage (basis points) when the
## attacker's own basic attack or signature hits an enemy its tactic prefers
## (or its payoff_vs); 0 otherwise.
static func damage_bonus_bp(sim: CombatSim, source: EffectSource, target: UnitState) -> int:
	var attacker: UnitState = sim.unit_by_id(source.unit_id)
	if attacker == null or attacker.tactic == null or attacker.tactic.damage_vs_bp <= 0:
		return 0
	var tactic: TacticDef = attacker.tactic
	if not (tactic.payoff_vs.holds(target) if tactic.payoff_vs != null else tactic.prefers_unit(target)):
		return 0
	return tactic.damage_vs_bp if _own(attacker, source) else 0


## Marked first's payoff: more crit chance on an enemy it prefers.
static func crit_bonus_bp(attacker: UnitState, target: UnitState) -> int:
	return attacker.tactic.crit_vs_bp if attacker.tactic.crit_vs_bp > 0 and target != null and attacker.tactic.prefers_unit(target) else 0


## Break the line's payoff: the share of its target's DEF its hits ignore.
static func def_ignore_bp(attacker: UnitState, target: UnitState) -> int:
	return attacker.tactic.def_ignore_bp if attacker.tactic.def_ignore_bp > 0 and target == attacker.target else 0


## True if `source` is `attacker`'s own basic attack or signature.
static func own_hit(attacker: UnitState, source: EffectSource) -> bool:
	return _own(attacker, source)


static func _own(attacker: UnitState, source: EffectSource) -> bool:
	return source.ability_id == attacker.attack.def.id or (attacker.signature != null and source.ability_id == attacker.signature.def.id)


## prefer_target and guard_ally: the enemy it goes for first, or null.
static func preferred(sim: CombatSim, unit: UnitState) -> UnitState:
	var tactic: TacticDef = unit.tactic
	var enemies: Array[UnitState] = sim.targetable_enemies_of(unit)
	if tactic.kind == TacticDef.Kind.GUARD_ALLY:
		var weakest: UnitState = weakest_ally(sim, unit)
		if weakest == null:
			return null
		var attackers: Array[UnitState] = enemies.filter(func(enemy: UnitState) -> bool: return enemy.target == weakest)
		return Targeting.nearest_of(sim, unit, attackers, false) if not attackers.is_empty() else null
	match tactic.pick:
		"lowest_hp_in_reach":
			return Targeting.pick(sim, unit, "weakest_in_reach", unit.reach_sq)
		"most_def":
			var best: UnitState = null
			for enemy: UnitState in enemies:
				if best == null or enemy.defense() > best.defense():
					best = enemy
			return best
		"farthest":
			return Targeting.pick(sim, unit, "farthest", -1)
	var candidates: Array[UnitState] = enemies.filter(func(enemy: UnitState) -> bool: return tactic.prefers_unit(enemy))
	if candidates.is_empty():
		return null
	return Targeting.nearest_of(sim, unit, candidates, false)


## The unit's ally lowest on HP (a share of max HP), another than itself,
## or null.
static func weakest_ally(sim: CombatSim, unit: UnitState) -> UnitState:
	var best: UnitState = null
	for ally: UnitState in sim.standing_allies_of(unit):
		if ally != unit and (best == null or ally.hp * best.max_hp < best.hp * ally.max_hp):
			best = ally
	return best


## The unit's ally with the most DEF, another than itself, or null (leash).
static func anchor_of(sim: CombatSim, unit: UnitState) -> UnitState:
	var best: UnitState = null
	for ally: UnitState in sim.standing_allies_of(unit):
		if ally != unit and (best == null or ally.defense() > best.defense()):
			best = ally
	return best


## Whether a kit can follow `tactic`: a held signature needs one that fits
## (a heal for Wait to heal, an area for Wait for a crowd, damage for Save
## it for the kill), and the rest anyone can.
static func can_follow(tactic: TacticDef, kit: UnitDef) -> bool:
	var signature: AbilityDef = kit.signature
	match tactic.kind:
		TacticDef.Kind.SIGNATURE_THRESHOLD:
			return can_wait(signature)
		TacticDef.Kind.SIGNATURE_CROWD:
			return _mana_signature(signature) and _area_size(signature) > 0
		TacticDef.Kind.SIGNATURE_FINISH:
			return _mana_signature(signature) and signature.effects.any(func(effect: EffectDef) -> bool:
				return effect.type == EffectDef.Type.DAMAGE or effect.area_effects.any(func(inner: EffectDef) -> bool: return inner.type == EffectDef.Type.DAMAGE))
	return true


static func _mana_signature(signature: AbilityDef) -> bool:
	return signature != null and signature.trigger != null and signature.trigger.kind == TriggerDef.Kind.MANA


## The radius (hexes) of a signature's first area (0: none).
static func _area_size(signature: AbilityDef) -> int:
	for effect: EffectDef in signature.effects:
		if effect.type == EffectDef.Type.AREA and effect.shape != null:
			return effect.shape.size
	return 0


## The unit's kit with its tactic's stat payoff as an aura while it follows
## its order (an id of its own), or the kit itself.
static func kit_with_payoff(kit: UnitDef, tactic: TacticDef) -> UnitDef:
	if tactic == null or not tactic.has_stat_payoff():
		return kit
	var built: UnitDef = kit.copy()
	built.phases = kit.phases
	var stats: Array = []
	if tactic.def_add != 0:
		stats.append([AuraDef.Stat.DEF, tactic.def_add])
	if tactic.def_bp != 0:
		stats.append([AuraDef.Stat.DEF_BP, FixedMath.BP_ONE + tactic.def_bp])
	if tactic.atk_mgk_bp != 0:
		stats.append([AuraDef.Stat.ATK_BP, FixedMath.BP_ONE + tactic.atk_mgk_bp])
		stats.append([AuraDef.Stat.MGK_BP, FixedMath.BP_ONE + tactic.atk_mgk_bp])
	if tactic.atsp_add != 0:
		stats.append([AuraDef.Stat.ATSP, tactic.atsp_add])
	for i: int in stats.size():
		var aura := AuraDef.new()
		aura.target = AuraDef.Target.HOLDER
		aura.stat = stats[i][0]
		aura.value = stats[i][1]
		aura.while_kind = AuraDef.While.TACTIC
		var part := PartDef.new()
		part.id = "tactic_%s_%d" % [tactic.id, i]
		part.name = tactic.name
		part.text = tactic.text
		part.kind = PartDef.Kind.AURA
		part.aura = aura
		built.passives.append(part)
	return built


## True while the unit follows its order, for its stat payoff's aura.
static func applies(sim: CombatSim, unit: UnitState) -> bool:
	var tactic: TacticDef = unit.tactic
	match tactic.kind:
		TacticDef.Kind.HOLD_GROUND:
			return unit.holding
		TacticDef.Kind.STOP_NEAR:
			return unit.feet_planted
		TacticDef.Kind.GUARD_ALLY:
			var weakest: UnitState = weakest_ally(sim, unit)
			return weakest != null and unit.target != null and unit.target.alive and unit.target.target == weakest
		TacticDef.Kind.KITE:
			return unit.target != null and unit.target.alive and _at_full_range(unit, unit.target)
		TacticDef.Kind.LEASH:
			var anchor: UnitState = anchor_of(sim, unit)
			return anchor != null and ArenaPlane.length_sq(anchor.pos - unit.pos) <= tactic.leash_range * tactic.leash_range
		TacticDef.Kind.PREFER_TARGET:
			return tactic.window_ticks <= 0 or sim.tick < unit.dive_until
	return false


## kite: in reach of `target`, no nearer than its reach less a hex.
static func _at_full_range(unit: UnitState, target: UnitState) -> bool:
	var reach: int = unit.reach()
	var near: int = maxi(reach - HexGrid.HEX, 0)
	var distance_sq: int = ArenaPlane.length_sq(target.pos - unit.pos)
	return distance_sq <= unit.reach_sq and distance_sq >= near * near


## kite, in reach with its attack not ready: steps back a hex's way from
## its target while it's nearer than its reach less a hex. True if it moved.
static func kite(sim: CombatSim, unit: UnitState, target: UnitState) -> bool:
	var near: int = unit.reach() - HexGrid.HEX
	if near <= 0 or ArenaPlane.length_sq(target.pos - unit.pos) >= near * near:
		return false
	var back: Vector2i = ArenaPlane.along(unit.pos, ArenaPlane.direction(target.pos, unit.pos, Vector2i(0, -ArenaPlane.DIR * unit.forward())), HexGrid.HEX)
	if not Movement.step_to(sim, unit, back):
		return false
	if not unit.tactic_backing:
		unit.tactic_backing = true
		log_tactic(sim, unit, "backs away from %s" % target.id, target.id)
	if unit.tactic.crit_after_back:
		unit.sure_crit = true
	return true


## leash, about to walk: true if it walks back to (or waits by) its ally
## with the most DEF instead of walking to its target.
static func leash(sim: CombatSim, unit: UnitState, target: UnitState) -> bool:
	var anchor: UnitState = anchor_of(sim, unit)
	if anchor == null:
		return false
	var range: int = unit.tactic.leash_range
	var away_sq: int = ArenaPlane.length_sq(anchor.pos - unit.pos)
	if away_sq > range * range:
		if not unit.tactic_backing:
			unit.tactic_backing = true
			log_tactic(sim, unit, "goes back to %s" % anchor.id, anchor.id)
		if not Movement.step_to(sim, unit, anchor.pos):
			Movement.wait(sim, unit, "")
		return true
	unit.tactic_backing = false
	# At the edge, it won't walk away from the tank.
	var edge: int = range - HexGrid.HEX / 4
	if away_sq >= edge * edge and ArenaPlane.length_sq(target.pos - anchor.pos) > away_sq:
		Movement.wait(sim, unit, "stays with %s" % anchor.id)
		return true
	return false


## Each tick, for a tactic with a twist that runs over time: Stay with the
## tank's regeneration and Guard the weakest's watch over its ally.
static func tick(sim: CombatSim, unit: UnitState) -> void:
	var tactic: TacticDef = unit.tactic
	if (sim.tick - unit.joined_at) % FixedMath.TICKS_PER_SECOND != 0 or not applies(sim, unit):
		return
	var source: EffectSource = EffectSource.make(unit.id, tactic.id, tactic.name)
	if tactic.regen_bp > 0 and unit.hp < unit.max_hp:
		EffectRunner.heal(sim, unit, FixedMath.apply_bp(unit.max_hp, tactic.regen_bp), source)
	if tactic.ally_def_add > 0 and sim.content.statuses.has("watched_over"):
		var weakest: UnitState = weakest_ally(sim, unit)
		if weakest != null:
			Statuses.apply(sim, weakest, "watched_over", 1, 0, source)


## A hit by `attacker` on `target` landed (EffectRunner.deal_hit): first_hit
## on each enemy it prefers, once; a crit stretching a Mark.
static func on_hit(sim: CombatSim, attacker: UnitState, target: UnitState, crit: bool) -> void:
	var tactic: TacticDef = attacker.tactic
	if not target.alive or target.side == attacker.side:
		return
	var source: EffectSource = EffectSource.make(attacker.id, tactic.id, tactic.name)
	if not tactic.first_hit_status.is_empty() and not attacker.tactic_hit.has(target.id) \
			and (not tactic.pick.is_empty() or tactic.prefers_unit(target)):
		attacker.tactic_hit[target.id] = true
		Statuses.apply(sim, target, tactic.first_hit_status, tactic.first_hit_stacks, tactic.first_hit_ticks, source)
	if crit and tactic.crit_extends_mark_ticks > 0 and Statuses.has_kind(target, StatusDef.Kind.MARKED):
		var mark: StatusState = null
		for state: StatusState in target.statuses:
			if state.def.kind == StatusDef.Kind.MARKED:
				mark = state
				break
		Statuses.extend(sim, target, mark.def.id, tactic.crit_extends_mark_ticks, source)


## `killer` felled an enemy (Events.kill): kill_mana, Dive's window again,
## and the bar back for a kill by its signature.
static func on_kill(sim: CombatSim, killer: UnitState, fallen: UnitState) -> void:
	var tactic: TacticDef = killer.tactic
	if tactic.kill_mana > 0:
		Mana.gain(sim, killer, tactic.kill_mana * Mana.SCALE)
	if tactic.restart_on_kill and tactic.window_ticks > 0 and sim.tick < killer.dive_until:
		killer.dive_until = sim.tick + tactic.window_ticks
		log_tactic(sim, killer, "dives on: %s fell" % fallen.id, fallen.id)
	if tactic.refund_bp > 0 and killer.def.mana != null and killer.signature != null and fallen.last_hit_source != null \
			and fallen.last_hit_source.ability_id == killer.signature.def.id:
		Mana.gain(sim, killer, FixedMath.apply_bp(killer.def.mana.max * Mana.SCALE, tactic.refund_bp))


## signature_crowd: true once enough enemies stand in its area around
## `target` (all still standing, if fewer than crowd), or it has waited
## max_wait; otherwise the bar waits, logged once.
static func crowd_ready(sim: CombatSim, unit: UnitState, target: UnitState) -> bool:
	var size: int = _area_size(unit.signature.def)
	if size <= 0:
		return true
	var needed: int = mini(unit.tactic.crowd, sim.standing_enemies_of(unit).size())
	if in_area(sim, unit, target) >= needed:
		unit.tactic_wait_since = -1
		return true
	if unit.tactic_wait_since < 0:
		unit.tactic_wait_since = sim.tick
		log_tactic(sim, unit, "%s waits for %d enemies in its area" % [unit.signature.def.name, needed])
	if sim.tick - unit.tactic_wait_since >= unit.tactic.max_wait_ticks:
		unit.tactic_wait_since = -1
		return true
	return false


## How many enemies stand within its signature's area around `target`.
static func in_area(sim: CombatSim, unit: UnitState, target: UnitState) -> int:
	var radius: int = _area_size(unit.signature.def) * HexGrid.HEX
	var count: int = 0
	for enemy: UnitState in sim.standing_enemies_of(unit):
		if ArenaPlane.length_sq(enemy.pos - target.pos) <= radius * radius:
			count += 1
	return count


## signature_finish: true once its target is below below_bp of max HP;
## otherwise the bar waits, logged once a bar.
static func finish_ready(sim: CombatSim, unit: UnitState, target: UnitState) -> bool:
	if target.hp * FixedMath.BP_ONE < target.max_hp * unit.tactic.below_bp:
		unit.tactic_waiting = false
		return true
	if not unit.tactic_waiting:
		unit.tactic_waiting = true
		log_tactic(sim, unit, "%s waits: %s isn't below %d%%" % [unit.signature.def.name, target.id, unit.tactic.below_bp / 100], target.id)
	return false


## The held signature's damage payoff (power, bp) as it fires at `target`:
## power_bp, and per_extra_bp for each enemy in its area past the crowd.
static func signature_power_bp(sim: CombatSim, unit: UnitState, target: UnitState) -> int:
	var tactic: TacticDef = unit.tactic
	var power: int = tactic.power_bp
	if tactic.per_extra_bp > 0 and target != null:
		power += tactic.per_extra_bp * maxi(in_area(sim, unit, target) - tactic.crowd, 0)
	return power


## Wait to heal's twist: the heal that waited also takes one harmful status
## (the newest) off `healed`, logged as it ends.
static func cleanse_one(sim: CombatSim, unit: UnitState, healed: UnitState) -> void:
	for i: int in range(healed.statuses.size() - 1, -1, -1):
		var state: StatusState = healed.statuses[i]
		if HARMFUL.has(state.def.kind):
			Statuses.end_now(sim, healed, state, "cleansed by %s" % unit.tactic.name)
			return


## The status kinds Wait to heal's twist takes off.
const HARMFUL: Array[StatusDef.Kind] = [StatusDef.Kind.DAMAGE_OVER_TIME, StatusDef.Kind.ROOT, StatusDef.Kind.STUN, StatusDef.Kind.SLOW,
	StatusDef.Kind.SILENCE, StatusDef.Kind.MARKED, StatusDef.Kind.GROUNDED]


## hold_ground: lets the unit go for good once an enemy is within reach of
## its tactic's release_range.
static func check_release(sim: CombatSim, unit: UnitState) -> void:
	var release: int = unit.tactic.release_range
	for enemy: UnitState in sim.standing_enemies_of(unit):
		if ArenaPlane.length_sq(enemy.pos - unit.pos) <= release * release:
			unit.holding = false
			log_tactic(sim, unit, "moves out: %s came within %d hexes" % [enemy.id, release / HexGrid.HEX], enemy.id)
			return


## hold_ground, when the unit's target is out of reach: it turns to the
## nearest enemy in reach, if any (not while Taunted). CombatSim then keeps
## it from walking (a holder never starts a walk, so it has none to stop).
static func stay(sim: CombatSim, unit: UnitState) -> void:
	if unit.statuses.is_empty() or Statuses.taunter(sim, unit) == null:
		var near: UnitState = Targeting.pick(sim, unit, "nearest", unit.reach_sq)
		if near != null and near != unit.target:
			Targeting.set_target(sim, unit, near, unit.tactic.name)


## stop_near, about to walk: true if an enemy stands within stop_range, so
## the unit stays (and turns to the nearest in reach). Logs each change.
static func planted(sim: CombatSim, unit: UnitState) -> bool:
	var stop: int = unit.tactic.stop_range
	var near: UnitState = null
	for enemy: UnitState in sim.standing_enemies_of(unit):
		if ArenaPlane.length_sq(enemy.pos - unit.pos) <= stop * stop:
			near = enemy
			break
	if near != null and not unit.feet_planted:
		log_tactic(sim, unit, "plants its feet: %s is within %d hexes" % [near.id, stop / HexGrid.HEX], near.id)
	elif near == null and unit.feet_planted:
		log_tactic(sim, unit, "closes in again: no enemy within %d hexes" % (stop / HexGrid.HEX))
	unit.feet_planted = near != null
	if near != null:
		stay(sim, unit)
	return near != null


## signature_threshold: true if the ally lowest on HP within its signature's
## reach is hurt enough to heal now; otherwise the bar waits, logged once
## per bar.
static func hurt_enough(sim: CombatSim, unit: UnitState) -> bool:
	var reach: int = unit.reach_of(unit.signature.def)
	var ally: UnitState = Targeting.pick(sim, unit, "lowest_hp_ally", reach * reach)
	if ally != null and ally.hp * FixedMath.BP_ONE < ally.max_hp * unit.tactic.below_bp:
		unit.tactic_waiting = false
		return true
	if not unit.tactic_waiting:
		unit.tactic_waiting = true
		log_tactic(sim, unit, "%s waits: no ally within %d hexes below %d%%" % [unit.signature.def.name,
			unit.reach_of(unit.signature.def) / HexGrid.HEX, unit.tactic.below_bp / 100])
	return false


## True if a signature_threshold tactic can hold this signature: it fires on
## mana and heals (phase 4, Decision 4).
static func can_wait(signature: AbilityDef) -> bool:
	return signature != null and signature.trigger != null and signature.trigger.kind == TriggerDef.Kind.MANA and signature.heals()
