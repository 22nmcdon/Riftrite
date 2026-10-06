extends GutTest
## Garrow's paths (phase 8 part 4, docs/plans/rebuild-phase8-heroes.md section
## 4; rebuild-heroes.md section 8d) in real fights: Aegisfang's capped Shield
## and its Burst, Chainwarden's Bleeding chains and Maelstrom, Spitemail's
## Spikes and Iron Maiden, Haul as each one's habit, and each deed moving.

const K = preload("res://tests/sim/sim_test_kit.gd")
const TEAM: Array[String] = ["maren", "vell", "garrow"]

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


## A fight of Garrow with Maren and Vell, Garrow on `path_id` (transformed
## if `transformed`).
func _fight(encounter_id: String, path_id: String, transformed: bool) -> CombatSim:
	var errors: Array[String] = []
	var vows: Dictionary[String, String] = {"garrow": path_id}
	var stages: Array[String] = []
	if transformed:
		stages.append("garrow")
	var formation: Dictionary[String, Vector2i] = HeroTeam.place(_content, TEAM, HeroTeam.GUARDED)
	var setup: FightSetup = Encounters.setup(_content, encounter_id, formation, 1, errors, {}, vows, stages)
	assert_eq(errors, [] as Array[String])
	var sim: CombatSim = CombatSim.new(setup, _content)
	while not sim.finished:
		sim.step()
	return sim


func _of(sim: CombatSim, kind: LogEntry.Kind, ability_id: String) -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in sim.combat_log.of_kind(kind):
		if entry.source_unit == "garrow" and entry.source_ability == ability_id:
			found.append(entry)
	return found


func _deed(sim: CombatSim, path_id: String) -> int:
	return CombatSim.result_of(sim).deed_amount("garrow", path_id)


func test_garrow_is_the_tank() -> void:
	assert_eq(HeroTeam.roles(_content, TEAM)["tank"], "garrow")
	assert_true(HeroTeam.ready(_content, "garrow"), "his three paths are built: he can be drafted")


func test_aegisfang_shields_himself_and_bursts_it() -> void:
	var vowed: CombatSim = _fight("the_pack", "aegisfang", false)
	var plated: Array[LogEntry] = _of(vowed, LogEntry.Kind.SHIELD, "plated_blows")
	assert_gt(plated.size(), 3, "a Shield from his blows")
	assert_eq(_deed(vowed, "aegisfang"), plated.reduce(func(sum: int, entry: LogEntry) -> int: return sum + entry.amount, 0), "the deed is that Shield")
	var sim: CombatSim = _fight("the_pack", "aegisfang", true)
	var garrow: UnitState = sim.unit_by_id("garrow")
	for entry: LogEntry in _of(sim, LogEntry.Kind.SHIELD, "plated_blows"):
		assert_lte(entry.amount, garrow.max_hp * 15 / 1000 + 1, "1.5% of max HP at most")
	var spent: Array[LogEntry] = _of(sim, LogEntry.Kind.SHIELD_SPENT, "bulwark_burst")
	assert_gt(spent.size(), 0, "Bulwark Burst spends his Shield")
	for entry: LogEntry in spent:
		assert_lte(entry.amount, garrow.max_hp, "never past his max HP (the cap is half, others' Shields add)")
	assert_gt(_of(sim, LogEntry.Kind.DAMAGE, "bulwark_burst").size(), 0, "and it hurts")


func test_chainwarden_bleeds_what_it_drags() -> void:
	var vowed: CombatSim = _fight("hollow_line", "chainwarden", false)
	var bleeds: Array[LogEntry] = _of(vowed, LogEntry.Kind.STATUS_APPLIED, "haul").filter(func(entry: LogEntry) -> bool: return entry.status == "bleed")
	assert_gt(bleeds.size(), 0, "Barbed Chain")
	assert_eq(_deed(vowed, "chainwarden"), bleeds.size(), "the deed counts them")
	assert_gt(_of(vowed, LogEntry.Kind.PUSH, "haul").size(), 0, "and drags")
	var sim: CombatSim = _fight("hollow_line", "chainwarden", true)
	var maelstrom: Array[LogEntry] = _of(sim, LogEntry.Kind.FIRE, "maelstrom")
	assert_gt(maelstrom.size(), 0)
	assert_string_contains(maelstrom[0].to_text(), "and readies its attack")
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "maelstrom").filter(func(entry: LogEntry) -> bool: return entry.status == "root").size(), 0, "it Roots")
	assert_eq(_of(sim, LogEntry.Kind.FIRE, "haul").size(), 0, "Haul is a habit now: it never fires as a signature")
	assert_gt(_of(sim, LogEntry.Kind.PUSH, "haul").size(), 0, "but it still drags, every 6th Chain Fist")


func test_spitemail_hits_back() -> void:
	var vowed: CombatSim = _fight("the_pack", "spitemail", false)
	var back: Array[LogEntry] = _of(vowed, LogEntry.Kind.DAMAGE, "spikes")
	assert_gt(back.size(), 0, "Spikes")
	assert_eq(_deed(vowed, "spitemail"), back.reduce(func(sum: int, entry: LogEntry) -> int: return sum + entry.amount, 0))
	var sim: CombatSim = _fight("the_pack", "spitemail", true)
	assert_gt(_of(sim, LogEntry.Kind.HEAL, "spikes").size(), 0, "he heals from what he sends back")
	var maiden: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "iron_maiden")
	assert_true(maiden.any(func(entry: LogEntry) -> bool: return entry.status == "taunt"), "Iron Maiden taunts")
	var windows: Array[Array] = []
	for entry: LogEntry in maiden:
		if entry.status == "iron_maiden":
			windows.append([entry.tick, entry.end_tick])
	assert_gt(windows.size(), 0)
	var spite: Array[LogEntry] = _of(sim, LogEntry.Kind.DAMAGE, "maidens_spite")
	assert_gt(spite.size(), 0, "hits sent back")
	for entry: LogEntry in spite:
		assert_true(windows.any(func(window: Array) -> bool: return entry.tick >= window[0] and entry.tick <= window[1]), "only while Iron Maiden lasts")
