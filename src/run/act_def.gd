class_name ActDef
extends RefCounted
## An act's shape (data/act1.json; docs/plans/rebuild-phase5-run.md, sections
## 2 and 3): its days (normal, elite, or boss), the shards a won fight pays by
## its tier, the shards a run starts with, how many losses end it, and each
## hero's loadout slots.

const DAY_KINDS: Array[String] = ["normal", "elite", "boss"]

var act: int
## One per day: "normal", "elite", or "boss".
var days: Array[String] = []
## Tier -> shards for a win or a tie.
var pay: Dictionary[String, int] = {}
var start_shards: int = 0
var losses_to_end: int = 2
## Loadout slots per hero (a relic may add one).
var slots: int = 3


static func read(reader: DataReader) -> ActDef:
	var def := ActDef.new()
	def.act = reader.req_int("act", 1)
	def.start_shards = reader.req_int("start_shards", 0)
	def.losses_to_end = reader.req_int("losses_to_end", 1)
	def.slots = reader.req_int("slots", 0, 6)
	var pay_reader: DataReader = reader.req_object("pay")
	if pay_reader != null:
		for tier: String in EncounterDef.TIERS:
			def.pay[tier] = pay_reader.req_int(tier, 0)
		pay_reader.finish()
	for day: String in reader.req_string_array("days"):
		if not DAY_KINDS.has(day):
			reader.error("days: \"%s\" isn't normal, elite, or boss" % day)
		def.days.append(day)
	if def.days.is_empty():
		reader.error("an act needs days")
	elif def.days.back() != "boss":
		reader.error("an act's last day is its boss")
	reader.finish()
	return def
