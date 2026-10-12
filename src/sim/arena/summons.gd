class_name Summons
extends RefCounted
## Summons (docs/plans/rebuild-phase1-arena-sim.md, section 10): the summon
## effect brings new units of a kit the fight's setup lists
## (FightSetup.summon_kits) onto the caster's side.
##
##   - Where (EffectDef.placement), each on a spot where it fits (safe
##     ground, touching nobody):
##       edges     along the edge of the safe ground, a radius in, every
##                 nav cell; the spot nearest the caster (or its target,
##                 "near": "target") first, ties going round clockwise from
##                 the heroes' left corner
##       adjacent  touching the caster, from the 12 points leaps use, the
##                 one straight ahead of it first and then clockwise
##       hexes     each on its hex's center, or else the free spot nearest
##                 it (Displacement.free_spot_near)
##       water     (phase 8 part 3) each on the water hex nearest any of
##                 its enemies, at the free spot nearest its center; none
##                 without water (dropped: "no water")
##   - A rise as another kit (phase 8 part 3; PartDef's rise "as") stands a
##     fresh unit of that kit where the fallen one fell (rise_as), logged as
##     a SUMMON sourced to the rise.
##   - A summoned unit joins at the end of the fight's order, so it acts
##     this tick if the order hasn't reached the end yet. It has a unique id
##     (the kit's id, then "#2", "#3", ...), no target, the kit's starting
##     mana, and never counts as a back-liner. Logged as SUMMON.
##   - No side has more than max_units_per_side standing units: extra
##     summons are dropped, and so are those with no room. Both are logged.
##   - A summon may name one of its caster's companions (phase 8 part 6,
##     Nest's vipers; CompanionDef): its kit takes its HP and ATK from the
##     caster (companion), and it counts as the caster's companion. With
##     "lasts_ms", a summon goes quietly once its time is up, like a thrall.
##   - Companions that start a fight (CombatSim.place_companions) and one
##     that returns stand beside their hero (beside).
##   - A copy (phase 8 part 6, Lucan; "copy_of"): a copy of the caster, or of
##     each standing hero on its side, beside it (copy_kit: its kit as it
##     stands, with its HP, ATK, and MGK at the share, its basic attack
##     only). The caster owns it (UnitState.owner, mirror_of): it keeps no
##     side up, is nobody's fallen ally, its work counts for the caster's
##     deeds, and it goes quietly when its time is up. max_standing counts
##     every copy standing on the side. Logged as SUMMON (end_tick: when it
##     goes); its id and name say whose copy it is.
##   - A raise (phase 8 part 5, Gravecaller; raise) stands a fallen enemy
##     up on the raiser's side as its own kit, a thrall, at the free spot
##     nearest where it fell: a share of its max HP for a while, then it
##     goes (CombatSim). Never a summon, an elite or boss, or a unit that
##     fell into the void (Decision 2); it never copies a signature. Logged
##     as a SUMMON sourced to the raise (amount: its HP; end_tick: when it
##     goes).


## `unit` summons as `effect` says (`aimed_at`: its ability's target, for
## "near": "target").
static func summon(sim: CombatSim, unit: UnitState, source: EffectSource, effect: EffectDef, aimed_at: UnitState) -> void:
	if effect.copy_of != EffectDef.CopyOf.NONE:
		_copies(sim, unit, source, effect)
		return
	var as_companion: CompanionDef = unit.def.companion(effect.summon_kit)
	var kit: UnitDef = companion(as_companion, unit) if as_companion != null else sim.setup.summon_kit(effect.summon_kit)
	var edges: Array[Vector2i] = []
	if effect.placement == EffectDef.Placement.EDGES:
		var near: Vector2i = aimed_at.pos if effect.near_target and aimed_at != null else unit.pos
		edges = _edge_spots(sim, sim.tuning.unit_radius, near)
	var joined: bool = false
	for i: int in effect.count:
		if sim.standing_count(unit.side) >= sim.tuning.max_units_per_side:
			_log_dropped(sim, source, kit, "its side is full")
			continue
		var summoned: UnitState = UnitState.make_summon(kit, unit.side, sim.next_unit_id(kit.id), sim.units.size(), sim.tuning.unit_radius)
		if effect.max_standing > 0 and _standing_of(sim, unit.side, kit.id) >= effect.max_standing:
			_log_dropped(sim, source, kit, "enough stand")
			continue
		if effect.placement == EffectDef.Placement.WATER and (not sim.has_water or sim.water.hexes.is_empty()):
			_log_dropped(sim, source, kit, "no water")
			continue
		var spot: Vector2i = _spot(sim, unit, summoned, effect, i, edges)
		if spot.x < 0:
			_log_dropped(sim, source, kit, "no room")
			continue
		summoned.pos = spot
		if as_companion != null:
			summoned.owner = unit
			summoned.companion = as_companion
			# What its hero's deed reads of its hits (Pack Call).
			summoned.bonus_parts = unit.bonus_parts
		if effect.lasts_ticks > 0:
			summoned.expires_at = sim.tick + effect.lasts_ticks
			sim.thralls = true
		sim.add_unit(summoned)
		joined = true
		var entry: LogEntry = sim.new_entry(LogEntry.Kind.SUMMON, source)
		entry.target = summoned.id
		entry.to_pos = spot
		sim.combat_log.add(entry)
	if joined:
		sim.units_joined()


