extends GutTest
## Tamsin's six apexes (phase 8 part 4, docs/plans/rebuild-phase8-heroes.md
## 8d-3c; apexes.md) in real fights: each loads on its path's transformed
## kit with its taste and deed, and its snowball grows at apex: Phantom's
## Stealth that attacks don't end, Veilmaster's veiled allies, Executioner's
## Marked executions, Bloodtrail's steps, Strangler's tightening grip, and
## Pinmaster's pinned enemies.

const K = preload("res://tests/sim/sim_test_kit.gd")
const APEXES: Dictionary[String, String] = {
	"phantom": "nightblade", "veilmaster": "nightblade",
	"executioner": "headhunter", "bloodtrail": "headhunter",
	"strangler": "garrote", "pinmaster": "garrote",
}

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


## A fight of Tamsin with `team`'s other two, Tamsin transformed on the path
## of `apex_id`, vowed to it, and at apex if `apexed`; `others` puts the
## others on paths (transformed).
func _fight(encounter_id: String, apex_id: String, apexed: bool, team: Array[String] = ["brannoc", "maren", "tamsin"], others: Dictionary[String, String] = {}) -> CombatSim:
	var errors: Array[String] = []
	var vows: Dictionary[String, String] = {"tamsin": APEXES[apex_id]}
	var stages: Array[String] = ["tamsin"]
	for hero_id: String in others:
		vows[hero_id] = others[hero_id]
		stages.append(hero_id)
	var formation: Dictionary[String, Vector2i] = HeroTeam.place(_content, team, HeroTeam.GUARDED)
	var at_apex: Array[String] = []
	if apexed:
		at_apex.append("tamsin")
	var setup: FightSetup = Encounters.setup(_content, encounter_id, formation, 1, errors, {}, vows, stages, {},
		{"tamsin": apex_id} as Dictionary[String, String], at_apex)
	assert_eq(errors, [] as Array[String])
	var sim: CombatSim = CombatSim.new(setup, _content)
	while not sim.finished:
		sim.step()
	return sim


func _of(sim: CombatSim, kind: LogEntry.Kind, ability_id: String) -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in sim.combat_log.of_kind(kind):
		if entry.source_unit == "tamsin" and entry.source_ability == ability_id:
			found.append(entry)
	return found


func _applied(sim: CombatSim, status_id: String) -> Array[LogEntry]:
	return sim.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED).filter(func(entry: LogEntry) -> bool: return entry.source_unit == "tamsin" and entry.status == status_id)


func _deed(sim: CombatSim, apex_id: String) -> int:
	return CombatSim.result_of(sim).deed_amount("tamsin", apex_id)


func _sum(entries: Array[LogEntry]) -> int:
	return entries.reduce(func(sum: int, entry: LogEntry) -> int: return sum + entry.amount, 0)


func test_her_six_apexes_load_on_their_paths() -> void:
	for apex_id: String in APEXES:
		var apex: ApexDef = _content.apexes[apex_id]
		assert_eq(apex.path, APEXES[apex_id], apex_id)
		assert_true(_content.paths[APEXES[apex_id]].apexes.has(apex), apex_id)
		var path_kit: UnitDef = _content.paths[apex.path].transformed_kit
		assert_eq(apex.apex_kit.stats.get_stat(UnitStats.Stat.HP), FixedMath.apply_bp(path_kit.stats.get_stat(UnitStats.Stat.HP), 11500), "%s: +15%% HP" % apex_id)
		assert_gt(apex.deed.threshold, 0, apex_id)
	assert_eq(_content.apexes.values().filter(func(apex: ApexDef) -> bool: return _content.paths[apex.path].hero == "tamsin").size(), 6)


