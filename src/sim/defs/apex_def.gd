class_name ApexDef
extends RefCounted
## One of a path's two apexes, in its entry in data/paths.json
## (docs/plans/rebuild-phase8-apexes.md; apexes.md): the path's final form.
##   "apexes": [{"id": "windrunner", "name": "Windrunner", "title": "...",
##     "fantasy": "...",
##     "vowed": {"taste": "...", "patch": {...a KitPatch...}},
##     "apex": {"text": "...", "patch": {...a KitPatch...}},
##     "deed": {...a DeedDef...}}]
## Both patches change the path's transformed kit (an apex builds on the
## transformation; the apex patch replaces the taste's rather than adding to
## it). No costs: the relic rules apply (apexes.md). ContentDb builds both
## kits once the path's are built. The texts are the player's.

var id: String
## The path it crowns.
var path: String
var name: String
var title: String
var fantasy: String
var taste: String
var vowed_patch: KitPatch
## What the apex brings.
var text: String
var apex_patch: KitPatch
var deed: DeedDef
## Built by ContentDb (null until then).
var vowed_kit: UnitDef = null
var apex_kit: UnitDef = null


static func read(reader: DataReader, path_id: String) -> ApexDef:
	var def := ApexDef.new()
	def.path = path_id
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.title = reader.req_string("title")
	def.fantasy = reader.req_string("fantasy")
	var vowed: DataReader = reader.req_object("vowed")
	if vowed != null:
		def.taste = vowed.req_string("taste")
		var patch: DataReader = vowed.req_object("patch")
		def.vowed_patch = KitPatch.read(patch) if patch != null else KitPatch.make()
		vowed.finish()
	var apex: DataReader = reader.req_object("apex")
	if apex != null:
		def.text = apex.req_string("text")
		var patch: DataReader = apex.req_object("patch")
		def.apex_patch = KitPatch.read(patch) if patch != null else KitPatch.make()
		apex.finish()
	if def.vowed_patch == null:
		def.vowed_patch = KitPatch.make()
	if def.apex_patch == null:
		def.apex_patch = KitPatch.make()
	var deed_reader: DataReader = reader.req_object("deed")
	def.deed = DeedDef.read(deed_reader) if deed_reader != null else DeedDef.new()
	reader.finish()
	return def


## The kit at an apex stage (APEX_VOWED or APEX); null for any other.
func kit(stage: PathDef.Stage) -> UnitDef:
	match stage:
		PathDef.Stage.APEX_VOWED:
			return vowed_kit
		PathDef.Stage.APEX:
			return apex_kit
	return null
