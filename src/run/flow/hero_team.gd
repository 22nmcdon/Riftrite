class_name HeroTeam
extends RefCounted
## A team (phase 8 part 4, docs/plans/rebuild-phase8-heroes.md, 8d-1): the
## three heroes a run or a Practice fight takes, drafted from the roster in
## data/heroes.json. A hero can be drafted once all its paths are built
## (`ready`), since a run vows every hero to one.
##
## Roles place a team the same way whoever is on it: the tank is the
## toughest base kit (HP x (100 + DEF), as the good bot reads it), the far
## hero the longer reach of the other two, and the mid hero the last; ties
## go to heroes.json's order.

const SIZE: int = 3
## The team before there was a draft, and every default since.
const DEFAULT: Array[String] = ["brannoc", "maren", "vell"]
const ROLES: Array[String] = ["tank", "far", "mid"]
## The first formation, by role, before any fight: the tank in front of the
## other two (the sim runner's "guarded").
const GUARDED: Dictionary[String, Vector2i] = {"tank": Vector2i(3, 2), "far": Vector2i(3, 0), "mid": Vector2i(4, 0)}


## True if `hero_id` can be drafted: a known hero with all its paths.
static func ready(content: ContentDb, hero_id: String) -> bool:
	return content.heroes.has(hero_id) and content.heroes[hero_id].paths.size() == ContentDb.PATHS_PER_HERO


## The heroes a draft offers: every ready hero, in heroes.json's order.
static func draftable(content: ContentDb) -> Array[String]:
	var ids: Array[String] = []
	for hero_id: String in content.hero_ids:
		if ready(content, hero_id):
			ids.append(hero_id)
	return ids


## Why `team` can't be drafted ("" if it can): three different ready heroes
## (Practice fields heroes whose paths aren't built yet, at base: `drafted`
## false).
static func problem(content: ContentDb, team: Array[String], drafted: bool = true) -> String:
	if team.size() != SIZE:
		return "a team is %d heroes, not %d" % [SIZE, team.size()]
	for hero_id: String in team:
		if not content.heroes.has(hero_id):
			return "unknown hero \"%s\"" % hero_id
		if team.count(hero_id) > 1:
			return "%s is on the team twice" % hero_id
		if drafted and not ready(content, hero_id):
			return "%s can't be drafted yet: their paths aren't built" % hero_id
	return ""


## `heroes` in heroes.json's order (the order they act in).
static func ordered(content: ContentDb, heroes: Array) -> Array[String]:
	var ids: Array[String] = []
	for hero_id: String in content.hero_ids:
		if heroes.has(hero_id):
			ids.append(hero_id)
	return ids


## Role -> hero id for a team of three (see the top).
static func roles(content: ContentDb, team: Array[String]) -> Dictionary[String, String]:
	var heroes: Array[String] = ordered(content, team)
	var by_role: Dictionary[String, String] = {}
	if heroes.size() != SIZE:
		return by_role
	var tank: String = heroes[0]
	for hero_id: String in heroes:
		if _toughness(content, hero_id) > _toughness(content, tank):
			tank = hero_id
	heroes.erase(tank)
	var far: String = heroes[0] if _reach(content, heroes[0]) >= _reach(content, heroes[1]) else heroes[1]
	heroes.erase(far)
	by_role["tank"] = tank
	by_role["far"] = far
	by_role["mid"] = heroes[0]
	return by_role


## A formation by role (role -> hex) for `team`: hero id -> hex.
static func place(content: ContentDb, team: Array[String], by_role: Dictionary) -> Dictionary[String, Vector2i]:
	var hexes: Dictionary[String, Vector2i] = {}
	var cast: Dictionary[String, String] = roles(content, team)
	for role: String in ROLES:
		if cast.has(role) and by_role.has(role):
			hexes[cast[role]] = by_role[role]
	return hexes


static func _toughness(content: ContentDb, hero_id: String) -> int:
	var stats: UnitStats = content.heroes[hero_id].kit.stats
	return stats.get_stat(UnitStats.Stat.HP) * (100 + stats.get_stat(UnitStats.Stat.DEF))


static func _reach(content: ContentDb, hero_id: String) -> int:
	return content.heroes[hero_id].kit.stats.get_stat(UnitStats.Stat.RANGE)
