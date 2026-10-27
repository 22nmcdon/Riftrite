class_name RunFightSetup
extends RefCounted
## Building a run's fight for RunFlow (docs/plans/phases/rebuild-phase5-run.md,
## section 7): each hero's kit as the run has it (its path or apex, its cards,
## its loadout, the relics' mods and rules), the enemies as the day has them
## (specializations, upgrades, a Rift Tear's depth, endless floors), and the
## FightSetup that holds it all. RunFlow keeps fight_setup() and kit_of() and
## delegates here; nothing here changes the run.


## The waiting fight from `formation` (hero id -> hex), with every hero as the
## run has it, or null with the reasons in `errors`. A hero's kit is its
## path's at its stage, then its upgrades, its loadout (slot order), the
## relics, the day's camp modifiers (Fortify, a steadying Rest), and its duo
## bonds. Enemies take the relics' enemy mods and a Rift Tear's; Dig In's
## rock joins the encounter's. A Hunt takes no camp modifiers. `snares`:
## hero id -> the hexes of the snares it places (a transformed Trapper), or
## of its lantern (First Lantern, phase 5c step 7d).
static func fight_setup(flow: RunFlow, formation: Dictionary[String, Vector2i], errors: Array[String], snares: Dictionary[String, Array] = {}) -> FightSetup:
	var encounter_id: String = flow.fight_encounter()
	if encounter_id.is_empty():
		errors.append(flow._not_now("fight"))
		return null
	var hunting: bool = encounter_id == flow.state.hunt
	var content: ContentDb = flow.run.content
	var vows: Dictionary[String, String] = {}
	var transformed: Array[String] = []
	var apex_vows: Dictionary[String, String] = {}
	var apexed: Array[String] = []
	var extras: Dictionary[String, HeroExtras] = {}
	var tactics: Dictionary[String, String] = {}
	var ranked_tactics: Dictionary[String, TacticDef] = {}
	var wound_bp: int = content.tuning.wound_bp
	# Stand Together (phase 5c step 6d): the hero sharing its holder's hex
	# gets its gambit's mod too.
	var shared_mods: Dictionary[String, KitMod] = {}
	# Only the run's team fights (phase 8 part 4).
	var outsiders: Array[String] = []
	for hero_id: String in formation:
		if flow.state.hero(hero_id) == null:
			outsiders.append(hero_id)
	if not outsiders.is_empty():
		for hero_id: String in outsiders:
			errors.append("%s isn't on the team" % hero_id)
		return null
	for hero: RunState.Hero in flow.state.heroes:
		var gambit: KitMod = flow.run.loadout_gambit(hero, flow.state)
		if gambit == null or gambit.place_rule != "share" or not formation.has(hero.id):
			continue
		for other: RunState.Hero in flow.state.heroes:
			if other != hero and formation.has(other.id) and formation[other.id] == formation[hero.id]:
				shared_mods[other.id] = gambit
	for hero: RunState.Hero in flow.state.heroes:
		if not formation.has(hero.id):
			continue
		vows[hero.id] = hero.path
		if hero.transformed:
			transformed.append(hero.id)
		if not hero.apex.is_empty():
			apex_vows[hero.id] = hero.apex
			if hero.apex_earned:
				apexed.append(hero.id)
		var mods: Array[KitMod] = flow.run.upgrade_mods(hero, flow.state.shards)
		mods.append_array(flow.run.loadout_mods(flow.state, hero))
		mods.append_array(flow.run.relic_mods(flow.state, flow.run.hero_kit(hero)))
		if shared_mods.has(hero.id):
			mods.append(shared_mods[hero.id])
		if not hunting and flow.state.fortify:
			mods.append(flow.run.camps.fortify_mod)
		if not hunting:
			for modifier: CampsDef.Modifier in _rift_modifiers(flow):
				if modifier.hero_mod != null:
					mods.append(modifier.hero_mod)
		var covenant: KitMod = _covenant_mod(flow, hero, formation)
		if covenant != null:
			mods.append(covenant)
		# Events (phase 5c step 8c), last, since dropping the signature must
		# come after any mod that changes it.
		var oath: EventDef.Oath = RunEvents.oath_of(flow, hero) if not hunting else null
		if not hunting:
			for key: String in hero.next_fight:
				mods.append(flow.run.events.next_fight_mods[key])
		for i: int in hero.weakened:
			mods.append(_weaken_mod(flow))
		if oath != null and oath.mod != null:
			mods.append(oath.mod)
		if oath != null and oath.front_row and formation[hero.id].y != RunEvents.front_row(flow):
			errors.append("%s is sworn to the front row (%s)" % [hero.id, oath.name])
		extras[hero.id] = HeroExtras.make(mods, hero.wounds, wound_bp)
		var tallies: Array = flow.run.growth_tallies(flow.state, hero)
		extras[hero.id].tally_keys.assign(tallies[0])
		extras[hero.id].tally_counts.assign(tallies[1])
		var tactic: TacticDef = flow.run.loadout_tactic(hero, flow.state)
		if oath != null and oath.no_tactic:
			tactic = null
		if tactic != null:
			tactics[hero.id] = tactic.id
			ranked_tactics[hero.id] = tactic
	var setup: FightSetup = Encounters.setup(content, encounter_id, formation, flow.fight_seed(), errors, tactics, vows, transformed, extras, apex_vows, apexed, {} as Dictionary[int, String] if hunting else flow.chosen_specs(),
		{} as Dictionary[int, PackedStringArray] if hunting else flow.chosen_upgrades())
	if setup != null:
		for hero: UnitSetup in setup.heroes:
			if hero.def.placed_lantern and not snares.get(hero.id, []).is_empty():
				# First Lantern (phase 5c step 7d): its one marker.
				hero.lantern = snares[hero.id][0]
			elif hero.def.placed_snares > 0 and snares.has(hero.id):
				hero.snares.assign(snares[hero.id])
			# A tactic at its item's rank (phase 5c step 6c).
			if ranked_tactics.has(hero.id):
				hero.tactic = ranked_tactics[hero.id]
			# One its kit can't follow now (a signature dropped by an event or
			# an oath, phase 5c step 8c) does nothing, as an item can.
			if hero.tactic != null and not Tactics.can_follow(hero.tactic, hero.def):
				hero.tactic = null
			# Switch Places at the moment the player chose (phase 5c step 6d).
			var chosen: int = flow.state.hero(hero.id).gambit_at if flow.state.hero(hero.id) != null else 0
			if chosen > 0 and hero.def.swap_choice:
				hero.swap_at = chosen * FixedMath.TICKS_PER_SECOND
		if not hunting and (not flow.state.rift_depth.is_empty() or not flow.state.endless_mods.is_empty()):
			_rift_rules(flow, setup, encounter_id)
		if not hunting:
			flow._endless_rules(setup)
		_modify_enemies(flow, setup, hunting, errors)
		_relic_rules(flow, setup)
		# The shards held, for what reads them (phase 8 part 5, Golden Aegis).
		setup.shards = flow.state.shards
		setup.tithe_shards = mini(flow.state.tithe_held, flow.state.shards)
		if not hunting and flow.state.dig_in and flow.state.rock.size() == 2:
			setup.rocks.append(Vector2i(flow.state.rock[0], flow.state.rock[1]))
		errors.append_array(setup.validate(content))
		for hero: RunState.Hero in flow.state.heroes:
			if not formation.has(hero.id):
				errors.append("%s isn't placed" % hero.id)
	return setup if errors.is_empty() else null


