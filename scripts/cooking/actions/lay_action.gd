# LayAction: put food straight onto the hot griddle, inside a marked zone
# (zone_size: just big enough for everything, outlined), each one anywhere in
# it as long as it fits and doesn't overlap anything (a ring shows where it'd
# go: red where it won't fit). It starts cooking as it lands (HeatAction).
#   - egg: press to crack it: the camera comes in close as it taps on the edge
#     of the griddle and cracks; then pick its spot and press again to open it
#     there, and it pours out like batter, the white running out to size and
#     the yolk dropping in last (sunny side up).
#   - bacon: press to lay a strip down, lengthways (pointing away from the cook).
# Nothing to get wrong here: give it weight 0. A pancake's batter is PourAction.
class_name LayAction
extends CookAction

@export var surface := "Griddle"
@export_enum("egg", "bacon") var kind := "egg"
@export var count := 2
@export var zone_size := Vector2.ZERO      # The marked zone everything goes in, round the surface's middle (zero: the whole surface).
@export var zone_offset := Vector2.ZERO
@export var egg_radius := 0.045            # An egg's white, once it's run out.
@export var bacon_size := Vector2(0.11, 0.026)  # A strip: length, width.
@export var thickness := 0.012
@export var side_seconds := 0.0            # Above 0: how long the side that's down takes (an egg's only side), instead of HeatAction's.
@export var hand_height := 0.09            # How high above the surface it's held.
@export_group("Cracking")
@export var crack_view_distance := 0.32    # The close-up on the egg cracking.
@export var crack_view_pitch := 30.0
@export var pour_seconds := 0.8            # The egg running out of its shell.
@export var pour_height := 0.07            # How high over the spot it's held open.

enum Phase { READY, CRACKING, AIM, POURING }  # An egg: whole, being cracked, cracked (pick a spot), pouring. Bacon is always AIM.

const GAP := 0.012           # Room left round each thing.
const SCRIPTED_WAIT := 0.4   # A reel's chef looks at the cracked egg this long before opening it.

var _hand: Node3D
var _top_shell: Node3D
var _bottom_shell: Node3D
var _crack_line: MeshInstance3D
var _ring: MeshInstance3D
var _outline: Node3D
var _stream: MeshInstance3D
var _laid := 0
var _phase := Phase.AIM
var _spot := Vector3.ZERO     # Where the egg being opened goes.
var _scripted_wait := 0.0


func view_point() -> Vector3:
	var middle := session.surface(surface).position
	return Vector3(middle.x + zone_offset.x, middle.y, middle.z + zone_offset.y)


func cursor_area() -> Rect2:
	if zone_size != Vector2.ZERO:
		var at := view_point()
		return Rect2(at.x - zone_size.x * 0.5, at.z - zone_size.y * 0.5, zone_size.x, zone_size.y)
	return session.area_of(surface, 0.0) if view_distance > 0.0 else Rect2()


func uses_cursor() -> bool:
	return false  # What's in hand, and the ring under it, show the spot.


func _begin() -> void:
	_phase = Phase.READY if kind == "egg" else Phase.AIM
	_hand = _make_hand()
	_hand.position = view_point() + Vector3(0.0, hand_height, 0.0)
	_ring = session.make_ring(egg_radius if kind == "egg" else bacon_size.x * 0.5)
	if kind == "bacon":
		_ring.scale = Vector3(bacon_size.y / bacon_size.x * 1.6, 0.3, 1.0)  # Flattened to the strip, lengthways.
	if zone_size != Vector2.ZERO:
		_outline = _make_outline()
	_stream = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.007
	mesh.bottom_radius = 0.01
	mesh.height = 1.0
	var material := StandardMaterial3D.new()
	material.albedo_color = CookPiece.EGG_RAW.lerp(Color.WHITE, 0.3)
	mesh.material = material
	_stream.mesh = mesh
	_stream.visible = false
	session.add_child(_stream)


func end() -> void:
	for node in [_hand, _ring, _outline, _stream]:
		if node != null:
			node.queue_free()


