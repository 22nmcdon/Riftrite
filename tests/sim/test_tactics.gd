extends GutTest
## What each tactic does in a fight (Tactics; docs/plans/rebuild-phase3b-tactics.md,
## section 2), in tiny fights. The board runs left to right in the plan's
## terms: heroes in rows 0-2, enemies in rows 4-6, a row a hex apart.

const K = preload("res://tests/sim/sim_test_kit.gd")


## A tactic of `kind` that the kits named in `heroes` can take, with no
## payoff unless `payoff_bp` (round 2) is given.
static func tactic(kind: TacticDef.Kind, heroes: Array[String], payoff_bp: int = 0) -> TacticDef:
	var def := TacticDef.new()
	def.id = TacticDef.KIND_NAMES[kind]
	def.name = {TacticDef.Kind.PREFER_TARGET: "Casters first", TacticDef.Kind.HOLD_GROUND: "Hold your ground",
		TacticDef.Kind.SIGNATURE_THRESHOLD: "Wait to heal"}[kind]
	def.kind = kind
	def.archetypes = ["caster", "support"] as Array[String]
	def.release_range = 2 * HexGrid.HEX
	def.below_bp = 5000
	def.heroes = heroes
	match kind:
		TacticDef.Kind.PREFER_TARGET:
			def.damage_vs_bp = payoff_bp
		TacticDef.Kind.HOLD_GROUND:
			def.atsp_bp = payoff_bp
		TacticDef.Kind.SIGNATURE_THRESHOLD:
			def.heal_bp = payoff_bp
	return def


static func with_tactic(setup: UnitSetup, kind: TacticDef.Kind, payoff_bp: int = 0) -> UnitSetup:
	setup.tactic = tactic(kind, [setup.def.id] as Array[String], payoff_bp)
	return setup


## An enemy kit of an archetype.
static func foe_kit(kit_id: String, archetype: String, overrides: Dictionary = {}) -> UnitDef:
	var kit: UnitDef = K.kit(kit_id, overrides)
	kit.archetype = archetype
	return kit


## A still archer: shoots from `range` hexes and never needs to walk.
static func archer(kit_id: String, archetype: String, range_hexes: int, extra: Dictionary = {}) -> UnitDef:
	var overrides: Dictionary = {"stats": {"hp": 5000, "atk": 1, "speed": 2, "range": range_hexes},
		"basic_attack": {"cooldown_ms": 2000, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}}
	overrides.merge(extra, true)
	return foe_kit(kit_id, archetype, overrides)


static func notes(fight: CombatSim, kind: LogEntry.Kind, unit_id: String) -> Array[String]:
	var found: Array[String] = []
	for entry: LogEntry in K.entries(fight, kind, unit_id):
		found.append("%s -> %s" % [entry.note, entry.target])
	return found


## The times `unit_id`'s signature `ability_id` fired (FIRE is basic attacks too).
static func fires(fight: CombatSim, unit_id: String, ability_id: String) -> int:
	return K.entries(fight, LogEntry.Kind.FIRE, unit_id).filter(func(entry: LogEntry) -> bool: return entry.source_ability == ability_id).size()


static func first_tick(fight: CombatSim, kind: LogEntry.Kind, unit_id: String, note_begins: String) -> int:
	for entry: LogEntry in K.entries(fight, kind, unit_id):
		if entry.note.begins_with(note_begins):
			return entry.tick
	return -1


# --- Casters first ---------------------------------------------------------------

func test_casters_first_picks_a_caster_over_a_nearer_enemy() -> void:
	var ranger: UnitSetup = with_tactic(K.at(K.kit("ranger", {"stats": {"hp": 2000, "range": 5}}), 3, 1), TacticDef.Kind.PREFER_TARGET)
	var fight: CombatSim = K.sim(K.fight([ranger], [K.foe(archer("pup", "swarm", 1), 3, 4), K.foe(archer("moth", "caster", 1), 5, 6)]))
	K.step(fight, 2)
	assert_eq(notes(fight, LogEntry.Kind.TARGET, "ranger")[0], "Casters first -> moth", "the caster, though the pup is nearer")


