# WaitIcon: a symbol over a customer's head saying what they're waiting for:
# a chair for a table, a notepad when they're ready to order, a glass of their
# drink (in its color; empty for "the usual") while it's made, a covered plate
# while their food cooks, a speech bubble while they're talking. No words over
# anyone's head: these icons (and the receipt, see CustomerDisplay) say it all.
# There's no timer: it just shows what they need, so you can see at a glance
# who still needs something. Bobs gently. Hidden otherwise. Display only:
# CustomerDisplay sets its size and stacks it over their head (rest_offset).
# icon() draws the same badges for anything else (the courier's bag or letter).
class_name WaitIcon
extends Sprite3D

const PIXELS := 64
const BOB := 0.1          # Of its height, up and down...
const BOB_SPEED := 2.5    # ...and how fast.
const INK := Color(0.25, 0.18, 0.12)
const BADGE := Color(1.0, 0.99, 0.95)
const WOOD := Color(0.72, 0.47, 0.27)
const PAPER := Color(0.86, 0.72, 0.52)   # A brown paper bag.

static var _drawn := {}   # Kind (and a drink's color) -> Texture2D.

var customer: Customer
var rest_offset := 0.0    # Its offset (pixels) when not bobbing.


func _ready() -> void:
	setup(self)
	visible = false


# The look every badge shares, on any sprite (the courier's too).
static func setup(sprite: Sprite3D) -> void:
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.fixed_size = true
	sprite.no_depth_test = true
	sprite.render_priority = 2
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	var kind := _kind()
	visible = not kind.is_empty()
	if not visible:
		return
	var color := Color(0, 0, 0, 0)
	if kind == "drink" and not customer.drink_secret:
		color = Color(customer.drink.get("color", "#f99e38"))
	texture = icon(kind, color)
	offset.y = rest_offset + sin(Time.get_ticks_msec() / 1000.0 * BOB_SPEED) * BOB * PIXELS


# What they're waiting for now, or "" for nothing.
func _kind() -> String:
	if customer == null:
		return ""
	if customer.talking or customer.state == Customer.State.WAITING_BY_DOOR:
		return "" if customer.quiet or ReelSandbox.active() else "talk"
	match customer.state:
		Customer.State.WAITING_TO_BE_SEATED:
			return "seat" if customer.line_place == 0 and not customer.is_walking() else ""  # One asking at a time.
		Customer.State.WAITING_DRINK_ORDER, Customer.State.WAITING_FOOD_ORDER:
			return "order"
		Customer.State.WAITING_FOR_DRINK:
			return "drink"
		Customer.State.WAITING_FOR_FOOD:
			return "food"
	return ""


# A badge: "seat", "order", "drink" (`color` its drink; none: an empty glass),
# "food", "talk", "delivery" or "letter". Each is drawn once.
static func icon(kind: String, color := Color(0, 0, 0, 0)) -> Texture2D:
	var key := kind + (color.to_html() if color.a > 0.0 else "")
	if not _drawn.has(key):
		_drawn[key] = ImageTexture.create_from_image(_draw(kind, color))
	return _drawn[key]


# A round badge with the symbol on it.
static func _draw(kind: String, color: Color) -> Image:
	var image := Image.create(PIXELS, PIXELS, false, Image.FORMAT_RGBA8)
	var middle := Vector2(PIXELS, PIXELS) * 0.5
	for y in PIXELS:
		for x in PIXELS:
			var r := Vector2(x + 0.5, y + 0.5).distance_to(middle)
			if r <= 30.5:
				image.set_pixel(x, y, INK if r > 27.5 else BADGE)
	match kind:
		"food":
			_cloche(image)
		"drink":
			_cup(image, color)
		"seat":
			_chair(image)
		"order":
			_notepad(image)
		"talk":
			_speech(image)
		"delivery":
			_bag(image)
		"letter":
			_envelope(image)
	return image