func update(delta: float, input: CookInput) -> void:
	var top := session.surface(surface).position.y
	var spot := Vector3(input.cursor.x, top, input.cursor.z)
	match _phase:
		Phase.READY:  # A whole egg in hand: crack it first.
			_ring.visible = false
			_hand.position = _hand.position.lerp(spot + Vector3(0.0, hand_height, 0.0), 1.0 - exp(-20.0 * delta))
			session.set_status("Egg %d of %d: press to crack it" % [_laid + 1, count])
			if input.just_pressed and _laid < count:
				_crack(spot)
		Phase.CRACKING:
			session.set_status("Crack...")
		Phase.AIM:
			var fits := _fits(spot)
			_hand.position = _hand.position.lerp(spot + Vector3(0.0, hand_height, 0.0), 1.0 - exp(-20.0 * delta))
			_ring.visible = true
			_ring.position = spot + Vector3(0.0, 0.003, 0.0)
			((_ring.mesh as TorusMesh).material as StandardMaterial3D).albedo_color = Color(1.0, 1.0, 1.0, 0.6) if fits else Color(1.0, 0.3, 0.25, 0.7)
			if kind == "egg":
				session.set_status("Cracked! Pick a spot in the box and press to open it")
			else:
				session.set_status("Strip %d of %d: pick a spot in the box" % [_laid + 1, count])
			if input.just_pressed and _laid < count:
				if not fits:
					session.pop_text("No room there" if _inside_zone(spot) else "Inside the box!", spot, -1)
					session.wobble(_hand)
				elif kind == "egg":
					_open(spot)
				else:
					_lay_bacon(spot)
		Phase.POURING:
			session.set_status("Pouring it out...")
	if _laid >= count and _phase in [Phase.AIM, Phase.READY]:
		finish(1.0)


# An egg is cracked where the hand is, looked at, then opened at a good spot:
# eggs side by side on the left, the bacon strips side by side on the right.
func scripted_hold(delta: float, input: CookInput) -> bool:
	if _laid >= count or _phase in [Phase.CRACKING, Phase.POURING]:
		return false
	if _phase == Phase.READY:
		_scripted_wait = SCRIPTED_WAIT
		return not input.held
	if kind == "egg":
		_scripted_wait -= delta
		if _scripted_wait > 0.0:
			return false
	var middle := view_point()
	var half := zone_size * 0.5 if zone_size != Vector2.ZERO else Vector2(0.2, 0.1)
	var goal := middle
	if kind == "egg":
		goal += Vector3(-half.x + egg_radius + 0.008 + _laid * (egg_radius * 2.0 + GAP + 0.004), 0.0, 0.0)
	else:
		goal += Vector3(half.x - bacon_size.y * 0.5 - 0.008 - _laid * (bacon_size.y + GAP + 0.012), 0.0, 0.0)
	goal = _scripted_free_spot(goal)
	return input.move_to(goal, delta) and not input.held and _fits(Vector3(input.cursor.x, goal.y, input.cursor.z))


# For a reel: the planned spot, or if what's already down crowds it (the last
# one landed a few millimetres off its mark), the nearest one that's clear,
# looking along the row first.
func _scripted_free_spot(goal: Vector3) -> Vector3:
	goal.y = session.surface(surface).position.y
	if _fits(goal):
		return goal
	var along := Vector3(1.0, 0.0, 0.0)  # Both lie in a row across the box.
	var across := Vector3(0.0, 0.0, 1.0)
	for step in range(1, 60):
		for sideways in [0.0, 0.02, -0.02, 0.04, -0.04]:
			for sign in [1.0, -1.0]:
				var spot: Vector3 = goal + along * sign * step * 0.004 + across * sideways
				if _fits(spot):
					return spot
	return goal


func _half() -> Vector2:
	return Vector2(egg_radius, egg_radius) if kind == "egg" else Vector2(bacon_size.y, bacon_size.x) * 0.5  # Bacon lies lengthways.


func _inside_zone(spot: Vector3) -> bool:
	var half := _half()
	if zone_size == Vector2.ZERO:
		return session.surface(surface).contains(spot, -maxf(half.x, half.y) * 0.8)
	var at := view_point()
	return absf(spot.x - at.x) <= zone_size.x * 0.5 - half.x and absf(spot.z - at.z) <= zone_size.y * 0.5 - half.y


