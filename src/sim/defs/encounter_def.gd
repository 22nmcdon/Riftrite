class_name EncounterDef
extends RefCounted
## An enemy team from data/encounters.json: which enemies stand where.

const ROW_NAMES: Array[String] = ["front", "back"]
## What kind of fight it is in a run: a normal day, an elite day, or the
## act's boss.
const KIND_NAMES: Array[String] = ["normal", "elite", "boss"]


class Slot:
	var enemy_id: String
	var row: UnitSetup.Row


var id: String
var name: String
var act: int = 1
var kind: String = "normal"
## In order: units in the same row stand left to right in this order.
var units: Array[Slot] = []
## Relic ids the enemy team carries.
var relics: Array[String] = []
## What this fight asks of the player (docs/plans/fight-questions-and-
## readability.md, section 2): a name, what it does, and what answers it.
## Text for the UI only; what the enemies do lives in their items, relics,
## and phases. Every elite and boss has one.
var mechanic_name: String = ""
var mechanic_text: String = ""
var mechanic_counter: String = ""


static func read(reader: DataReader) -> EncounterDef:
	var def := EncounterDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.act = reader.req_int("act", 1)
	def.kind = reader.opt_string_choice("kind", "normal", KIND_NAMES)
	for unit_reader: DataReader in reader.opt_object_array("units"):
		var slot := Slot.new()
		slot.enemy_id = unit_reader.req_string("enemy")
		slot.row = maxi(ROW_NAMES.find(unit_reader.opt_string_choice("row", "front", ROW_NAMES)), 0) as UnitSetup.Row
		unit_reader.finish()
		def.units.append(slot)
	if reader.has("relics"):
		def.relics = reader.req_string_array("relics")
	var mechanic: DataReader = reader.req_object("mechanic") if reader.has("mechanic") else null
	if mechanic != null:
		def.mechanic_name = mechanic.req_string("name")
		def.mechanic_text = mechanic.req_string("text")
		def.mechanic_counter = mechanic.req_string("counter")
		mechanic.finish()
	elif def.kind != "normal":
		reader.error("%s encounter needs a mechanic (name, text, counter)" % ("an elite" if def.kind == "elite" else "a boss"))
	if def.units.is_empty():
		reader.error("an encounter needs at least one unit")
	reader.finish()
	return def
