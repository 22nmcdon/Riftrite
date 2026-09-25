class_name DamageMeterView
extends GridContainer
## The per-item damage meter after a fight (DamageMeter, built from the log),
## best item first, with a bar for each item's share of the top output.


static func make(result: FightResult, names: FightNames) -> DamageMeterView:
	var view := DamageMeterView.new()
	view.columns = 5
	view.add_theme_constant_override("h_separation", 16)
	for header: String in ["Your items", "", "Damage", "Healing", "Shielding"]:
		view.add_child(UiStyle.label(header, 15, UiStyle.EMBER))
	var meter: DamageMeter = DamageMeter.from_log(result.combat_log, names.hero_ids)
	var rows: Array[DamageMeter.Row] = []
	for row: DamageMeter.Row in meter.rows:
		if row.side == UnitSetup.Side.HEROES and row.output() > 0:
			rows.append(row)
	rows.sort_custom(func(a: DamageMeter.Row, b: DamageMeter.Row) -> bool: return a.output() > b.output())
	var top: int = rows[0].output() if not rows.is_empty() else 1
	for row: DamageMeter.Row in rows:
		var who: String = names.name_of(row.unit_id) if not row.unit_id.is_empty() else "Relic"
		view.add_child(UiStyle.label("%s · %s" % [who, row.item_name], 14))
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = top
		bar.value = row.output()
		bar.custom_minimum_size = Vector2(90, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("fill", UiStyle.box(UiStyle.EMBER, UiStyle.EMBER, 0))
		view.add_child(bar)
		view.add_child(UiStyle.label(str(row.damage), 14))
		view.add_child(UiStyle.label(str(row.healing), 14, UiStyle.GOOD))
		view.add_child(UiStyle.label(str(row.shielding), 14, UiStyle.SHIELD))
	return view
