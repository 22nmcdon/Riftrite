class_name CompanionDef
extends RefCounted
## A hero's companion (phase 8 part 6, docs/plans/phases/rebuild-phase8-last-heroes.md
## section 6, Kestra): a kit of its own that fights beside the hero, written
## in the hero's kit:
##   {"kit": {...a kit with "id" and "name"...}, "hp_pct": 40, "atk_pct": 60,
##    "return_ms": 10000, "starts": true}
## Its max HP and ATK are those shares of its hero's as the fight is set up
## (CombatSim: her max HP with her wounds, her kit's ATK with her upgrades,
## loadout, and relics; Decision 4). One that `starts` stands beside her from
## the fight's start; one that doesn't is a kit her summons may name (Nest's
## vipers). With `return_ms`, one that falls comes back that long after, if
## its hero stands then (0: it doesn't).

var kit: UnitDef
var hp_bp: int = 0
var atk_bp: int = 0
var return_ticks: int = 0
var starts: bool = true


static func read(reader: DataReader) -> CompanionDef:
	var def := CompanionDef.new()
	var kit_reader: DataReader = reader.req_object("kit")
	def.kit = UnitDef.read(kit_reader) if kit_reader != null else null
	def.hp_bp = reader.req_int("hp_pct", 1, 500) * 100
	def.atk_bp = reader.req_int("atk_pct", 1, 500) * 100
	def.return_ticks = reader.opt_ticks("return_ms", 0)
	def.starts = reader.opt_bool("starts", true)
	if def.kit != null and not def.kit.companions.is_empty():
		reader.error("a companion has no companions of its own")
	reader.finish()
	return def


## A copy to change (KitMod): the kit is shared until it's replaced.
func copy() -> CompanionDef:
	var other := CompanionDef.new()
	other.kit = kit
	other.hp_bp = hp_bp
	other.atk_bp = atk_bp
	other.return_ticks = return_ticks
	other.starts = starts
	return other


## Its kit for a fight beside `owner`: its HP and ATK its shares of hers.
func kit_for(owner_max_hp: int, owner_atk: int) -> UnitDef:
	var built: UnitDef = kit.copy()
	built.phases = kit.phases
	built.stats = kit.stats.copy()
	built.stats.values[UnitStats.Stat.HP] = maxi(FixedMath.apply_bp(owner_max_hp, hp_bp), 1)
	built.stats.values[UnitStats.Stat.ATK] = FixedMath.apply_bp(owner_atk, atk_bp)
	return built
