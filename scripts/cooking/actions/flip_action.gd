# FlipAction: a spatula follows the cursor. Press the button (or RT) on a piece
# and the spatula slides under it; then flick up (the right stick, the up key,
# or a quick upward swipe of the mouse) to flip it over. Pressing again puts
# it back down. Just moving over a piece does nothing. While one's held an
# arrow over it shows the flick.
# Each flip scores how cooked the side that was down got (the recipe's
# HeatAction decides what's raw, golden and burnt), so you have to watch every
# piece's edge.
class_name FlipAction
extends CookAction

@export var surface := "Griddle"
@export var flip_height := 0.16       # How high it jumps.
@export var flip_seconds := 0.45
@export var lift := 0.012             # How far a held piece rises off the surface.
@export var grab_margin := 0.02       # How far outside a piece you can still get hold of it.
@export_range(0.0, 1.0) var up_needed := 0.6  # How straight up the flick must be (1 = exactly).

var _scores: Array[float] = []
var _held: CookPiece = null
var _spatula: Node3D
var _arrow: Node3D


func view_point() -> Vector3:
	return session.surface(surface).position


# With a view of its own, the cursor stays on the surface (and on screen).
func cursor_area() -> Rect2:
	return session.area_of(surface, 0.03) if view_distance > 0.0 else Rect2()


func _begin() -> void:
	_spatula = session.make_spatula()
	_spatula.position = session.surface(surface).position
	_arrow = session.make_flick_arrow()


# The spatula shows where it'll go in.
func uses_cursor() -> bool:
	return false


func update(delta: float, input: CookInput) -> void:
	if _held == null:
		if input.just_pressed:
			_grab(_piece_at(input.cursor))
	elif input.flick.y <= -up_needed:  # Away from the camera: up the screen.
		var piece := _held
		_let_go()
		_turn(piece)
	elif input.just_pressed:  # Changed their mind: back down.
		_let_go()
		session.pop_text(_flick_words(), input.cursor, 0)
	# The spatula: under the piece it's holding, or at the cursor, just on the surface.
	var goal := Vector3(input.cursor.x, session.surface(surface).position.y + 0.004, input.cursor.z)
	if _held != null:
		goal = _held.position + Vector3(0.0, -0.004, 0.0)
	_spatula.position = _spatula.position.lerp(goal, 1.0 - exp(-22.0 * delta))
	if _held != null:
		session.show_flick(_arrow, _held.position + Vector3(0.0, _held.thickness, 0.0))
	else:
		_arrow.visible = false
	var left := session.pieces_on(surface).filter(func(p): return _needs(p) or p.busy)
	if left.is_empty() and not session.pieces_on(surface).is_empty():
		finish(average(_scores))


func end() -> void:
	if _held != null:
		_let_go()
	_spatula.queue_free()
	_arrow.queue_free()


# Whether a piece still needs this step (a FoldAction overrides these three).
func _needs(piece: CookPiece) -> bool:
	return not piece.flipped


func _flick_words() -> String:
	return "Flick up to flip!"


func ready_word(piece: CookPiece) -> String:
	return "Flip!" if _needs(piece) and piece.surface == surface else ""


# Over it goes: toward the flick, or sideways for a folded one (a half-moon
# turned the other way would jump back when it lands).
func _turn(piece: CookPiece) -> void:
	_flip(piece, Vector2(1.0, 0.0) if piece.folded else Vector2(0.0, -1.0))


func _grab(piece: CookPiece) -> void:
	if piece == null:
		return
	_held = piece
	piece.position.y += lift
	session.wobble(piece, 0.08)
	session.play_sound("tick", piece.position)


func _let_go() -> void:
	_held.position.y -= lift
	_held = null


# The unflipped piece under the cursor, or null.
func _piece_at(spot: Vector3) -> CookPiece:
	var best: CookPiece = null
	var best_gap := INF
	for piece in session.pieces_on(surface):
		if not _needs(piece) or piece.busy:
			continue
		var gap := Vector2(piece.position.x - spot.x, piece.position.z - spot.z).length()
		if gap <= piece.radius + grab_margin and gap < best_gap:
			best = piece
			best_gap = gap
	return best

func _flip(piece: CookPiece, direction: Vector2) -> void:
	piece.busy = true
	var heat := session.step_of(HeatAction) as HeatAction
	var cooked: float = piece.doneness[piece.down_side]
	var score := heat.score(cooked) if heat != null else 1.0
	piece.scores["flip"] = score
	_scores.append(score)
	session.play_sound("whoosh", piece.position, -4.0)
	var axis := Vector3(direction.y, 0.0, -direction.x).normalized()  # Turns over toward the flick.
	var base := piece.position
	var tween := piece.create_tween()
	tween.tween_method(func(t: float):
		piece.position = base + Vector3(0.0, sin(t * PI) * flip_height, 0.0)
		piece.quaternion = Quaternion(axis, t * PI), 0.0, 1.0, flip_seconds).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		piece.position = base
		piece.quaternion = Quaternion.IDENTITY
		piece.down_side = piece.up_side()
		piece.flipped = true
		piece.busy = false
		piece.refresh()
		session.wobble(piece, 0.15)
		session.play_sound("plop", base)
		session.burst(base + Vector3(0.0, 0.02, 0.0), piece.raw_color.darkened(0.2), 8, 0.25)
		session.pop_text(heat.verdict(cooked) if heat != null else "Flipped!", base, CookSession.mood_of(score)))
