# PlaceAction: put things down on a target, stacking them. Two ways:
#   - from_surface set: move the pieces sitting there one at a time. Hold the
#     button on one to pick it up, carry it over, let go to drop it. Or, with
#     auto_plate, just press on one: it hops onto the middle of the stack by
#     itself (no aiming, so no score of its own: give the step weight 0). With
#     carry, the same, but a spatula slides under it and carries it over.
#   - from_surface empty: place a new item (e.g. a pat of butter), already in
#     hand, kept over the target. Press the button to drop it.
# Each drop scores how well centered it landed on what's below (the target
# itself for the first one). A new item that misses the stack scores 0.
class_name PlaceAction
extends CookAction

@export var from_surface := "Griddle"
@export var target := "Plate"
@export var auto_plate := false         # Press on a piece and it goes to the target by itself.
@export var carry := false              # Like auto_plate, but the spatula slides under the piece and carries it over.
# auto_plate or carry: where each kind of piece lands on the target instead of the
# middle of the stack, in turn: kind -> [Vector3(x, z off the middle, turned degrees)].
# E.g. a breakfast face: { "egg": [the eyes], "bacon": [a mustache] }.
@export var arrange := {}
@export_group("New item")
@export var item_size := Vector3(0.055, 0.025, 0.04)
@export var item_color := Color(1.0, 0.92, 0.55)
@export var melt_seconds := 0.0           # Above 0, it melts into a puddle over this long.
@export var anywhere := false             # Fine anywhere on the target (bacon beside the eggs), not just on the food.
@export_enum("block", "toast_half", "flower", "strawberries", "blueberries", "rice_mound") var item_shape := "block"  # toast_half: a slice cut corner to corner, its point down the plate. strawberries, blueberries: a little heap of them. rice_mound: a dome of rice in item_color (omurice).
@export var aim_at := false              # Score how near a spot on the target it lands (aim, off the middle), marked with a ring.
@export var aim := Vector2.ZERO
@export_group("Feel")
@export var carry_height := 0.09          # How high above the stack things are carried.
@export var perfect_offset := 0.012       # Off-center (meters) that still gets full marks...
@export var worst_offset := 0.09          # ...and the offset that gets none.
@export var drop_seconds := 0.18
@export var grab_margin := 0.03           # How far outside a piece you can still grab it.
@export var hop_seconds := 0.45          # An auto_plate piece's trip to the plate...
@export var hop_height := 0.14           # ...and how high it arcs.

const SCRIPTED_PAUSE := 0.5  # A reel holds a new item over the food this long.
const SCRIPTED_BESIDE := Vector3(0.12, 0.0, 0.05)  # Where a reel puts things that go beside the food, either side.

var _carrying: Node3D = null
var _carry_home := Vector3.ZERO
var _needed := 0
var _scores: Array[float] = []
var _landing := 0  # Drops still falling.
var _spatula: Node3D = null  # Follows the cursor (carry).
var _riding: CookPiece = null  # On the spatula, on its way to the target.
var _queued: CookPiece = null  # Pressed on while the spatula was busy: it goes next.
var _scripted_pause := SCRIPTED_PAUSE
var _ring: MeshInstance3D = null  # aim_at: where it should go.
var _arranged := {}  # arrange: kind -> how many of its spots are taken.


func _begin() -> void:
	if _new_item():
		_needed = 1
		_carrying = _make_item()
		_carrying.position = session.stack_top(target) + Vector3(0.0, carry_height, 0.0)
		if aim_at:
			_ring = session.make_ring(maxf(item_size.x, item_size.z) * 0.45)
			_ring.position = _aim_spot() + Vector3(0.0, 0.003, 0.0)
	else:
		_needed = session.pieces_on(from_surface).size()
		if carry:
			_spatula = session.make_spatula()
			_spatula.position = session.surface(from_surface).position


# Picking pieces up: looking at where they are. A new item: at the stack it goes on.
func view_point() -> Vector3:
	if aim_at:
		return _aim_spot()
	return session.stack_top(target) if _new_item() else session.surface(from_surface).position  # carry: the griddle, centred.