func test_phantom_stays_hidden_and_sharpens() -> void:
	var sim: CombatSim = _fight("pup_warren", "phantom", true)
	var veils: Array[LogEntry] = _applied(sim, "phantom_veil")
	assert_gt(veils.size(), 0, "her Stealth is Phantom's")
	assert_eq(_applied(sim, "hidden").size(), 0, "never the kind an attack ends")
	assert_gt(_applied(sim, "phantom_edge").size(), 0, "attacks from Stealth sharpen her")
	assert_gt(_deed(sim, "phantom"), 0)


func test_veilmaster_hides_her_allies() -> void:
	var vowed: CombatSim = _fight("the_pack", "veilmaster", false)
	var veiled: Array[LogEntry] = _applied(vowed, "veiled")
	assert_gt(veiled.size(), 0, "the taste hides allies near her")
	assert_eq(_deed(vowed, "veilmaster"), veiled.size(), "the deed counts them")
	for entry: LogEntry in veiled:
		assert_ne(entry.target, "tamsin", "her allies, not her")
	var sim: CombatSim = _fight("the_pack", "veilmaster", true)
	assert_gt(_applied(sim, "veil_haste").size(), 0, "each veiling quickens every hero")


func test_executioner_finishes_the_marked() -> void:
	var sim: CombatSim = _fight("bog_crossing", "executioner", true)
	var kills: int = _deed(sim, "executioner")
	assert_gt(kills, 0, "Sentence kills")
	assert_eq(_applied(sim, "executioner_rush").size(), kills, "a stack of ATK a Sentence kill")
	var sentence: AbilityDef = _content.apexes["executioner"].apex_kit.signature
	assert_eq(sentence.effects[0].execute_below_bp, 2500, "finishing below 25%")
	assert_eq(sentence.effects[0].execute_vs.keywords, ["marked"] as Array[String], "only the Marked")


func test_bloodtrail_steps_and_doubles_the_next_strike() -> void:
	var sim: CombatSim = _fight("witch_coven", "bloodtrail", true)
	var trail: Array[LogEntry] = _applied(sim, "on_the_trail")
	assert_gt(trail.size(), 0, "she follows the Marks")
	assert_eq(_deed(sim, "bloodtrail"), trail.size())
	assert_eq(_applied(sim, "trailing").size(), trail.size(), "each next strike doubled")
	assert_gt(_applied(sim, "blood_scent").size(), 0, "each kill feeds the trail")


func test_strangler_tightens_with_every_tick() -> void:
	var vowed: CombatSim = _fight("the_pack", "strangler", false)
	var garroted: Array = _applied(vowed, "garroted")
	assert_gt(garroted.size(), 0)
	assert_eq(garroted[0].end_tick - garroted[0].tick, 40, "the taste holds 2s")
	assert_eq(_deed(vowed, "strangler"), _sum(_of(vowed, LogEntry.Kind.DAMAGE, "garrote")), "the deed is the Garrote's damage")
	var sim: CombatSim = _fight("the_pack", "strangler", true)
	var ticks: Array[LogEntry] = _of(sim, LogEntry.Kind.DAMAGE, "garrote")
	assert_gt(ticks.size(), 2)
	assert_eq(_applied(sim, "strangle").size(), ticks.size(), "a stack a tick")
	assert_gt(ticks[ticks.size() - 1].amount, ticks[0].amount, "the cord tightens")


func test_pinmaster_pins_what_others_hold() -> void:
	var team: Array[String] = ["maren", "garrow", "tamsin"]
	var others: Dictionary[String, String] = {"maren": "trapper", "garrow": "chainwarden"}
	var sim: CombatSim = _fight("the_pack", "pinmaster", true, team, others)
	var pinned: Array[LogEntry] = _applied(sim, "pinned")
	assert_gt(pinned.size(), 0, "held enemies she hits are pinned")
	assert_gt(_applied(sim, "pin_rally").size(), 0, "and every 4th Knife on one rallies the heroes")
	assert_gt(_deed(sim, "pinmaster"), 0, "her allies' damage to Rooted enemies counts")