# Inside the zone and clear of everything already down.
func _fits(spot: Vector3) -> bool:
	if not _inside_zone(spot):
		return false
	var half := _half()
	for piece in session.pieces_on(surface):
		var other := _half_of(piece)
		if absf(piece.position.x - spot.x) < half.x + other.x + GAP and absf(piece.position.z - spot.z) < half.y + other.y + GAP:
			return false
	return true


static func _half_of(piece: CookPiece) -> Vector2:
	if piece.kind == "bacon":
		var half := Vector2(piece.radius, piece.spread_to * 0.5)
		return Vector2(half.y, half.x) if absf(sin(piece.rotation.y)) > 0.7 else half  # Laid lengthways.
	var r := maxf(piece.spread_to, piece.radius)
	return Vector2(r, r)


# Tap on the front edge of the griddle, close up: a crack round its middle.
# Then back to the box, the cracked egg in hand, to pick where it goes.
func _crack(spot: Vector3) -> void:
	_phase = Phase.CRACKING
	_ring.visible = false
	var griddle := session.surface(surface)
	var edge := Vector3(spot.x, griddle.position.y + 0.03, griddle.position.z + griddle.size.y * 0.5 - 0.015)
	session.frame(edge, crack_view_distance, crack_view_pitch, 0.35)
	# Like a real egg: turned on its side, lifted, then its middle tapped on the edge.
	var tween := _hand.create_tween()
	tween.tween_property(_hand, "position", edge + Vector3(0.0, 0.06, 0.0), 0.3).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_hand, "rotation:z", PI * 0.5, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_hand, "position", edge + Vector3(0.0, 0.08, 0.0), 0.12).set_ease(Tween.EASE_OUT)  # A little wind-up.
	tween.tween_property(_hand, "position", edge + Vector3(0.0, 0.022, 0.0), 0.07).set_ease(Tween.EASE_IN)  # Tap! (its side, half its width, meets the edge)
	tween.tween_callback(func():
		_crack_line.visible = true
		session.play_sound("tick", edge, 0.0, 0.7)
		session.burst(edge + Vector3(0.0, 0.01, 0.0), Color(0.95, 0.9, 0.8), 5, 0.12)
		session.pop_text("Crack!", edge + Vector3(0.0, 0.05, 0.0), 1)
		session.wobble(_hand, 0.12))
	tween.tween_property(_hand, "position", edge + Vector3(0.0, 0.04, 0.0), 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		session.frame(view_point(), view_distance, view_pitch, 0.35)
		_phase = Phase.AIM)


# Over the spot, the shell comes apart and the egg pours out like batter.
func _open(spot: Vector3) -> void:
	_phase = Phase.POURING
	_spot = spot
	_ring.visible = false
	var over := _spot + Vector3(0.0, pour_height, 0.0)
	session.frame(_spot, crack_view_distance * 1.3, 50.0, 0.35)
	var piece := session.add_piece(Color.WHITE, thickness, _spot, surface)
	piece.side_seconds = side_seconds
	piece.scores["lay"] = 1.0
	piece.make_egg(egg_radius)
	piece.show_yolk(false)
	piece.busy = true  # Not cooking till it's all out.
	piece.set_radius(0.004)
	var seconds := pour_seconds
	var tween := _hand.create_tween()
	tween.tween_property(_hand, "position", over, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		# Pulled apart at the crack (the egg's on its side: its halves are left and right), tipping out.
		_crack_line.visible = false  # The crack is now the gap between the halves.
		for half in [[_top_shell, 1.0], [_bottom_shell, -1.0]]:
			var open := (half[0] as Node3D).create_tween().set_parallel(true)
			open.tween_property(half[0], "position:y", 0.03 * half[1], 0.2).set_ease(Tween.EASE_OUT)
			open.tween_property(half[0], "rotation:z", -0.5 * half[1], 0.2).set_ease(Tween.EASE_OUT)
		_stream.visible = true
		_stream.position = _spot + Vector3(0.0, pour_height * 0.5, 0.0)
		_stream.scale = Vector3(1.0, pour_height, 1.0)
		session.play_sound("plop", _spot, -6.0, 1.4))
	tween.tween_method(func(t: float):
		piece.set_radius(lerpf(0.004, egg_radius, ease(t, 0.6))), 0.0, 1.0, seconds)
	tween.parallel().tween_callback(func():  # The yolk drops in near the end.
		piece.show_yolk(true)
		session.wobble(piece, 0.15)
		session.play_sound("plop", _spot, -4.0, 1.1)).set_delay(seconds * 0.7)
	tween.tween_callback(func():
		_stream.visible = false
		piece.busy = false
		_laid += 1
		session.pop_text("Sunny side up!", _spot, 1)
		_hand.queue_free()  # The empty shell goes; a fresh egg for the next one.
		_hand = _make_hand()
		_hand.position = _spot + Vector3(0.0, hand_height, 0.0)
		session.frame(view_point(), view_distance, view_pitch, 0.35)
		_phase = Phase.READY)