static func _spot(sim: CombatSim, unit: UnitState, summoned: UnitState, effect: EffectDef, i: int, edges: Array[Vector2i]) -> Vector2i:
	match effect.placement:
		EffectDef.Placement.EDGES:
			for spot: Vector2i in edges:
				if sim.fits(summoned, spot):
					return spot
		EffectDef.Placement.ADJACENT:
			return touching(sim, unit, summoned)
		EffectDef.Placement.HEXES:
			var hex: Vector2i = effect.summon_hexes[i]
			return Displacement.free_spot_near(sim, summoned, sim.grid.center(hex.x, hex.y), null, 0)
		EffectDef.Placement.WATER:
			return Displacement.free_spot_near(sim, summoned, _water_near_enemy(sim, unit), null, 0)
	return Vector2i(-1, -1)


## A spot touching `unit` where `other` fits, from the 12 points leaps use,
## the one straight ahead of it first and then clockwise (x -1: none).
static func touching(sim: CombatSim, unit: UnitState, other: UnitState) -> Vector2i:
	var forward: int = unit.forward()
	for dir: Vector2i in Displacement.LEAP_DIRECTIONS:
		var spot: Vector2i = ArenaPlane.along(unit.pos, dir * forward, unit.radius + other.radius)
		if sim.fits(other, spot):
			return spot
	return Vector2i(-1, -1)


## touching, or else the free spot nearest `unit` (x -1: none).
static func beside(sim: CombatSim, unit: UnitState, other: UnitState) -> Vector2i:
	var spot: Vector2i = touching(sim, unit, other)
	return spot if spot.x >= 0 else Displacement.free_spot_near(sim, other, unit.pos, null, 0)


## `unit` makes copies as `effect` says (see the top).
static func _copies(sim: CombatSim, unit: UnitState, source: EffectSource, effect: EffectDef) -> void:
	var copied: Array[UnitState] = []
	if effect.copy_of == EffectDef.CopyOf.SELF:
		copied.append(unit)
	else:
		for ally: UnitState in sim.units:
			if ally.alive and ally.side == unit.side and not ally.summoned:
				copied.append(ally)
	var joined: bool = false
	# Thousand Faces (phase 8 part 6): each copy it has made adds to the share.
	var share: int = mini(effect.copy_share_bp + unit.copies_made * effect.copy_grows_bp, maxi(effect.copy_share_max_bp, effect.copy_share_bp))
	for of: UnitState in copied:
		var kit: UnitDef = copy_kit(of, share, effect.copy_casts)
		if sim.standing_count(unit.side) >= sim.tuning.max_units_per_side:
			_log_dropped(sim, source, kit, "its side is full")
			continue
		if effect.max_standing > 0 and _copies_on(sim, of) >= effect.max_standing:
			_log_dropped(sim, source, kit, "enough stand")
			continue
		var copy: UnitState = UnitState.make_summon(kit, unit.side, sim.next_unit_id(kit.id), sim.units.size(), sim.tuning.unit_radius)
		var spot: Vector2i = beside(sim, of, copy)
		if spot.x < 0:
			_log_dropped(sim, source, kit, "no room")
			continue
		copy.pos = spot
		copy.owner = unit
		copy.mirror_of = of
		copy.bonus_parts = unit.bonus_parts
		copy.expires_at = sim.tick + effect.lasts_ticks
		unit.copies_made += 1
		sim.thralls = true
		sim.add_unit(copy)
		joined = true
		var entry: LogEntry = sim.new_entry(LogEntry.Kind.SUMMON, source)
		entry.target = copy.id
		entry.to_pos = spot
		entry.end_tick = copy.expires_at
		sim.combat_log.add(entry)
	if joined:
		sim.units_joined()


