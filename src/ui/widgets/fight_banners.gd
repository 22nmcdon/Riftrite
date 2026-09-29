class_name FightBanners
extends PanelContainer
## A banner over the board for the fight's big moments
## (docs/plans/rebuild-phase3-fight-sandbox.md, sections 5 and 6): a unit
## entering a phase, the rift starting to collapse (the first ring
## crumbling, at 45s unless something starts it sooner), and the end. One at
## a time, queued; each stays about 1.5s of real time (less at 2x, so they
## keep up), and waits while the fight is paused. Time comes in only through
## advance(seconds), so tests drive it by hand.
## (The old game's FightBanners, from git history, adapted.)

const SECONDS: float = 1.5
const COLLAPSE_TEXT: String = "The rift collapses"

var queue: Array[String] = []
var speed: float = 1.0
var label: Label
## Seconds the shown banner has left.
var left: float = 0.0


static func make() -> FightBanners:
	var banners := FightBanners.new()
	banners.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.NAVY_700, UiStyle.GOLD_300, 3))
	banners.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banners.label = UiStyle.label("", 26, UiStyle.GOLD_300)
	banners.label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banners.add_child(banners.label)
	banners.visible = false
	return banners


## The banner for a log entry, or "" if it isn't a big moment.
static func text_for(entry: LogEntry, names: FightNames) -> String:
	match entry.kind:
		LogEntry.Kind.PHASE:
			return "%s: %s" % [names.name_of(entry.target), entry.note]
		LogEntry.Kind.COLLAPSE_RING:
			if entry.amount == 0 and entry.note == "crumbled":
				return COLLAPSE_TEXT
		LogEntry.Kind.FIGHT_END:
			return entry.note
	return ""


func push(text: String) -> void:
	if text.is_empty():
		return
	queue.append(text)
	if not visible:
		_next()


## Drops the banner and whatever is waiting (a restart).
func clear() -> void:
	queue.clear()
	left = 0.0
	visible = false


## Moves the banners on by `seconds` of real time.
func advance(seconds: float) -> void:
	left -= seconds
	if left <= 0.0:
		_next()


func _next() -> void:
	if queue.is_empty():
		visible = false
		return
	label.text = queue.pop_front()
	left = SECONDS / maxf(speed, 1.0)
	visible = true