func test_casters_first_counts_supports_and_falls_back_to_its_own_rule() -> void:
	var ranger: UnitSetup = with_tactic(K.at(K.kit("ranger", {"stats": {"hp": 2000, "range": 5}}), 3, 1), TacticDef.Kind.PREFER_TARGET)
	var fight: CombatSim = K.sim(K.fight([ranger], [K.foe(archer("pup", "swarm", 1), 3, 4), K.foe(archer("witch", "support", 1), 6, 6)]))
	K.step(fight, 2)
	assert_eq(notes(fight, LogEntry.Kind.TARGET, "ranger")[0], "Casters first -> witch", "a support counts")
	ranger = with_tactic(K.at(K.kit("ranger", {"stats": {"hp": 2000, "range": 5}}), 3, 1), TacticDef.Kind.PREFER_TARGET)
	fight = K.sim(K.fight([ranger], [K.foe(archer("pup", "swarm", 1), 3, 4), K.foe(archer("hound", "flanker", 1), 5, 6)]))
	K.step(fight, 2)
	assert_eq(notes(fight, LogEntry.Kind.TARGET, "ranger")[0], "nearest -> pup", "no caster standing: its own rule")


func test_casters_first_stays_on_its_target_when_a_caster_turns_up() -> void:
	var moth: UnitDef = archer("moth", "caster", 1)
	var caller: UnitDef = archer("caller", "swarm", 1, {"signature": {"id": "call", "name": "Call", "trigger": {"kind": "fight_start"}, "targeting": "self",
		"effects": [{"type": "summon", "kit": "moth", "placement": "adjacent"}]}})
	var ranger: UnitSetup = with_tactic(K.at(K.kit("ranger", {"stats": {"hp": 2000, "range": 5}}), 3, 1), TacticDef.Kind.PREFER_TARGET)
	var setup: FightSetup = K.fight([ranger], [K.foe(caller, 3, 5)])
	setup.summon_kits = [moth] as Array[UnitDef]
	var fight: CombatSim = K.sim(setup)
	K.step(fight, 60)
	assert_eq(K.entries(fight, LogEntry.Kind.SUMMON).size(), 1, "the moth joined")
	assert_eq(notes(fight, LogEntry.Kind.TARGET, "ranger"), ["nearest -> caller"] as Array[String], "targets stay sticky")


func test_taunt_still_pulls_a_caster_hunter_away() -> void:
	var taunter: UnitDef = archer("brute", "anchor", 1, {"signature": {"id": "roar", "name": "Roar", "trigger": {"kind": "fight_start"}, "targeting": "self",
		"effects": [{"type": "area", "shape": {"kind": "circle", "radius": 3}, "anchor": "self", "hits": "enemies",
			"effects": [{"type": "apply_status", "status": "taunt", "target": "target"}]}]}})
	var ranger: UnitSetup = with_tactic(K.at(K.kit("ranger", {"stats": {"hp": 2000, "range": 5}}), 3, 2), TacticDef.Kind.PREFER_TARGET)
	var fight: CombatSim = K.sim(K.fight([ranger], [K.foe(taunter, 3, 4), K.foe(archer("moth", "caster", 1), 6, 6)]))
	K.step(fight, 3)
	var seen: Array[String] = notes(fight, LogEntry.Kind.TARGET, "ranger")
	assert_eq(seen[0], "Casters first -> moth")
	assert_true(seen.has("taunted -> brute"), "Taunt wins: %s" % [seen])


# --- Hold your ground --------------------------------------------------------------

func test_holding_starts_logged_and_never_walks_while_no_enemy_is_near() -> void:
	var warden: UnitSetup = with_tactic(K.at(K.kit("warden", {"stats": {"hp": 5000}}), 3, 1), TacticDef.Kind.HOLD_GROUND)
	var fight: CombatSim = K.sim(K.fight([warden], [K.foe(archer("archer", "ranged", 6), 3, 6)]))
	K.step(fight, 200)
	var lines: Array[LogEntry] = K.entries(fight, LogEntry.Kind.TACTIC, "warden")
	assert_eq(lines.size(), 1)
	assert_eq(lines[0].tick, 0)
	assert_eq(lines[0].to_text(), "[0.00s] warden · Hold your ground: holds its ground")
	assert_eq(lines[0].source_ability, "hold_ground")
	assert_eq(K.entries(fight, LogEntry.Kind.MOVE, "warden").size(), 0, "a target out of reach, and it stays put")
	assert_true(fight.unit_by_id("warden").holding)


