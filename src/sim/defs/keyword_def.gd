class_name KeywordDef
extends RefCounted
## A keyword from data/keywords.json (docs/plans/infusion-rework.md). Items
## carry 1-3 of them; a Resonant single essence spills to its holder's other
## items that share one. Each hero has two as affinities (HeroDef), and each
## keyword's "affinity" perk goes to those heroes: {"text", "parts": [...]},
## specialization-style parts credited as "Blade affinity"
## (docs/plans/keywords-and-affinities.md, section 4).

var id: String
var name: String
## One line for the UI: what kind of item carries it.
var text: String
## The affinity perk: what it does in words, and its parts.
var affinity_text: String = ""
var affinity: Array[SpecializationDef.Part] = []


static func read(reader: DataReader) -> KeywordDef:
	var def := KeywordDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.text = reader.req_string("text")
	var affinity_reader: DataReader = reader.req_object("affinity")
	if affinity_reader != null:
		def.affinity_text = affinity_reader.req_string("text")
		for part_reader: DataReader in affinity_reader.opt_object_array("parts"):
			var part: SpecializationDef.Part = SpecializationDef.read_part(part_reader, "%s affinity" % def.name, "affinity_%s" % def.id)
			if part.kind == SpecializationDef.Kind.BASIC_ATTACK:
				part_reader.error("an affinity can't replace the basic attack")
			# Its own key space: "affinity_blade_<key>".
			part.key = "affinity_%s_%s" % [def.id, part.key]
			def.affinity.append(part)
		if def.affinity.is_empty():
			affinity_reader.error("an affinity needs parts")
		affinity_reader.finish()
	reader.finish()
	return def
