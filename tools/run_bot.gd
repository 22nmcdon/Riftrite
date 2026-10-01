extends RefCounted
## The simple run bot (docs/plans/rebuild-phase5-run.md, section 12, Decision
## 14): plays whole runs through RunFlow, for tests and pacing, not for a win
## rate (the good bot is phase 6). It vows each hero to its first path unless
## told otherwise, takes a camp option by a fixed order (Rest when someone has
## 2 wounds), buys what it can use and equips it, takes today's first fight,
## places the sim runner's "guarded" formation, takes the pick's card for
## the hero with the fewest upgrades, and the first relic of a choice.

const Report = preload("res://tools/sim_report.gd")
const FORMATIONS_FILE: String = "res://tools/sim_formations.json"
const FORMATION: String = "guarded"
## The named formations a looking-ahead bot tries, in this order.
const FORMATIONS: Array[String] = ["guarded", "exposed", "spread", "clumped"]
## A run is at most 7 days of at most 2 attempts, a few actions each;
## anything past this is a bug.
const MAX_STEPS: int = 400
## Camp options, first the bot likes best (Rest only when someone's hurt).
const CAMP_ORDER: Array[String] = ["magpie", "train", "pedlar", "shrine", "fortify", "hunt", "scout", "dig_in", "map_the_rift", "rift_tear", "rest"]
## Where Dig In's rock goes: a corner of the heroes' zone, out of the way.
const ROCK: Vector2i = Vector2i(0, 0)


## The formation the bot places.
static func formation(name: String = FORMATION) -> Dictionary[String, Vector2i]:
	var errors: Array[String] = []
	var named: Dictionary[String, Dictionary] = Report.read_formations(FileAccess.get_file_as_string(FORMATIONS_FILE), errors)
	var hexes: Dictionary[String, Vector2i] = {}
	hexes.assign(named[name])
	return hexes


## A looking-ahead bot's formation for the waiting fight (the run report's
## stand-in for a player who places well): the first of FORMATIONS whose
## fight isn't lost, or the first one.
static func formation_for(flow: RunFlow) -> Dictionary[String, Vector2i]:
	for name: String in FORMATIONS:
		var hexes: Dictionary[String, Vector2i] = formation(name)
		var errors: Array[String] = []
		var setup: FightSetup = flow.fight_setup(hexes, errors)
		if setup != null and CombatSim.run(setup, flow.run.content).outcome != FightResult.Outcome.DEFEAT:
			return hexes
	return formation()


## Each hero's first path.
static func first_vows(content: ContentDb) -> Dictionary[String, String]:
	var vows: Dictionary[String, String] = {}
	for hero_id: String in content.hero_ids:
		vows[hero_id] = content.heroes[hero_id].paths[0].id
	return vows


## Plays a run from `run_seed` to its end. Errors (a refused action) go in
## `errors` and stop it.
static func play(run: RunContent, run_seed: int, errors: Array[String], vows: Dictionary[String, String] = {}) -> RunFlow:
	var flow: RunFlow = RunFlow.start(run, run_seed, vows if not vows.is_empty() else first_vows(run.content), errors)
	if flow == null:
		return null
	var hexes: Dictionary[String, Vector2i] = formation()
	for step: int in MAX_STEPS:
		if flow.state.phase == RunState.Phase.ENDED:
			return flow
		var refused: String = step_once(flow, hexes, errors)
		if not refused.is_empty():
			errors.append("day %d (%s): %s" % [flow.state.day, RunState.PHASE_NAMES[flow.state.phase], refused])
			return flow
	errors.append("the run didn't end in %d steps" % MAX_STEPS)
	return flow


