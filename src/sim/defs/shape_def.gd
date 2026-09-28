class_name ShapeDef
extends RefCounted
## An area's shape (docs/plans/rebuild-phase1-arena-sim.md, section 7),
## measured in hexes:
##   {"kind": "circle", "radius": 2}   within 2 hexes of its center
##   {"kind": "ring", "radius": 2}     between 1.5 and 2.5 hexes from it
##   {"kind": "line", "length": 4}     4 hexes long and 1 wide, from the
##                                     caster's edge along its aim
##   {"kind": "cone", "depth": 3}      from the caster's edge along its aim,
##                                     widening from 1 hex to 3 (depth 3 by
##                                     default)
## A unit is inside if its center is (decided).

enum Kind { CIRCLE, RING, LINE, CONE }

const KIND_NAMES: Array[String] = ["circle", "ring", "line", "cone"]

var kind: Kind
## circle and ring: the radius; line: the length; cone: the depth (hexes).
var size: int = 0


static func read(reader: DataReader) -> ShapeDef:
	var def := ShapeDef.new()
	var kind_name: String = reader.req_choice("kind", KIND_NAMES)
	def.kind = maxi(KIND_NAMES.find(kind_name), 0) as Kind
	if not kind_name.is_empty():
		match def.kind:
			Kind.CIRCLE, Kind.RING:
				def.size = reader.req_int("radius", 1)
			Kind.LINE:
				def.size = reader.req_int("length", 1)
			Kind.CONE:
				def.size = reader.opt_int("depth", 3, 1)
	reader.finish()
	return def


## Lines and cones are aimed; circles and rings are placed.
func is_aimed() -> bool:
	return kind == Kind.LINE or kind == Kind.CONE


## True if `point` is inside the shape placed at `origin` (a circle's or
## ring's center; a line's or cone's start), aimed along `dir` (length
## ArenaPlane.DIR; lines and cones only).
func contains(origin: Vector2i, dir: Vector2i, point: Vector2i) -> bool:
	match kind:
		Kind.CIRCLE:
			return ArenaPlane.in_circle(origin, size * HexGrid.HEX, point)
		Kind.RING:
			return ArenaPlane.in_ring(origin, size * HexGrid.HEX, point)
		Kind.LINE:
			return ArenaPlane.in_line(origin, dir, size * HexGrid.HEX, point)
	return ArenaPlane.in_cone(origin, dir, size * HexGrid.HEX, point)


## For the log: "circle 2", "line 4".
func describe() -> String:
	return "%s %d" % [KIND_NAMES[kind], size]
