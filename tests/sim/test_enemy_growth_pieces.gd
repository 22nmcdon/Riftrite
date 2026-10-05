extends GutTest
## The sim pieces of Act 3's enemy growth (docs/plans/rebuild-phase8-act3.md,
## part 8c-5a): the upgrades' aura stats (Shieldbreaker's damage to Shields,
## Watchful's sight, Cinder-Skinned, Mark-Shy, Anchored's cap on Roots) and
## Festering's cut to healing, and Engage reaching farther (the Warden Sentinel), each in a small fight, with
## the real upgrades from data/enemy_upgrades.json.

const K = preload("res://tests/sim/sim_test_kit.gd")

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


static func still(unit_id: String, extra: Dictionary = {}) -> UnitDef:
	var data: Dictionary = {"stats": {"hp": 1000, "atk": 10, "speed": 0, "range": 3},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}
	for key: String in extra:
		if key == "stats":
			(data["stats"] as Dictionary).merge(extra["stats"], true)
		else:
			data[key] = extra[key]
	return K.kit(unit_id, data)


func _upgraded(kit: UnitDef, upgrade_id: String) -> UnitDef:
	var problems: Array[String] = []
	var built: UnitDef = _content.enemy_upgrades[upgrade_id].apply(kit, problems)
	assert_eq(problems, [] as Array[String])
	return built


func _from(unit_id: String) -> EffectSource:
	return EffectSource.make(unit_id, unit_id + "_attack", "Strike")


## A fight of one still hero against `foes` (enemy kits on row 4 and up).
func _fight(hero: UnitDef, foes: Array[UnitDef]) -> CombatSim:
	var enemies: Array[UnitSetup] = []
	for i: int in foes.size():
		enemies.append(K.foe(foes[i], 2 + i, 4, foes[i].id if i == 0 else "%s#%d" % [foes[i].id, i + 1]))
	return K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], enemies))


func test_the_upgrades_are_data() -> void:
	assert_eq(_content.enemy_upgrade_ids, ["frenzied", "warded", "swift", "rift_touched", "thick_hided", "vengeful", "anchored", "watchful", "cinder_skinned",
		"shieldbreaker", "mark_shy", "festering"] as Array[String], "enemy-growth.md section 3's eleven, and Festering (Question CM)")
	var hound: UnitDef = _content.enemies["rift_hound"].kit
	var frenzied: UnitDef = _upgraded(hound, "frenzied")
	assert_eq([frenzied.name, frenzied.upgrades], ["Frenzied Rift Hound", ["frenzied"]])
	var both: UnitDef = _upgraded(frenzied, "warded")
	assert_eq([both.name, both.upgrades], ["Warded Frenzied Rift Hound", ["frenzied", "warded"]])
	assert_eq([hound.name, hound.upgrades], ["Rift Hound", [] as Array[String]], "the enemy's own kit is untouched")
	assert_eq(_upgraded(hound, "swift").stats.get_stat(UnitStats.Stat.SPEED), hound.stats.get_stat(UnitStats.Stat.SPEED) + 1, "Swift: +1 speed")
	assert_eq(_upgraded(hound, "thick_hided").stats.get_stat(UnitStats.Stat.DEF), FixedMath.apply_bp(hound.stats.get_stat(UnitStats.Stat.DEF), 12000), "Thick-Hided: +20% DEF")
	var caster: UnitDef = _content.enemies["cinder_moth"].kit
	assert_not_null(caster.mana, "a kit with a mana bar")
	assert_eq(_upgraded(caster, "rift_touched").mana.max, caster.mana.max * 4 / 5, "Rift-Touched: a fifth smaller bar, so 25% faster")
	var no_bar: UnitDef = still("no_bar")
	assert_false(_content.enemy_upgrades["rift_touched"].changes(no_bar), "Rift-Touched changes nothing without a mana bar")
	assert_true(_content.enemy_upgrades["frenzied"].changes(no_bar))


