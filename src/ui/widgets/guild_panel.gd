class_name GuildPanel
extends VBoxContainer
## The guild between fights: each hero's row (formation controls,
## specialization pick), the stash, the essence pouch, relics, and a place
## to throw things away. Everything goes through the RunSession.

var session: RunSession


static func make(run_session: RunSession) -> GuildPanel:
	var panel := GuildPanel.new()
	panel.session = run_session
	panel.add_theme_constant_override("separation", 6)
	panel._build()
	return panel


func _build() -> void:
	var state: RunState = session.state
	add_child(UiStyle.label("Your guild", 20, UiStyle.EMBER))
	for i: int in state.heroes.size():
		add_child(_hero_row(state.heroes[i], i))
	var stash_line := HBoxContainer.new()
	stash_line.add_child(UiStyle.label("Stash (%d/%d slots)" % [state.stash_used(session.content), session.content.tuning.stash_slots], 16))
	for i: int in state.stash.size():
		stash_line.add_child(ItemTile.owned(session, state.stash[i], RunState.STASH, i, null))
	stash_line.add_child(DropZone.make("Drop here to put it in the stash", func(data: Dictionary) -> void: session.move_item(data["uid"], RunState.STASH, 99)))
	add_child(stash_line)
	var pouch_line := HBoxContainer.new()
	pouch_line.add_child(UiStyle.label("Essences (%d/%d)" % [state.pouch.size(), session.content.tuning.pouch_cap], 16))
	for i: int in state.pouch.size():
		pouch_line.add_child(EssenceChip.make(session.content, state.pouch[i], i))
	var shards: PackedStringArray = PackedStringArray()
	var shard_ids: Array = state.shards.keys()
	shard_ids.sort()
	for essence_id: String in shard_ids:
		if state.shards[essence_id] > 0:
			shards.append("%s %d" % [session.content.essences[essence_id].name, state.shards[essence_id]])
	if not shards.is_empty():
		pouch_line.add_child(UiStyle.label("   Shards: " + ", ".join(shards), 13, UiStyle.TEXT_DIM))
	pouch_line.add_child(DropZone.make("Throw away", _discard, true, 110))
	add_child(pouch_line)
	var relic_line := HBoxContainer.new()
	relic_line.add_child(UiStyle.label("Relics:", 16))
	for relic_id: String in state.relics:
		var relic: Label = UiStyle.label(session.content.relics[relic_id].name, 16, UiStyle.rarity_color(session.content.relics[relic_id].rarity))
		Inspector.hover_text(relic, ItemInfo.relic_text(session.content, relic_id))
		relic.mouse_filter = Control.MOUSE_FILTER_STOP
		relic_line.add_child(relic)
	if state.relics.is_empty():
		relic_line.add_child(UiStyle.label("none yet", 16, UiStyle.TEXT_DIM))
	add_child(relic_line)


func _discard(data: Dictionary) -> void:
	if data.has("uid"):
		session.discard_item(data["uid"])
	else:
		session.discard_essence(data["pouch_index"])


func _hero_row(hero: RunHero, at: int) -> Control:
	var content: ContentDb = session.content
	var def: HeroDef = content.heroes[hero.hero_id]
	var panel := PanelContainer.new()
	if hero.benched:
		panel.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.BACKGROUND, UiStyle.BORDER))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	panel.add_child(line)
	line.add_child(Glyph.portrait(def.name, Glyph.CLASS_COLORS.get(def.hero_class, UiStyle.EMBER), 56))
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(330, 0)
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	line.add_child(info)
	var title: String = "%s  %s" % [def.name, TuningDef.TIER_LABELS[hero.rank]]
	var name_label: Label = UiStyle.label(title, 17, UiStyle.TEXT_DIM if hero.benched else UiStyle.TEXT)
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	Inspector.hover_text(name_label, ItemInfo.hero_text(content, hero.hero_id, hero.rank))
	info.add_child(name_label)
	var stats: UnitStats = ItemInfo.hero_stats(content, hero)
	var spec: String = content.specializations[hero.specialization_id].name if not hero.specialization_id.is_empty() else "no specialization yet"
	info.add_child(UiStyle.label("%s · %s" % [def.hero_class.capitalize(), spec], 14, UiStyle.EMBER))
	info.add_child(UiStyle.label("HP %d  ATK %d  MGK %d  DEF %d" % [stats.get_stat(UnitStats.Stat.HP), stats.get_stat(UnitStats.Stat.ATK), stats.get_stat(UnitStats.Stat.MGK), stats.get_stat(UnitStats.Stat.DEF)], 14, UiStyle.TEXT_DIM))
	var controls := HBoxContainer.new()
	info.add_child(controls)
	var row_name: String = "Front row" if hero.row == UnitSetup.Row.FRONT else "Back row"
	var row_button: Button = UiStyle.button(row_name, func() -> void:
		session.set_row(hero.hero_id, UnitSetup.Row.BACK if hero.row == UnitSetup.Row.FRONT else UnitSetup.Row.FRONT))
	row_button.tooltip_text = "Switch rows"
	controls.add_child(row_button)
	var bench_button: Button = UiStyle.button("In backup" if hero.benched else "Fielded", func() -> void: session.set_benched(hero.hero_id, not hero.benched))
	bench_button.tooltip_text = "Field this hero, or sit them in backup"
	controls.add_child(bench_button)
	var left: Button = UiStyle.button("◀", func() -> void: session.move_hero(hero.hero_id, at - 1))
	left.tooltip_text = "Move this hero earlier (further left)"
	controls.add_child(left)
	var right: Button = UiStyle.button("▶", func() -> void: session.move_hero(hero.hero_id, at + 1))
	right.tooltip_text = "Move this hero later (further right)"
	controls.add_child(right)
	if hero.needs_specialization:
		var pick := MenuButton.new()
		pick.text = "Choose a specialization!"
		pick.flat = false
		pick.add_theme_color_override("font_color", UiStyle.HIGHLIGHT)
		var options: Array[String] = []
		for spec_id: String in content.specialization_ids:
			if content.specializations[spec_id].hero == hero.hero_id:
				options.append(spec_id)
				pick.get_popup().add_item(content.specializations[spec_id].name)
		pick.get_popup().id_pressed.connect(func(id: int) -> void: session.choose_specialization(hero.hero_id, options[id]))
		info.add_child(pick)
	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", 4)
	line.add_child(items)
	for i: int in hero.items.size():
		items.add_child(ItemTile.owned(session, hero.items[i], hero.hero_id, i, stats))
	var free: int = hero.slots() - hero.used_slots(content)
	items.add_child(DropZone.make("%d free slot%s" % [free, "" if free == 1 else "s"], func(data: Dictionary) -> void: session.move_item(data["uid"], hero.hero_id, 99), false, maxi(free, 1) * UiStyle.SLOT_WIDTH))
	return panel
