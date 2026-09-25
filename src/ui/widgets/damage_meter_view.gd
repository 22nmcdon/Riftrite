class_name DamageMeterView
extends GridContainer
## The per-item damage meter after a fight (DamageMeter, built from the log).


static func make(result: FightResult, hero_ids: Array[String]) -> DamageMeterView:
	var view := DamageMeterView.new()
	view.columns = 4
	view.add_theme_constant_override("h_separation", 24)
	for header: String in ["Guild: item", "Damage", "Healing", "Shielding"]:
		view.add_child(UiStyle.label(header, 14, UiStyle.EMBER))
	var meter: DamageMeter = DamageMeter.from_log(result.combat_log, hero_ids)
	var rows: Array[DamageMeter.Row] = []
	for row: DamageMeter.Row in meter.rows:
		if row.side == UnitSetup.Side.HEROES and row.output() > 0:
			rows.append(row)
	rows.sort_custom(func(a: DamageMeter.Row, b: DamageMeter.Row) -> bool: return a.output() > b.output())
	for row: DamageMeter.Row in rows:
		var who: String = row.unit_id if not row.unit_id.is_empty() else "relic"
		view.add_child(UiStyle.label("%s · %s" % [who, row.item_name], 13))
		view.add_child(UiStyle.label(str(row.damage), 13))
		view.add_child(UiStyle.label(str(row.healing), 13, UiStyle.GOOD))
		view.add_child(UiStyle.label(str(row.shielding), 13, UiStyle.SHIELD))
	return view
