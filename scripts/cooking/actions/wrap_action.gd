# WrapAction: fill each round of dough and close it up round the filling, the
# way hotteok are made: a spoonful of brown sugar, cinnamon and chopped nuts
# goes in the middle, and the dough gathers up over it into a ball (PressAction
# flattens it again in the pan, spreading the filling to the edges). Press over a
# round to spoon it in: it scores how near the middle it lands, marked with a
# ring on each one still to do. Done when every round is filled and closed.
class_name WrapAction
extends CookAction

@export var surface := "Griddle"
@export var filling := "Filling"            # For the count.
@export var filling_color := Color(0.42, 0.22, 0.08)   # Brown sugar and cinnamon...
@export var bits_color := Color(0.78, 0.6, 0.38)       # ...with chopped nuts in it.
@export var filling_radius := 0.014
@export var gather := 0.62                  # How wide it is once closed (of its width)...
@export var ball_height := 1.6              # ...and how much taller.
@export var perfect_offset := 0.25          # How far off the middle still gets full marks (of its radius)...
@export var worst_offset := 0.8             # ...and gets least.
@export var round_radius := 0.075           # Dough waiting in its bowl (KneadAction): each round this wide...
@export var round_thickness := 0.022
@export var round_gap := 0.2                # ...this far apart.
@export var dough_color := Color(0.93, 0.82, 0.62)

const CLOSE_SECONDS := 0.35

var _pieces: Array[CookPiece] = []
var _filled := {}                           # Piece -> its score.
var _scores: Array[float] = []
var _spoon: Node3D                          # The spoonful waiting to go in, under the cursor.
var _marks := {}                            # Piece -> the ring marking its middle, till it's filled.


func _init() -> void:
	view_distance = 0.5
	view_pitch = 64.0


func view_point() -> Vector3:
	return session.surface(surface).position


func uses_cursor() -> bool:
	return false  # The spoonful shows the spot.


func marks_spot() -> bool:
	return true


func cursor_height() -> float:
	return session.surface(surface).position.y + 0.02


func ready_word(piece: CookPiece) -> String:
	return "Fill!" if piece in _pieces and not _filled.has(piece) else ""


func _begin() -> void:
	_pieces = session.pieces_on(surface)
	var dough: Node3D = session.context.get("dough")
	if _pieces.is_empty() and is_instance_valid(dough):
		_from_bowl(dough)
	if _pieces.is_empty():
		finish(1.0)
		return
	_spoon = _make_spoonful()
	session.add_child(_spoon)
	for piece in _pieces:
		var mark := session.make_ring(piece.radius * perfect_offset + 0.004, Color(1.0, 1.0, 1.0, 0.9))
		mark.position = piece.position + Vector3(0.0, piece.thickness + 0.003, 0.0)
		_marks[piece] = mark


func end() -> void:
	if _spoon != null:
		_spoon.queue_free()
	for mark in _marks.values():
		mark.queue_free()


func update(delta: float, input: CookInput) -> void:
	if done:
		return
	var spot := Vector3(input.cursor.x, cursor_height(), input.cursor.z)
	_spoon.position = _spoon.position.lerp(spot + Vector3(0.0, 0.05, 0.0), 1.0 - exp(-20.0 * delta))
	for piece: CookPiece in _marks:
		_marks[piece].position = piece.position + Vector3(0.0, piece.thickness + 0.003, 0.0)
	session.set_status("%s: %d of %d" % [filling, _filled.size(), _pieces.size()])
	if input.just_pressed:
		_spoon_in(spot)


# The kneaded dough, divided: a round of it on the griddle for each piece.
func _from_bowl(dough: Node3D) -> void:
	session.context.erase("dough")
	dough.queue_free()
	var count := maxi(session.recipe.pieces, 1)
	for i in count:
		var spot := KneadAction.round_spot(session, surface, i, count, round_gap)
		var piece := session.add_piece(dough_color, round_thickness, spot, surface)
		piece.spread_to = round_radius
		piece.create_tween().tween_method(piece.set_radius, round_radius * 0.6, round_radius, 0.25).set_ease(Tween.EASE_OUT)
		piece.set_radius(round_radius * 0.6)
		_pieces.append(piece)
	session.play_sound("plop", session.surface(surface).position, -6.0)


