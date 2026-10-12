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
## Its Tithe's taste (added to its path's transformed one while vowed) and
## its own once earned (phase 8 part 5, Collector of Debts; null: none).
var vowed_tithe: TitheDef = null
var apex_tithe: TitheDef = null
## Its transmuting's taste and its own once earned (phase 8 part 6, Grand
## Transmutation; null: none).
var vowed_transmute: TransmuteDef = null
var apex_transmute: TransmuteDef = null
## A run snowball (phase 8 part 5: Golden Aegis, Collector of Debts): a
## growth on what the run counts ("run_counts"), from when it's earned; its
## steps' mod goes to its hero, or every hero with "team" (null: none).
var grows: GrowthDef = null
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
		# A taste that's only a Tithe needs no patch (phase 8 part 5,
		# Collector of Debts).
		var patch: DataReader = vowed.req_object("patch") if vowed.has("patch") or not (vowed.has("tithe") or vowed.has("transmute")) else null
		def.vowed_patch = KitPatch.read(patch) if patch != null else KitPatch.make()
		var tithe: DataReader = vowed.req_object("tithe") if vowed.has("tithe") else null
		def.vowed_tithe = TitheDef.read(tithe) if tithe != null else null
		def.vowed_transmute = TransmuteDef.read_in(vowed)
		vowed.finish()
	var apex: DataReader = reader.req_object("apex")
	if apex != null:
		def.text = apex.req_string("text")
		var patch: DataReader = apex.req_object("patch")
		def.apex_patch = KitPatch.read(patch) if patch != null else KitPatch.make()
		var tithe: DataReader = apex.req_object("tithe") if apex.has("tithe") else null
		def.apex_tithe = TitheDef.read(tithe) if tithe != null else null
		def.apex_transmute = TransmuteDef.read_in(apex)
		apex.finish()
	if def.vowed_patch == null:
		def.vowed_patch = KitPatch.make()
	if def.apex_patch == null:
		def.apex_patch = KitPatch.make()
	var deed_reader: DataReader = reader.req_object("deed")
	def.deed = DeedDef.read(deed_reader) if deed_reader != null else DeedDef.new()
	var grows: DataReader = reader.req_object("grows") if reader.has("grows") else null
	if grows != null:
		def.grows = GrowthDef.read(grows)
		if def.grows.counted_in_fights():
			reader.error("an apex grows with what the run counts (\"run_counts\")")
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