func test_a_holder_fights_what_comes_into_reach_then_moves_out_for_good() -> void:
	var ranger: UnitSetup = with_tactic(K.at(K.kit("ranger", {"stats": {"hp": 5000, "range": 3}}), 3, 0), TacticDef.Kind.HOLD_GROUND)
	var hound: UnitDef = foe_kit("hound", "flanker", {"stats": {"hp": 3000, "atk": 1, "speed": 2}})
	var fight: CombatSim = K.sim(K.fight([ranger], [K.foe(archer("archer", "ranged", 6), 1, 4), K.foe(hound, 5, 6)]))
	var holder: UnitState = fight.unit_by_id("ranger")
	var distances: Array[int] = []
	while holder.holding and fight.tick < 400:
		distances.append(ArenaPlane.length_sq(fight.unit_by_id("hound").pos - holder.pos))
		fight.step()
	assert_false(holder.holding, "it let go")
	var release: int = 2 * HexGrid.HEX
	assert_lte(distances[distances.size() - 1], release * release, "when the hound was within 2 hexes")
	assert_gt(distances[distances.size() - 2], release * release, "and not before")
	var seen: Array[String] = notes(fight, LogEntry.Kind.TARGET, "ranger")
	assert_eq(seen[0], "nearest -> archer", "the nearer archer first, out of its reach")
	assert_true(seen.has("Hold your ground -> hound"), "then the hound, once in reach: %s" % [seen])
	assert_lt(first_tick(fight, LogEntry.Kind.TARGET, "ranger", "Hold your ground"), first_tick(fight, LogEntry.Kind.TACTIC, "ranger", "moves out"))
	assert_gt(K.entries(fight, LogEntry.Kind.DAMAGE, "ranger").size(), 0, "it shot the hound while holding")
	assert_eq(K.entries(fight, LogEntry.Kind.MOVE, "ranger").size(), 0, "without taking a step")
	var out: Array[LogEntry] = K.entries(fight, LogEntry.Kind.TACTIC, "ranger").filter(func(entry: LogEntry) -> bool: return entry.note.begins_with("moves out"))
	assert_eq(out.size(), 1)
	assert_eq(out[0].note, "moves out: hound came within 2 hexes")
	assert_eq(out[0].target, "hound")
	K.step(fight, 200)
	assert_false(holder.holding, "for good")
	assert_eq(K.entries(fight, LogEntry.Kind.TACTIC, "ranger").size(), 2, "one start, one release")


func test_a_taunted_holder_keeps_the_taunter() -> void:
	var taunter: UnitDef = archer("brute", "anchor", 7, {"signature": {"id": "roar", "name": "Roar", "trigger": {"kind": "fight_start"}, "targeting": "self",
		"effects": [{"type": "area", "shape": {"kind": "circle", "radius": 7}, "anchor": "self", "hits": "enemies",
			"effects": [{"type": "apply_status", "status": "taunt", "target": "target"}]}]}})
	var ranger: UnitSetup = with_tactic(K.at(K.kit("ranger", {"stats": {"hp": 5000, "range": 3}}), 3, 0), TacticDef.Kind.HOLD_GROUND)
	var hound: UnitDef = foe_kit("hound", "flanker", {"stats": {"hp": 3000, "atk": 1, "speed": 2}})
	var fight: CombatSim = K.sim(K.fight([ranger], [K.foe(taunter, 3, 6), K.foe(hound, 2, 4)]))
	var holder: UnitState = fight.unit_by_id("ranger")
	while holder.holding and fight.tick < 200:
		fight.step()
	assert_false(holder.holding, "the hound came near")
	assert_false(notes(fight, LogEntry.Kind.TARGET, "ranger").has("Hold your ground -> hound"), "no turning from the taunter")


