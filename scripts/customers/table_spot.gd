# TableSpot: how each table's spot (DiningTable.spot: middle, kitchen, corner,
# window...) is marked, so a ticket and the customer it's for can be matched at
# a glance: a name, a color and a shape each (data/service.json "table_spots"),
# drawn as a little badge. The shape is there so it doesn't depend on color.
class_name TableSpot
extends RefCounted

const PIXELS := 64
const INK := Color(0.25, 0.18, 0.12)
const RIM := Color(1.0, 0.99, 0.95)
const EDGE := 5.0      # Pixels of cream rim...
const LINE := 3.0      # ...and of dark line round that.
const NO_SPOT := { "name": "", "color": "#A97251", "shape": "circle" }

static var _badges := {}  # Spot -> its Texture2D.


static func of(customer: Customer) -> String:
	if not is_instance_valid(customer) or customer.seat == null or customer.seat.table == null:
		return ""
	return customer.seat.table.spot


static func title(spot: String) -> String:
	return String(_data(spot).get("name", spot.capitalize()))


static func color(spot: String) -> Color:
	return Color(String(_data(spot).get("color", NO_SPOT["color"])))


static func badge(spot: String) -> Texture2D:
	if not _badges.has(spot):
		_badges[spot] = ImageTexture.create_from_image(_draw(color(spot), String(_data(spot).get("shape", "circle"))))
	return _badges[spot]


static func _data(spot: String) -> Dictionary:
	return GameData.service.get("table_spots", {}).get(spot, NO_SPOT)


# The shape filled in its color, with a cream rim and a dark line round it.
static func _draw(fill: Color, shape: String) -> Image:
	var image := Image.create(PIXELS, PIXELS, false, Image.FORMAT_RGBA8)
	for y in PIXELS:
		for x in PIXELS:
			var inside := _depth(Vector2(x + 0.5, y + 0.5) - Vector2.ONE * PIXELS * 0.5, shape)
			if inside < 0.0:
				continue
			image.set_pixel(x, y, INK if inside < LINE else (RIM if inside < LINE + EDGE else fill))
	return image


# How far inside the shape a point is (pixels from its nearest edge, below zero outside).
static func _depth(p: Vector2, shape: String) -> float:
	const R := 30.0
	match shape:
		"square":
			return minf(27.0 - absf(p.x), 27.0 - absf(p.y))
		"diamond":
			return (R + 1.0 - absf(p.x) - absf(p.y)) * 0.7071 + 2.0 * float(absf(p.x) + absf(p.y) < R)
		"triangle":
			return _polygon_depth(p + Vector2(0.0, 4.0), 3, 17.5)
		"hexagon":
			return _polygon_depth(p, 6, 27.0)
		"pentagon":
			return _polygon_depth(p + Vector2(0.0, -1.0), 5, 24.5)
	return R - p.length()


# A regular polygon, point up, `inner` from its middle to each side.
static func _polygon_depth(p: Vector2, sides: int, inner: float) -> float:
	var depth := INF
	for i in sides:
		var normal := Vector2.UP.rotated(PI / sides + TAU * i / sides)
		depth = minf(depth, inner - p.dot(normal))
	return depth
