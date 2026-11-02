# PlaceAction: put things down on a target, stacking them. Two ways:
#   - from_surface set: move the pieces sitting there one at a time. Hold the
#     button on one to pick it up, carry it over, let go to drop it. Or, with
#     auto_plate, just press on one: it hops onto the middle of the stack by
#     itself (no aiming, so no score of its own: give the step weight 0).
#   - from_surface empty: place a new item (e.g. a pat of butter), already in
#     hand, kept over the target. Press the button to drop it.
# Each drop scores how well centered it landed on what's below (the target
# itself for the first one). A new item that misses the stack scores 0.
class_name PlaceAction
extends CookAction

@export var from_surface := "Griddle"
@export var target := "Plate"
@export var auto_plate := false         # Press on a piece and it goes to the target by itself.
@export var carry := false              # Press to lift a piece on the spatula, press over the target to put it down in the middle.
@export_group("New item")
@export var item_size := Vector3(0.055, 0.025, 0.04)
@export var item_color := Color(1.0, 0.92, 0.55)
@export var melt_seconds := 0.0           # Above 0, it melts into a puddle over this long.
@export_group("Feel")
@export var carry_height := 0.09          # How high above the stack things are carried.
@export var perfect_offset := 0.012       # Off-center (meters) that still gets full marks...
@export var worst_offset := 0.09          # ...and the offset that gets none.
@export var drop_seconds := 0.18
@export var grab_margin := 0.03           # How far outside a piece you can still grab it.
@export var hop_seconds := 0.45          # An auto_plate piece's trip to the plate...
@export var hop_height := 0.14           # ...and how high it arcs.

var _carrying: Node3D = null
var _carry_home := Vector3.ZERO
var _needed := 0
var _scores: Array[float] = []
var _landing := 0  # Drops still falling.
var _spatula: Node3D = null  # Under what's carried (carry).


func _begin() -> void:
	if _new_item():
		_needed = 1
		_carrying = _make_item()
		_carrying.position = session.stack_top(target) + Vector3(0.0, carry_height, 0.0)
	else:
		_needed = session.pieces_on(from_surface).size()
		if carry:
			_spatula = session.make_spatula()
			_spatula.position = session.surface(from_surface).position


# Picking pieces up: looking at where they are. A new item: at the stack it goes on.
func view_point() -> Vector3:
	if carry:  # Between the griddle and the plate (nearer the plate, in front), to see both.
		return session.surface(from_surface).position.lerp(session.surface(target).position, 0.65)
	return session.stack_top(target) if _new_item() else session.surface(from_surface).position


# With a view of its own, the cursor stays where the step is (and on screen).
func cursor_area() -> Rect2:
	if view_distance <= 0.0:
		return Rect2()
	if carry:
		return session.area_of(from_surface, 0.03).merge(session.area_of(target, 0.03))
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
		if (input.just_pressed if _new_item() or carry else input.just_released):
			_drop(spot)
			if _carrying != null:
				return  # Not over the plate: still carrying it.
	elif input.just_pressed and not _new_item():
		var piece := _piece_at(spot)
		if piece != null and auto_plate:
			_hop(piece)
		elif piece != null:
			_carrying = piece
			_carry_home = piece.position
			piece.surface = ""
			session.play_sound("tick", piece.position)
			session.wobble(piece, 0.1)
	if _spatula != null:  # Under what's carried, or at the cursor.
		var under := _carrying.position + Vector3(0.0, -0.004, 0.0) if _carrying != null else Vector3(spot.x, maxf(session.stack_top(target).y, session.work_height) + 0.004, spot.z)
		_spatula.position = _spatula.position.lerp(under, 1.0 - exp(-22.0 * delta))
	if _scores.size() >= _needed and _carrying == null and _landing == 0:
		finish(average(_scores))


# Carrying: the spatula shows where things are.
func uses_cursor() -> bool:
	return not carry


func end() -> void:
	if _spatula != null:
		_spatula.queue_free()


func ready_word(piece: CookPiece) -> String:
	return "Plate it!" if not _new_item() and piece.surface == from_surface else ""


func _new_item() -> bool:
	return from_surface.is_empty()


func _drop(spot: Vector3) -> void:
	var item := _carrying
	_carrying = null
	var top := session.stack_top(target)
	var on_target := session.surface(target).contains(spot)
	if carry:
		if not on_target:  # Keeps hold of it until it's over the plate.
			_carrying = item
			session.pop_text("Over the plate!", spot, 0)
			return
		spot = top  # Then it slides to the middle.
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
		if misses or not on_target:
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
func _hop(piece: CookPiece) -> void:
	var top := session.stack_top(target)
	var at := Vector3(top.x, top.y, top.z)
	piece.surface = ""  # Off the heat: it's scored when it lands.
	piece.busy = true
	session.stack_push(target, piece, at, piece.thickness)
	piece.scores["place"] = 1.0
	_scores.append(1.0)
	_landing += 1
	session.play_sound("whoosh", piece.position, -6.0, 1.2)
	var from := piece.position
	var tween := piece.create_tween()
	tween.tween_method(func(t: float):
		piece.position = from.lerp(at, t) + Vector3(0.0, sin(t * PI) * hop_height, 0.0), 0.0, 1.0, hop_seconds).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		_landing -= 1
		piece.busy = false
		piece.surface = target
		session.wobble(piece, 0.18)
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


# The new item: a block sitting on its bottom middle.
func _make_item() -> Node3D:
	var item := Node3D.new()
	var block := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = item_size
	var material := StandardMaterial3D.new()
	material.albedo_color = item_color
	material.roughness = 0.4
	mesh.material = material
	block.mesh = mesh
	block.position.y = item_size.y * 0.5
	item.add_child(block)
	session.add_child(item)
	return item


# Slumps and spreads a shiny puddle under itself.
func _melt(item: Node3D) -> void:
	var puddle := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.002
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(item_color, 0.75)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.1
	mesh.material = material
	puddle.mesh = mesh
	puddle.position.y = 0.001
	puddle.scale = Vector3(item_size.x * 0.4, 1.0, item_size.x * 0.4)
	item.add_child(puddle)
	var tween := item.create_tween().set_parallel(true)
	tween.tween_property(item, "scale", Vector3(1.2, 0.55, 1.2), melt_seconds).set_ease(Tween.EASE_OUT)
	tween.tween_property(puddle, "scale", Vector3(item_size.x * 1.1, 1.0, item_size.x * 1.1), melt_seconds).set_ease(Tween.EASE_OUT)
