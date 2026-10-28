# FlipAction: flick the stick (or swipe the mouse) toward a piece to flip it
# over, in any order. Each flip scores how cooked the side that was down got
# (the recipe's HeatAction decides what's raw, golden and burnt), so you have
# to watch every piece's edge.
class_name FlipAction
extends CookAction

@export var surface := "Griddle"
@export var flip_height := 0.16       # How high it jumps.
@export var flip_seconds := 0.45
@export_range(0.0, 1.0) var aim_needed := 0.3  # How directly the flick must point at a piece (with more than one left).

var _scores: Array[float] = []


func uses_cursor() -> bool:
	return false


func update(_delta: float, input: CookInput) -> void:
	if input.flick != Vector2.ZERO:
		var piece := _target(input.flick)
		if piece != null:
			_flip(piece, input.flick)
	var left := session.pieces_on(surface).filter(func(p): return not p.flipped or p.busy)
	if left.is_empty() and not session.pieces_on(surface).is_empty():
		finish(average(_scores))


# The unflipped piece the flick points at most directly, from the middle of the surface.
func _target(direction: Vector2) -> CookPiece:
	var candidates := session.pieces_on(surface).filter(func(p): return not p.flipped and not p.busy)
	if candidates.size() == 1:
		return candidates[0]
	var center := session.surface(surface).position
	var best: CookPiece = null
	var best_aim := aim_needed
	for piece in candidates:
		var toward := Vector2(piece.position.x - center.x, piece.position.z - center.z).normalized()
		var aim := toward.dot(direction)
		if aim > best_aim:
			best = piece
			best_aim = aim
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
