extends GutTest
## The apex cards (docs/plans/rebuild-phase8-apexes.md, part 8b-4; apexes.md's
## two upgrades for each apex): every apex has two; they're offered only once
## that apex is earned and count only on it; the knobs they needed change
## what they name; and on_rise sets off Dread Return in a fight.

const FORMATION: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": Vector2i(4, 0), "vell": Vector2i(3, 1)}

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func _cards_of(apex_id: String) -> Array[String]:
	return _run.upgrade_ids.filter(func(id: String) -> bool: return _run.upgrades[id].apex == apex_id)


## `card_id`'s mod on its apex's kit.
func _on_apex(card_id: String) -> UnitDef:
	var card: UpgradeDef = _run.upgrades[card_id]
	var problems: Array[String] = []
	var kit: UnitDef = card.mod.apply(_run.content.apexes[card.apex].apex_kit, problems)
	assert_eq(problems, [] as Array[String], card_id)
	return kit


func _part(kit: UnitDef, part_id: String) -> PartDef:
	for part: PartDef in kit.passives:
		if part.id == part_id:
			return part
	return null


func test_every_apex_has_two_cards_of_its_hero() -> void:
	for apex_id: String in _run.content.apex_ids:
		var cards: Array[String] = _cards_of(apex_id)
		assert_eq(cards.size(), 2, apex_id)
		var apex: ApexDef = _run.content.apexes[apex_id]
		for id: String in cards:
			assert_eq([_run.upgrades[id].layer, _run.upgrades[id].path, _run.upgrades[id].hero],
				[UpgradeDef.Layer.APEX, apex.path, _run.content.paths[apex.path].hero], id)


func test_apex_cards_wait_for_their_apex() -> void:
	var maren := RunState.Hero.new()
	maren.id = "maren"
	maren.path = "volley"
	maren.transformed = true
	assert_false(_run.upgrades_for(maren).has("endless_hail"), "not before the apex")
	maren.apex = "hailstorm"
	assert_false(_run.upgrades_for(maren).has("endless_hail"), "not while only vowed")
	maren.apex_earned = true
	assert_true(_run.upgrades_for(maren).has("endless_hail"))
	assert_false(_run.upgrades_for(maren).has("gale"), "not another apex's")
	maren.upgrades.append("endless_hail")
	assert_true(_run.held_upgrades(maren).any(func(card: UpgradeDef) -> bool: return card.id == "endless_hail"))
	maren.apex_earned = false
	assert_false(_run.held_upgrades(maren).any(func(card: UpgradeDef) -> bool: return card.id == "endless_hail"), "it counts only at its apex")


func test_the_apex_cards_knobs() -> void:
	assert_eq(_part(_on_apex("hot_iron"), "forge_blast").ability.effects[1].at_stacks, 4, "Hot Iron: 4 brands")
	assert_eq(_on_apex("gatehouse").signature.effects[0].width_range, 5 * HexGrid.HEX, "Gatehouse: a hex wider")
	assert_eq(_part(_on_apex("deeper_hearth"), "hearthkeeper").ability.effects[0].overheal_max_hp_per, 5, "Deeper Hearth: every 5 overheal")
	var stormline: UnitDef = _run.content.apexes["stormline"].apex_kit
	assert_eq(_on_apex("gathering_line").signature.effects[0].per_enemy_bp, stormline.signature.effects[0].per_enemy_bp + 500, "Gathering Line: +5% more an enemy")
	assert_eq(_on_apex("war_cry").signature.grows_boosts_bp, 5000, "War Cry: the rally grows faster")
	assert_eq(_on_apex("rising_light").signature.grows_bp, 2000, "Rising Light: each lantern +20%")
	var undying: UnitDef = _run.content.apexes["undying_oath"].apex_kit
	assert_eq(_part(_on_apex("stubborn_flame"), "undying_oath").rise_hp_bp, _part(undying, "undying_oath").rise_hp_bp + 2000, "Stubborn Flame: rises with 20% more")
	var loom: UnitDef = _run.content.apexes["loomwarden"].apex_kit
	assert_eq(_part(_on_apex("iron_loom"), "loom").per_shared, _part(loom, "loom").per_shared / 2, "Iron Loom: twice as often")
	var bonfire: EffectDef = _part(_on_apex("bonfire"), "martyrs_pyre").ability.effects[0].area_effects[0]
	assert_eq(bonfire.power_per_taken_bp, 1500, "Bonfire: +15% per 1,000")
	var thicket: EffectDef = _on_apex("thicket").signature.effects[0]
	assert_eq(thicket.max_standing, 3, "Thicket leaves the snares alone")
	assert_eq(thicket.area_effects.back().max_standing, 9, "Thicket: 9 briars")
	var lines: Array[EffectDef] = _on_apex("holy_land").signature.effects.filter(func(effect: EffectDef) -> bool: return effect.max_standing > 0)
	assert_eq(lines.map(func(effect: EffectDef) -> int: return effect.max_standing), [6], "Holy Land: 6 lines")