func _lay_bacon(spot: Vector3) -> void:
	var piece := session.add_piece(Color.WHITE, thickness, spot, surface)
	piece.side_seconds = side_seconds
	piece.scores["lay"] = 1.0
	piece.make_bacon(bacon_size.x, bacon_size.y)
	piece.rotation.y = PI * 0.5  # Lengthways, pointing away from the cook.
	_laid += 1
	piece.position = spot + Vector3(0.0, 0.05, 0.0)  # Laid down from just above.
	piece.create_tween().tween_property(piece, "position", spot, 0.15).set_ease(Tween.EASE_IN)
	session.wobble(piece, 0.12)
	session.play_sound("plop", spot, -4.0, 0.9)
	session.pop_text("Sizzle!", spot, 1)
	session.wobble(_hand, 0.1)


# An egg in its shell (two halves, so it can come apart), or a raw strip of bacon.
func _make_hand() -> Node3D:
	var hand := Node3D.new()
	var material := StandardMaterial3D.new()
	material.roughness = 0.5
	if kind == "egg":
		material.albedo_color = Color(0.96, 0.9, 0.8)
		_top_shell = _half_shell(material, false)
		_bottom_shell = _half_shell(material, true)
		hand.add_child(_top_shell)
		hand.add_child(_bottom_shell)
		_crack_line = MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.0215
		ring.outer_radius = 0.0235
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(0.45, 0.35, 0.25)
		ring.material = dark
		_crack_line.mesh = ring
		_crack_line.scale.y = 0.4
		_crack_line.visible = false
		hand.add_child(_crack_line)
	else:
		material.albedo_color = CookPiece.BACON_RAW
		var strip := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(bacon_size.y, 0.006, bacon_size.x)  # Lengthways, like it'll lie.
		box.material = material
		strip.mesh = box
		hand.add_child(strip)
	session.add_child(hand)
	return hand


# Half an egg shell, its cut edge at the hand's middle, hinged at the edge so it
# can swing open (rotation.z).
func _half_shell(material: StandardMaterial3D, bottom: bool) -> Node3D:
	var hinge := Node3D.new()
	hinge.position.x = 0.022 if bottom else -0.022
	var shell := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 0.022
	dome.height = 0.028  # Half of an egg 0.056 tall.
	dome.is_hemisphere = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # The inside shows once it's open.
	dome.material = material
	shell.mesh = dome
	shell.position.x = -hinge.position.x
	if bottom:
		shell.rotation.x = PI  # Dome down.
	hinge.add_child(shell)
	return hinge


# The zone's outline on the griddle.
func _make_outline() -> Node3D:
	var outline := Node3D.new()
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(1.0, 1.0, 1.0, 0.55)
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var at := view_point()
	for side in 4:
		var across := side < 2
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(zone_size.x if across else 0.006, 0.002, 0.006 if across else zone_size.y)
		mesh.material = paint
		bar.mesh = mesh
		var way := -1.0 if side % 2 == 0 else 1.0
		bar.position = at + (Vector3(0.0, 0.002, way * zone_size.y * 0.5) if across else Vector3(way * zone_size.x * 0.5, 0.002, 0.0))
		outline.add_child(bar)
	session.add_child(outline)
	return outline