func test_a_push_moves_a_holder_and_it_holds_where_it_lands() -> void:
	var pusher: UnitDef = archer("slinger", "ranged", 6, {"basic_attack": {"cooldown_ms": 1000,
		"effects": [{"type": "damage", "amount": 1, "target": "target"}, {"type": "knockback", "hexes": 1, "target": "target"}]}})
	var warden: UnitSetup = with_tactic(K.at(K.kit("warden", {"stats": {"hp": 5000}}), 3, 2), TacticDef.Kind.HOLD_GROUND)
	var fight: CombatSim = K.sim(K.fight([warden], [K.foe(pusher, 3, 6)]))
	var start: Vector2i = fight.unit_by_id("warden").pos
	K.step(fight, 60)
	assert_gt(K.entries(fight, LogEntry.Kind.PUSH).size(), 0)
	assert_ne(fight.unit_by_id("warden").pos, start, "pushed")
	assert_eq(K.entries(fight, LogEntry.Kind.MOVE, "warden").size(), 0, "and it never walked back")
	assert_true(fight.unit_by_id("warden").holding)


# --- Wait to heal -------------------------------------------------------------------

func _healer_fight(payoff_bp: int = 0) -> CombatSim:
	var mender: UnitSetup = with_tactic(K.at(K.kit("mender", {"stats": {"hp": 1000, "range": 3, "mgk": 10},
		"mana": {"max": 20, "start": 20, "regen_per_s": 10},
		"signature": {"id": "mend", "name": "Mend", "trigger": {"kind": "mana"}, "targeting": "lowest_hp_ally",
			"effects": [{"type": "heal", "amount": 30, "target": "target"}, {"type": "shield", "amount": 10, "target": "target"}]}}), 3, 0),
		TacticDef.Kind.SIGNATURE_THRESHOLD, payoff_bp)
	var tank: UnitSetup = K.at(K.kit("tank", {"stats": {"hp": 1000}}), 4, 0)
	var dummy: UnitDef = archer("dummy", "swarm", 1, {"basic_attack": {"effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([mender, tank], [K.foe(dummy, 3, 6)]))
	fight.unit_by_id("tank").hp = 600
	return fight


func test_wait_to_heal_holds_a_full_bar_until_an_ally_is_hurt_enough() -> void:
	var fight: CombatSim = _healer_fight()
	var mender: UnitState = fight.unit_by_id("mender")
	K.step(fight, 30)
	assert_eq(fires(fight, "mender", "mend"), 0, "the tank at 60%: no Mend")
	assert_eq(mender.mana, mender.mana_cap, "the bar waits, full")
	var waits: Array[LogEntry] = K.entries(fight, LogEntry.Kind.TACTIC, "mender")
	assert_eq(waits.size(), 1, "logged once for the bar")
	assert_eq(waits[0].note, "Mend waits: no ally within 3 hexes below 50%")
	fight.unit_by_id("tank").hp = 450
	K.step(fight, 1)
	assert_eq(fires(fight, "mender", "mend"), 1, "below 50%: it fires")
	K.step(fight, 5)
	var heals: Array[LogEntry] = K.entries(fight, LogEntry.Kind.HEAL, "mender")
	assert_eq(heals.size(), 1, "and lands (a shot, from 2 hexes or more)")
	assert_eq(heals[0].target if not heals.is_empty() else "", "tank")
	fight.unit_by_id("tank").hp = 900
	K.step(fight, 55)
	assert_eq(K.entries(fight, LogEntry.Kind.TACTIC, "mender").size(), 2, "the next full bar waits again, logged again")
	assert_eq(fires(fight, "mender", "mend"), 1)


func test_without_the_tactic_mend_fires_at_once() -> void:
	var fight: CombatSim = _healer_fight()
	fight.unit_by_id("mender").tactic = null
	K.step(fight, 2)
	assert_eq(fires(fight, "mender", "mend"), 1)
	assert_eq(K.entries(fight, LogEntry.Kind.TACTIC).size(), 0)


# --- Payoffs (round 2) --------------------------------------------------------------

## The ranger's first hit on `foe_id` in a fight against a pup and a moth:
## [damage before DEF, the log line].
func _first_hit(payoff_bp: int, foe_id: String, stop_after: int = 60) -> Array:
	var ranger: UnitSetup = with_tactic(K.at(K.kit("ranger", {"stats": {"hp": 5000, "range": 5, "atk": 40}}), 3, 1), TacticDef.Kind.PREFER_TARGET, payoff_bp)
	var fight: CombatSim = K.sim(K.fight([ranger], [K.foe(archer("pup", "swarm", 1), 3, 4), K.foe(archer("moth", "caster", 1), 5, 6)]))
	K.step(fight, stop_after)
	for entry: LogEntry in K.entries(fight, LogEntry.Kind.DAMAGE, "ranger"):
		if entry.target == foe_id:
			return [entry.amount + entry.mitigated + entry.absorbed, entry.to_text()]
	return [0, ""]


func test_casters_first_hits_casters_harder() -> void:
	var plain: Array = _first_hit(0, "moth")
	var paid: Array = _first_hit(2000, "moth")
	assert_gt(plain[0], 0)
	assert_eq(paid[0], FixedMath.apply_bp(plain[0], 12000), "+20% before DEF")
	assert_string_contains(paid[1], "(+20% from Casters first")
	assert_false((plain[1] as String).contains("Casters first"), "no payoff, no note")


func test_the_damage_payoff_is_for_its_own_attack_and_signature() -> void:
	var sting: Dictionary = {"passives": [{"id": "sting", "name": "Sting", "kind": "ability",
		"effects": [{"trigger": "on_basic_attack", "type": "damage", "amount": 5, "target": "target"}]}]}
	var ranger: UnitSetup = with_tactic(K.at(K.kit("ranger", sting.merged({"stats": {"hp": 5000, "range": 5, "atk": 40}})), 3, 1), TacticDef.Kind.PREFER_TARGET, 2000)
	var fight: CombatSim = K.sim(K.fight([ranger], [K.foe(archer("moth", "caster", 1), 5, 6)]))
	K.step(fight, 60)
	var stings: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "ranger").filter(func(hit: LogEntry) -> bool: return hit.source_ability == "sting")
	var shots: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "ranger").filter(func(hit: LogEntry) -> bool: return hit.source_ability != "sting")
	assert_gt(stings.size(), 0)
	assert_gt(shots.size(), 0)
	for hit: LogEntry in stings:
		assert_eq(hit.bonus, "", "a passive's hit gets no payoff")
	for hit: LogEntry in shots:
		assert_eq(hit.bonus, "+20% from Casters first")


func test_the_damage_payoff_skips_other_archetypes() -> void:
	var ranger: UnitSetup = with_tactic(K.at(K.kit("ranger", {"stats": {"hp": 5000, "range": 5, "atk": 40}}), 3, 1), TacticDef.Kind.PREFER_TARGET, 2000)
	var fight: CombatSim = K.sim(K.fight([ranger], [K.foe(archer("pup", "swarm", 1), 3, 4)]))
	K.step(fight, 60)
	var hits: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "ranger")
	assert_gt(hits.size(), 0)
	for hit: LogEntry in hits:
		assert_eq(hit.bonus, "", "a swarm unit takes no payoff")