## Garrow's (phase 8 part 4, 8d-2c): the snowballs' steps grow, and the
## rest add what they say.
func test_garrows_apex_cards() -> void:
	var bulwark: UnitDef = _run.content.apexes["endless_bulwark"].apex_kit
	assert_eq(_part(_on_apex("layered_plate"), "plated_blows").ability.effects[0].grows_stack_bp, _part(bulwark, "plated_blows").ability.effects[0].grows_stack_bp + 2000,
		"Layered Plate: each layer twice as big")
	assert_not_null(_part(_on_apex("plate_on_plate"), "plate_on_plate"))
	var burst: UnitDef = _run.content.apexes["shatterburst"].apex_kit
	var echoing: EffectDef = _on_apex("echoing_burst").signature.effects[0].area_effects[0]
	assert_eq(echoing.grows_stack_bp, burst.signature.effects[0].area_effects[0].grows_stack_bp + 300, "Echoing Burst: +3% more an echo")
	var stun: Array = _on_apex("aftershock").signature.effects[0].area_effects.filter(func(effect: EffectDef) -> bool: return effect.status_id == "stun")
	assert_eq(stun.size(), 1, "Aftershock Stuns")
	var grinder: UnitDef = _run.content.apexes["grinder"].apex_kit
	assert_eq(_part(_on_apex("meat_grinder"), "grinder").ability.effects[0].grows_stack_bp, _part(grinder, "grinder").ability.effects[0].grows_stack_bp + 1000, "Meat Grinder: +30% a kill")
	assert_eq(_part(_on_apex("barbed_ring"), "grinder").ability.effects.size(), _part(grinder, "grinder").ability.effects.size() + 1, "Barbed Ring: a Bleed too")
	assert_not_null(_part(_on_apex("deep_current"), "deep_current"))
	assert_not_null(_part(_on_apex("drowning_depths"), "drowning_depths"))
	var king: UnitDef = _run.content.apexes["thorned_king"].apex_kit
	assert_eq(_part(_on_apex("crown_of_thorns"), "maidens_spite").ability.effects[0].grows_stack_bp, _part(king, "maidens_spite").ability.effects[0].grows_stack_bp + 300, "Crown of Thorns")
	assert_not_null(_part(_on_apex("barbed_hide"), "barbed_hide"))
	var vengeance: UnitDef = _run.content.apexes["vengeance"].apex_kit
	assert_eq(_part(_on_apex("wrath"), "vengeance_grudge").aura.value, _part(vengeance, "vengeance_grudge").aura.value + 200, "Wrath: grows 5% a second")
	assert_not_null(_part(_on_apex("patient_fury"), "patient_fury"))


## Tamsin's (phase 8 part 4, 8d-3c): the "more" stacks join the snowballs,
## Tightening Cord reaches the grip, and the rest add what they say.
func test_tamsins_apex_cards() -> void:
	var phantom: UnitDef = _run.content.apexes["phantom"].apex_kit
	assert_eq(_part(_on_apex("deeper_dark"), "phantom_edge").ability.effects.size(), _part(phantom, "phantom_edge").ability.effects.size() + 1, "Deeper Dark: more ATK an attack")
	assert_not_null(_part(_on_apex("smoke_trail"), "smoke_trail"))
	var veil: UnitDef = _run.content.apexes["veilmaster"].apex_kit
	assert_eq(_part(_on_apex("shadow_pact"), "veilmaster").ability.effects.size(), _part(veil, "veilmaster").ability.effects.size() + 2, "Shadow Pact: every hero and her")
	assert_eq(_part(_on_apex("long_shadows"), "veilmaster").ability.effects[0].duration_ticks, _part(veil, "veilmaster").ability.effects[0].duration_ticks + 20, "Long Shadows: 1s longer")
	var axe: UnitDef = _run.content.apexes["executioner"].apex_kit
	assert_eq(_part(_on_apex("bloodied_axe"), "executioner").ability.effects.size(), _part(axe, "executioner").ability.effects.size() + 1)
	assert_true(_part(_on_apex("hanging_judge"), "hanging_judge").ability.effects[0].executed, "Hanging Judge: on an execution")
	var trail: UnitDef = _run.content.apexes["bloodtrail"].apex_kit
	assert_eq(_part(_on_apex("relentless"), "bloodtrail").ability.effects.size(), _part(trail, "bloodtrail").ability.effects.size() + 1)
	assert_eq(_part(_on_apex("open_veins"), "the_hunt").ability.effects.size(), _part(trail, "the_hunt").ability.effects.size() + 1, "Open Veins: a Bleed with each step")
	var strangler: UnitDef = _run.content.apexes["strangler"].apex_kit
	assert_eq(_on_apex("tightening_cord").signature.grip_effects[0].grows_stack_bp, strangler.signature.grip_effects[0].grows_stack_bp + 150, "Tightening Cord: +1.5% more a tick")
	assert_eq(_part(_on_apex("silent_grip"), "strangler").ability.effects.size(), _part(strangler, "strangler").ability.effects.size() + 1, "Silent Grip")
	var pin: UnitDef = _run.content.apexes["pinmaster"].apex_kit
	assert_eq(_part(_on_apex("iron_grip"), "pinning").ability.effects.size(), _part(pin, "pinning").ability.effects.size() + 2, "Iron Grip: every hero and her")
	assert_not_null(_part(_on_apex("pinning_knives"), "pinning_knives"))


