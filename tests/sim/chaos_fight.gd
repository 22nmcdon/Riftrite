extends RefCounted
## The chaos fight (docs/plans/rebuild-phase1-arena-sim.md, section 13): one
## seeded fight that uses every piece of the arena sim, for the determinism
## tests and the log audit. test_determinism checks it uses them all.
##
## Heroes: a warden (Engage; a hit that marks and, on a crit, stuns; below
## half HP a ring a hex out that taunts; a hex, not two, since phase 5c's
## walkable crumbled ground no longer herds enemies inward), a mender (a cast that heals, shields, and
## cleanses the most hurt ally; an attack aura for a while; Burn it applies
## lands as Poison), a brand (burning strikes that stun on a crit; every
## third attack a charge that knocks back), and a hook (hops away; Bleed; a
## pull every fourth attack; Stealth each time it hops; when it would fall,
## Undying).
## Enemies: two hounds (flying, Engage, a Pounce leap, a pack aura, and a
## knockback on every third hit taken), a witch (Slow on hit; a cast that
## warns a circle of Silence and mana drain on whoever has the most mana), a
## caller (a poison line; pups on two hexes every fourth hit taken), and a
## brute with phases: it Roots and pulls the farthest hero at 5s; below 80%
## it casts a call for pups from the edges each time its bar fills, and the
## first call starts Rift Collapse early; below 50% it breathes a warned cone
## at the largest group and hits back on every fifth hit taken. Rocks sit in
## the middle.
## Phase 5c step 3 adds keywords and triggers: the brand's every third hit
## on a Burning enemy shields it, and each Burn it applies counts too; the
## hook deals more to Marked enemies and attacks faster while Stealthed; the
## witch shields herself when an ally's signature fires, and lashes out
## when she's shielded (a chain two links deep); a pup whose Shield breaks
## bites back.
## Phase 5c step 5b adds the pieces relics share: a relic's Shield on every
## hero as the fight starts, and Salt Circle breaking the first enemy area;
## the hook steals life and, leaving Stealth, attacks faster for a while (a
## boost); the warden's crits on Marked enemies make the Mark last longer
## and it takes less damage beside an ally; the brand's crits hit harder,
## and a Burning enemy it fells spreads its Burn around; the mender's
## signature gives every ally a boost.
##
## Some pieces (a shot fizzling, a cleanse cutting stacks, a cast cancelled
## by a stun, a target lost to Stealth, a Taunt) happen only in some seeds;
## 26 has them all (17, 18, then 21 did before playtest gate 1 shrank units
## and added Stealth, then 23 until phase 5c step 5b's pieces changed the
## fight). If a change to the
## sim moves them, test_the_chaos_fight_uses_everything says which, and the
## seed or the kits need adjusting.

const K = preload("res://tests/sim/sim_test_kit.gd")