## The relics' effects at the fight's start and Salt Circle (phase 5c step
## 5b), for the sim to run.
static func _relic_rules(flow: RunFlow, setup: FightSetup) -> void:
	for start: Array in flow.run.relic_starts(flow.state):
		var relic: RelicDef = start[0]
		setup.relic_effects.append(start[1])
		setup.relic_sources.append(EffectSource.relic(relic.id, relic.name, EffectSource.Team.HEROES))
		setup.relic_scales.append(start[2])
	for id: String in flow.state.relics:
		if flow.run.relics.has(id) and flow.run.relics[id].salt_circle:
			setup.salt_circles += 2 if flow.run.counts_twice(flow.state, flow.run.relics[id]) else 1
	setup.hero_rules = flow.run.hero_rules(flow.state)


## The Hollow Covenant (phase 5c step 5a): what `hero` needs added to reach
## the team's highest HP, ATK, MGK, DEF, CRIT, and attack speed (among the
## heroes placed), worked out from each kit as it stands between fights.
## Null without the relic, or with nothing to add.
static func _covenant_mod(flow: RunFlow, hero: RunState.Hero, formation: Dictionary[String, Vector2i]) -> KitMod:
	if not flow.run.relic_rule(flow.state, "covenant"):
		return null
	var mine: UnitStats = _kit_without_covenant(flow, hero.id).stats
	var mod: KitMod = KitMod.make()
	for other: RunState.Hero in flow.state.heroes:
		if not formation.has(other.id) or other == hero:
			continue
		var theirs: UnitStats = _kit_without_covenant(flow, other.id).stats
		for stat: UnitStats.Stat in COVENANT_STATS:
			mod.stats_add[stat] = maxi(mod.stats_add[stat], theirs.get_stat(stat) - mine.get_stat(stat))
	return mod if mod.changes_anything() else null


## The stats The Hollow Covenant raises each placed hero to the team's best in.
const COVENANT_STATS: Array[UnitStats.Stat] = [UnitStats.Stat.HP, UnitStats.Stat.ATK, UnitStats.Stat.MGK, UnitStats.Stat.DEF, UnitStats.Stat.CRIT, UnitStats.Stat.ATSP]


static func _kit_without_covenant(flow: RunFlow, hero_id: String) -> UnitDef:
	return kit_of(flow, hero_id, false)