# With a view of its own, the cursor stays where the step is (and on screen).
func cursor_area() -> Rect2:
	if view_distance <= 0.0:
		return Rect2()
	return session.area_of(target if _new_item() else from_surface, 0.03)


func cursor_height() -> float:
	return session.stack_top(target).y if _new_item() else session.work_height


func update(delta: float, input: CookInput) -> void:
	if _new_item():  # It can only go down on the plate.
		input.cursor = session.surface(target).keep_inside(input.cursor, maxf(item_size.x, item_size.z) * 0.5)
	var spot := input.cursor
	if _carrying != null:
		var lift := maxf(session.stack_top(target).y, session.work_height) + carry_height
		var goal := Vector3(spot.x, lift, spot.z)
		_carrying.position = _carrying.position.lerp(goal, 1.0 - exp(-18.0 * delta))
		if (input.just_pressed if _new_item() else input.just_released):
			_drop(spot)
	elif input.just_pressed and not _new_item() and _riding != null and (auto_plate or carry):
		var next := _piece_at(spot)  # The spatula's busy: this one goes as soon as it's free.
		if next != null and next != _riding:
			_queued = next
			session.wobble(next, 0.08)
	elif input.just_pressed and not _new_item() and _riding == null:
		var piece := _piece_at(spot)
		if piece != null and (auto_plate or carry):
			_hop(piece)
		elif piece != null:
			_carrying = piece
			_carry_home = piece.position
			piece.surface = ""
			session.play_sound("tick", piece.position)
			session.wobble(piece, 0.1)
	if _spatula != null:  # Under what it's carrying, or at the cursor.
		var under := _riding.position + Vector3(0.0, -0.004, 0.0) if _riding != null else Vector3(spot.x, session.surface(from_surface).position.y + 0.004, spot.z)
		_spatula.position = _spatula.position.lerp(under, 1.0 - exp(-22.0 * delta))
	if _scores.size() >= _needed and _carrying == null and _landing == 0:
		finish(average(_scores))


# Carrying: the spatula shows where things are.
func uses_cursor() -> bool:
	return not carry


func end() -> void:
	if _spatula != null:
		_spatula.queue_free()
	if _ring != null:
		_ring.queue_free()


func ready_word(piece: CookPiece) -> String:
	return "Plate it!" if not _new_item() and piece.surface == from_surface else ""


# A new item straight down the middle, or each piece over as soon as it's done.
func scripted_hold(delta: float, input: CookInput) -> bool:
	if _new_item():
		_scripted_pause -= delta
		var goal := session.stack_top(target)
		if aim_at:
			goal = _aim_spot()
		elif anywhere:
			var side := 1.0 if session.stack_of(target).size() % 2 == 0 else -1.0
			goal = session.surface(target).position + SCRIPTED_BESIDE * Vector3(side, 1.0, 1.0)
		goal = session.surface(target).keep_inside(goal, maxf(item_size.x, item_size.z) * 0.5)  # Somewhere it can go (a small pan).
		return input.move_to(goal, delta) and _scripted_pause <= 0.0 and _carrying != null
	if _riding != null or input.held:
		return false
	var left := session.pieces_on(from_surface).filter(func(p): return not p.busy)
	if left.is_empty():
		return false
	var piece := HeatAction.most_done(left)
	var heat := session.step_of(HeatAction) as HeatAction
	return input.move_to(piece.position, delta) and (heat == null or heat.scripted_ready(piece))


func _new_item() -> bool:
	return from_surface.is_empty()


