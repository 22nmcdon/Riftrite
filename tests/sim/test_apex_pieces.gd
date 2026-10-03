extends GutTest
## The sim pieces apexes added (docs/plans/rebuild-phase8-apexes.md, part
## 8b-2), each in the fights of the apex that uses it: an execution
## (Eagle Eye), on_kill's "executed" and from_ability, a kills deed by an
## ability, an area's per_enemy_bp (Stormline), the hop effect, a patch's
## hop_cooldown_ms, and a deed's within_ms_of_hop (Windrunner). A fight
## without them is unchanged (the bench's fingerprints).

const K = preload("res://tests/sim/sim_test_kit.gd")

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


## A sim of `encounter_id` with Maren transformed into `path_id` and at
## `apex_id`'s apex, stepped to its end.
func _apex_fight(encounter_id: String, path_id: String, apex_id: String, maren_hex: Vector2i) -> CombatSim:
	var errors: Array[String] = []
	var formation: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": maren_hex, "vell": Vector2i(3, 1)}
	var setup: FightSetup = Encounters.setup(_content, encounter_id, formation, 7, errors, {}, {"maren": path_id} as Dictionary[String, String],
		["maren"] as Array[String], {}, {"maren": apex_id} as Dictionary[String, String], ["maren"] as Array[String])
	assert_eq(errors, [] as Array[String])
	return CombatSim.new(setup, _content)


func _run(sim: CombatSim) -> CombatSim:
	while not sim.finished:
		sim.step()
	return sim


func test_an_execution_finishes_a_target_left_below_its_share() -> void:
	var executions: int = 0
	var refills: int = 0
	for encounter_id: String in _content.encounter_ids:
		var sim: CombatSim = _apex_fight(encounter_id, "deadeye", "eagle_eye", Vector2i(0, 0))
		var maren: UnitState = sim.unit_by_id("maren")
		while not sim.finished:
			var from: int = sim.combat_log.entries.size()
			sim.step()
			for i: int in range(from, sim.combat_log.entries.size()):
				var entry: LogEntry = sim.combat_log.entries[i]
				if entry.note != "executed":
					continue
				executions += 1
				assert_eq([entry.kind, entry.source_unit, entry.source_ability], [LogEntry.Kind.DAMAGE, "maren", "heartseeker"])
				var victim: UnitState = sim.unit_by_id(entry.target)
				assert_eq(victim.hp, 0, "finished")
				assert_true(victim.executed)
				# Just before it: Heartseeker's own hit left it below 20%.
				var hit: LogEntry = sim.combat_log.entries[i - 1]
				assert_eq([hit.kind, hit.target, hit.source_ability], [LogEntry.Kind.DAMAGE, entry.target, "heartseeker"])
				assert_true(entry.amount * FixedMath.BP_ONE < 2000 * victim.max_hp, "below 20%")
				# Hunter's Return refills her bar as the kill is credited.
				if maren.mana == maren.def.mana.max * Mana.SCALE:
					refills += 1
		if executions >= 3:
			break
	assert_gt(executions, 0, "Heartseeker executes")
	assert_gt(refills, 0, "an execution refills her mana")


func test_a_kills_deed_counts_only_its_abilitys_kills() -> void:
	var sim: CombatSim = _run(_apex_fight("pup_warren", "deadeye", "eagle_eye", Vector2i(0, 0)))
	var by_heartseeker: int = 0
	var by_maren: int = 0
	for entry: LogEntry in sim.combat_log.of_kind(LogEntry.Kind.DEATH):
		var fallen: UnitState = sim.unit_by_id(entry.target)
		if fallen.last_attacker == "maren":
			by_maren += 1
			if fallen.last_hit_source.ability_id == "heartseeker":
				by_heartseeker += 1
	assert_gt(by_maren, by_heartseeker, "she kills with her shots too")
	assert_eq(CombatSim.result_of(sim).deed_amount("maren", "eagle_eye"), by_heartseeker)


func test_a_line_hits_each_enemy_it_passes_harder() -> void:
	var checked: int = 0
	for encounter_id: String in _content.encounter_ids:
		var sim: CombatSim = _run(_apex_fight(encounter_id, "deadeye", "stormline", Vector2i(0, 0)))
		for landed: LogEntry in sim.combat_log.of_kind(LogEntry.Kind.AREA_LANDED):
			if landed.source_ability != "heartseeker" or landed.amount < 2:
				continue
			var powers: Array[int] = []
			for entry: LogEntry in sim.combat_log.of_kind(LogEntry.Kind.DAMAGE):
				if entry.tick == landed.tick and entry.source_ability == "heartseeker" and entry.note.is_empty():
					powers.append(entry.rule_power)
			powers.sort()
			for i: int in powers.size():
				assert_eq(powers[i] - powers[0], 1000 * i, "+10%% for each enemy passed (%s)" % encounter_id)
			checked += 1
		if checked >= 3:
			break
	assert_gt(checked, 0, "a line hit several enemies")


