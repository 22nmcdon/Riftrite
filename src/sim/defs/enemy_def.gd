class_name EnemyDef
extends RefCounted
## An enemy in data/enemies.json (docs/plans/rebuild-phase2-heroes-enemies.md,
## section 2): its archetype and the one-line threat the fight card shows,
## and its kit (phases included; the kit carries the archetype too, for
## tactics). Summons name enemies.
##   {"id": "rift_hound", "name": "Rift Hound", "archetype": "flanker",
##    "threat": "Pounces on your weakest back-liner",
##    "kit": {...a UnitDef, without id or name...},
##    "specializations": [...up to two SpecializationDefs...]}  (phase 8 part 3)

## Phase 8 part 3 (Act 2) adds the summoner and the splitter.
enum Archetype { SWARM, FLANKER, CASTER, RANGED, ANCHOR, CHARGER, DISRUPTOR, SUPPORT, SUMMONER, SPLITTER }

const ARCHETYPE_NAMES: Array[String] = ["swarm", "flanker", "caster", "ranged", "anchor", "charger", "disruptor", "support", "summoner", "splitter"]

var id: String
var name: String
var archetype: Archetype
var threat: String
var kit: UnitDef
## Its specializations (phase 8 part 3), up to SpecializationDef.PER_ENEMY.
var specializations: Array[SpecializationDef] = []


static func read(reader: DataReader) -> EnemyDef:
	var def := EnemyDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.archetype = maxi(ARCHETYPE_NAMES.find(reader.req_choice("archetype", ARCHETYPE_NAMES)), 0) as Archetype
	def.threat = reader.req_string("threat")
	var kit_reader: DataReader = reader.req_object("kit")
	def.kit = UnitDef.read(kit_reader, def.id, def.name) if kit_reader != null else null
	if def.kit != null:
		def.kit.archetype = ARCHETYPE_NAMES[def.archetype]
	for spec_reader: DataReader in reader.opt_object_array("specializations"):
		def.specializations.append(SpecializationDef.read(spec_reader, def.id))
	if def.specializations.size() > SpecializationDef.PER_ENEMY:
		reader.error("an enemy has at most %d specializations" % SpecializationDef.PER_ENEMY)
	reader.finish()
	return def
