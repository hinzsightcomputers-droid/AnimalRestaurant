# LayAction: put food straight onto the hot griddle, one press each: crack an
# egg (it lands sunny side up and its white runs out to size) or lay a strip of
# bacon. What's in hand follows the cursor; press where there's room for it on
# the surface (not over the edge, not on anything else) and it goes down and
# starts cooking (HeatAction). Somewhere it won't fit just says so, so there's
# nothing to get wrong here: give it weight 0. A pancake's batter is PourAction.
class_name LayAction
extends CookAction

@export var surface := "Griddle"
@export_enum("egg", "bacon") var kind := "egg"
@export var count := 2
@export var egg_radius := 0.045          # An egg's white, once it's run out.
@export var bacon_size := Vector2(0.11, 0.026)  # A strip: length, width.
@export var thickness := 0.012
@export var side_seconds := 0.0          # Above 0: how long the side that's down takes (an egg's only side), instead of HeatAction's.
@export var hand_height := 0.09          # How high above the surface it's held.

const SPREAD_SECONDS := 0.35  # An egg's white running out.
const GAP := 0.012            # Room left round each thing.
const SCRIPTED_SPACING := 0.17

var _hand: Node3D
var _laid := 0


func view_point() -> Vector3:
	return session.surface(surface).position


func cursor_area() -> Rect2:
	return session.area_of(surface, 0.0) if view_distance > 0.0 else Rect2()


func uses_cursor() -> bool:
	return false  # What's in hand shows the spot.


func _begin() -> void:
	_hand = _make_hand()
	_hand.position = session.surface(surface).position + Vector3(0.0, hand_height, 0.0)


func end() -> void:
	_hand.queue_free()


func update(delta: float, input: CookInput) -> void:
	var top := session.surface(surface).position.y
	var spot := Vector3(input.cursor.x, top, input.cursor.z)
	_hand.position = _hand.position.lerp(spot + Vector3(0.0, hand_height, 0.0), 1.0 - exp(-20.0 * delta))
	if input.just_pressed and _laid < count:
		_try_lay(spot)
	session.set_status("%d of %d" % [_laid, count])
	if _laid >= count:
		finish(1.0)


# A good spot each, side by side across the near half of the griddle: eggs on
# the left, bacon on the right.
func scripted_hold(delta: float, input: CookInput) -> bool:
	if _laid >= count:
		return false
	var middle := session.surface(surface).position
	var across := (-0.24 if kind == "egg" else 0.2) + (_laid - (count - 1) / 2.0) * (SCRIPTED_SPACING if kind == "egg" else 0.0)
	var depth := 0.0 if kind == "egg" else (_laid - (count - 1) / 2.0) * 0.08
	return input.move_to(middle + Vector3(across, 0.0, depth), delta) and not input.held


func _half() -> Vector2:
	return Vector2(egg_radius, egg_radius) if kind == "egg" else bacon_size * 0.5


func _try_lay(spot: Vector3) -> void:
	var half := _half()
	if not session.surface(surface).contains(spot, -maxf(half.x, half.y) * 0.8):
		session.pop_text("On the %s!" % surface.to_lower(), spot, -1)
		session.wobble(_hand)
		return
	for piece in session.pieces_on(surface):
		var other := _half_of(piece)
		if absf(piece.position.x - spot.x) < half.x + other.x + GAP and absf(piece.position.z - spot.z) < half.y + other.y + GAP:
			session.pop_text("No room there", spot, -1)
			session.wobble(_hand)
			return
	var piece := session.add_piece(Color.WHITE, thickness, spot, surface)
	piece.side_seconds = side_seconds
	piece.scores["lay"] = 1.0
	_laid += 1
	if kind == "egg":
		piece.make_egg(egg_radius)
		piece.set_radius(egg_radius * 0.3)
		piece.create_tween().tween_method(piece.set_radius, egg_radius * 0.3, egg_radius, SPREAD_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		session.burst(spot + Vector3(0.0, 0.04, 0.0), Color(0.93, 0.85, 0.7), 6, 0.2)  # Bits of shell.
		session.play_sound("plop", spot, -4.0, 1.3)
		session.pop_text("Crack!", spot, 1)
	else:
		piece.make_bacon(bacon_size.x, bacon_size.y)
		session.wobble(piece, 0.12)
		session.play_sound("plop", spot, -4.0, 0.9)
		session.pop_text("Sizzle!", spot, 1)
	session.wobble(_hand, 0.1)


static func _half_of(piece: CookPiece) -> Vector2:
	if piece.kind == "bacon":
		return Vector2(piece.radius, piece.spread_to * 0.5)
	var r := maxf(piece.spread_to, piece.radius)
	return Vector2(r, r)


# An egg in its shell, or a raw strip of bacon, to hold over the griddle.
func _make_hand() -> Node3D:
	var hand := Node3D.new()
	var material := StandardMaterial3D.new()
	material.roughness = 0.5
	var mesh_instance := MeshInstance3D.new()
	if kind == "egg":
		material.albedo_color = Color(0.96, 0.9, 0.8)
		var shell := SphereMesh.new()
		shell.radius = 0.022
		shell.height = 0.056
		shell.material = material
		mesh_instance.mesh = shell
		mesh_instance.rotation.z = deg_to_rad(-25.0)
	else:
		material.albedo_color = CookPiece.BACON_RAW
		var strip := BoxMesh.new()
		strip.size = Vector3(bacon_size.x, 0.006, bacon_size.y)
		strip.material = material
		mesh_instance.mesh = strip
	hand.add_child(mesh_instance)
	session.add_child(hand)
	return hand
