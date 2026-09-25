class_name ModifierDef
extends RefCounted
## A passive change to the stats of the item it sits on (for example, Storm's
## faster cooldown). Values are basis points added to the item's stat:
##   cooldown_bp:             -1500 means the cooldown is 15% shorter
##   crit_chance_bp:          added to the item's crit chance
##   extra_trigger_chance_bp: chance the item fires a second time
## Adding a stat is a code change; say so when you make one.

enum Stat { COOLDOWN_BP, CRIT_CHANCE_BP, EXTRA_TRIGGER_CHANCE_BP }

const STAT_NAMES: Array[String] = ["cooldown_bp", "crit_chance_bp", "extra_trigger_chance_bp"]

var stat: Stat
var value: int


static func read(reader: DataReader) -> ModifierDef:
	var def := ModifierDef.new()
	var stat_name: String = reader.req_choice("stat", STAT_NAMES)
	def.stat = maxi(STAT_NAMES.find(stat_name), 0) as Stat
	def.value = reader.req_int("value", -FixedMath.BP_ONE, FixedMath.BP_ONE)
	reader.finish()
	return def
