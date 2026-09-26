class_name GuildBar
extends PanelContainer
## The guild along the bottom of every run screen (docs/plans/ui-overhaul.md,
## 3.1): a token per hero (click for their sheet, drop an item to give it),
## then the stash as compact tiles, the essence pouch as gems, relics as hex
## tokens, and the synergies found. Everything shows its details on hover.
## Everything goes through the RunSession.

var session: RunSession


static func make(run_session: RunSession) -> GuildBar:
	var bar := GuildBar.new()
	bar.session = run_session
	bar.add_theme_stylebox_override("panel", UiStyle.chrome("panel_bar", 14, 10))
	bar._build()
	return bar


func _build() -> void:
	var state: RunState = session.state
	var line := HFlowContainer.new()
	line.add_theme_constant_override("h_separation", 18)
	line.add_theme_constant_override("v_separation", 8)
	add_child(line)
	var heroes := HBoxContainer.new()
	heroes.add_theme_constant_override("separation", 6)
	for hero: RunHero in state.heroes:
		heroes.add_child(HeroToken.make(session, hero))
	line.add_child(_section("Your guild (%d/%d)" % [state.heroes.size(), FightSetup.ROSTER_CAP], heroes, "Click a hero to open their sheet."))
	line.add_child(_stash())
	line.add_child(_pouch())
	line.add_child(_relics())
	line.add_child(_synergies())


## A titled block of the bar.
func _section(title: String, body: Control, hint: String = "") -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	var heading: Label = UiStyle.heading(title, 15, UiStyle.EMBER)
	if not hint.is_empty():
		heading.mouse_filter = Control.MOUSE_FILTER_STOP
		Inspector.hover(heading, title, hint)
	section.add_child(heading)
	section.add_child(body)
	return section


func _stash() -> Control:
	var state: RunState = session.state
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	for i: int in state.stash.size():
		row.add_child(ItemTile.owned(session, state.stash[i], RunState.STASH, i, null, true))
	row.add_child(DropZone.make("Drop to stash", func(data: Dictionary) -> void: session.move_item(data["uid"], RunState.STASH, 99), false, 84,
		_can_move.bind(RunState.STASH), ItemTile.COMPACT_HEIGHT))
	return _section("Stash (%d/%d slots)" % [state.stash_used(session.content), session.content.tuning.stash_slots], row,
		"Items waiting for a hero. Drag one onto a hero's token (or into their sheet) to equip it.")


func _pouch() -> Control:
	var state: RunState = session.state
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	for i: int in state.pouch.size():
		row.add_child(EssenceChip.make(session.content, state.pouch[i], i, true))
	row.add_child(DropZone.make("Throw away", _discard, true, 76, Callable(), ItemTile.COMPACT_HEIGHT))
	var hint: String = "Drag an essence onto an item to infuse it. Drop an item or essence on Throw away to get rid of it."
	var shards: PackedStringArray = PackedStringArray()
	var shard_ids: Array = state.shards.keys()
	shard_ids.sort()
	for essence_id: String in shard_ids:
		if state.shards[essence_id] > 0:
			shards.append("%s %d" % [session.content.essences[essence_id].name, state.shards[essence_id]])
	if not shards.is_empty():
		hint += "\n\nShards: " + ", ".join(shards)
	return _section("Essences (%d/%d)" % [state.pouch.size(), session.content.tuning.pouch_cap], row, hint)


## Relics as hex tokens (docs/ui-asset-design.md, 8.2): rim by rarity;
## Legendary (boss) relics carry the rift bleed.
func _relics() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.custom_minimum_size = Vector2(0, ItemTile.COMPACT_HEIGHT)
	for relic_id: String in session.state.relics:
		var def: RelicDef = session.content.relics[relic_id]
		var hex: Glyph = Glyph.hex(def.name, UiStyle.rarity_color(def.rarity), 46, def.rarity == "legendary")
		hex.mouse_filter = Control.MOUSE_FILTER_STOP
		Inspector.hover_text(hex, ItemInfo.relic_text(session.content, relic_id))
		row.add_child(hex)
	if session.state.relics.is_empty():
		row.add_child(UiStyle.label("none yet", 14, UiStyle.TEXT_DIM))
	return _section("Relics (%d)" % session.state.relics.size(), row, "Relics work for the whole guild, and stay for the rest of the run.")


## Discovered synergies (hidden until found); hovering lists them, with the
## ones active for today's fight (as the guild stands) starred.
func _synergies() -> Control:
	var active: Array[String] = session.active_synergies()
	var found: PackedStringArray = PackedStringArray()
	var lit: int = 0
	for synergy_id: String in session.content.synergy_ids:
		if session.state.discovered.has(synergy_id):
			var on: bool = active.has(synergy_id)
			lit += 1 if on else 0
			found.append(("★ " if on else "• ") + session.content.synergies[synergy_id].name)
	var badge: Label = UiStyle.label("%d found · %d active" % [found.size(), lit] if not found.is_empty() else "none yet", 16, UiStyle.HIGHLIGHT if lit > 0 else UiStyle.TEXT_DIM)
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	var body: String = "\n".join(found) + "\n\n★ = active for today's fight as the guild stands." if not found.is_empty() else "None yet. They're hidden until a fight sets one off."
	Inspector.hover(badge, "Synergies found", body)
	return _section("Synergies", badge)


func _can_move(data: Dictionary, to: String) -> bool:
	return session.would_succeed(func(state: RunState) -> RunActions.Result: return RunActions.move_item(state, session.content, data["uid"], to, 99))


func _discard(data: Dictionary) -> void:
	if data.has("uid"):
		session.discard_item(data["uid"])
	else:
		session.discard_essence(data["pouch_index"])
