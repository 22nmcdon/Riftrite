class_name UnitState
extends RefCounted
## One unit in a fight: where it stands on the plane, its health, its target,
## the route it's walking, and its abilities
## (docs/plans/rebuild-phase1-arena-sim.md, sections 1 to 5).

## Where it is in the fight's order (heroes, then enemies, then summons).
var index: int
var id: String
## What the log credits for what the unit does itself (moving, picking a
## target), made once.
var own_source: EffectSource
var def: UnitDef
var side: EffectSource.Team
## The hex it started on; "back-liner" means it started in its side's back
## two rows (decided).
var start_col: int
var start_row: int
## Its kit's stats; `stats` is these with its auras folded in (Passives).
var base_stats: UnitStats
var stats: UnitStats
## What auras do to it, indexed by AuraDef.Stat: multipliers (10000 = x1)
## for the output and unit stats, additions for crit chance and cooldown.
var aura_bp: Array[int] = []
var max_hp: int
var hp: int
var shield: int = 0
## False once it has fallen (deaths are settled at the end of a tick).
var alive: bool = true
var pos: Vector2i
var radius: int
var attack: AbilityState
## Its signature (null if it has none).
var signature: AbilityState = null
## Mana in hundredths (see Mana); only a unit with a mana bar has any. Its
## full bar and its regen a tick, in hundredths (0 without a bar).
var mana: int = 0
var mana_cap: int = 0
var mana_regen: int = 0
## Its basic attack's reach, squared (plane units).
var reach_sq: int = 0
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

# Passives (see Passives).
## Its ability passives' event effects, each with its own count.
var listeners: Array[Passives.Listener] = []
## Statuses it applies as the key land as the value (lookup only).
var status_swaps: Dictionary[String, String] = {}

## A leap's landing: it can't act before this tick.
var landing_until: int = 0
## The flying trait (read every tick, so kept here).
var flying: bool = false
## A flier in the air: others move as if it weren't there. It's in the air
## while it moves, and lands on a free spot to attack (Movement.settle).
var airborne: bool = false
## Where a flier over someone is heading to land (valid while has_spot).
var settle_spot: Vector2i
var has_settle_spot: bool = false
## hop_away: the first tick it can hop again.
var hop_ready_at: int = 0
## The engagers it's next to (Engage).
var engagements: Array[Engage.Engagement] = []

# Statuses, in ContentDb.status_ids order (see Statuses).
var statuses: Array[StatusState] = []
## Ticks of this unit's recent heals, for the heal-cleanse falloff.
var recent_heal_ticks: Array[int] = []

# For the log.
## What last hurt it: a hit's source, or a damage-over-time status (then
## last_hit_status is its name).
var last_hit_source: EffectSource = null
var last_hit_status: String = ""
## The unit that last hit it (an enemy), for on_kill.
var last_attacker: String = ""


static func from_setup(setup: UnitSetup, fight_index: int, grid: HexGrid, unit_radius: int) -> UnitState:
	var unit := UnitState.new()
	unit.index = fight_index
	unit.id = setup.id
	unit.def = setup.def
	unit.own_source = EffectSource.make(setup.id, "", "")
	unit.side = setup.side
	unit.start_col = setup.col
	unit.start_row = setup.row
	unit.base_stats = setup.def.stats
	unit.stats = setup.def.stats.copy()
	unit.aura_bp = Passives.no_auras()
	unit.max_hp = unit.stats.get_stat(UnitStats.Stat.HP)
	unit.hp = unit.max_hp
	unit.pos = grid.center(setup.col, setup.row)
	unit.radius = unit_radius
	unit.attack = AbilityState.make(setup.def.basic_attack, setup.id)
	if setup.def.signature != null:
		unit.signature = AbilityState.make(setup.def.signature, setup.id)
	if setup.def.mana != null:
		unit.mana = setup.def.mana.start * Mana.SCALE
		unit.mana_cap = setup.def.mana.max * Mana.SCALE
		@warning_ignore("integer_division")
		unit.mana_regen = setup.def.mana.regen_per_s * Mana.SCALE / FixedMath.TICKS_PER_SECOND
	unit.refresh_reach()
	unit.flying = setup.def.has_trait("flying")
	Passives.set_up(unit)
	return unit


## +1 for a hero (toward larger y, the enemy's side), -1 for an enemy.
func forward() -> int:
	return 1 if side == EffectSource.Team.HEROES else -1


## What last hurt it, for the log ("maren · Marking Shot", "Burn from
## brannoc · Brand").
func last_hit_text() -> String:
	if last_hit_source == null:
		return ""
	if last_hit_status.is_empty():
		return last_hit_source.describe()
	return "%s from %s" % [last_hit_status, last_hit_source.describe()]


## Plane units a tick at its speed, less any Slow.
func step_length() -> int:
	@warning_ignore("integer_division")
	var full: int = stats.get_stat(UnitStats.Stat.SPEED) * HexGrid.HEX / FixedMath.TICKS_PER_SECOND
	return FixedMath.apply_bp(full, FixedMath.BP_ONE - Statuses.slow_bp(self))


## Its basic attack's reach in plane units.
func reach() -> int:
	return stats.get_stat(UnitStats.Stat.RANGE) * HexGrid.HEX


func in_reach_of(other: UnitState) -> bool:
	var dx: int = other.pos.x - pos.x
	var dy: int = other.pos.y - pos.y
	return dx * dx + dy * dy <= reach_sq


## Works out reach_sq again (its stats changed).
func refresh_reach() -> void:
	var reach_units: int = stats.values[UnitStats.Stat.RANGE] * HexGrid.HEX
	reach_sq = reach_units * reach_units


## Its DEF, less what damage over time has shredded (never below 0).
func defense() -> int:
	return maxi(stats.get_stat(UnitStats.Stat.DEF) - Statuses.defense_shred(self), 0)


func circle() -> ArenaPlane.Circle:
	return ArenaPlane.Circle.make(pos, radius, id)