func test_dread_return_taunts_as_he_rises() -> void:
	var taunts: int = 0
	var rises: int = 0
	var mods: Array[KitMod] = [_run.upgrades["dread_return"].mod]
	var extras: Dictionary[String, HeroExtras] = {"brannoc": HeroExtras.make(mods)}
	for encounter_id: String in _run.content.encounter_ids:
		var errors: Array[String] = []
		var setup: FightSetup = Encounters.setup(_run.content, encounter_id, FORMATION, 7, errors, {}, {"brannoc": "last_watch"} as Dictionary[String, String],
			["brannoc"] as Array[String], extras, {"brannoc": "undying_oath"} as Dictionary[String, String], ["brannoc"] as Array[String])
		assert_eq(errors, [] as Array[String])
		var result: FightResult = CombatSim.run(setup, _run.content)
		var risen_at: Array[int] = []
		for entry: LogEntry in result.combat_log.entries:
			if entry.kind == LogEntry.Kind.RISE and entry.target == "brannoc":
				risen_at.append(entry.tick)
			elif entry.kind == LogEntry.Kind.STATUS_APPLIED and entry.source_ability == "dread_return":
				assert_true(risen_at.has(entry.tick), "taunts as he rises (%s)" % encounter_id)
				taunts += 1
		rises += risen_at.size()
	assert_gt(rises, 0)
	assert_gt(taunts, 0)


## Aldous's (phase 8 part 4, 8d-4c): each changes what it names on its apex.
func test_aldous_apex_cards() -> void:
	var chorus: UnitDef = _run.content.apexes["grand_chorus"].apex_kit
	assert_eq(_part(_on_apex("rising_chorus"), "grand_chorus").ability.effects[0].amount, 6, "Rising Chorus: 6 mana, not 4")
	assert_eq(_on_apex("encore").signature.effects.size(), chorus.signature.effects.size() + 1, "Encore: mana back")
	var well: UnitDef = _run.content.apexes["wellspring"].apex_kit
	assert_eq(_part(_on_apex("deep_reservoir"), "chorus").ability.effects[0].grows_stack_bp, _part(well, "chorus").ability.effects[0].grows_stack_bp + 500)
	assert_not_null(_part(_on_apex("overflowing_start"), "overflowing_start"))
	var wind: UnitDef = _run.content.apexes["long_wind"].apex_kit
	assert_eq(_part(_on_apex("far_wind"), "long_wind_gust").ability.effects.size(), _part(wind, "long_wind_gust").ability.effects.size() + 2, "Far Wind: the ranged and him")
	assert_not_null(_part(_on_apex("clear_air"), "clear_air"))
	var arrows: UnitDef = _run.content.apexes["singing_arrows"].apex_kit
	assert_eq(_part(_on_apex("rising_pitch_card"), "rising_pitch").aura.value, _part(arrows, "rising_pitch").aura.value + 300)
	assert_eq(_part(_on_apex("ringing_arrows"), "singing_arrows").ability.effects.size(), _part(arrows, "singing_arrows").ability.effects.size() + 1)
	var bell: UnitDef = _run.content.apexes["the_great_bell"].apex_kit
	assert_eq(_on_apex("deep_bronze").signature.effects.size(), bell.signature.effects.size() + 2, "Deep Bronze: every hero and him")
	assert_eq(_on_apex("ringing_ears").signature.effects.size(), bell.signature.effects.size() + 2, "Ringing Ears: his target and the field")
	var requiem: UnitDef = _run.content.apexes["requiem"].apex_kit
	assert_eq(_part(_on_apex("dirge"), "requiem").ability.effects[0].grows_stack_bp, _part(requiem, "requiem").ability.effects[0].grows_stack_bp + 1000)
	assert_eq(_part(_on_apex("silent_toll"), "requiem").ability.effects.size(), _part(requiem, "requiem").ability.effects.size() + 1)
