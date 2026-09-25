class_name EncounterDef
extends RefCounted
## An enemy team from data/encounters.json: which enemies stand where.

const ROW_NAMES: Array[String] = ["front", "back"]


class Slot:
	var enemy_id: String
	var row: UnitSetup.Row


var id: String
var name: String
var act: int = 1
## In order: units in the same row stand left to right in this order.
var units: Array[Slot] = []


static func read(reader: DataReader) -> EncounterDef:
	var def := EncounterDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.act = reader.req_int("act", 1)
	for unit_reader: DataReader in reader.opt_object_array("units"):
		var slot := Slot.new()
		slot.enemy_id = unit_reader.req_string("enemy")
		slot.row = maxi(ROW_NAMES.find(unit_reader.opt_string_choice("row", "front", ROW_NAMES)), 0) as UnitSetup.Row
		unit_reader.finish()
		def.units.append(slot)
	if def.units.is_empty():
		reader.error("an encounter needs at least one unit")
	reader.finish()
	return def