func test_shieldbreaker_takes_more_off_a_shield() -> void:
	for upgraded: bool in [false, true]:
		var striker: UnitDef = still("striker", {"stats": {"range": 3}, "basic_attack": {"cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 20, "target": "target"}]}})
		if upgraded:
			striker = _upgraded(striker, "shieldbreaker")
		var fight: CombatSim = _fight(still("hero"), [striker] as Array[UnitDef])
		var hero: UnitState = fight.unit_by_id("hero")
		hero.shield = 100
		while K.entries(fight, LogEntry.Kind.DAMAGE, "striker").is_empty():
			fight.step()
		var hit: LogEntry = K.entries(fight, LogEntry.Kind.DAMAGE, "striker")[0]
		assert_eq([hit.amount, hit.absorbed, hero.shield, hero.hp], [20, 20, 70 if upgraded else 80, 1000], "Shieldbreaker: +50% off a Shield" if upgraded else "a plain hit")
	# What's left of the hit goes to HP at full strength.
	var breaker: UnitDef = _upgraded(still("breaker", {"basic_attack": {"cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 20, "target": "target"}]}}), "shieldbreaker")
	var fight: CombatSim = _fight(still("hero"), [breaker] as Array[UnitDef])
	var hero: UnitState = fight.unit_by_id("hero")
	hero.shield = 15
	while K.entries(fight, LogEntry.Kind.DAMAGE, "breaker").is_empty():
		fight.step()
	assert_eq([K.entries(fight, LogEntry.Kind.DAMAGE, "breaker")[0].absorbed, hero.shield, hero.hp], [10, 0, 990], "15 Shield soaks 10 of the hit")


func test_festering_cuts_the_healing_of_the_hero_it_hits() -> void:
	for upgraded: bool in [false, true]:
		var striker: UnitDef = still("striker", {"basic_attack": {"cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 5, "target": "target"}]}})
		if upgraded:
			striker = _upgraded(striker, "festering")
		var fight: CombatSim = _fight(still("hero"), [striker] as Array[UnitDef])
		var hero: UnitState = fight.unit_by_id("hero")
		while K.entries(fight, LogEntry.Kind.DAMAGE, "striker").is_empty():
			fight.step()
		fight.step()
		assert_eq(hero.statuses.any(func(state: StatusState) -> bool: return state.def.id == "festering"), upgraded, "Festering on the hero it hit" if upgraded else "none without it")
		hero.hp = 500
		EffectRunner.heal(fight, hero, 100, _from("hero"))
		assert_eq(hero.hp, 570 if upgraded else 600, "healed 30% less while Festering" if upgraded else "a plain heal")


func test_watchful_picks_a_stealthed_hero() -> void:
	for upgraded: bool in [false, true]:
		var watcher: UnitDef = still("watcher")
		if upgraded:
			watcher = _upgraded(watcher, "watchful")
		var fight: CombatSim = _fight(still("hero"), [watcher] as Array[UnitDef])
		Statuses.apply(fight, fight.unit_by_id("hero"), "stealth", 1, 200, _from("hero"))
		K.step(fight, 10)
		var target: UnitState = fight.unit_by_id("watcher").target
		if upgraded:
			assert_true(target != null and target.id == "hero", "Watchful: it picks the stealthed hero")
		else:
			assert_null(target, "nothing picks a stealthed hero")


func test_cinder_skinned_halves_burn() -> void:
	var fight: CombatSim = _fight(still("hero"), [still("plain"), _upgraded(still("skinned"), "cinder_skinned")] as Array[UnitDef])
	for unit_id: String in ["plain", "skinned#2"]:
		Statuses.apply(fight, fight.unit_by_id(unit_id), "burn", 40, 0, _from("hero"))
	K.step(fight, 20)
	var burns: Array[LogEntry] = K.entries(fight, LogEntry.Kind.STATUS_DAMAGE)
	var plain: Array[LogEntry] = burns.filter(func(entry: LogEntry) -> bool: return entry.target == "plain")
	var skinned: Array[LogEntry] = burns.filter(func(entry: LogEntry) -> bool: return entry.target == "skinned#2")
	assert_false(plain.is_empty())
	assert_eq(skinned.size(), plain.size())
	assert_eq(skinned[0].amount, plain[0].amount / 2, "half as much")
	assert_eq([skinned[0].note, plain[0].note], ["cinder-skinned", ""])


func test_mark_shy_and_anchored_shorten_marks_and_roots() -> void:
	var anchored: UnitDef = _upgraded(still("anchored"), "anchored")
	var fight: CombatSim = _fight(still("hero"), [still("plain"), _upgraded(still("shy"), "mark_shy"), anchored] as Array[UnitDef])
	fight.step()
	var applied: Callable = func(unit_id: String, status_id: String) -> int:
		var found: Array[LogEntry] = K.entries(fight, LogEntry.Kind.STATUS_APPLIED).filter(func(entry: LogEntry) -> bool: return entry.target == unit_id and entry.status == status_id)
		return found[-1].end_tick - found[-1].tick
	for unit_id: String in ["plain", "shy#2", "anchored#3"]:
		Statuses.apply(fight, fight.unit_by_id(unit_id), "marked", 0, 0, _from("hero"))
		Statuses.apply(fight, fight.unit_by_id(unit_id), "root", 0, 60, _from("hero"))
	assert_eq([applied.call("plain", "marked"), applied.call("shy#2", "marked"), applied.call("anchored#3", "marked")], [80, 40, 80], "Mark-Shy: Marks last half as long")
	assert_eq([applied.call("plain", "root"), applied.call("shy#2", "root"), applied.call("anchored#3", "root")], [60, 60, 20], "Anchored: Roots last at most 1s")
	var anchored_unit: UnitState = fight.unit_by_id("anchored#3")
	var before: Vector2i = anchored_unit.pos
	Displacement.push(fight, anchored_unit, Vector2i(0, ArenaPlane.DIR), 1000, _from("hero"), "knocked back")
	assert_eq(anchored_unit.pos, before, "Anchored: it can't be knocked back")
	assert_eq(K.entries(fight, LogEntry.Kind.RESISTED).filter(func(entry: LogEntry) -> bool: return entry.target == "anchored#3").size(), 1)


func test_frenzied_warded_and_vengeful() -> void:
	var fight: CombatSim = _fight(still("hero"), [_upgraded(_upgraded(still("elite"), "frenzied"), "warded"), _upgraded(still("vengeful"), "vengeful"), still("near"),
		still("far")] as Array[UnitDef])
	K.step(fight, 2)
	var elite: UnitState = fight.unit_by_id("elite")
	assert_eq(elite.shield, 150, "Warded: a Shield of 15% of its max HP")
	assert_eq(elite.aura_bp[AuraDef.Stat.ATSP], 0, "Frenzied: not yet")
	elite.hp = 400
	K.step(fight, 1)
	assert_eq(elite.aura_bp[AuraDef.Stat.ATSP], 30, "Frenzied: +30 attack speed below half its HP")
	# The vengeful one stands at (3, 4); "near" at (4, 4) and "elite" at (2, 4)
	# are a hex away, "far" at (5, 4) two.
	var far: UnitState = fight.unit_by_id("far#4")
	far.pos = fight.grid.center(7, 6)
	fight.unit_by_id("vengeful#2").hp = 0
	K.step(fight, 2)
	assert_not_null(Statuses.find(fight.unit_by_id("near#3"), "vengeance"), "Vengeful: allies within 2 hexes")
	assert_not_null(Statuses.find(elite, "vengeance"))
	assert_null(Statuses.find(far, "vengeance"), "not those farther")
	assert_eq(fight.unit_by_id("near#3").aura_bp[AuraDef.Stat.ATK_BP], 12000, "+20% ATK")


func test_engage_reaches_farther() -> void:
	for reach_add: int in [0, 1]:
		var engager: UnitDef = still("engager", {"traits": ["engage"]})
		if reach_add > 0:
			var errors: Array[String] = []
			var mod: KitMod = KitMod.read(DataReader.new({"engage": {"reach_add": reach_add}}, "mod", errors))
			assert_eq(errors, [] as Array[String])
			engager = mod.apply(engager)
		# The hero walks in from two hexes away: an engager is next to it from
		# there only with a reach of 2.
		var walker: UnitDef = still("hero", {"stats": {"speed": 2, "range": 1}})
		var fight: CombatSim = K.sim(K.fight([K.at(walker, 3, 2)] as Array[UnitSetup], [K.foe(engager, 3, 4)] as Array[UnitSetup]))
		K.step(fight, 2)
		assert_eq(fight.unit_by_id("hero").engagements.size(), reach_add, "engaged from 2 hexes" if reach_add > 0 else "not yet")


func _specialized(enemy_id: String, spec_id: String) -> UnitDef:
	var spec: SpecializationDef = _content.specializations[spec_id]
	assert_eq(spec.enemy, enemy_id)
	var problems: Array[String] = []
	var built: UnitDef = spec.apply(_content.enemies[enemy_id].kit, problems)
	assert_eq(problems, [] as Array[String])
	return built


## The returning enemies' specializations (rebuild-phase8-act3.md section 2)
## that 8c-5a builds, in small fights against still heroes.
func test_the_returning_specializations() -> void:
	# Pinning: its shots Root.
	var fight: CombatSim = K.sim(K.fight([K.at(still("hero"), 3, 2)] as Array[UnitSetup], [K.foe(_specialized("hollow_archer", "pinning_archer"), 3, 5)] as Array[UnitSetup]))
	while K.entries(fight, LogEntry.Kind.DAMAGE, "hollow_archer").is_empty() and fight.tick < 200:
		fight.step()
	K.step(fight, 1)
	assert_not_null(Statuses.find(fight.unit_by_id("hero"), "root"), "Pinning: the hero it shot is Rooted")
	# Volley: a line through every hero toward its target.
	fight = K.sim(K.fight([K.at(still("front"), 3, 2), K.at(still("back"), 3, 0)] as Array[UnitSetup], [K.foe(_specialized("hollow_archer", "volley_archer"), 3, 5)] as Array[UnitSetup]))
	K.step(fight, 120)
	var hit: Array = K.entries(fight, LogEntry.Kind.DAMAGE, "hollow_archer").map(func(entry: LogEntry) -> String: return entry.target)
	assert_true(hit.has("front") and hit.has("back"), "Volley: the hero behind is hit too: %s" % [hit])
	# Ashback: its Pounce leaves burning ground.
	fight = K.sim(K.fight([K.at(still("hero"), 3, 2)] as Array[UnitSetup], [K.foe(_specialized("rift_hound", "ashback_hound"), 3, 5)] as Array[UnitSetup]))
	K.step(fight, 30)
	assert_false(K.entries(fight, LogEntry.Kind.ZONE, "rift_hound").is_empty(), "Ashback: a zone where it lands")
	assert_true(K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "rift_hound").any(func(entry: LogEntry) -> bool: return entry.status == "burn" and entry.target == "hero"), "the hero Burns")
	# Warden: Engage reaches 2 hexes.
	assert_eq(_specialized("rift_worn_sentinel", "warden_sentinel").engage_reach_add, HexGrid.HEX)
	# Shattered: a Slowing burst as it falls.
	fight = K.sim(K.fight([K.at(still("hero"), 3, 2), K.at(still("away"), 7, 0)] as Array[UnitSetup], [K.foe(_specialized("rift_worn_sentinel", "shattered_sentinel"), 3, 4)] as Array[UnitSetup]))
	K.step(fight, 1)
	fight.unit_by_id("rift_worn_sentinel").hp = 0
	K.step(fight, 2)
	assert_not_null(Statuses.find(fight.unit_by_id("hero"), "slow"), "Shattered: heroes within 2 hexes are Slowed")
	assert_null(Statuses.find(fight.unit_by_id("away"), "slow"), "not those farther")


# --- 8c-5c-2: misses, drifting dust, leaping back out ------------------------

func test_ember_blind_attacks_miss_some_of_the_time() -> void:
	var striker: UnitDef = still("striker", {"basic_attack": {"cooldown_ms": 50, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}})
	var fight: CombatSim = _fight(still("hero"), [striker] as Array[UnitDef])
	fight.step()
	Statuses.apply(fight, fight.unit_by_id("striker"), "ember_blind", 1, 0, _from("hero"))
	assert_eq(fight.unit_by_id("striker").aura_bp[AuraDef.Stat.MISS_BP], 3000)
	# Only its basic attack's hits miss: a signature's never do.
	for i: int in 40:
		EffectRunner.deal_hit(fight, EffectSource.make("striker", "boom", "Boom"), fight.unit_by_id("hero"), 1, false)
	assert_eq(K.entries(fight, LogEntry.Kind.DODGED, "striker"), [] as Array[LogEntry], "a signature's hit never misses")
	K.step(fight, 60)
	var missed: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DODGED, "striker").filter(func(entry: LogEntry) -> bool: return entry.note == "missed")
	var hits: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "striker")
	assert_between(missed.size(), 5, 35, "about 30%% of %d attacks" % (missed.size() + hits.size()))
	assert_gt(hits.size(), missed.size())
	assert_string_contains(missed[0].to_text(), "(dazzled)")
	var after: int = missed[-1].tick
	K.step(fight, 60)
	var later: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DODGED, "striker").filter(func(entry: LogEntry) -> bool: return entry.tick > after + 1 and entry.tick > 3 * 20 + 1)
	assert_eq(later, [] as Array[LogEntry], "none once it's gone")


func test_the_moths_dust_drifts_and_dazzles() -> void:
	for spec_id: String in ["drifting_moth", "dazzling_moth"]:
		var moth: UnitDef = _specialized("cinder_moth", spec_id)
		var fight: CombatSim = K.sim(K.fight([K.at(still("near"), 2, 2), K.at(still("far"), 6, 0)] as Array[UnitSetup], [K.foe(moth, 3, 5)] as Array[UnitSetup]))
		fight.step()
		var unit: UnitState = fight.unit_by_id("cinder_moth")
		unit.mana = unit.mana_cap
		K.step(fight, 3)
		# The hero it was cast at steps away, so the dust has somewhere to go.
		fight.unit_by_id("near").pos = fight.grid.center(0, 1)
		K.step(fight, 60)
		if spec_id == "drifting_moth":
			var drifts: Array[LogEntry] = K.entries(fight, LogEntry.Kind.AREA_LANDED, "cinder_moth").filter(func(entry: LogEntry) -> bool: return entry.note == "moved")
			assert_false(drifts.is_empty(), "the dust drifts")
			assert_true(K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "cinder_moth").any(func(entry: LogEntry) -> bool: return entry.status == "burn" and entry.amount == 1), "burning as it passes")
		else:
			assert_true(K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "cinder_moth").any(func(entry: LogEntry) -> bool: return entry.status == "ember_blind"), "the heroes caught are Ember-Blind")


func test_a_zone_follows_the_nearest_enemy() -> void:
	var caster: UnitDef = still("caster", {"stats": {"range": 9}, "signature": {"id": "dust", "name": "Dust", "trigger": {"kind": "fight_start"}, "targeting": "nearest", "max_range": 9,
		"effects": [{"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "target", "duration_ms": 3000, "every_ms": 500, "follows": "nearest", "hits": "enemies",
			"effects": [{"type": "damage", "amount": 1, "target": "target"}]}]}})
	var setup: FightSetup = K.fight([K.at(still("near"), 3, 2), K.at(still("crowd"), 7, 0), K.at(still("crowd2"), 6, 0)] as Array[UnitSetup], [K.foe(caster, 3, 5)] as Array[UnitSetup])
	var fight: CombatSim = K.sim(setup)
	fight.step()
	var near: UnitState = fight.unit_by_id("near")
	near.pos = fight.grid.center(0, 1)
	K.step(fight, 40)
	var landed: Array[LogEntry] = K.entries(fight, LogEntry.Kind.AREA_LANDED, "caster")
	assert_gt(landed.size(), 3)
	assert_lt(ArenaPlane.distance(landed[-1].from_pos, near.pos), ArenaPlane.distance(landed[0].from_pos, near.pos), "toward the hero nearest it, not the biggest group")


func test_the_gloam_hound_leaps_back_out_and_pounces_again() -> void:
	var hound: UnitDef = _specialized("rift_hound", "gloam_hound")
	var fight: CombatSim = K.sim(K.fight([K.at(still("front"), 3, 2), K.at(still("back"), 4, 0)] as Array[UnitSetup], [K.foe(hound, 3, 5)] as Array[UnitSetup]))
	var start: Vector2i = fight.unit_by_id("rift_hound").pos
	K.step(fight, 20 * 12)
	var fires: Array[LogEntry] = K.entries(fight, LogEntry.Kind.FIRE, "rift_hound").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "pounce")
	assert_eq(fires.size(), 2, "at the start, and again at 8s")
	assert_eq(fires[1].tick, 160)
	assert_eq(fires[1].note, "again")
	var homes: Array[LogEntry] = K.entries(fight, LogEntry.Kind.LEAP, "rift_hound").filter(func(entry: LogEntry) -> bool: return entry.note == "back to where it started")
	assert_eq(homes.size(), 2)
	assert_eq(homes[0].tick, fires[0].tick + 60, "3s after the first Pounce")
	assert_eq(homes[1].tick, fires[1].tick + 60)
	assert_true(ArenaPlane.distance(homes[0].to_pos, start) <= 300, "back where it started")
	assert_eq([homes[0].source_ability, homes[0].target], ["gloam_return", "rift_hound"])


func test_a_delayed_effect_waits_and_needs_its_unit_standing() -> void:
	var hound: UnitDef = _specialized("rift_hound", "gloam_hound")
	var fight: CombatSim = K.sim(K.fight([K.at(still("front"), 3, 2), K.at(still("back"), 4, 0)] as Array[UnitSetup], [K.foe(hound, 3, 5), K.foe(still("other"), 6, 6)] as Array[UnitSetup]))
	K.step(fight, 20)
	assert_eq(fight.delayed.size(), 1, "the leap back waits")
	fight.unit_by_id("rift_hound").hp = 0
	K.step(fight, 60)
	assert_eq(fight.delayed.size(), 0)
	assert_false(K.entries(fight, LogEntry.Kind.LEAP, "rift_hound").any(func(entry: LogEntry) -> bool: return entry.note == "back to where it started"), "not once it has fallen")


func test_the_new_words() -> void:
	var hound: UnitDef = _specialized("rift_hound", "gloam_hound")
	var leap_back: EffectDef = hound.passives[-1].ability.effects[0]
	assert_eq(UnitInfo.passive_trigger_text(leap_back), "Every ability, 3s later")
	var mod: KitMod = _content.specializations["gloam_hound"].mod
	var parts: Array[String] = ModInfo.mod_parts(mod, _content.enemies["rift_hound"].kit, _content)
	assert_true(parts.has("Signature also fires: every 8s"), str(parts))
	for data: Dictionary in [{"type": "leap", "to": "start", "target": "target"}, {"trigger": "on_fire", "type": "damage", "amount": 1, "target": "target", "delay_ms": 1000}]:
		var errors: Array[String] = []
		EffectDef.read(DataReader.new(data, "test", errors))
		assert_false(errors.is_empty(), "refused: %s" % data)
