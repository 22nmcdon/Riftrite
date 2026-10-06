extends GutTest
## Tamsin's upgrade cards (phase 8 part 4, docs/plans/upgrade-pools.md Tamsin;
## rebuild-phase8-heroes.md 8d-3d) and her bond relic on her real kits: each
## changes the kit it's offered on, a card on Shadowstep reaches it as her
## signature or as her habit, and Hammer and Wire changes only Garrote.

const K = preload("res://tests/sim/sim_test_kit.gd")

var _content: ContentDb
var _run: RunContent


func before_all() -> void:
	_content = K.content()
	_run = RunContent.load_dir("res://data", _content)


func _base() -> UnitDef:
	return _content.heroes["tamsin"].kit


func _kit(path_id: String, stage: PathDef.Stage) -> UnitDef:
	return _content.paths[path_id].kit(stage, _base())


func _with(card_id: String, kit: UnitDef, transformed: bool = false) -> UnitDef:
	var problems: Array[String] = []
	var built: UnitDef = _run.upgrades[card_id].mod_for(transformed).apply(kit, problems)
	assert_eq(problems, [] as Array[String], card_id)
	return built


func _passive(kit: UnitDef, part_id: String) -> PartDef:
	for part: PartDef in kit.passives:
		if part.id == part_id:
			return part
	return null


func _hidden_ticks(ability: AbilityDef) -> int:
	for effect: EffectDef in ability.effects:
		if effect.type == EffectDef.Type.APPLY_STATUS and effect.status_id == "hidden":
			return effect.duration_ticks
	return -1


func test_every_card_changes_the_kit_it_is_offered_on() -> void:
	var cards: Array[String] = []
	for id: String in _run.upgrade_ids:
		var card: UpgradeDef = _run.upgrades[id]
		if card.hero == "tamsin" or (_content.paths.has(card.path) and _content.paths[card.path].hero == "tamsin"):
			cards.append(id)
			var kit: UnitDef = _base()
			if not card.path.is_empty():
				kit = _kit(card.path, PathDef.Stage.VOWED if card.layer == UpgradeDef.Layer.TASTE else PathDef.Stage.TRANSFORMED)
			assert_true(_run.changes_something(card, card.layer == UpgradeDef.Layer.PATH, kit), id)
	assert_eq(cards.size(), 12 + 6 + 15, "12 of her own, and 2 tastes and 5 path cards a path")


func test_long_shadowstep_reaches_the_signature_and_the_habit() -> void:
	assert_eq(_hidden_ticks(_with("long_shadowstep", _base()).signature), 60, "hidden 3s, not 2s")
	var habit: PartDef = _passive(_with("long_shadowstep", _kit("nightblade", PathDef.Stage.TRANSFORMED)), "shadowstep")
	assert_eq(_hidden_ticks(habit.ability), 60, "and as a habit")
	assert_eq(_passive(_with("deep_ambush", _base()), "ambusher").ability.effects[0].duration_ticks, 60)


func test_the_hero_cards_read_her_targets() -> void:
	var backstab: AuraDef = _passive(_with("backstab", _base()), "backstab").aura
	assert_eq(backstab.vs.targets_holder, UnitCondition.Flying.NO)
	assert_eq(_passive(_with("evasive", _base()), "evasive").aura.stat, AuraDef.Stat.EVADE_BP)
	var blades: UnitDef = _with("poisoned_blades", _base())
	assert_eq(blades.basic_attack.effects.map(func(effect: EffectDef) -> String: return effect.status_id), ["", "poison"])


func test_the_nightblade_cards() -> void:
	var blade: UnitDef = _kit("nightblade", PathDef.Stage.TRANSFORMED)
	assert_eq(_passive(_with("lingering_fade", _kit("nightblade", PathDef.Stage.VOWED)), "fade").ability.effects[0].duration_ticks, 30, "1.5s, not 1s")
	assert_eq(_passive(_with("lingering_fade", blade, true), "fade").ability.effects[0].duration_ticks, 50, "carried past the transformation")
	assert_eq(_with("long_dance", blade).signature.effects[0].duration_ticks, 80, "Shadow Dance 4s")
	var mist: EffectDef = _passive(_with("mist_step", blade), "mist_step").ability.effects[0]
	assert_eq(mist.keywords, ["stealthed"] as Array[String])
	assert_true(mist.cleanse_statuses.has("root") and mist.cleanse_statuses.has("slow"))


func test_the_headhunter_cards() -> void:
	var hunter: UnitDef = _kit("headhunter", PathDef.Stage.TRANSFORMED)
	assert_eq(_with("quick_sentence", hunter).mana.max, hunter.mana.max - 10)
	assert_eq(_passive(_with("lasting_scent", _kit("headhunter", PathDef.Stage.VOWED)), "scent").ability.effects[0].duration_ticks, 15, "0.75s a hit")
	var swift: PartDef = _passive(_with("swift_step", hunter), "the_hunt")
	assert_eq(swift.ability.effects.map(func(effect: EffectDef) -> String: return EffectDef.TYPE_NAMES[effect.type]), ["leap", "apply_status"])
	assert_not_null(_passive(_with("stalker", hunter), "stalker").aura.state.target, "while her target is Marked")


func test_the_garrote_cards() -> void:
	var garrote: UnitDef = _kit("garrote", PathDef.Stage.TRANSFORMED)
	assert_eq(_with("long_garrote", garrote).signature.effects[0].duration_ticks, 50, "2.5s")
	var drag: EffectDef = _with("drag", garrote).signature.effects[1]
	assert_eq(drag.type, EffectDef.Type.PULL)
	assert_eq(drag.toward, EffectDef.Toward.ALLY)
	assert_eq(_passive(_with("tight_choke", _kit("garrote", PathDef.Stage.VOWED)), "choke").ability.effects[0].duration_ticks, 10, "0.5s, not 0.3s")


func test_hammer_and_wire_changes_only_garrote() -> void:
	var relic: RelicDef = _run.relics["hammer_and_wire"]
	assert_eq(relic.tier, RelicDef.Tier.BOND)
	assert_eq(_run.bonds["hold_and_break"].relic, "hammer_and_wire")
	var garrote: UnitDef = _kit("garrote", PathDef.Stage.TRANSFORMED)
	var problems: Array[String] = []
	var wired: UnitDef = relic.mod.apply(garrote, problems)
	assert_eq(problems, [] as Array[String])
	assert_eq(wired.signature.max_range, 4, "a Stunned enemy within 4 hexes")
	assert_not_null(wired.signature.prefer)
	assert_not_null(wired.signature.grip_fast_vs)
	assert_eq(EffectDef.TYPE_NAMES[wired.signature.effects[1].type], "leap", "she steps behind it")
	for path_id: String in ["nightblade", "headhunter", "ironbrand", "aegisfang"]:
		var kit: UnitDef = _content.paths[path_id].transformed_kit
		assert_false(relic.mod.affects(kit), "%s: nothing" % path_id)
		assert_eq(relic.mod.apply(kit, problems).signature.max_range, kit.signature.max_range)
		assert_eq(problems, [] as Array[String], path_id)