func _drop(spot: Vector3) -> void:
	var item := _carrying
	_carrying = null
	var top := session.stack_top(target)
	var on_target := session.surface(target).contains(spot)
	if not on_target and not _new_item():
		# Not over the plate: back onto the griddle (where it was, if dropped off it).
		var home := session.surface(from_surface)
		var back := Vector3(spot.x, home.position.y, spot.z) if home.contains(spot) else _carry_home
		_land(item, back, from_surface)
		session.pop_text("Onto the plate!", back, 0)
		return

	var offset := Vector2(spot.x - top.x, spot.z - top.z).length()
	var score := 1.0 - clampf((offset - perfect_offset) / (worst_offset - perfect_offset), 0.0, 1.0)
	var at := Vector3(spot.x, top.y, spot.z)
	if _new_item():
		var below := session.top_piece(target)
		var misses := below == null or Vector2(spot.x - below.position.x, spot.z - below.position.z).length() > below.radius
		if aim_at and on_target:  # How near its spot (the toast nose, in the middle of the face).
			var aimed := _aim_spot()
			offset = Vector2(spot.x - aimed.x, spot.z - aimed.z).length()
			score = 1.0 - clampf((offset - perfect_offset) / (worst_offset - perfect_offset), 0.0, 1.0)
			at.y = _height_at(Vector2(spot.x, spot.z))
		elif anywhere and on_target:
			score = 1.0  # On the food if it's over it, else beside it on the plate.
			at.y = _height_at(Vector2(spot.x, spot.z))
		elif misses or not on_target:
			score = 0.0
			at.y = session.surface(target).position.y if on_target else session.work_height
	_scores.append(score)
	if on_target and score > 0.0:
		session.stack_push(target, item, at, item_size.y if _new_item() else (item as CookPiece).thickness)
	if item is CookPiece:
		item.scores["place"] = score
	_land(item, at, target)
	var words := "Centered!" if score >= 0.9 else ("Nice" if score >= 0.6 else ("A bit off" if score > 0.25 else ("Missed!" if score == 0.0 else "Lopsided!")))
	session.pop_text(words, at, CookSession.mood_of(score))


# An auto_plate piece arcs over to the middle of the stack and lands there.
# With carry, the spatula slides under it first and carries it.
func _hop(piece: CookPiece) -> void:
	var top := session.stack_top(target)
	var at := Vector3(top.x, top.y, top.z)
	var turn := piece.rotation.y
	var spots: Array = arrange.get(piece.kind, [])
	var taken: int = _arranged.get(piece.kind, 0)
	if taken < spots.size():  # Its own place on the plate (an eye, half the mustache).
		_arranged[piece.kind] = taken + 1
		var spot: Vector3 = spots[taken]
		var middle := session.surface(target).position
		at = Vector3(middle.x + spot.x, middle.y, middle.z + spot.y)
		turn = deg_to_rad(spot.z)
	var from_turn := piece.rotation.y
	piece.surface = ""  # Off the heat: it's scored when it lands.
	piece.busy = true
	piece.droop = 0.014
	session.stack_push(target, piece, at, piece.thickness)
	piece.scores["place"] = 1.0
	_scores.append(1.0)
	_landing += 1
	session.play_sound("whoosh", piece.position, -6.0, 1.2)
	var from := piece.position
	var tween := piece.create_tween()
	if carry:
		_riding = piece
		tween.tween_interval(0.2)  # The spatula slides under.
	tween.tween_method(func(t: float):
		piece.position = from.lerp(at, t) + Vector3(0.0, sin(t * PI) * hop_height, 0.0)
		piece.rotation.y = lerp_angle(from_turn, turn, t), 0.0, 1.0, hop_seconds).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		_landing -= 1
		piece.busy = false
		piece.droop = 0.0
		piece.surface = target
		if _riding == piece:
			_riding = null
			if _queued != null and is_instance_valid(_queued) and _queued.surface == from_surface and not _queued.busy:
				var next := _queued
				_queued = null
				_hop(next)
			_queued = null
		session.wobble(piece, 0.3)
		for under in session.pieces_on(target):  # What it lands on gives too.
			if under != piece:
				session.wobble(under, 0.16)
		session.play_sound("plop", at)
		session.burst(at + Vector3(0.0, 0.01, 0.0), Color(1.0, 0.95, 0.8), 8, 0.2))


