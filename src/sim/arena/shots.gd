class_name Shots
extends RefCounted
## Shots in flight (docs/plans/rebuild-phase1-arena-sim.md, section 5,
## decided): an attack from 2 or more hexes away flies for 1 tick per hex
## (rounded up, at least 1; faster with its shooter's shot_speed_bp, phase
## 8 part 4) and follows its target, so it can't miss. Its
## numbers (damage and crit) are set when it's fired, and it still lands if
## the shooter falls first. If the target falls before it lands, it fizzles.
## A wall standing between where it was fired and its target (phase 4,
## Walls) stops it as it would land: it fizzles too, noting the wall.
## Shots land at the start of a tick, in the order they were fired.


## One shot on its way.
class Shot:
	var source: EffectSource
	var shooter: UnitState
	## Where it was fired from (a wall between here and the target stops it).
	var from_pos: Vector2i
	var ability: AbilityDef
	var target: UnitState
	var land_tick: int
	## The effects it carries (those aimed at the target), with their numbers
	## as fired.
	var effects: Array[EffectDef] = []
	var amounts: Array[int] = []
	## Each effect's power bonus (EffectRunner.power_of), applied as it lands.
	var powers: Array[int] = []
	var crits: Array[bool] = []


## How many ticks a shot takes over `distance` plane units.
static func flight_ticks(distance: int) -> int:
	@warning_ignore("integer_division")
	return maxi((distance + HexGrid.HEX - 1) / HexGrid.HEX, 1)


## Sends a shot on its way and logs it.
static func fire(sim: CombatSim, shot: Shot) -> void:
	var distance: int = ArenaPlane.distance(shot.shooter.pos, shot.target.pos)
	var speed_bp: int = shot.shooter.aura_bp[AuraDef.Stat.SHOT_SPEED_BP]
	if speed_bp != 0:
		# Faster shots (phase 8 part 4, Windcaller): the distance as it flies.
		@warning_ignore("integer_division")
		distance = distance * FixedMath.BP_ONE / maxi(FixedMath.BP_ONE + speed_bp, 1)
	shot.land_tick = sim.tick + flight_ticks(distance)
	shot.from_pos = shot.shooter.pos
	sim.shots.append(shot)
	sim.next_shot_tick = mini(sim.next_shot_tick, shot.land_tick)
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.SHOT, shot.source)
	entry.target = shot.target.id
	entry.from_pos = shot.shooter.pos
	entry.to_pos = shot.target.pos
	entry.end_tick = shot.land_tick
	sim.combat_log.add(entry)


## Lands every shot that's due this tick, in the order they were fired.
static func land_due(sim: CombatSim) -> void:
	if sim.tick < sim.next_shot_tick:
		return
	var waiting: Array[Shot] = []
	var next: int = CombatSim.NEVER
	for shot: Shot in sim.shots:
		if shot.land_tick > sim.tick:
			waiting.append(shot)
			next = mini(next, shot.land_tick)
			continue
		if not shot.target.alive:
			var entry: LogEntry = sim.new_entry(LogEntry.Kind.SHOT_FIZZLED, shot.source)
			entry.target = shot.target.id
			entry.note = "%s fell" % shot.target.id
			sim.combat_log.add(entry)
			continue
		if not sim.walls.is_empty():
			var wall: Walls.Wall = Walls.blocking(sim, shot.shooter.side, shot.from_pos, shot.target.pos)
			if wall != null:
				var stopped: LogEntry = sim.new_entry(LogEntry.Kind.SHOT_FIZZLED, shot.source)
				stopped.target = shot.target.id
				stopped.note = "stopped by %s" % wall.source.describe()
				stopped.wall_of = wall.source.unit_id
				sim.combat_log.add(stopped)
				if wall.max_hp > 0:
					Walls.take_shot(sim, wall, shot)
				if wall.reflect_bp > 0 and shot.shooter.alive:
					# Reflecting Wall (phase 5c step 7d): its damage goes back
					# at the shooter at the wall's share, as the wall's hit.
					for i: int in shot.effects.size():
						if shot.effects[i].type == EffectDef.Type.DAMAGE:
							EffectRunner.deal_hit(sim, wall.source, shot.shooter, FixedMath.apply_bp(shot.amounts[i], wall.reflect_bp), false, shot.powers[i], false, "reflected")
				continue
		for i: int in shot.effects.size():
			EffectRunner.land(sim, shot.shooter, shot.ability, shot.source, shot.effects[i], shot.target, shot.amounts[i], shot.crits[i], EffectRunner.NO_POINT, shot.powers[i])
	sim.shots = waiting
	sim.next_shot_tick = next