## One action for wherever the day is. Returns why it was refused ("": done).
## `look_ahead`: place by formation_for (the run report) instead of `hexes`.
static func step_once(flow: RunFlow, hexes: Dictionary[String, Vector2i], errors: Array[String], look_ahead: bool = false) -> String:
	var state: RunState = flow.state
	if not state.pick.is_empty():
		return flow.take_pick(pick_choice(flow))
	if not state.relic_choice.is_empty():
		return flow.take_relic(0) if state.shards >= state.relic_choice_price else flow.decline_relic()
	match state.phase:
		RunState.Phase.CAMP:
			if state.camp_used.is_empty():
				return flow.choose_camp(camp_choice(state))
			if not state.hunt.is_empty():
				var hunt_errors: Array[String] = []
				var hunt_hexes: Dictionary[String, Vector2i] = hexes
				if look_ahead:
					hunt_hexes = formation_for(flow)
				if flow.fight(hunt_hexes, hunt_errors) == null:
					return ", ".join(hunt_errors)
				return ""
			if state.mapping:
				return flow.swap_fight(0)
			if not state.shop.is_empty() and shop_once(flow):
				return ""
			if state.dig_in and state.rock.is_empty():
				return flow.place_rock(ROCK)
			return flow.leave_camp()
		RunState.Phase.ROUTE:
			return flow.choose_fight(0)
		RunState.Phase.LOADOUT:
			var fight_errors: Array[String] = []
			var fight_hexes: Dictionary[String, Vector2i] = hexes
			if look_ahead:
				fight_hexes = formation_for(flow)
			if flow.fight(fight_hexes, fight_errors) == null:
				return ", ".join(fight_errors)
			return ""
		RunState.Phase.AFTER:
			return flow.finish_day()
	return "nothing to do"


## The pick's card the bot takes: the one for the hero with the fewest
## upgrades so far (the first such card), so growth spreads out.
static func pick_choice(flow: RunFlow) -> int:
	var best: int = 0
	var fewest: int = 1 << 30
	for i: int in flow.state.pick.size():
		var owner: String = flow.run.upgrades[flow.state.pick[i]].hero
		var taken: int = flow.state.hero(owner).upgrades.size()
		if taken < fewest:
			fewest = taken
			best = i
	return best


## The camp option the bot takes: Rest if someone has 2 wounds or more,
## else the first of CAMP_ORDER offered.
static func camp_choice(state: RunState) -> int:
	if state.camp.has("rest") and state.heroes.any(func(hero: RunState.Hero) -> bool: return hero.wounds >= 2):
		return state.camp.find("rest")
	for option: String in CAMP_ORDER:
		if state.camp.has(option):
			return state.camp.find(option)
	return 0


## One purchase at the open shop: the first ware it can afford that it owns
## (a rank up) or that suits a hero with a free slot (equipped there), else
## a relic, else a wound. It never rerolls or sells.
## False if there's nothing left to do.
static func shop_once(flow: RunFlow) -> bool:
	var state: RunState = flow.state
	for i: int in state.wares.size():
		var id: String = state.wares[i]
		if id.is_empty() or flow.price_of(id) > state.shards:
			continue
		if state.item_ranks.has(id):
			return flow.buy(i) == ""
		for hero: RunState.Hero in state.heroes:
			if hero.slots.has("") and suits(flow, flow.run.items[id], hero):
				# A second tactic or gambit can't be equipped; it waits in the stash.
				if flow.buy(i) == "":
					flow.equip(hero.id, hero.slots.find(""), id)
				return true
	for i: int in state.shop_relics.size():
		if not state.shop_relics[i].is_empty() and flow.relic_price(i) <= state.shards:
			return flow.buy_relic(i) == ""
	for hero: RunState.Hero in state.heroes:
		if hero.wounds > 0 and state.shards >= flow.wound_price():
			return flow.treat_wound(hero.id) == ""
	return false


## The bot's own judgment of an item for a hero (players get no such
## warning, loadout rule 2): a mod that changes its kit, or a tactic it can
## follow.
static func suits(flow: RunFlow, item: ItemDef, hero: RunState.Hero) -> bool:
	var kit: UnitDef = flow.run.hero_kit(hero)
	if item.tactic != null:
		return RunContent.can_follow(item.tactic, kit, hero.id)
	var mod: KitMod = item.mod_at(1)
	return mod != null and mod.affects(kit)