static func setup(fight_seed: int = 26) -> FightSetup:
	var warden: UnitDef = K.kit("warden", {"stats": {"hp": 1400, "atk": 14, "def": 30, "crit": 15, "speed": 2}, "traits": ["engage"],
		"basic_attack": {"effects": [{"type": "damage", "amount": 8, "target": "target", "scaling": {"atk": 5000}},
			{"trigger": "on_hit", "type": "apply_status", "status": "marked", "target": "hit_target"},
			{"trigger": "on_crit", "type": "apply_status", "status": "stun", "target": "hit_target"}]},
		"passives": [{"id": "ledger", "name": "Ledger", "kind": "ability", "effects": [
				{"trigger": "on_holder_crit", "vs": {"keywords": ["marked"]}, "type": "extend_status", "status": "marked", "duration_ms": 500, "target": "hit_target"}]},
			{"id": "banner", "name": "Banner", "kind": "aura", "aura": {"target": "holder", "stat": "damage_reduced_bp", "value": 1000, "while": "ally_near", "within_hexes": 2}}],
		"signature": {"id": "hold", "name": "Hold the Line", "trigger": {"kind": "hp_below", "threshold_bp": 5000}, "targeting": "self",
			"effects": [{"type": "area", "shape": {"kind": "ring", "radius": 1}, "anchor": "self", "hits": "enemies",
				"effects": [{"type": "apply_status", "status": "taunt", "target": "target"}, {"type": "damage", "amount": 10, "target": "target"}]}]}})
	var mender: UnitDef = K.kit("mender", {"stats": {"hp": 700, "atk": 10, "mgk": 20, "speed": 2, "range": 4},
		"mana": {"max": 40, "per_attack": 10, "per_10_damage_taken": 2, "regen_per_s": 3},
		"basic_attack": {"cooldown_ms": 1100, "effects": [{"type": "damage", "amount": 6, "target": "target"}, {"type": "apply_status", "status": "burn", "stacks": 2, "target": "target"}]},
		"signature": {"id": "mend", "name": "Mend", "trigger": {"kind": "mana"}, "targeting": "lowest_hp_ally", "cast_ms": 500, "max_range": 6,
			"effects": [{"type": "heal", "amount": 40, "target": "target", "scaling": {"mgk": 10000}}, {"type": "shield", "amount": 20, "target": "target"},
				{"type": "cleanse", "amount_bp": 5000, "target": "target"}]},
		"passives": [{"id": "rally", "name": "Rally", "kind": "aura", "aura": {"target": "all_allies", "stat": "atk_bp", "value": 12000, "window": {"until_ms": 20000}}},
			{"id": "venom", "name": "Venom", "kind": "replace_status", "from": "burn", "to": "poison"},
			{"id": "toll", "name": "Toll", "kind": "ability", "effects": [{"trigger": "on_ability", "type": "apply_status", "status": "storm_call", "target": "all_allies"}]}]})
	var brand: UnitDef = K.kit("brand", {"stats": {"hp": 900, "atk": 18, "crit": 25, "speed": 3},
		"basic_attack": {"cooldown_ms": 900, "effects": [{"type": "damage", "amount": 10, "target": "target", "scaling": {"atk": 6000}},
			{"trigger": "on_hit", "type": "apply_status", "status": "burn", "target": "hit_target"},
			{"trigger": "on_crit", "type": "apply_status", "status": "stun", "target": "hit_target"}]},
		"signature": {"id": "rush", "name": "Rush", "trigger": {"kind": "count", "event": "on_basic_attack", "every": 3}, "max_range": 3,
			"effects": [{"type": "charge", "hexes": 3, "knockback": 1, "target": "target"}, {"type": "damage", "amount": 15, "target": "target"}]},
		"passives": [{"id": "feast", "name": "Feast", "kind": "ability", "effects": [{"trigger": "on_kill", "type": "heal", "amount": 60, "target": "self"}]},
			{"id": "kindle", "name": "Kindle", "kind": "ability", "effects": [
				{"trigger": "on_holder_hit", "every": 3, "vs": {"keywords": ["burning"]}, "type": "shield", "amount": 5, "target": "self"},
				{"trigger": "on_status", "keywords": ["burning"], "every": 4, "type": "shield", "amount": 2, "target": "self"}]},
			{"id": "keen", "name": "Keen", "kind": "aura", "aura": {"target": "holder", "stat": "crit_damage_bp", "value": 5000}},
			{"id": "pyre", "name": "Pyre", "kind": "ability", "effects": [
				{"trigger": "on_kill", "vs": {"keywords": ["burning"]}, "type": "apply_status", "status": "burn", "stacks_of": "burn", "target": "enemies_near_named", "within_hexes": 2}]}]})
	var hook: UnitDef = K.kit("hook", {"stats": {"hp": 600, "atk": 12, "speed": 2, "range": 5}, "traits": ["hop_away"], "hop_cooldown_ms": 3000,
		"basic_attack": {"effects": [{"type": "damage", "amount": 9, "target": "target", "scaling": {"atk": 5000}}, {"type": "apply_status", "status": "bleed", "target": "target"}]},
		"signature": {"id": "last_rites", "name": "Last Rites", "trigger": {"kind": "would_fall"}, "targeting": "self",
			"effects": [{"type": "apply_status", "status": "undying", "duration_ms": 2000, "target": "self"}]},
		"passives": [{"id": "snare", "name": "Snare", "kind": "ability", "effects": [{"trigger": "on_basic_attack", "every": 4, "type": "pull", "hexes": 2, "target": "target"}]},
			{"id": "vanish", "name": "Vanish", "kind": "ability", "effects": [{"trigger": "on_hop", "type": "apply_status", "status": "stealth", "target": "self"}]},
			{"id": "hunt", "name": "Hunt", "kind": "aura", "aura": {"target": "holder", "stat": "damage_bp", "value": 12000, "vs": {"keywords": ["marked"]}}},
			{"id": "shade", "name": "Shade", "kind": "aura", "aura": {"target": "holder", "stat": "atsp_bp", "value": 13000, "while": "state", "state": {"keywords": ["stealthed"]}}},
			{"id": "leech", "name": "Leech", "kind": "aura", "aura": {"target": "holder", "stat": "lifesteal_bp", "value": 1500}},
			{"id": "veil", "name": "Veil", "kind": "ability", "effects": [{"trigger": "on_status_ended", "statuses": ["stealth"], "type": "apply_status", "status": "veiled_haste", "target": "self"}]}]})

	var hound: UnitDef = K.kit("hound", {"stats": {"hp": 500, "atk": 14, "speed": 3, "crit": 10}, "traits": ["engage", "flying"],
		"passives": [{"id": "pack", "name": "Pack", "kind": "aura", "aura": {"target": "all_allies", "stat": "atsp_bp", "value": 11000}},
			{"id": "snap", "name": "Snap", "kind": "ability", "effects": [{"trigger": "on_hit_taken", "every": 3, "type": "knockback", "hexes": 1, "target": "hit_target"}]}],
		"signature": {"id": "pounce", "name": "Pounce", "trigger": {"kind": "fight_start"}, "targeting": "weakest_backliner", "max_range": 5,
			"effects": [{"type": "leap", "max_hexes": 5, "target": "target"}, {"type": "damage", "amount": 12, "target": "target"}]}})
	var witch: UnitDef = K.kit("witch", {"stats": {"hp": 600, "atk": 10, "speed": 2, "range": 4},
		"mana": {"max": 30, "per_attack": 10, "regen_per_s": 2},
		"basic_attack": {"effects": [{"type": "damage", "amount": 7, "target": "target"}, {"type": "apply_status", "status": "slow", "target": "target"}]},
		"passives": [{"id": "coven", "name": "Coven", "kind": "ability", "effects": [{"trigger": "on_ally_ability", "type": "shield", "amount": 8, "target": "self"},
			{"trigger": "on_shielded", "type": "damage", "amount": 3, "target": "target"}]}],
		"signature": {"id": "hush", "name": "Hush", "trigger": {"kind": "mana"}, "targeting": "highest_mana", "max_range": 6, "cast_ms": 1000,
			"effects": [{"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "target", "warning_ms": 500, "hits": "enemies",
				"effects": [{"type": "apply_status", "status": "silence", "target": "target"}, {"type": "mana_drain", "amount": 20, "target": "target"}]}]}})
	var caller: UnitDef = K.kit("caller", {"stats": {"hp": 700, "atk": 10, "speed": 1, "range": 3},
		"basic_attack": {"cooldown_ms": 1500, "effects": [{"type": "area", "shape": {"kind": "line", "length": 3}, "anchor": "target_direction", "hits": "enemies",
			"effects": [{"type": "damage", "amount": 8, "target": "target"}, {"type": "apply_status", "status": "poison", "target": "target"}]}]},
		"signature": {"id": "brood", "name": "Brood", "trigger": {"kind": "count", "event": "on_hit_taken", "every": 4}, "targeting": "self",
			"effects": [{"type": "summon", "kit": "pup", "placement": "hexes", "hexes": [[0, 6], [7, 6]]}]}})
	var brute: UnitDef = K.kit("brute", {"stats": {"hp": 2400, "atk": 20, "def": 20, "speed": 2, "range": 1},
		"basic_attack": {"cooldown_ms": 1400, "effects": [{"type": "damage", "amount": 16, "target": "target", "scaling": {"atk": 5000}}]},
		"signature": {"id": "drag", "name": "Drag", "trigger": {"kind": "at_time", "at_ms": 5000}, "targeting": "farthest",
			"effects": [{"type": "pull", "hexes": 3, "target": "target"}, {"type": "apply_status", "status": "root", "target": "target"}]},
		"phases": [
			{"id": "molt", "name": "Molt", "below_hp_bp": 8000, "targeting": "farthest",
				"mana": {"max": 100, "regen_per_s": 20},
				"signature": {"id": "call", "name": "Call the Brood", "trigger": {"kind": "mana"}, "targeting": "self", "cast_ms": 1500,
					"effects": [{"type": "start_collapse"}, {"type": "summon", "kit": "pup", "count": 2, "placement": "edges"}]}},
			{"id": "last_ember", "name": "Last Ember", "below_hp_bp": 5000, "targeting": "nearest",
				"signature": {"id": "ember_breath", "name": "Ember Breath", "trigger": {"kind": "fight_start"}, "targeting": "largest_group", "max_range": 6,
					"effects": [{"type": "start_collapse"}, {"type": "area", "shape": {"kind": "cone", "depth": 3}, "anchor": "target_direction", "warning_ms": 800, "hits": "enemies",
						"effects": [{"type": "damage", "amount": 30, "target": "target"}]}]},
				"passives": [{"id": "cinders", "name": "Cinders", "kind": "ability", "effects": [{"trigger": "on_hit_taken", "every": 5, "type": "damage", "amount": 6, "target": "hit_target"}]}]},
		]})
	var pup: UnitDef = K.kit("pup", {"stats": {"hp": 90, "atk": 8, "speed": 3}, "basic_attack": {"cooldown_ms": 800, "effects": [{"type": "damage", "amount": 5, "target": "target"}]},
		"signature": {"id": "yelp", "name": "Yelp", "trigger": {"kind": "fight_start"}, "targeting": "self", "effects": [{"type": "shield", "amount": 10, "target": "self"}]},
		"passives": [{"id": "spite", "name": "Spite", "kind": "ability", "effects": [{"trigger": "on_shield_broken", "type": "damage", "amount_bp_of_damage": 10000, "target": "hit_target"}]}]})

	var fight: FightSetup = K.fight(
		[K.at(warden, 3, 2), K.at(mender, 2, 0), K.at(brand, 5, 2), K.at(hook, 6, 1)] as Array[UnitSetup],
		[K.foe(hound, 2, 4), K.foe(hound, 5, 4), K.foe(witch, 1, 6), K.foe(caller, 6, 6), K.foe(brute, 4, 5)] as Array[UnitSetup],
		[Vector2i(3, 3), Vector2i(4, 3), Vector2i(0, 3)] as Array[Vector2i], fight_seed)
	fight.summon_kits.append(pup)
	var tithe: EffectDef = EffectDef.new()
	tithe.type = EffectDef.Type.SHIELD
	tithe.target = EffectDef.Target.ALL_ALLIES
	tithe.amount_bp_of_max_hp = 500
	fight.relic_effects.append(tithe)
	fight.relic_sources.append(EffectSource.relic("tithe", "Tithe", EffectSource.Team.HEROES))
	fight.relic_scales.append(FixedMath.BP_ONE)
	fight.salt_circles = 1
	return fight
