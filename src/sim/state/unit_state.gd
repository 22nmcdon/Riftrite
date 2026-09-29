class_name UnitState
extends RefCounted
## One unit in a fight: where it stands on the plane, its health, its target,
## the route it's walking, and its abilities
## (docs/plans/rebuild-phase1-arena-sim.md, sections 1 to 5).

## Where it is in the fight's order (heroes, then enemies, then summons).
## moved_at for a unit that hasn't moved yet.
const NEVER_MOVED: int = -1000000

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
## It started in its side's back two rows (fixed for the fight).
var back_liner: bool = false
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
## How far it reaches if it's melee (tuning's melee_reach; set as it joins).
var melee_reach: int = HexGrid.HEX
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
## Its last `nearest` search found no one (the next one checks cheaply first
## whether the enemies are closed off; see NavGrid.find_nearest).
var nearest_failed: bool = false

# Walking (Movement).
## The corners still to walk to, in order.
var route: Array[Vector2i] = []
## The target the route leads to (null: it leads back to safe ground, see
## Movement.escape), and when to plan it again.
var route_for: UnitState:
	get:
		return _route_for.get_ref() as UnitState if _route_for != null else null
	set(value):
		_route_for = weakref(value) if value != null else null
var _route_for: WeakRef = null
var replan_at: int = 0
## Its kit's phases (UnitDef.phases; `def` becomes each one's kit in turn),
## and how many it has entered (Phases).
var phases: Array[PhaseDef] = []
var phase: int = 0
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
## The tick it joined the fight (0, or when it was summoned): on_interval
## counts from here.
var joined_at: int = 0
## The last tick it moved (walked, flew, hopped, leapt, or was pushed):
## phase 4's planted auras and plant delay read it. A unit that hasn't moved
## since it was placed has stood still since before the fight
## (NEVER_MOVED), so it starts planted.
var moved_at: int = NEVER_MOVED
## The fires_moving trait (phase 4), read every tick it walks.
var fires_moving: bool = false
## Range its planted auras add once it stands still (phase 4, Steady), and
## the reach it stops walking at to plant (squared; 0: no such aura).
var planted_bonus: int = 0
var plant_reach_sq: int = 0
## Its conditional auras' state (Passives.condition_key), as last folded in.
var condition_key: int = 0

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
## A hero's tactic (Tactics), or null. hold_ground: whether it still holds.
## signature_threshold: whether its full bar's wait has been logged.
var tactic: TacticDef = null
var holding: bool = false
var tactic_waiting: bool = false
## Its Guard passive (phase 4; null: none).
var guard: PartDef = null
## The deeds it counts (Deeds; null: none).
var deeds: Deeds.Counter = null


static func from_setup(setup: UnitSetup, fight_index: int, grid: HexGrid, unit_radius: int) -> UnitState:
	var unit := UnitState.new()
	unit.index = fight_index
	unit.id = setup.id
	unit.def = setup.def
	unit.phases = setup.def.phases
	unit.own_source = EffectSource.make(setup.id, "", "")
	unit.side = setup.side
	unit.start_col = setup.col
	unit.start_row = setup.row
	unit.back_liner = grid != null and grid.is_back_row(setup.row)
	unit.base_stats = setup.def.stats
	unit.stats = setup.def.stats.copy()
	unit.aura_bp = Passives.no_auras()
	unit.max_hp = unit.stats.get_stat(UnitStats.Stat.HP)
	unit.hp = unit.max_hp
	if grid != null:
		unit.pos = grid.center(setup.col, setup.row)
	unit.radius = unit_radius
	unit.attack = AbilityState.make(setup.def.basic_attack, setup.id)
	if setup.def.signature != null:
		unit.signature = AbilityState.make(setup.def.signature, setup.id)
	Mana.set_bar(unit, setup.def.mana)
	unit.refresh_reach()
	unit.flying = setup.def.has_trait("flying")
	unit.fires_moving = setup.def.has_trait("fires_moving")
	for part: PartDef in setup.def.passives:
		if part.kind == PartDef.Kind.AURA and part.aura.stat == AuraDef.Stat.RANGE and part.aura.while_kind == AuraDef.While.PLANTED:
			unit.planted_bonus += part.aura.value
	unit.tactic = setup.tactic
	unit.holding = setup.tactic != null and setup.tactic.kind == TacticDef.Kind.HOLD_GROUND
	unit.deeds = Deeds.make_counter(setup.deed_paths)
	for part: PartDef in setup.def.passives:
		if part.kind == PartDef.Kind.GUARD and unit.guard == null:
			unit.guard = part
	Passives.set_up(unit)
	return unit


## A summoned unit of `kit` (Summons): placed by its summoner, with no
## starting hex, and never a back-liner.
static func make_summon(kit: UnitDef, unit_side: EffectSource.Team, unit_id: String, fight_index: int, unit_radius: int) -> UnitState:
	var setup: UnitSetup = UnitSetup.make(kit, unit_side, -1, -1, unit_id)
	var unit: UnitState = from_setup(setup, fight_index, null, unit_radius)
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
## How far its attacks reach on the plane: melee_reach for range 1 (melee),
## otherwise its range in hexes.
func reach() -> int:
	var hexes: int = stats.get_stat(UnitStats.Stat.RANGE)
	return melee_reach if hexes <= 1 else hexes * HexGrid.HEX


## How far a signature reaches: its own max_range, or the unit's reach.
func reach_of(ability: AbilityDef) -> int:
	return ability.max_range * HexGrid.HEX if ability.max_range > 0 else reach()


func in_reach_of(other: UnitState) -> bool:
	var dx: int = other.pos.x - pos.x
	var dy: int = other.pos.y - pos.y
	return dx * dx + dy * dy <= reach_sq


## Works out reach_sq again (its stats changed).
func refresh_reach() -> void:
	var reach_units: int = reach()
	reach_sq = reach_units * reach_units
	if planted_bonus > 0:
		var planted: int = (base_stats.get_stat(UnitStats.Stat.RANGE) + planted_bonus) * HexGrid.HEX
		plant_reach_sq = planted * planted


## Its DEF, less what damage over time has shredded (never below 0).
func defense() -> int:
	return maxi(stats.get_stat(UnitStats.Stat.DEF) - Statuses.defense_shred(self), 0)


func circle() -> ArenaPlane.Circle:
	return ArenaPlane.Circle.make(pos, radius, id)
