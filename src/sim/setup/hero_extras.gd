class_name HeroExtras
extends RefCounted
## What a hero brings into a fight beyond its path and tactic (docs/plans/rebuild-phase5-run.md,
## sections 6 and 7): kit modifiers (its upgrades, its loadout's charms,
## sigils, and grafts, the team's relics, a duo bond), applied in this order
## after the path's patch, and its wounds.

var mods: Array[KitMod] = []
var wounds: int = 0
## What each wound takes, in basis points of max HP (0: tuning's wound_bp;
## a relic can change it).
var wound_bp: int = 0
## What its growing cards count (phase 5c step 4): keys and how each counts
## (UnitSetup.tally_keys, tally_counts).
var tally_keys: Array[String] = []
var tally_counts: Array[DeedDef] = []


static func make(kit_mods: Array[KitMod] = [], wound_count: int = 0, each_wound_bp: int = 0) -> HeroExtras:
	var extras := HeroExtras.new()
	extras.mods = kit_mods
	extras.wounds = wound_count
	extras.wound_bp = each_wound_bp
	return extras
