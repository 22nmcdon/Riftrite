class_name UnitState
extends RefCounted
## One unit in a fight: where it stands on the plane, its health, its target,
## the route it's walking, and its abilities
## (docs/plans/rebuild-phase1-arena-sim.md, sections 1 to 5).

## Where it is in the fight's order (heroes, then enemies, then summons).
var index: int
var id: String
var def: UnitDef
var side: EffectSource.Team
## The hex it started on; "back-liner" means it started in its side's back
## two rows (decided).
var start_col: int
var start_row: int
var stats: UnitStats
var max_hp: int
var hp: int
var shield: int = 0
## False once it has fallen (deaths are settled at the end of a tick).
var alive: bool = true
var pos: Vector2i
var radius: int
var attack: AbilityState
## How fast its basic attack's cooldown runs (10000 = normal).
var attack_rate_bp: int = FixedMath.BP_ONE

# Targeting. Units point at each other only weakly (the fight holds every
# unit), so two units targeting each other don't keep each other alive.
var target: UnitState:
	get:
		return _target.get_ref() as UnitState if _target != null else null
	set(value):
		_target = weakref(value) if value != null else null
var _target: WeakRef = null
## When a unit with no target looks again.
var look_again_at: int = 0

# Walking (Movement).
## The corners still to walk to, in order.
var route: Array[Vector2i] = []
## The target the route leads to, and when to plan it again.
var route_for: UnitState:
	get:
		return _route_for.get_ref() as UnitState if _route_for != null else null
	set(value):
		_route_for = weakref(value) if value != null else null
var _route_for: WeakRef = null
var replan_at: int = 0
## The first tick it had no way to its target (-1: it has one).
var no_path_since: int = -1
## The leg last written to the log (a MOVE): while it's active, each tick's
## step toward `leg_to` by `leg_amount` needs no new entry.
var leg_active: bool = false
var leg_to: Vector2i
var leg_amount: int = 0

# For the log.
var last_hit_by: String = ""
## The unit that last hit it (an enemy), for on_kill.
var last_attacker: String = ""


static func from_setup(setup: UnitSetup, fight_index: int, grid: HexGrid, unit_radius: int) -> UnitState:
	var unit := UnitState.new()
	unit.index = fight_index
	unit.id = setup.id
	unit.def = setup.def
	unit.side = setup.side
	unit.start_col = setup.col
	unit.start_row = setup.row
	unit.stats = setup.def.stats.copy()
	unit.max_hp = unit.stats.get_stat(UnitStats.Stat.HP)
	unit.hp = unit.max_hp
	unit.pos = grid.center(setup.col, setup.row)
	unit.radius = unit_radius
	unit.attack = AbilityState.make(setup.def.basic_attack)
	return unit


## +1 for a hero (toward larger y, the enemy's side), -1 for an enemy.
func forward() -> int:
	return 1 if side == EffectSource.Team.HEROES else -1


## Plane units a tick at its speed.
func step_length() -> int:
	@warning_ignore("integer_division")
	return stats.get_stat(UnitStats.Stat.SPEED) * HexGrid.HEX / FixedMath.TICKS_PER_SECOND


## Its basic attack's reach in plane units.
func reach() -> int:
	return stats.get_stat(UnitStats.Stat.RANGE) * HexGrid.HEX


func in_reach_of(other: UnitState) -> bool:
	var dx: int = other.pos.x - pos.x
	var dy: int = other.pos.y - pos.y
	var reach_units: int = stats.values[UnitStats.Stat.RANGE] * HexGrid.HEX
	return dx * dx + dy * dy <= reach_units * reach_units


func defense() -> int:
	return stats.get_stat(UnitStats.Stat.DEF)


func circle() -> ArenaPlane.Circle:
	return ArenaPlane.Circle.make(pos, radius, id)