## A copy of `of` (phase 8 part 6, Lucan): its kit as it stands (its upgrades,
## loadout, and relics, not its in-fight auras), its max HP (wounds counted),
## ATK, and MGK at `share_bp`, and its basic attack only: no signature or mana,
## no passives, phases, companions, Engage, hop, or what's placed before a
## fight. Its id is its kit's with "_copy", its name "Copy of" its first name.
## `casts` (True Reflection): it keeps a mana signature, its bar full and
## gaining nothing, so it casts it once (never one that makes copies).
static func copy_kit(of: UnitState, share_bp: int, casts: bool = false) -> UnitDef:
	var kit: UnitDef = of.def.copy()
	kit.id = of.def.id + "_copy"
	kit.name = "Copy of %s" % of.def.name.get_slice(" ", 0)
	kit.stats = of.def.stats.copy()
	kit.stats.values[UnitStats.Stat.HP] = maxi(FixedMath.apply_bp(of.base_max_hp, share_bp), 1)
	kit.stats.values[UnitStats.Stat.ATK] = FixedMath.apply_bp(of.def.stats.get_stat(UnitStats.Stat.ATK), share_bp)
	kit.stats.values[UnitStats.Stat.MGK] = FixedMath.apply_bp(of.def.stats.get_stat(UnitStats.Stat.MGK), share_bp)
	var keeps: AbilityDef = of.def.signature if casts and of.def.signature != null and of.def.mana != null \
			and of.def.signature.trigger.kind == TriggerDef.Kind.MANA and not of.def.signature.effects.any(func(effect: EffectDef) -> bool: return effect.copy_of != EffectDef.CopyOf.NONE) else null
	kit.signature = keeps
	kit.mana = null
	if keeps != null:
		kit.mana = ManaDef.new()
		kit.mana.max = of.def.mana.max
		kit.mana.start = of.def.mana.max
	kit.passives = []
	kit.phases = []
	kit.companions = []
	kit.traits.erase("engage")
	kit.hop_cooldown_ticks = 0
	kit.placed_snares = 0
	kit.placed_lantern = false
	kit.place_rule = ""
	kit.arrive_ticks = 0
	kit.arrive_at = ""
	kit.swap_ticks = 0
	kit.start_hp_bp = FixedMath.BP_ONE
	kit.shard_cap = 0
	return kit


## How many copies of `of` stand (whoever made them).
static func _copies_on(sim: CombatSim, of: UnitState) -> int:
	var count: int = 0
	for unit: UnitState in sim.units:
		if unit.alive and unit.mirror_of == of:
			count += 1
	return count


## `as_companion`'s kit beside `owner` (phase 8 part 6): its HP a share of
## her max HP as the fight began (wounds counted), its ATK of her kit's.
static func companion(as_companion: CompanionDef, owner: UnitState) -> UnitDef:
	return as_companion.kit_for(owner.base_max_hp, owner.def.stats.get_stat(UnitStats.Stat.ATK))


## The center of the water hex nearest any standing enemy of `unit` (ties to
## the first water hex, then the first enemy).
static func _water_near_enemy(sim: CombatSim, unit: UnitState) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_sq: int = -1
	for hex: Vector2i in sim.water.hexes:
		var middle: Vector2i = sim.grid.center(hex.x, hex.y)
		for enemy: UnitState in sim.standing_enemies_of(unit):
			var distance_sq: int = ArenaPlane.length_sq(enemy.pos - middle)
			if best_sq < 0 or distance_sq < best_sq:
				best = middle
				best_sq = distance_sq
	return best if best.x >= 0 else sim.grid.center(sim.water.hexes[0].x, sim.water.hexes[0].y)


## A fallen unit rises as another kit (see the top): a fresh one at the
## free spot nearest where it fell, at the rise's share of its max HP. With
## no room, or its side full, none (dropped).
static func rise_as(sim: CombatSim, fallen: UnitState, part: PartDef) -> void:
	var kit: UnitDef = sim.setup.summon_kit(part.rise_as)
	var source: EffectSource = EffectSource.make(fallen.id, part.id, part.name)
	if sim.standing_count(fallen.side) >= sim.tuning.max_units_per_side:
		_log_dropped(sim, source, kit, "its side is full")
		return
	var risen: UnitState = UnitState.make_summon(kit, fallen.side, sim.next_unit_id(kit.id), sim.units.size(), sim.tuning.unit_radius)
	var spot: Vector2i = Displacement.free_spot_near(sim, risen, sim.nearest_safe_point(fallen.pos, risen.radius), null, 0)
	if spot.x < 0:
		_log_dropped(sim, source, kit, "no room")
		return
	risen.pos = spot
	risen.hp = maxi(FixedMath.apply_bp(risen.max_hp, part.rise_hp_bp), 1)
	sim.add_unit(risen)
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.SUMMON, source)
	entry.target = risen.id
	entry.to_pos = spot
	entry.note = ""
	sim.combat_log.add(entry)
	sim.units_joined()