func _land(item: Node3D, at: Vector3, on_surface: String) -> void:
	_landing += 1
	var tween := item.create_tween()
	tween.tween_property(item, "position", at, drop_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		_landing -= 1
		if item is CookPiece:
			item.surface = on_surface
		if not (_new_item() and melt_seconds > 0.0):  # Melting squashes it instead.
			session.wobble(item, 0.18)
		session.play_sound("plop", at, -2.0, 1.3 if _new_item() else 1.0)
		session.burst(at + Vector3(0.0, 0.01, 0.0), item_color if _new_item() else Color(1.0, 0.95, 0.8), 8, 0.2)
		if _new_item() and melt_seconds > 0.0:
			_melt(item))


# The top of whatever's on the target under a new item at a point (anywhere
# under its middle or corners): the food, things already put down, or just
# the target.
func _height_at(point: Vector2) -> float:
	var top := session.surface(target).position.y
	var half := Vector2(item_size.x, item_size.z) * 0.5
	var spots := [point, point + half, point - half, point + Vector2(half.x, -half.y), point + Vector2(-half.x, half.y)]
	for entry in session.stack_of(target):
		var node: Node3D = entry["node"]
		var middle := Vector2(entry["at"].x, entry["at"].z)
		for spot: Vector2 in spots:
			if node.covers(spot) if node is CookPiece else middle.distance_to(spot) < 0.04:
				top = maxf(top, entry["at"].y + entry["height"])
				break
	return top


func _piece_at(spot: Vector3) -> CookPiece:
	var best: CookPiece = null
	var best_gap := INF
	for piece in session.pieces_on(from_surface):
		if piece.busy:
			continue
		var gap := Vector2(piece.position.x - spot.x, piece.position.z - spot.z).length()
		if gap <= piece.radius + grab_margin and gap < best_gap:
			best = piece
			best_gap = gap
	return best


func _aim_spot() -> Vector3:
	var middle := session.surface(target).position
	return Vector3(middle.x + aim.x, middle.y, middle.z + aim.y)


# The new item: a block sitting on its bottom middle (or a diagonal half of toast).
func _make_item() -> Node3D:
	if item_shape == "toast_half":
		return _make_toast_half()
	if item_shape == "flower":
		return _make_flower()
	if item_shape == "rice_mound":
		return _make_rice_mound()
	if item_shape in ["strawberries", "blueberries"]:
		return _make_berries(item_shape == "strawberries")
	var item := Node3D.new()
	var block := MeshInstance3D.new()
	block.mesh = rounded_block(item_size, minf(item_size.x, minf(item_size.y, item_size.z)) * 0.32)
	var material := StandardMaterial3D.new()
	material.albedo_color = item_color
	material.roughness = 0.28 if melt_seconds > 0.0 else 0.5
	material.set_meta(ToonStyle.FOOD, "butter" if melt_seconds > 0.0 else "cooked")
	block.material_override = material
	block.position.y = item_size.y * 0.5
	item.add_child(block)
	session.add_child(item)
	return item


# A box with soft, rounded corners, its middle at the origin.
static func rounded_block(size: Vector3, corner: float) -> ArrayMesh:
	var ball := SphereMesh.new()
	ball.radius = corner
	ball.height = corner * 2.0
	ball.radial_segments = 24
	ball.rings = 11
	var arrays := ball.get_mesh_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var inner := (size * 0.5 - Vector3.ONE * corner).max(Vector3.ZERO)
	for i in points.size():  # Each eighth of the ball out to its corner.
		var p := points[i]
		points[i] = p + Vector3(inner.x * (1.0 if p.x >= 0.0 else -1.0), inner.y * (1.0 if p.y >= 0.0 else -1.0), inner.z * (1.0 if p.z >= 0.0 else -1.0))
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# A slice of toast cut corner to corner, item_size.x along its cut edge: a
# triangle with its point down toward the mustache (a nose), browner crust round a golden
# middle, sitting on its bottom middle.
func _make_toast_half() -> Node3D:
	var item := Node3D.new()
	# Three-sided cylinders, widened: a triangle with its point toward the cook (+z).
	var tall := item_size.x * 0.5
	var corner := tall / 1.5  # An even triangle this far to its corners is `tall` from point to base...
	var widen := item_size.x / (corner * sqrt(3.0))  # ...then widened to item_size.x along the base.
	for layer in [[1.0, item_size.y, Color(0.72, 0.45, 0.2)], [0.78, item_size.y + 0.002, item_color]]:  # Crust, then the golden middle.
		var mesh := CylinderMesh.new()
		mesh.top_radius = corner * layer[0]
		mesh.bottom_radius = corner * layer[0]
		mesh.height = layer[1]
		mesh.radial_segments = 3
		mesh.rings = 1
		var material := StandardMaterial3D.new()
		material.albedo_color = layer[2]
		material.roughness = 0.7
		material.set_meta(ToonStyle.FOOD, "baked")
		mesh.material = material
		var slab := MeshInstance3D.new()
		slab.mesh = mesh
		slab.position.y = layer[1] * 0.5
		slab.rotation.y = PI  # Turned so a corner points down the plate.
		slab.scale.x = widen
		item.add_child(slab)
	session.add_child(item)
	return item


