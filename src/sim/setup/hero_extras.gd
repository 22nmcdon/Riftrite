class_name HeroExtras
extends RefCounted
## What a hero brings into a fight beyond its path and tactic (docs/plans/rebuild-phase5-run.md,
## sections 6 and 7): kit modifiers (its upgrades, its loadout's charms,
## sigils, and grafts, the team's relics, a duo bond), applied in this order
## after the path's patch, and its wounds.

var mods: Array[KitMod] = []
var wounds: int = 0


static func make(kit_mods: Array[KitMod] = [], wound_count: int = 0) -> HeroExtras:
	var extras := HeroExtras.new()
	extras.mods = kit_mods
	extras.wounds = wound_count
	return extras
