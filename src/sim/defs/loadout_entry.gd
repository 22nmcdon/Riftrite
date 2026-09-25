class_name LoadoutEntry
extends RefCounted
## One item in a fixed layout (an enemy's row, or a balance-sim party):
##   {"item": "rusted_cleaver", "tier": "b", "essences": ["ember"], "xp": 120}
## Only "item" is required. References are checked by ContentDb and turned
## into an ItemSetup by SetupBuilder.

var item_id: String
## 0 = C ... 3 = S.
var tier: int = 0
var essence_ids: Array[String] = []
var xp: int = 0


static func read(reader: DataReader) -> LoadoutEntry:
	var entry := LoadoutEntry.new()
	entry.item_id = reader.req_string("item")
	entry.tier = maxi(TuningDef.TIER_NAMES.find(reader.opt_string_choice("tier", "c", TuningDef.TIER_NAMES)), 0)
	if reader.has("essences"):
		entry.essence_ids = reader.req_string_array("essences")
	entry.xp = reader.opt_int("xp", 0, 0)
	reader.finish()
	return entry


static func read_list(reader: DataReader, key: String) -> Array[LoadoutEntry]:
	var entries: Array[LoadoutEntry] = []
	for entry_reader: DataReader in reader.opt_object_array(key):
		entries.append(LoadoutEntry.read(entry_reader))
	return entries
