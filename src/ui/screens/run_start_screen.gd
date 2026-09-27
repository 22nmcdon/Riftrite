class_name RunStartScreen
extends UiScreen
## The team draft (docs/plans/heroes-and-deeds.md, section 1): pick 1 of 3
## heroes, three times (standing figures on pedestals), then a starting
## package (gold, a relic, or one of two kits), over the title backdrop.


func build() -> void:
	var state: RunState = session.state
	add_theme_constant_override("separation", 20)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	if state.phase == "start_hero":
		heading("Draft your team: hero %d of %d" % [state.heroes.size() + 1, RunState.TEAM_SIZE])
		var picked: PackedStringArray = PackedStringArray()
		for hero: RunHero in state.heroes:
			picked.append(session.content.heroes[hero.hero_id].name)
		hint("Pick one. These three heroes fight together for the whole run; nobody joins later." + ("" if picked.is_empty() else "  Your team so far: " + ", ".join(picked) + "."))
		for i: int in state.offers.size():
			row.add_child(_hero_card(state.offers[i], i))
	else:
		heading("Choose a starting package")
		hint("You also start with %d gold." % session.run.economy.base_gold)
		for i: int in state.offers.size():
			row.add_child(_package_card(state.offers[i], i))
	add_child(row)


## A hero on a pedestal: figure, name, class, stats, attacks, and Take.
func _hero_card(offer: Dictionary, index: int) -> Control:
	var content: ContentDb = session.content
	var def: HeroDef = content.heroes[offer["hero"]]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	panel.add_theme_stylebox_override("panel", UiStyle.chrome("panel_oak", 24, 20))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 230)
	box.add_child(stage)
	var pedestal := Pedestal.new()
	pedestal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(pedestal)
	var figure: Figure = Figure.make(def.id, 210)
	figure.bob = true
	figure.bob_phase = float(index)
	figure.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	figure.position = Vector2(-figure.custom_minimum_size.x / 2.0, -figure.custom_minimum_size.y - 6)
	stage.add_child(figure)
	var name_label: Label = UiStyle.heading(def.name, 24, UiStyle.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var kind: Label = UiStyle.label("%s · rank %s" % [def.hero_class.capitalize(), TuningDef.TIER_LABELS[offer["rank"]]], 16, UiStyle.EMBER)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(kind)
	var stats: HBoxContainer = UiStyle.stat_row(def.stats.boosted(content.tuning.rank_multiplier_bp[offer["rank"]]), 16)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(stats)
	box.add_child(UiStyle.label("Basic attack: " + def.basic_attack.name, 15, UiStyle.TEXT_DIM))
	box.add_child(UiStyle.label("Affinities: " + ItemInfo.keyword_names(content, def.affinities), 15, UiStyle.HIGHLIGHT))
	for note: String in team_notes(content, session.state, def.id):
		box.add_child(UiStyle.label(note, 15, UiStyle.GOOD))
	var innate: Label = UiStyle.label("Innate: %s. %s" % [def.innate_name, def.innate_text], 15, UiStyle.TEXT_DIM)
	innate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(innate)
	if def.calling != null:
		var calling: Label = UiStyle.label("Calling: %s. Grows by: %s." % [def.calling_name, def.calling.deed.text.to_lower()], 15, UiStyle.BRASS_300)
		calling.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(calling)
	var take: Button = primary_button("Take", _pick_hero.bind(index), 0)
	take.size_flags_horizontal = Control.SIZE_FILL
	box.add_child(take)
	Inspector.hover_text(panel, ItemInfo.hero_text(content, def.id, offer["rank"]))
	return panel


## How a hero on offer fits the heroes already drafted
## (docs/plans/heroes-and-deeds.md, section 1): the affinities they share,
## and "a bond: ?" for each duo bond they'd form (its name stays hidden
## until it's found).
static func team_notes(content: ContentDb, state: RunState, hero_id: String) -> PackedStringArray:
	var notes := PackedStringArray()
	var def: HeroDef = content.heroes[hero_id]
	for hero: RunHero in state.heroes:
		var other: HeroDef = content.heroes[hero.hero_id]
		var shared: Array[String] = []
		for keyword_id: String in def.affinities:
			if other.affinities.has(keyword_id):
				shared.append(keyword_id)
		var first: String = HeroToken.first_name(other.name)
		if not shared.is_empty():
			notes.append("Shares %s with %s" % [ItemInfo.keyword_names(content, shared), first])
		for synergy_id: String in content.synergy_ids:
			var synergy: SynergyDef = content.synergies[synergy_id]
			if synergy.layer == SynergyDef.Layer.DUO and synergy.heroes.has(hero_id) and synergy.heroes.has(hero.hero_id):
				notes.append("A bond with %s: %s" % [first, synergy.name if state.discovered.has(synergy_id) else "?"])
	return notes


## A starting package (gold, a relic, or a kit): its picture, what it is,
## and a button to take it.
func _package_card(offer: Dictionary, index: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 300)
	panel.add_theme_stylebox_override("panel", UiStyle.chrome("panel_oak", 24, 24))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var picture: Control
	match offer["package"]:
		"gold":
			picture = UiStyle.icon("gold", 112)
		"relic":
			var def: RelicDef = session.content.relics[offer["relic"]]
			picture = Glyph.hex(def.name, UiStyle.rarity_color(def.rarity), 112, def.rarity == "legendary", offer["relic"])
			Inspector.hover_text(panel, ItemInfo.relic_text(session.content, offer["relic"]))
		_:
			# A kit (docs/plans/fight-questions-and-readability.md, section 3):
			# its item, already infused.
			var essences: Array[String] = [offer["essence"]]
			picture = Glyph.item(session.content.items[offer["item"]], UiStyle.ESSENCE.get(offer["essence"], UiStyle.TEXT), 112)
			Inspector.hover_text(panel, ItemInfo.item_text(session.content, offer["item"], 0, essences, 0))
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(picture)
	if offer["package"] == "kit":
		var about: Label = UiStyle.label("%s, infused with %s. For %s heroes." % [session.content.items[offer["item"]].name,
			session.content.essences[offer["essence"]].name, session.content.keywords[offer["kit"]].name], 16, UiStyle.TEXT_DIM)
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		about.custom_minimum_size = Vector2(280, 0)
		box.add_child(about)
	var button: Button = UiStyle.button(_package_text(offer), _pick_package.bind(index))
	button.size_flags_horizontal = Control.SIZE_FILL
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_font_size_override("font_size", 19)
	box.add_child(button)
	return panel


func _package_text(offer: Dictionary) -> String:
	match offer["package"]:
		"gold":
			return "+%d gold" % session.run.economy.package_gold
		"relic":
			return "A relic: %s" % session.content.relics[offer["relic"]].name
	return offer["name"]


func _pick_hero(index: int) -> void:
	session.pick_start_hero(index)


func _pick_package(index: int) -> void:
	session.pick_package(index)


## A round stone pedestal under a hero, lit from above.
class Pedestal:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var base := Vector2(size.x / 2.0, size.y - 12.0)
		draw_circle(base + Vector2(0, -90), 120.0, Color(UiStyle.BRASS_300, 0.06))
		draw_set_transform(base, 0.0, Vector2(1.0, 0.28))
		draw_circle(Vector2(0, 14), 96.0, UiStyle.INK_900)
		draw_circle(Vector2.ZERO, 96.0, Color("5e5a68"))
		draw_circle(Vector2(0, -6), 90.0, Color("7a7686"))
		draw_set_transform_matrix(Transform2D.IDENTITY)