## The ticks its basic attack fired on, holding or not.
static func _attack_ticks(fight: CombatSim, unit_id: String) -> Array[int]:
	var ticks: Array[int] = []
	var attack_id: String = fight.unit_by_id(unit_id).attack.def.id
	for entry: LogEntry in K.entries(fight, LogEntry.Kind.FIRE, unit_id):
		if entry.source_ability == attack_id:
			ticks.append(entry.tick)
	return ticks


func test_a_holder_attacks_faster_only_while_it_holds() -> void:
	var ranger: UnitSetup = with_tactic(K.at(K.kit("ranger", {"stats": {"hp": 5000, "range": 5}}), 3, 0), TacticDef.Kind.HOLD_GROUND, 2000)
	var hound: UnitDef = foe_kit("hound", "flanker", {"stats": {"hp": 30000, "atk": 1, "speed": 1}})
	var fight: CombatSim = K.sim(K.fight([ranger], [K.foe(hound, 3, 6)]))
	var holder: UnitState = fight.unit_by_id("ranger")
	assert_string_contains(K.entries(fight, LogEntry.Kind.TACTIC, "ranger")[0].note, "holds its ground (+20% attack speed while it holds)")
	while holder.holding and fight.tick < 600:
		fight.step()
	var released: int = fight.tick
	K.step(fight, 200)
	var ticks: Array[int] = _attack_ticks(fight, "ranger")
	var held_gaps: Array[int] = []
	var free_gaps: Array[int] = []
	for i: int in range(1, ticks.size()):
		if ticks[i] <= released:
			held_gaps.append(ticks[i] - ticks[i - 1])
		elif ticks[i - 1] > released + 20:
			free_gaps.append(ticks[i] - ticks[i - 1])
	assert_gt(held_gaps.size(), 1, "it shot while holding")
	assert_gt(free_gaps.size(), 1, "and after")
	for gap: int in held_gaps:
		assert_eq(gap, 17, "a 1s attack every 17 ticks at +20%")
	for gap: int in free_gaps:
		assert_eq(gap, 20, "every 20 once it lets go")