# A little flower lying open: two rings of cupped petals round a yellow middle.
func _make_flower() -> Node3D:
	var item := Node3D.new()
	var reach := item_size.x * 0.5
	for ring in 2:
		for i in 6:
			var petal := MeshInstance3D.new()
			var ball := SphereMesh.new()
			ball.radius = reach * 0.34
			ball.height = reach * 0.68
			ball.radial_segments = 20
			ball.rings = 10
			var paint := StandardMaterial3D.new()
			paint.albedo_color = item_color.lightened(0.3 * ring + randf() * 0.1)
			paint.roughness = 0.6
			paint.set_meta(ToonStyle.FOOD, "egg")
			ball.material = paint
			petal.mesh = ball
			var turn := TAU * (i + ring * 0.5) / 6.0
			var far := reach * (0.62 - 0.26 * ring)
			petal.position = Vector3(cos(turn) * far, item_size.y * (0.3 + 0.3 * ring), sin(turn) * far)
			petal.rotation = Vector3(0.0, -turn, 0.32 + 0.2 * ring)
			petal.scale = Vector3(1.15, 0.2, 0.85) * (1.0 - 0.2 * ring)
			item.add_child(petal)
	var middle := MeshInstance3D.new()
	var heart := SphereMesh.new()
	heart.radius = reach * 0.22
	heart.height = reach * 0.3
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.98, 0.78, 0.2)
	gold.set_meta(ToonStyle.FOOD, "baked")
	heart.material = gold
	middle.mesh = heart
	middle.position.y = item_size.y * 0.75
	item.add_child(middle)
	session.add_child(item)
	return item


# A mound of rice, item_size.x long, item_size.z wide and item_size.y tall, in
# item_color (the ketchup rice), grains showing all over it.
func _make_rice_mound() -> Node3D:
	var item := Node3D.new()
	var dome := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = item_size.x * 0.5
	mesh.height = item_size.x
	mesh.is_hemisphere = true
	var rice := StandardMaterial3D.new()
	rice.albedo_color = item_color
	rice.roughness = 0.6
	rice.set_meta(ToonStyle.FOOD, "baked")
	mesh.material = rice
	dome.mesh = mesh
	dome.scale = Vector3(1.0, item_size.y / (item_size.x * 0.5), item_size.z / item_size.x)
	item.add_child(dome)
	var grain := SphereMesh.new()
	grain.radius = 0.003
	grain.height = 0.006
	grain.radial_segments = 6
	grain.rings = 3
	var light := StandardMaterial3D.new()
	light.albedo_color = item_color.lightened(0.15)
	light.set_meta(ToonStyle.FOOD, "baked")
	grain.material = light
	for i in 60:  # Grains over its surface.
		var turn := i * 2.4
		var y := 1.0 - sqrt((i + 0.5) / 60.0)  # Evenly over the dome, top to bottom.
		var r := sqrt(1.0 - y * y)
		var bit := MeshInstance3D.new()
		bit.mesh = grain
		bit.position = Vector3(cos(turn) * r * item_size.x * 0.5, y * item_size.y, sin(turn) * r * item_size.z * 0.5) * 0.98
		bit.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
		bit.scale = Vector3(1.0, 1.0, 2.2)
		item.add_child(bit)
	session.add_child(item)
	return item


