extends GutTest
## The sim pieces phase 5's sigils and tactics need (docs/plans/rebuild-phase5-run.md,
## section 7): a signature's extra triggers (an ally falls; below an HP
## share), its Echo, and the Plant your feet tactic (stop_near).

const K = preload("res://tests/sim/sim_test_kit.gd")

## A mana signature that never fills on its own: it fires only on what a
## sigil adds.
const ZAP: Dictionary = {"id": "zap", "name": "Zap", "trigger": {"kind": "mana"}, "targeting": "nearest", "max_range": 8,
	"effects": [{"type": "damage", "amount": 40, "target": "target"}]}


static func mod(data: Dictionary) -> KitMod:
	var errors: Array[String] = []
	var made: KitMod = KitMod.read(DataReader.new(data, "mod", errors))
	assert(errors.is_empty(), str(errors))
	return made


func _zapper(sigil: Dictionary, overrides: Dictionary = {}) -> UnitDef:
	var data: Dictionary = {"signature": ZAP, "mana": {"max": 1000}, "stats": {"hp": 200, "atk": 0, "speed": 0}}
	data.merge(overrides, true)
	return mod(sigil).apply(K.kit("zapper", data))


func _fires(fight: CombatSim, ability_id: String) -> Array[LogEntry]:
	return K.entries(fight, LogEntry.Kind.FIRE, "zapper").filter(func(entry: LogEntry) -> bool: return entry.source_ability == ability_id)


func test_a_signature_also_fires_when_an_ally_falls() -> void:
	var zapper: UnitDef = _zapper({"also_fires": [{"kind": "ally_falls"}]})
	var frail: UnitDef = K.kit("frail", {"stats": {"hp": 5, "speed": 0}})
	var brute: UnitDef = K.kit("brute", {"stats": {"hp": 1000, "speed": 2}})
	var fight: CombatSim = K.sim(K.fight([K.at(zapper, 3, 0), K.at(frail, 3, 2)] as Array[UnitSetup], [K.foe(brute, 3, 4)] as Array[UnitSetup]))
	K.step(fight, 60)
	var deaths: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DEATH)
	assert_eq(deaths.size(), 1)
	var fires: Array[LogEntry] = _fires(fight, "zap")
	assert_eq(fires.size(), 1, "one ally fell, one fire")
	assert_eq(fires[0].note, "an ally fell")
	assert_eq(fires[0].tick, deaths[0].tick + 1, "on the next update")
	assert_eq(fight.unit_by_id("zapper").mana, 0, "free of mana")


