class_name HeroDef
extends RefCounted
## A hero from data/heroes.json: class, stats at rank C, their own basic
## auto-attack, their innate, and their calling (a deed track from the start
## of the run; docs/plans/deeds.md). Loadout slots come from rank (see
## TuningDef.ability_slots / passive_slots), and the loadout comes from the
## run (or a balance-sim party).

const CLASSES: Array[String] = ["warden", "striker", "arcanist", "mender", "trickster", "ranger"]

var id: String
var name: String
var hero_class: String
var stats: UnitStats
var basic_attack: ItemDef
## The hero's innate: something only they do, always on while they fight
## (docs/plans/heroes-and-deeds.md). Made of specialization-style parts
## (auras, grants, abilities, replace_status), credited to `innate_name`.
var innate_name: String = ""
var innate_text: String = ""
var innate: Array[SpecializationDef.Part] = []
## The calling: "calling": {"name", "text", "deed", "levels"}. Its parts
## merge with the innate's (a same-key part replaces the innate's).
var calling_name: String = ""
var calling_text: String = ""
var calling: DeedTrackDef = null


static func read(reader: DataReader) -> HeroDef:
	var def := HeroDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.hero_class = reader.req_choice("class", CLASSES)
	var stats_reader: DataReader = reader.req_object("stats")
	def.stats = UnitStats.read(stats_reader) if stats_reader != null else UnitStats.make(1)
	var attack_reader: DataReader = reader.req_object("basic_attack")
	if attack_reader != null:
		def.basic_attack = ItemDef.read_basic_attack(attack_reader)
	var innate_reader: DataReader = reader.req_object("innate")
	if innate_reader != null:
		def.innate_name = innate_reader.req_string("name")
		def.innate_text = innate_reader.req_string("text")
		var keys: Array[String] = []
		for part_reader: DataReader in innate_reader.opt_object_array("parts"):
			var part: SpecializationDef.Part = SpecializationDef.read_part(part_reader, def.innate_name, "%s_innate" % def.id)
			if part.kind == SpecializationDef.Kind.BASIC_ATTACK:
				part_reader.error("an innate can't replace the basic attack")
			if keys.has(part.key):
				part_reader.error("key \"%s\" is used twice" % part.key)
			keys.append(part.key)
			def.innate.append(part)
		if def.innate.is_empty():
			innate_reader.error("an innate needs parts")
		innate_reader.finish()
	var calling_reader: DataReader = reader.req_object("calling")
	if calling_reader != null:
		def.calling_name = calling_reader.req_string("name")
		def.calling_text = calling_reader.req_string("text")
		def.calling = DeedTrackDef.read(calling_reader, def.calling_name, "%s_calling" % def.id)
	reader.finish()
	return def