func _spoon_in(spot: Vector3) -> void:
	var piece := _piece_at(spot)
	if piece == null:
		session.pop_text("In the dough!", spot, -1)
		return
	if _filled.has(piece):
		session.pop_text("That one's full", spot, 0)
		return
	var offset := Vector2(spot.x - piece.position.x, spot.z - piece.position.z)
	var off := offset.length() / maxf(piece.radius, 0.001)
	var score := 1.0 - clampf((off - perfect_offset) / (worst_offset - perfect_offset), 0.0, 1.0)
	_filled[piece] = score
	_scores.append(score)
	piece.scores["wrap"] = score
	_marks[piece].queue_free()
	_marks.erase(piece)
	session.play_sound("plop", spot, -6.0, 1.2)
	session.pop_text("Right in the middle!" if score >= 0.9 else ("Nice" if score >= 0.6 else "Off to the side"), spot, CookSession.mood_of(score))
	# The spoonful drops in...
	var dollop := _make_spoonful()
	piece.add_child(dollop)
	dollop.global_position = _spoon.global_position
	var rest := Vector3(offset.x, piece.thickness + filling_radius * 0.3, offset.y)
	var close := dollop.create_tween()
	close.tween_property(dollop, "position", rest, 0.12).set_ease(Tween.EASE_IN)
	# ...and the dough gathers up over it into a ball.
	var from_radius := piece.radius
	var from_height := piece.scale.y
	close.tween_interval(0.08)
	close.tween_callback(func(): session.pop_text("Pinch!", piece.position, 1); session.play_sound("squish", piece.position, -8.0))
	close.tween_method(func(t: float):
		piece.set_radius(lerpf(from_radius, from_radius * gather, t))
		piece.scale.y = lerpf(from_height, from_height * ball_height, t)
		dollop.position = Vector3(offset.x * (1.0 - t), lerpf(rest.y, piece.thickness * 0.5, t), offset.y * (1.0 - t))
		dollop.scale = Vector3.ONE * (1.0 - t * 0.9), 0.0, 1.0, CLOSE_SECONDS).set_trans(Tween.TRANS_QUAD)
	close.tween_callback(func():
		dollop.visible = false  # Sealed inside.
		session.wobble(piece, 0.12)
		if _filled.size() >= _pieces.size() and not done:
			finish(average(_scores)))


func _piece_at(spot: Vector3) -> CookPiece:
	var best: CookPiece = null
	var nearest := INF
	for piece in _pieces:
		var d := Vector2(piece.position.x - spot.x, piece.position.z - spot.z).length()
		if d <= piece.radius * 1.1 and d < nearest:
			best = piece
			nearest = d
	return best


# A heaped spoonful: sticky brown sugar with flecks of nut.
func _make_spoonful() -> Node3D:
	var heap := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = filling_radius
	mesh.height = filling_radius * 1.1
	var sugar := StandardMaterial3D.new()
	sugar.albedo_color = filling_color
	sugar.roughness = 0.35
	sugar.set_meta(ToonStyle.FOOD, "baked")
	mesh.material = sugar
	heap.mesh = mesh
	var nut := StandardMaterial3D.new()
	nut.albedo_color = bits_color
	nut.set_meta(ToonStyle.FOOD, "baked")
	for i in 6:
		var bit := MeshInstance3D.new()
		var bit_mesh := BoxMesh.new()
		bit_mesh.size = Vector3.ONE * filling_radius * 0.32
		bit_mesh.material = nut
		bit.mesh = bit_mesh
		var at := Vector2.from_angle(i * 1.9) * filling_radius * randf_range(0.3, 0.75)
		bit.position = Vector3(at.x, filling_radius * 0.4, at.y)
		bit.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		heap.add_child(bit)
	return heap


# For a reel: one in the middle of each.
func scripted_hold(delta: float, input: CookInput) -> bool:
	for piece in _pieces:
		if not _filled.has(piece):
			return input.move_to(piece.position, delta, 1.0) and not input.held
	return false