# A filled box, with an ink edge `edge` wide.
static func _box(image: Image, from: Vector2, to: Vector2, fill: Color, edge := 1.5) -> void:
	for y in range(int(from.y), int(ceil(to.y))):
		for x in range(int(from.x), int(ceil(to.x))):
			var p := Vector2(x + 0.5, y + 0.5)
			if p.x < from.x or p.x > to.x or p.y < from.y or p.y > to.y:
				continue
			var inside := minf(minf(p.x - from.x, to.x - p.x), minf(p.y - from.y, to.y - p.y))
			image.set_pixel(x, y, INK if inside < edge else fill)


# A line `width` wide from a to b, in ink round `fill`.
static func _line(image: Image, a: Vector2, b: Vector2, width: float, fill: Color) -> void:
	for y in PIXELS:
		for x in PIXELS:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p)
			if d <= width * 0.5:
				image.set_pixel(x, y, INK if d > width * 0.5 - 1.2 else fill)


# A silver dome on a plate, with a knob on top.
static func _cloche(image: Image) -> void:
	var silver := Color(0.74, 0.77, 0.82)
	var shine := Color(0.93, 0.95, 0.98)
	for y in PIXELS:
		for x in PIXELS:
			var p := Vector2(x + 0.5, y + 0.5)
			# The plate: a flat ellipse under the dome.
			var plate := pow((p.x - 32.0) / 21.0, 2.0) + pow((p.y - 45.0) / 4.0, 2.0)
			if plate <= 1.0:
				image.set_pixel(x, y, INK if plate > 0.55 else Color(0.9, 0.9, 0.92))
			# The dome: the top half of a circle.
			var d := p.distance_to(Vector2(32.0, 43.0))
			if p.y <= 43.0 and d <= 16.0:
				var highlight := p.distance_to(Vector2(26.0, 35.0)) < 4.0
				image.set_pixel(x, y, INK if d > 14.0 or p.y > 41.5 else (shine if highlight else silver))
			# The knob.
			var k := p.distance_to(Vector2(32.0, 25.0))
			if k <= 3.5:
				image.set_pixel(x, y, INK if k > 2.0 else silver)


# A glass of their drink, with a red straw; without a color, empty.
static func _cup(image: Image, color: Color) -> void:
	var glass := Color(0.86, 0.94, 0.98)
	var straw := Color(0.9, 0.25, 0.22)
	var drink := Color(color, 1.0)
	for y in PIXELS:
		for x in PIXELS:
			var p := Vector2(x + 0.5, y + 0.5)
			# The straw, leaning out of the cup (drawn first, so the cup's rim covers its foot).
			var t := clampf((p.y - 12.0) / (30.0 - 12.0), 0.0, 1.0)
			var along := Vector2(41.0, 12.0).lerp(Vector2(35.0, 30.0), t)
			if p.y >= 11.0 and p.y <= 30.0 and absf(p.x - along.x) <= 2.0:
				image.set_pixel(x, y, INK if absf(p.x - along.x) > 1.0 else straw)
			# The cup: wider at the top (y 22) than the bottom (y 50).
			if p.y >= 21.0 and p.y <= 51.0:
				var half := lerpf(12.0, 8.5, (p.y - 21.0) / 30.0)
				var gap := absf(p.x - 32.0)
				if gap <= half:
					var edge := gap > half - 2.0 or p.y < 23.0 or p.y > 49.0
					var full := color.a > 0.0 and p.y > 28.0
					image.set_pixel(x, y, INK if edge else (drink if full else glass))


# A wooden chair, seen from the side a little: a tall back, the seat, legs.
static func _chair(image: Image) -> void:
	_box(image, Vector2(19.0, 12.0), Vector2(25.0, 50.0), WOOD)       # The back post, down to the back leg.
	_box(image, Vector2(19.0, 14.0), Vector2(31.0, 19.0), WOOD)       # A rail across the back.
	_box(image, Vector2(19.0, 22.0), Vector2(31.0, 27.0), WOOD)
	_box(image, Vector2(18.0, 31.0), Vector2(46.0, 37.0), WOOD)       # The seat.
	_box(image, Vector2(40.0, 36.0), Vector2(46.0, 50.0), WOOD)       # The front leg.