# A little heap of fruit, item_size.x across: strawberry halves fanned round, or
# a handful of blueberries.
func _make_berries(strawberry: bool) -> Node3D:
	var item := Node3D.new()
	var reach := item_size.x * 0.5
	var count := 4 if strawberry else 9
	for i in count:
		var berry := MeshInstance3D.new()
		var ball := SphereMesh.new()
		var paint := StandardMaterial3D.new()
		paint.set_meta(ToonStyle.FOOD, "fruit")
		var turn := TAU * i / count + randf() * 0.3
		if strawberry:  # A half, cut side up: red round a paler middle, its tip out.
			ball.radius = reach * 0.42
			ball.height = reach * 0.84
			ball.is_hemisphere = true
			paint.albedo_color = Color(0.88, 0.16, 0.2)
			paint.roughness = 0.35
			berry.position = Vector3(cos(turn) * reach * 0.42, 0.0, sin(turn) * reach * 0.42)
			berry.scale = Vector3(1.0, 0.55, 1.3)
			berry.rotation.y = -turn + PI * 0.5
			var cut := MeshInstance3D.new()
			var face := CylinderMesh.new()
			face.top_radius = reach * 0.36
			face.bottom_radius = reach * 0.36
			face.height = 0.001
			var pale := StandardMaterial3D.new()
			pale.albedo_color = Color(1.0, 0.6, 0.6)
			pale.set_meta(ToonStyle.FOOD, "fruit")
			face.material = pale
			cut.mesh = face
			cut.position.y = reach * 0.42 + 0.0005
			berry.add_child(cut)
		else:  # Round and dusky blue, heaped up in the middle.
			ball.radius = reach * 0.2
			ball.height = reach * 0.4
			paint.albedo_color = Color(0.24, 0.27, 0.55).lightened(randf() * 0.1)
			paint.roughness = 0.5
			var out := reach * 0.62 * sqrt((i + 0.5) / count)
			berry.position = Vector3(cos(turn * 2.4) * out, reach * 0.2 + (reach * 0.25 if i == 0 else 0.0), sin(turn * 2.4) * out)
		ball.material = paint
		berry.mesh = ball
		item.add_child(berry)
	session.add_child(item)
	return item


# Softens and slumps, sliding a little, its melted butter running out from under
# it over the food (a SauceSheet).
func _melt(item: Node3D) -> void:
	var sheet := session.make_sauce(target, "butter", item_color.darkened(0.12))
	sheet.look_under(func(point: Vector2) -> float:  # It runs under the pat, not over it.
		var place := session.surface(target)
		if not place.contains(Vector3(point.x, 0.0, point.y), -0.004):
			return INF
		var top := place.position.y
		for piece in session.pieces_on(target):
			top = maxf(top, piece.height_at(point))
		return top)
	var tween := item.create_tween().set_parallel(true)
	tween.tween_property(item, "scale", Vector3(1.22, 0.5, 1.22), melt_seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(item, "position", item.position + Vector3(randf_range(-0.006, 0.006), 0.0, 0.007), melt_seconds * 1.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(item, "rotation:y", item.rotation.y + randf_range(-0.25, 0.25), melt_seconds * 1.5).set_trans(Tween.TRANS_SINE)
	var ran := [0.0]
	tween.tween_method(func(t: float):
		if not is_instance_valid(sheet):
			return
		var size := item_size.x * 0.55
		var spot := Vector2(item.position.x, item.position.z) + Vector2.from_angle(randf() * TAU) * size * 0.9
		sheet.pour(spot, 0.0000052 * (t - ran[0]), 0.011)
		ran[0] = t, 0.0, 1.0, melt_seconds * 2.0)