func test_a_signature_also_fires_once_below_an_hp_share() -> void:
	var zapper: UnitDef = _zapper({"also_fires": [{"kind": "hp_below", "threshold_bp": 5000}]})
	var brute: UnitDef = K.kit("brute", {"stats": {"hp": 1000, "speed": 2}, "basic_attack": {"effects": [{"type": "damage", "amount": 30, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(zapper, 3, 2)] as Array[UnitSetup], [K.foe(brute, 3, 4)] as Array[UnitSetup]))
	K.step(fight, 200)
	var fires: Array[LogEntry] = _fires(fight, "zap")
	assert_eq(fires.size(), 1, "once a fight")
	assert_eq(fires[0].note, "below 50% HP")


func test_an_echo_fires_again_weaker() -> void:
	var zapper: UnitDef = mod({"echo": {"after_ms": 1000, "share_pct": 50}}).apply(K.kit("zapper", {"stats": {"hp": 200, "atk": 0, "speed": 0},
		"signature": {"id": "zap", "name": "Zap", "trigger": {"kind": "fight_start"}, "targeting": "nearest", "max_range": 8,
			"effects": [{"type": "damage", "amount": 40, "target": "target"}]}}))
	assert_eq([zapper.signature.echo.id, zapper.signature.echo.name, zapper.signature.echo.effects[0].amount], ["zap_echo", "Zap (Echo)", 20])
	var dummy: UnitDef = K.kit("dummy", {"stats": {"hp": 1000, "speed": 0}, "basic_attack": {"effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(zapper, 3, 0)] as Array[UnitSetup], [K.foe(dummy, 3, 6)] as Array[UnitSetup]))
	K.step(fight, 80)
	var first: Array[LogEntry] = _fires(fight, "zap")
	var echo: Array[LogEntry] = _fires(fight, "zap_echo")
	assert_eq([first.size(), echo.size()], [1, 1], "one fire, one echo")
	assert_eq(echo[0].tick, first[0].tick + 20, "1s later")
	var hits: Array = K.entries(fight, LogEntry.Kind.DAMAGE).filter(func(entry: LogEntry) -> bool: return entry.source_unit == "zapper").map(func(entry: LogEntry) -> int: return entry.amount)
	assert_eq(hits, [40, 20], "the echo at half strength")


func test_sigil_mods_are_checked() -> void:
	var errors: Array[String] = []
	KitMod.read(DataReader.new({"also_fires": [{"kind": "mana"}]}, "mod", errors))
	assert_string_contains(errors[0], "can also fire on hp_below, ally_falls, or every")
	errors.clear()
	KitMod.read(DataReader.new({"echo": {"after_ms": 1000, "share_pct": 150}}, "mod", errors))
	assert_eq(errors.size(), 1)
	var echo: KitMod = mod({"echo": {"after_ms": 1000, "share_pct": 50}})
	assert_true(echo.affects(K.kit("zapper", {"signature": ZAP, "mana": {"max": 50}})))
	assert_false(echo.affects(K.kit("plain")), "no signature, no effect")


func test_plant_your_feet_stops_near_an_enemy() -> void:
	var content: ContentDb = K.content()
	var archer: UnitDef = K.kit("maren", {"stats": {"range": 1, "speed": 2}})
	var post: UnitDef = K.kit("post", {"stats": {"hp": 1000, "speed": 0}, "basic_attack": {"effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var hero: UnitSetup = K.at(archer, 3, 0)
	hero.tactic = content.tactics["plant_feet"]
	var fight: CombatSim = K.sim(K.fight([hero] as Array[UnitSetup], [K.foe(post, 3, 6)] as Array[UnitSetup]))
	K.step(fight, 200)
	var unit: UnitState = fight.unit_by_id("maren")
	var gap: int = ArenaPlane.length(fight.unit_by_id("post").pos - unit.pos)
	assert_between(gap, 1700, 2000, "it walked in, then stopped at 2 hexes (%d)" % gap)
	var lines: Array[LogEntry] = K.entries(fight, LogEntry.Kind.TACTIC, "maren")
	assert_eq(lines.size(), 1)
	assert_eq(lines[0].note, "plants its feet: post is within 2 hexes")
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "maren"), [] as Array[LogEntry], "the post is out of its reach")


func test_plant_your_feet_closes_in_again() -> void:
	var content: ContentDb = K.content()
	var fighter: UnitDef = K.kit("brannoc", {"stats": {"hp": 1000, "speed": 2}})
	var archer: UnitDef = K.kit("archer", {"stats": {"hp": 1000, "range": 5, "speed": 0}})
	var frail: UnitDef = K.kit("frail", {"stats": {"hp": 5, "speed": 0}})
	var far: UnitDef = K.kit("far", {"stats": {"hp": 1000, "speed": 0}, "basic_attack": {"effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var hero: UnitSetup = K.at(fighter, 3, 2)
	hero.tactic = content.tactics["plant_feet"]
	var fight: CombatSim = K.sim(K.fight([hero, K.at(archer, 2, 0)] as Array[UnitSetup], [K.foe(frail, 3, 4), K.foe(far, 6, 6)] as Array[UnitSetup]))
	K.step(fight, 300)
	var notes: Array = K.entries(fight, LogEntry.Kind.TACTIC, "brannoc").map(func(entry: LogEntry) -> String: return entry.note)
	assert_eq(notes, ["plants its feet: frail is within 2 hexes", "closes in again: no enemy within 2 hexes", "plants its feet: far is within 2 hexes"],
		"it waits near the frail one, walks on once the archer fells it, and waits again")