# A notepad with lines on it and a pencil across it: ready to order.
static func _notepad(image: Image) -> void:
	_box(image, Vector2(17.0, 13.0), Vector2(41.0, 50.0), BADGE.darkened(0.03))
	_box(image, Vector2(17.0, 13.0), Vector2(41.0, 19.0), Color(0.85, 0.35, 0.3))  # Its binding.
	for row in [25.0, 31.0, 37.0, 43.0]:
		for x in range(21, 37):
			image.set_pixel(x, int(row), Color(0.6, 0.55, 0.5))
	_line(image, Vector2(48.0, 20.0), Vector2(33.0, 45.0), 6.0, Color(0.98, 0.8, 0.3))  # The pencil...
	for y in PIXELS:  # ...and its point.
		for x in PIXELS:
			var p := Vector2(x + 0.5, y + 0.5)
			if p.distance_to(Vector2(32.0, 47.0)) < 2.2:
				image.set_pixel(x, y, INK)


# A speech bubble with three dots: they're talking.
static func _speech(image: Image) -> void:
	for pass_ in 2:  # Ink, then the white inside it 1.8 pixels in.
		var inset := 1.8 * pass_
		for y in PIXELS:
			for x in PIXELS:
				var p := Vector2(x + 0.5, y + 0.5)
				var e := pow((p.x - 32.0) / (18.0 - inset), 2.0) + pow((p.y - 29.0) / (13.0 - inset), 2.0)
				var tail := Geometry2D.is_point_in_polygon(p, PackedVector2Array([Vector2(22.0 + inset, 34.0), Vector2(32.0 - inset, 38.0), Vector2(19.0 + inset * 0.6, 50.0 - inset * 1.6)]))
				if e <= 1.0 or tail:
					image.set_pixel(x, y, Color.WHITE if pass_ == 1 else INK)
	for y in PIXELS:
		for x in PIXELS:
			for dot in [23.0, 32.0, 41.0]:
				if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(dot, 29.0)) < 2.8:
					image.set_pixel(x, y, INK)


# A paper takeout bag with a handle, rushing along (lines behind it): a Moober order.
static func _bag(image: Image) -> void:
	for y in PIXELS:  # The handle: a loop over the bag.
		for x in PIXELS:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(36.0, 22.0))
			if y + 0.5 < 23.0 and d <= 8.0 and d >= 4.5:
				image.set_pixel(x, y, INK if d > 7.0 or d < 5.5 else PAPER.darkened(0.15))
	_box(image, Vector2(24.0, 21.0), Vector2(48.0, 50.0), PAPER)
	_box(image, Vector2(24.0, 21.0), Vector2(48.0, 26.0), PAPER.darkened(0.12))  # The folded top.
	_box(image, Vector2(31.0, 32.0), Vector2(41.0, 42.0), Color(0.4, 0.68, 0.45))  # A green sticker.
	for row in [28.0, 36.0, 44.0]:  # Speed lines.
		for x in range(9, 20 - int(row) % 3 * 2):
			for t in 2:
				image.set_pixel(x, int(row) + t, INK)


# An envelope: a letter for you.
static func _envelope(image: Image) -> void:
	_box(image, Vector2(13.0, 19.0), Vector2(51.0, 45.0), Color.WHITE)
	_line(image, Vector2(14.0, 20.0), Vector2(32.0, 34.0), 2.0, INK)  # The flap.
	_line(image, Vector2(50.0, 20.0), Vector2(32.0, 34.0), 2.0, INK)
	for y in PIXELS:  # A red seal where they meet.
		for x in PIXELS:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(32.0, 34.0))
			if d < 4.5:
				image.set_pixel(x, y, INK if d > 3.3 else Color(0.85, 0.3, 0.28))
