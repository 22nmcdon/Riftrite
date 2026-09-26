class_name OfferView
extends RefCounted
## One offer (a RunFlow offer dictionary) as a clickable control: an item
## tile, a hero card, or a button for a relic, essence, gold, or key. Taken
## offers are dimmed and inert. `action` is called on click.


static func make(session: RunSession, offer: Dictionary, action: Callable, lit: bool = false) -> Control:
	var content: ContentDb = session.content
	var price: int = offer.get("price", 0)
	var cost: String = "%d gold" % price if price > 0 else "Take"
	if offer.get("taken", false):
		cost = "Taken"
	var node: Control
	match offer["type"]:
		"item":
			var tile: ItemTile = ItemTile.offer(session, offer["item"], offer["tier"], cost, lit)
			if not offer.get("taken", false):
				tile.clicked.connect(action)
			node = tile
		"hero":
			node = _hero_card(session, offer, cost, action)
		_:
			var button: Button = UiStyle.button("%s  (%s)" % [_describe(content, offer), cost], action)
			button.custom_minimum_size = Vector2(0, 56)
			if offer["type"] == "relic":
				Inspector.hover_text(button, ItemInfo.relic_text(content, offer["relic"]))
				button.add_theme_color_override("font_color", UiStyle.rarity_color(content.relics[offer["relic"]].rarity))
			elif offer["type"] == "essence":
				button.add_theme_color_override("font_color", UiStyle.ESSENCE.get(offer["essence"], UiStyle.TEXT))
			node = button
	if offer.get("taken", false):
		node.modulate = Color(1, 1, 1, 0.4)
		if node is Button:
			(node as Button).disabled = true
	return node


static func _describe(content: ContentDb, offer: Dictionary) -> String:
	match offer["type"]:
		"relic":
			return "%s (%s relic)" % [content.relics[offer["relic"]].name, content.relics[offer["relic"]].rarity]
		"essence":
			return "%s essence" % content.essences[offer["essence"]].name
		"gold":
			return "%d gold" % offer["amount"]
		"key":
			return "A vault key"
	return str(offer)


static func _hero_card(session: RunSession, offer: Dictionary, cost: String, action: Callable) -> Control:
	var content: ContentDb = session.content
	var def: HeroDef = content.heroes[offer["hero"]]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 0)
	var box := VBoxContainer.new()
	card.add_child(box)
	var held: RunHero = session.state.hero(def.id) if session.state != null else null
	var top := HBoxContainer.new()
	box.add_child(top)
	top.add_child(Glyph.portrait(def.name, Glyph.CLASS_COLORS.get(def.hero_class, UiStyle.EMBER), 48))
	var names := VBoxContainer.new()
	top.add_child(names)
	names.add_child(UiStyle.label("%s  %s" % [def.name, TuningDef.TIER_LABELS[offer["rank"]]], 17, UiStyle.HIGHLIGHT if held != null else UiStyle.TEXT))
	names.add_child(UiStyle.label(def.hero_class.capitalize() + ("  · ranks up yours" if held != null else ""), 14, UiStyle.EMBER if held != null else UiStyle.TEXT_DIM))
	var stats: UnitStats = def.stats.boosted(content.tuning.rank_multiplier_bp[offer["rank"]])
	box.add_child(UiStyle.label("HP %d  ATK %d  MGK %d  DEF %d" % [stats.get_stat(UnitStats.Stat.HP), stats.get_stat(UnitStats.Stat.ATK), stats.get_stat(UnitStats.Stat.MGK), stats.get_stat(UnitStats.Stat.DEF)], 14))
	box.add_child(UiStyle.label("Basic attack: " + def.basic_attack.name, 14, UiStyle.TEXT_DIM))
	if def.backup != null:
		box.add_child(UiStyle.label("Backup: " + def.backup.name, 14, UiStyle.TEXT_DIM))
	if not str(offer.get("specialization", "")).is_empty():
		box.add_child(UiStyle.label(content.specializations[offer["specialization"]].name, 14, UiStyle.EMBER))
	var button: Button = UiStyle.button(cost, action)
	button.size_flags_horizontal = Control.SIZE_FILL
	button.disabled = offer.get("taken", false)
	box.add_child(button)
	Inspector.hover_text(card, ItemInfo.hero_text(content, def.id, offer["rank"]))
	return card
