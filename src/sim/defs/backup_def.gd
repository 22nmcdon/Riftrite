class_name BackupDef
extends RefCounted
## What a hero (their Backup effect) or an item (its backup mode) does while
## its hero sits in backup (docs/plans/backup-in-sim.md):
##   "backup": {"name": "Lantern Vigil", "cooldown_ms": 5000,
##              "effects": [...], "auras": [...]}
## Effects fire every cooldown; auras hold all fight. From backup there is no
## spot on the field, so effects can't target self, linked allies, or the
## row, and auras can only target all_allies.

const DEFAULT_NAME: String = "Backup"
const FIELD_ONLY_TARGETS: Array[EffectDef.Target] = [
	EffectDef.Target.SELF,
	EffectDef.Target.LINKED_ALLY,
	EffectDef.Target.LINKED_LEFT_ALLY,
	EffectDef.Target.LINKED_RIGHT_ALLY,
	EffectDef.Target.LINKED_ALLIES,
	EffectDef.Target.ROW_ALLIES,
]

## Shown in the log as "<name> (backup)". Items default to the item's name.
var name: String = ""
var cooldown_ticks: int = 0
var effects: Array[EffectDef] = []
var auras: Array[AuraDef] = []


static func read(reader: DataReader, allow_rate_scaling: bool) -> BackupDef:
	var def := BackupDef.new()
	if reader.has("name"):
		def.name = reader.req_string("name")
	for effect_reader: DataReader in reader.opt_object_array("effects"):
		var effect: EffectDef = EffectDef.read(effect_reader)
		if FIELD_ONLY_TARGETS.has(effect.target):
			effect_reader.error("\"%s\" needs a spot on the field, so a backup effect can't use it" % EffectDef.TARGET_NAMES[effect.target])
		if effect.scales_from_rate_stats() and not allow_rate_scaling:
			effect_reader.error("only Epic and Legendary items can scale from crit or atsp")
		def.effects.append(effect)
	for aura_reader: DataReader in reader.opt_object_array("auras"):
		var aura: AuraDef = AuraDef.read(aura_reader)
		if aura.target != AuraDef.Target.ALL_ALLIES:
			aura_reader.error("a backup aura can only target all_allies")
		def.auras.append(aura)
	if def.effects.is_empty():
		def.cooldown_ticks = reader.opt_ticks("cooldown_ms", 0)
	else:
		def.cooldown_ticks = reader.req_ticks("cooldown_ms", FixedMath.MS_PER_TICK)
	if def.effects.is_empty() and def.auras.is_empty():
		reader.error("a backup needs effects or auras")
	reader.finish()
	return def


## The backup as an item that fires from the bench. `source` is the item whose
## backup mode this is (it keeps that item's id, rarity, size, and XP rate so
## infusions, tiers, and XP work), or null for a hero's own Backup effect.
func as_item_def(source: ItemDef, hero_id: String) -> ItemDef:
	var item := ItemDef.new()
	if source != null:
		item.id = source.id
		item.size = source.size
		item.tags = source.tags
		item.rarity = source.rarity
		item.xp_per_fire = source.xp_per_fire
		item.crit_chance_bp = source.crit_chance_bp
	else:
		item.id = "%s_backup" % hero_id
	var label: String = name
	if label.is_empty():
		label = source.name if source != null else DEFAULT_NAME
	item.name = "%s (backup)" % label
	item.cooldown_ticks = maxi(cooldown_ticks, 1)
	item.effects = effects
	item.auras = auras
	return item
