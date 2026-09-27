class_name FightBanners
extends PanelContainer
## Banners in the middle of the arena for the fight's big moments, at the
## moment they happen (docs/plans/fight-questions-and-readability.md,
## section 4): a phase, an infusion reaching Resonant or awakening, a deed
## level, a synergy found for the first time. One at a time, queued; each
## stays about 1.5s of real time (less at high speed, so they keep up).

const SECONDS: float = 1.5
const MIN_SECONDS: float = 0.6

var queue: Array[String] = []
var speed: float = 1.0
var _label: Label
var _left: float = 0.0


static func make() -> FightBanners:
	var banners := FightBanners.new()
	banners.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.OAK_600, UiStyle.BRASS_300, 3))
	banners.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banners._label = UiStyle.label("", 22, UiStyle.BRASS_300)
	banners._label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banners.add_child(banners._label)
	banners.visible = false
	return banners


## The banner text for a log entry, or "" if it isn't a big moment.
## `heroes` are the guild's unit ids; `names` gives display names.
static func text_for(entry: LogEntry, heroes: Array[String], names: FightNames) -> String:
	match entry.kind:
		LogEntry.Kind.PHASE:
			return "%s: %s" % [names.name_of(entry.target), entry.note]
		LogEntry.Kind.DEED_LEVEL:
			if heroes.has(entry.target):
				return "✦ %s: %s" % [names.name_of(entry.target), entry.note.get_slice(":", 0)]
		LogEntry.Kind.INFUSION_LEVEL:
			if heroes.has(entry.source_unit):
				if entry.note.contains("awakens"):
					return "✦ %s awakens: %s" % [entry.source_item_name, entry.source_infusion_name]
				if entry.note.begins_with(Infusions.LEVEL_NAMES[Infusions.Level.RESONANT]):
					return "✦ %s is Resonant (%s)" % [entry.source_item_name, entry.source_infusion_name]
	return ""


func push(text: String) -> void:
	if text.is_empty():
		return
	queue.append(text)
	if not visible:
		_next()


## Drops whatever is waiting (the fight ended, or was skipped).
func clear() -> void:
	queue.clear()
	_left = 0.0
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	if _left <= 0.0:
		_next()


func _next() -> void:
	if queue.is_empty():
		visible = false
		return
	_label.text = queue.pop_front()
	_left = maxf(SECONDS / maxf(speed, 1.0), MIN_SECONDS)
	visible = true
