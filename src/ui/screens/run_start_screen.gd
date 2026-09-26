class_name RunStartScreen
extends UiScreen
## Pick your first hero (standing figures on pedestals), then a starting
## package (three cards), over the title backdrop.


func build() -> void:
	var state: RunState = session.state
	add_theme_constant_override("separation", 20)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	if state.phase == "start_hero":
		heading("Choose your first hero")
		hint("A run starts with one hero. You can recruit more at the Caravan (up to 6).")
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
	if def.backup != null:
		box.add_child(UiStyle.label("Backup: " + def.backup.name, 15, UiStyle.TEXT_DIM))
	var take: Button = primary_button("Take", _pick_hero.bind(index), 0)
	take.size_flags_horizontal = Control.SIZE_FILL
	box.add_child(take)
	Inspector.hover_text(panel, ItemInfo.hero_text(content, def.id, offer["rank"]))
	return panel


## A starting package: its picture, what it is, and a button to take it.
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
			picture = Glyph.item(session.content.items[offer["item"]], UiStyle.TEXT, 112)
			Inspector.hover_text(panel, ItemInfo.item_text(session.content, offer["item"], 0, [] as Array[String], 0))
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(picture)
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
	return "An item: %s" % session.content.items[offer["item"]].name


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