func test_windrunner_hops_every_third_shot_and_counts_shots_after_a_hop() -> void:
	var sim: CombatSim = _run(_apex_fight("the_pack", "volley", "windrunner", Vector2i(4, 0)))
	var shots: int = 0
	var hops: int = 0
	var tailwinds: int = 0
	for entry: LogEntry in sim.combat_log.entries:
		if entry.source_unit != "maren":
			continue
		if entry.kind == LogEntry.Kind.FIRE and entry.source_ability == "longshot":
			shots += 1
		if entry.kind == LogEntry.Kind.HOP and entry.source_ability == "longshot":
			hops += 1
		if entry.kind == LogEntry.Kind.STATUS_APPLIED and entry.status == "tailwind":
			tailwinds += 1
	assert_gt(hops, 0, "she hops")
	assert_true(hops <= shots / 3, "at most every 3rd shot")
	assert_true(tailwinds >= hops, "a Tailwind stack each hop (her own hop away too)")
	# The deed: hits from her shots within 1s (20 ticks) of her last hop.
	var last_hop: int = -1
	var counted: int = 0
	for entry: LogEntry in sim.combat_log.entries:
		if entry.source_unit != "maren":
			continue
		if entry.kind == LogEntry.Kind.HOP:
			last_hop = entry.tick
		elif entry.kind == LogEntry.Kind.DAMAGE and entry.source_ability == "longshot" and last_hop >= 0 and entry.tick - last_hop <= 20:
			if sim.unit_by_id(entry.target).side != EffectSource.Team.HEROES:
				counted += 1
	assert_gt(counted, 0)
	assert_eq(CombatSim.result_of(sim).deed_amount("maren", "windrunner"), counted)


func test_a_patch_sets_a_hoppers_cooldown() -> void:
	var windrunner: ApexDef = _content.apexes["windrunner"]
	assert_eq([_content.paths["volley"].transformed_kit.hop_cooldown_ticks, windrunner.vowed_kit.hop_cooldown_ticks], [120, 100], "1s sooner")
	var patch: KitPatch = KitPatch.make()
	patch.hop_cooldown_ticks = 100
	var problems: Array[String] = []
	patch.apply(_content.heroes["brannoc"].kit, problems)
	assert_eq(problems, ["only a unit that hops away has a hop cooldown"] as Array[String])


## A sim of `encounter_id` with Vell transformed into `path_id` and at
## `apex_id`'s apex, stepped to its end.
func _vell_fight(encounter_id: String, path_id: String, apex_id: String) -> CombatSim:
	var errors: Array[String] = []
	var formation: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": Vector2i(4, 0), "vell": Vector2i(3, 1)}
	var setup: FightSetup = Encounters.setup(_content, encounter_id, formation, 7, errors, {}, {"vell": path_id} as Dictionary[String, String],
		["vell"] as Array[String], {}, {"vell": apex_id} as Dictionary[String, String], ["vell"] as Array[String])
	assert_eq(errors, [] as Array[String])
	return _run(CombatSim.new(setup, _content))


func _of(sim: CombatSim, kind: LogEntry.Kind, unit_id: String, ability_id: String = "") -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in sim.combat_log.of_kind(kind):
		if entry.source_unit == unit_id and (ability_id.is_empty() or entry.source_ability == ability_id):
			found.append(entry)
	return found


func test_a_zone_stands_only_so_many_at_once() -> void:
	var checked: int = 0
	for encounter_id: String in _content.encounter_ids:
		var sim: CombatSim = _vell_fight(encounter_id, "vigil_keeper", "sanctifier")
		var casts: int = _of(sim, LogEntry.Kind.FIRE, "vell", "sunfall").size()
		var grounds: int = _of(sim, LogEntry.Kind.ZONE, "vell", "sunfall").size()
		assert_eq(grounds, mini(casts, 4), "a line of hallowed ground a cast, up to 4 (%s)" % encounter_id)
		if casts > 4:
			checked += 1
	assert_gt(checked, 0, "some fight cast Sunfall more than 4 times")


func test_a_signature_grows_with_each_cast() -> void:
	var sim: CombatSim = _vell_fight("bog_crossing", "lanternbearer", "the_beacon")
	var powers: Array[int] = []
	for entry: LogEntry in _of(sim, LogEntry.Kind.HEAL, "vell", "night_lantern"):
		if not powers.has(entry.rule_power):
			powers.append(entry.rule_power)
	powers.sort()
	assert_gt(powers.size(), 2, "several lanterns")
	for i: int in powers.size():
		assert_eq(powers[i] - powers[0], 1000 * i, "each lantern 10%% stronger than the last")