## `unit` raises `fallen` as a thrall (see the top): a fresh unit of its kit
## on `unit`'s side, at the raise's share of its max HP (grown by each earlier
## raise), standing that long (grown too). Dropped (logged) with its side
## full, enough thralls standing, or no room.
static func raise(sim: CombatSim, unit: UnitState, source: EffectSource, effect: EffectDef, fallen: UnitState) -> void:
	if fallen == null or fallen.alive or fallen.fell or fallen.summoned or not fallen.def.rank.is_empty() or fallen.side == unit.side:
		return
	var kit: UnitDef = fallen.def
	if sim.standing_count(unit.side) >= sim.tuning.max_units_per_side:
		_log_dropped(sim, source, kit, "its side is full")
		return
	if effect.max_standing > 0 and _raised_by(sim, unit) >= effect.max_standing:
		_log_dropped(sim, source, kit, "enough stand")
		return
	var setup: UnitSetup = UnitSetup.make(kit, unit.side, -1, -1, sim.next_unit_id(kit.id))
	setup.max_hp_bp = mini(effect.raise_hp_bp + unit.raises * effect.raise_grow_hp_bp, FixedMath.BP_ONE)
	var risen: UnitState = UnitState.from_setup(setup, sim.units.size(), null, sim.tuning.unit_radius)
	var spot: Vector2i = Displacement.free_spot_near(sim, risen, sim.nearest_safe_point(fallen.pos, risen.radius), null, 0)
	if spot.x < 0:
		_log_dropped(sim, source, kit, "no room")
		return
	risen.summoned = true
	risen.raised = true
	risen.raised_by = unit.id
	risen.copy_part = null
	risen.expires_at = sim.tick + effect.raise_ticks + unit.raises * effect.raise_grow_ticks
	risen.pos = spot
	unit.raises += 1
	sim.add_unit(risen)
	sim.thralls = true
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.SUMMON, source)
	entry.target = risen.id
	entry.to_pos = spot
	entry.amount = risen.hp
	entry.end_tick = risen.expires_at
	sim.combat_log.add(entry)
	sim.units_joined()


## How many thralls `unit` raised stand now.
static func _raised_by(sim: CombatSim, unit: UnitState) -> int:
	var count: int = 0
	for other: UnitState in sim.units:
		if other.alive and other.raised and other.raised_by == unit.id:
			count += 1
	return count


## Spots along the safe ground's edge for a unit of `radius`, nearest `near`
## first (ties in the order they go round).
static func _edge_spots(sim: CombatSim, radius: int, near: Vector2i) -> Array[Vector2i]:
	var step: int = sim.tuning.nav_cell
	var x0: int = sim.safe.position.x + radius
	var y0: int = sim.safe.position.y + radius
	var x1: int = sim.safe.end.x - radius
	var y1: int = sim.safe.end.y - radius
	var round_spots: Array[Vector2i] = []
	for x: int in range(x0, x1, step):
		round_spots.append(Vector2i(x, y0))
	for y: int in range(y0, y1, step):
		round_spots.append(Vector2i(x1, y))
	for x: int in range(x1, x0, -step):
		round_spots.append(Vector2i(x, y1))
	for y: int in range(y1, y0, -step):
		round_spots.append(Vector2i(x0, y))
	# Sort by (distance, place in the round): the keys are unique.
	var keys: Array[int] = []
	for i: int in round_spots.size():
		keys.append(ArenaPlane.length_sq(round_spots[i] - near) * 65536 + i)
	keys.sort()
	var spots: Array[Vector2i] = []
	for key: int in keys:
		spots.append(round_spots[key % 65536])
	return spots


## How many standing units of `kit_id` are on `side`.
static func _standing_of(sim: CombatSim, side: EffectSource.Team, kit_id: String) -> int:
	var count: int = 0
	for unit: UnitState in sim.units:
		if unit.alive and unit.side == side and unit.def.id == kit_id:
			count += 1
	return count


static func _log_dropped(sim: CombatSim, source: EffectSource, kit: UnitDef, why: String) -> void:
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.SUMMON, source)
	entry.target = kit.id
	entry.note = why
	sim.combat_log.add(entry)