## The kit `hero_id` fights with as things stand between fights: its path's
## at its stage, then its upgrades, loadout, relics, and bonds (camp's
## modifiers for the next fight aside). For showing, not for fights.
static func kit_of(flow: RunFlow, hero_id: String, with_covenant: bool = true) -> UnitDef:
	var hero: RunState.Hero = flow.state.hero(hero_id)
	var kit: UnitDef = flow.run.hero_kit(hero)
	var mods: Array[KitMod] = flow.run.upgrade_mods(hero, flow.state.shards)
	mods.append_array(flow.run.loadout_mods(flow.state, hero))
	mods.append_array(flow.run.relic_mods(flow.state, kit))
	if with_covenant:
		var formation: Dictionary[String, Vector2i] = {}
		for other: RunState.Hero in flow.state.heroes:
			formation[other.id] = Vector2i.ZERO
		var covenant: KitMod = _covenant_mod(flow, hero, formation)
		if covenant != null:
			mods.append(covenant)
	for mod: KitMod in mods:
		kit = mod.apply(kit)
	return kit


## Every enemy and summon kit takes the relics' enemy mods, and a Rift
## Tear's upgrade (not on a Hunt).
static func _modify_enemies(flow: RunFlow, setup: FightSetup, hunting: bool, errors: Array[String]) -> void:
	var mods: Array[KitMod] = []
	for id: String in flow.state.relics:
		if flow.run.relics[id].enemy_mod != null:
			mods.append(flow.run.relics[id].enemy_mod)
	if not hunting:
		if not flow.state.rift_depth.is_empty():
			mods.append(flow.run.camps.rift_tear_mod)
		for modifier: CampsDef.Modifier in _rift_modifiers(flow):
			if modifier.mod != null:
				mods.append(modifier.mod)
		var growth: KitMod = flow._floor_growth_mod()
		if growth != null:
			mods.append(growth)
	if mods.is_empty():
		return
	var problems: Array[String] = []
	for enemy: UnitSetup in setup.enemies:
		for mod: KitMod in mods:
			enemy.def = mod.apply(enemy.def, problems)
	for i: int in setup.summon_kits.size():
		for mod: KitMod in mods:
			setup.summon_kits[i] = mod.apply(setup.summon_kits[i], problems)
	for problem: String in problems:
		errors.append("an enemy upgrade leaves a kit unsound: %s" % problem)


## The Old Well's cut (phase 5c step 8c): max HP times the weaken result's
## bp, once for each drink this act.
static func _weaken_mod(flow: RunFlow) -> KitMod:
	var mod: KitMod = KitMod.make()
	mod.stats_bp[UnitStats.Stat.HP] = flow.run.events.weaken_bp()
	return mod


## The rift modifiers on the next day fight (phase 5c step 8b).
static func _rift_modifiers(flow: RunFlow) -> Array[CampsDef.Modifier]:
	var found: Array[CampsDef.Modifier] = []
	for id: String in flow.state.endless_mods + flow.state.rift_mods:
		if flow.run.camps.modifiers.has(id) and not found.has(flow.run.camps.modifiers[id]):
			found.append(flow.run.camps.modifiers[id])
	return found


## A Rift Tear's rules for the sim (phase 5c step 8b): Early Collapse's
## start, and Reinforcements: that many of the encounter's first enemy that
## isn't its elite or boss (the first listed, or the second in an elite or
## boss fight), summoned from the edge as the rift's own effect, its kit
## added to the summon kits (scaled like the encounter's, and modified with
## them).
static func _rift_rules(flow: RunFlow, setup: FightSetup, encounter_id: String) -> void:
	var encounter: EncounterDef = flow.run.content.encounters[encounter_id]
	for modifier: CampsDef.Modifier in _rift_modifiers(flow):
		if modifier.collapse_from_ticks > 0:
			setup.collapse_start_ticks = modifier.collapse_from_ticks if setup.collapse_start_ticks == 0 else mini(setup.collapse_start_ticks, modifier.collapse_from_ticks)
		if modifier.reinforce_count <= 0:
			continue
		var first: int = 1 if encounter.tier == "elite" or encounter.tier == "boss" else 0
		if first >= encounter.enemies.size():
			continue
		var kind: String = encounter.enemies[first].enemy
		if setup.summon_kit(kind) == null:
			setup.summon_kits.append(Encounters.scaled(flow.run.content.enemies[kind].kit, encounter.scale_bp))
		var errors: Array[String] = []
		var effect: EffectDef = EffectDef.read(DataReader.new({"type": "summon", "kit": kind, "count": modifier.reinforce_count, "placement": "edges"}, "reinforcements", errors))
		setup.rift_effects.append(effect)
		setup.rift_sources.append(EffectSource.rift_effect(modifier.id, modifier.name))
		setup.rift_ticks.append(modifier.reinforce_ticks)
