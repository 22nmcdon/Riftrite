class_name HeroSheet
extends PanelContainer
## A hero's sheet (docs/plans/ui-overhaul.md, 3.2), opened by clicking their
## token in the guild bar. It opens above the bar: portrait, name, class and
## specialization, stats, basic attack and Backup, the formation controls,
## and the hero's item row at full size, where items are rearranged,
## combined, and infused by dragging. Arrows step to the next hero; ✕ (or
## clicking the token again) closes it. Everything goes through the
## RunSession.

var session: RunSession
var hero_id: String


static func make(run_session: RunSession, hero: RunHero) -> HeroSheet:
	var sheet := HeroSheet.new()
	sheet.session = run_session
	sheet.hero_id = hero.hero_id
	var style: StyleBoxFlat = UiStyle.box(UiStyle.PANEL, UiStyle.BRASS_500, 3)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 12
	sheet.add_theme_stylebox_override("panel", style)
	sheet._build(hero)
	return sheet


func _build(hero: RunHero) -> void:
	var content: ContentDb = session.content
	var def: HeroDef = content.heroes[hero.hero_id]
	var at: int = session.state.heroes.find(hero)
	var stats: UnitStats = ItemInfo.hero_stats(content, hero)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	add_child(line)
	line.add_child(Glyph.portrait(def.name, Glyph.CLASS_COLORS.get(def.hero_class, UiStyle.EMBER), 88))
	# Who they are, and their controls.
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.custom_minimum_size = Vector2(420, 0)
	line.add_child(info)
	info.add_child(UiStyle.label("%s   %s" % [def.name, TuningDef.TIER_LABELS[hero.rank]], 22, UiStyle.TEXT_DIM if hero.benched else UiStyle.TEXT))
	var spec: String = content.specializations[hero.specialization_id].name if not hero.specialization_id.is_empty() else "no specialization yet"
	info.add_child(UiStyle.label("%s · %s" % [def.hero_class.capitalize(), spec], 16, UiStyle.EMBER))
	info.add_child(UiStyle.label(ItemInfo.stat_line(stats), 15, UiStyle.TEXT))
	var about: Label = UiStyle.label(_basic_and_backup(def), 14, UiStyle.TEXT_DIM)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(about)
	info.add_child(_controls(hero, at))
	if hero.needs_specialization:
		info.add_child(_specialization_pick(hero))
	# Their items.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	line.add_child(right)
	var top := HBoxContainer.new()
	right.add_child(top)
	var free: int = hero.slots() - hero.used_slots(content)
	var heading: Label = UiStyle.label("Items (%d of %d slots used)" % [hero.used_slots(content), hero.slots()], 16, UiStyle.HIGHLIGHT)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	var count: int = session.state.heroes.size()
	if count > 1:
		var previous: Button = UiStyle.button("◀ Previous hero", func() -> void: session.open_hero(session.state.heroes[posmod(at - 1, count)].hero_id))
		top.add_child(previous)
		var next: Button = UiStyle.button("Next hero ▶", func() -> void: session.open_hero(session.state.heroes[posmod(at + 1, count)].hero_id))
		top.add_child(next)
	var close: Button = UiStyle.button("✕", func() -> void: session.open_hero(""))
	close.tooltip_text = "Close the sheet"
	top.add_child(close)
	right.add_child(UiStyle.label("Drag items to rearrange them, onto a copy to combine, or drop an essence on one to infuse it. Click an item for everything else.", 13, UiStyle.TEXT_DIM))
	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", 4)
	right.add_child(items)
	for i: int in hero.items.size():
		items.add_child(ItemTile.owned(session, hero.items[i], hero.hero_id, i, stats))
	items.add_child(DropZone.make("%d free slot%s" % [free, "" if free == 1 else "s"], func(data: Dictionary) -> void: session.move_item(data["uid"], hero.hero_id, 99), false, maxi(free, 1) * UiStyle.SLOT_WIDTH,
		func(data: Dictionary) -> bool: return session.would_succeed(func(state: RunState) -> RunActions.Result: return RunActions.move_item(state, content, data["uid"], hero.hero_id, 99))))


## The basic attack and Backup lines from the hero's info text.
func _basic_and_backup(def: HeroDef) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Basic attack: %s" % def.basic_attack.name)
	if def.backup != null:
		lines.append("Backup: %s (acts while this hero sits in backup)" % def.backup.name)
	return "\n".join(lines)


func _controls(hero: RunHero, at: int) -> HBoxContainer:
	var controls := HBoxContainer.new()
	var row_name: String = "Front row" if hero.row == UnitSetup.Row.FRONT else "Back row"
	var row_button: Button = UiStyle.button(row_name, func() -> void:
		session.set_row(hero.hero_id, UnitSetup.Row.BACK if hero.row == UnitSetup.Row.FRONT else UnitSetup.Row.FRONT))
	row_button.tooltip_text = "Switch rows"
	controls.add_child(row_button)
	var bench_button: Button = UiStyle.button("In backup" if hero.benched else "Fielded", func() -> void: session.set_benched(hero.hero_id, not hero.benched))
	bench_button.tooltip_text = "Field this hero, or sit them in backup"
	controls.add_child(bench_button)
	var left: Button = UiStyle.button("◀ Move", func() -> void: session.move_hero(hero.hero_id, at - 1))
	left.tooltip_text = "Move this hero earlier (further left)"
	controls.add_child(left)
	var right: Button = UiStyle.button("Move ▶", func() -> void: session.move_hero(hero.hero_id, at + 1))
	right.tooltip_text = "Move this hero later (further right)"
	controls.add_child(right)
	return controls


func _specialization_pick(hero: RunHero) -> MenuButton:
	var content: ContentDb = session.content
	var pick := MenuButton.new()
	pick.text = "Choose a specialization!"
	pick.flat = false
	pick.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pick.add_theme_color_override("font_color", UiStyle.HIGHLIGHT)
	var options: Array[String] = []
	for spec_id: String in content.specialization_ids:
		if content.specializations[spec_id].hero == hero.hero_id:
			options.append(spec_id)
			pick.get_popup().add_item(content.specializations[spec_id].name)
	pick.get_popup().id_pressed.connect(func(id: int) -> void: session.choose_specialization(hero.hero_id, options[id]))
	return pick