func test_every_ally_hears_a_shield_break() -> void:
	var heard: int = 0
	for encounter_id: String in _content.encounter_ids:
		var sim: CombatSim = _vell_fight(encounter_id, "wardweaver", "thornweave")
		var breaks: int = 0
		for entry: LogEntry in sim.combat_log.entries:
			var hit: bool = entry.kind == LogEntry.Kind.DAMAGE or entry.kind == LogEntry.Kind.STATUS_DAMAGE
			if hit and entry.broke_shield and sim.unit_by_id(entry.target).side == EffectSource.Team.HEROES:
				breaks += 1
		var stacks: int = 0
		for entry: LogEntry in _of(sim, LogEntry.Kind.STATUS_APPLIED, "vell"):
			if entry.status == "woven_thorns":
				stacks += 1
		assert_true(stacks <= breaks, "a stack a break heard (%s)" % encounter_id)
		heard += stacks
		if breaks > 0:
			assert_gt(_of(sim, LogEntry.Kind.DAMAGE, "vell", "thornweave").size(), 0, "the breaker is hit back (%s)" % encounter_id)
	assert_gt(heard, 0)


func test_a_link_splits_a_hit_over_the_linked() -> void:
	var shared_total: int = 0
	for encounter_id: String in _content.encounter_ids:
		var sim: CombatSim = _vell_fight(encounter_id, "wardweaver", "loomwarden")
		var shared: Array[LogEntry] = _of(sim, LogEntry.Kind.SHARED, "vell", "loom")
		var total: int = 0
		for entry: LogEntry in shared:
			total += entry.amount
			assert_ne(entry.target, entry.note, "the part goes to another ally")
			var first: UnitState = sim.unit_by_id(entry.note)
			assert_eq(first.side, EffectSource.Team.HEROES)
		assert_eq(CombatSim.result_of(sim).deed_amount("vell", "loomwarden"), total, "the deed counts what's shared (%s)" % encounter_id)
		shared_total += total
	assert_gt(shared_total, 0)


func test_a_links_shared_damage_buys_iron_loom() -> void:
	# Loomwarden's link with a smaller step, so a fight reaches it.
	var link: PartDef = null
	for part: PartDef in _content.apexes["loomwarden"].apex_kit.passives:
		if part.kind == PartDef.Kind.LINK:
			link = part
	var per_shared: int = link.per_shared
	link.per_shared = 10
	var stacks: int = 0
	var shared: int = 0
	for encounter_id: String in _content.encounter_ids:
		var sim: CombatSim = _vell_fight(encounter_id, "wardweaver", "loomwarden")
		shared += sim.unit_by_id("vell").link_shared
		for entry: LogEntry in _of(sim, LogEntry.Kind.STATUS_APPLIED, "vell", "loom"):
			if entry.status == "iron_loom":
				stacks += 1
	link.per_shared = per_shared
	assert_gt(shared, 10)
	assert_gt(stacks, 0, "Iron Loom stacks as the link shares")


func test_an_applied_deed_can_count_its_statuses_on_allies() -> void:
	var sim: CombatSim = _vell_fight("bog_crossing", "lanternbearer", "dawnbringer")
	var applied: int = 0
	var first_light: int = 0
	for entry: LogEntry in _of(sim, LogEntry.Kind.STATUS_APPLIED, "vell"):
		if entry.status == "dawnlight" or entry.status == "morning_haste":
			applied += 1
		if entry.status == "first_light":
			first_light += 1
	assert_gt(applied, 0)
	assert_eq(CombatSim.result_of(sim).deed_amount("vell", "dawnbringer"), applied)
	assert_gt(first_light, 0, "healing a sped-up ally makes them faster for the fight")


func test_a_smite_kill_feeds_zeal() -> void:
	var zeal: int = 0
	var smite_kills: int = 0
	for encounter_id: String in _content.encounter_ids:
		var sim: CombatSim = _vell_fight(encounter_id, "vigil_keeper", "inquisitor")
		for entry: LogEntry in sim.combat_log.of_kind(LogEntry.Kind.DEATH):
			var fallen: UnitState = sim.unit_by_id(entry.target)
			if fallen.last_attacker == "vell" and fallen.last_hit_source.ability_id == "mend":
				smite_kills += 1
		for entry: LogEntry in _of(sim, LogEntry.Kind.STATUS_APPLIED, "vell"):
			if entry.status == "zeal":
				zeal += 1
	assert_gt(smite_kills, 0)
	assert_eq(zeal, smite_kills, "a Zeal stack for each smite kill")
