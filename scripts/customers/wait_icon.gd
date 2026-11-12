# WaitIcon: a symbol over a customer who's waiting for something to be brought:
# a covered plate while they wait for their food, a cup with a straw while they
# wait for their drink. There's no timer: it just says what they're waiting
# for, so you can see at a glance who still needs something. Bobs gently.
# Hidden otherwise. Display only: CustomerDisplay sets its size and puts it
# over the text above their head (rest_offset).
class_name WaitIcon
extends Sprite3D

const PIXELS := 64
const BOB := 0.1          # Of its height, up and down...
const BOB_SPEED := 2.5    # ...and how fast.
const INK := Color(0.25, 0.18, 0.12)
const BADGE := Color(1.0, 0.99, 0.95)

static var _food_texture: Texture2D
static var _drink_texture: Texture2D

var customer: Customer
var rest_offset := 0.0    # Its offset (pixels) when not bobbing.


func _ready() -> void:
	if _food_texture == null:
		_food_texture = ImageTexture.create_from_image(_draw(true))
		_drink_texture = ImageTexture.create_from_image(_draw(false))
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fixed_size = true
	no_depth_test = true
	render_priority = 2
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func _process(_delta: float) -> void:
	var state := customer.state if customer != null else Customer.State.GONE
	visible = state == Customer.State.WAITING_FOR_FOOD or state == Customer.State.WAITING_FOR_DRINK
	if not visible:
		return
	texture = _food_texture if state == Customer.State.WAITING_FOR_FOOD else _drink_texture
	offset.y = rest_offset + sin(Time.get_ticks_msec() / 1000.0 * BOB_SPEED) * BOB * PIXELS


# A round badge with the symbol on it.
static func _draw(food: bool) -> Image:
	var image := Image.create(PIXELS, PIXELS, false, Image.FORMAT_RGBA8)
	var middle := Vector2(PIXELS, PIXELS) * 0.5
	for y in PIXELS:
		for x in PIXELS:
			var r := Vector2(x + 0.5, y + 0.5).distance_to(middle)
			if r <= 30.5:
				image.set_pixel(x, y, INK if r > 27.5 else BADGE)
	if food:
		_cloche(image)
	else:
		_cup(image)
	return image


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


# A cup of something orange, with a red straw.
static func _cup(image: Image) -> void:
	var drink := Color(0.98, 0.62, 0.22)
	var glass := Color(0.86, 0.94, 0.98)
	var straw := Color(0.9, 0.25, 0.22)
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
					image.set_pixel(x, y, INK if edge else (drink if p.y > 28.0 else glass))