func test_the_heal_it_lets_go_is_stronger() -> void:
	for payoff_bp: int in [0, 3000]:
		var fight: CombatSim = _healer_fight(payoff_bp)
		K.step(fight, 5)
		fight.unit_by_id("tank").hp = 450
		K.step(fight, 8)
		var heals: Array[LogEntry] = K.entries(fight, LogEntry.Kind.HEAL, "mender")
		assert_eq(heals.size(), 1)
		assert_eq(heals[0].amount, 39 if payoff_bp > 0 else 30, "30 heal, +30% with the payoff")
		assert_eq(heals[0].to_text().ends_with("(+30% from Wait to heal)"), payoff_bp > 0, heals[0].to_text())
		assert_eq(K.entries(fight, LogEntry.Kind.SHIELD, "mender")[0].amount, 10, "its heals only, not its shield")
		K.step(fight, 40)
		var hits: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "mender")
		assert_gt(hits.size(), 0, "it has attacked by now")
		for hit: LogEntry in hits:
			assert_eq(hit.bonus, "", "and not its basic attack")


# --- The real tactics in a real fight ---------------------------------------------

## Witch Circle with each hero on a tactic: Brannoc holds, Maren hunts
## casters, Vell waits to heal. The log audit and the determinism tests use
## it too (every tactic's lines in a real fight).
static func tactics_setup(fight_seed: int = 3) -> FightSetup:
	var errors: Array[String] = []
	var formation: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": Vector2i(3, 0), "vell": Vector2i(4, 0)}
	var tactics: Dictionary[String, String] = {"brannoc": "hold_ground", "maren": "casters_first", "vell": "wait_to_heal"}
	return Encounters.setup(K.content(), "witch_circle", formation, fight_seed, errors, tactics)


func test_every_tactic_shows_in_a_real_fight() -> void:
	var setup: FightSetup = tactics_setup()
	assert_eq(setup.validate(K.content()), [] as Array[String])
	var text: String = K.run(setup).combat_log.to_text()
	for line: String in ["brannoc · Hold your ground: holds its ground", "brannoc · Hold your ground: moves out:", "maren targets gloam_witch: Casters first",
			"vell · Wait to heal: Mend waits: no ally within 3 hexes below 60%"]:
		assert_string_contains(text, line)


# --- No tactics ---------------------------------------------------------------------

func test_a_fight_without_tactics_logs_none() -> void:
	var content: ContentDb = K.content()
	var errors: Array[String] = []
	var formation: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": Vector2i(3, 0), "vell": Vector2i(4, 0)}
	var result: FightResult = CombatSim.run(Encounters.setup(content, "witch_circle", formation, 1, errors), content)
	assert_eq(result.combat_log.entries.filter(func(entry: LogEntry) -> bool: return entry.kind == LogEntry.Kind.TACTIC).size(), 0)
