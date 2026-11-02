# FoldAction: fold an omelette in half on the griddle, with the same controls
# as flipping (hold the button on it, then flick up): its near half turns over
# onto the far half. Scores how cooked the underside got, like a flip. After
# the fold its two outsides start cooking afresh (shown at least as golden as
# the fold left them), so a FlipAction after it browns the other side.
class_name FoldAction
extends FlipAction

@export var fold_seconds := 0.5
@export var cooked_after := 0.4  # Where both sides' cooking starts again after the fold.


func _needs(piece: CookPiece) -> bool:
	return not piece.folded


func _flick_words() -> String:
	return "Flick up to fold!"


func ready_word(piece: CookPiece) -> String:
	return "Fold!" if _needs(piece) and piece.surface == surface else ""


func _turn(piece: CookPiece) -> void:
	piece.busy = true
	var heat := session.step_of(HeatAction) as HeatAction
	var cooked: float = piece.doneness[piece.down_side]
	var score := heat.score(cooked) if heat != null else 1.0
	piece.scores["fold"] = score
	_scores.append(score)
	session.play_sound("whoosh", piece.position, -6.0, 1.2)
	await piece.fold_over(fold_seconds)
	piece.up_shade = minf(cooked, heat.perfect_to if heat != null else 1.0)
	piece.doneness = [cooked_after, cooked_after]
	piece.busy = false
	piece.refresh()
	session.wobble(piece, 0.12)
	session.play_sound("plop", piece.position, -4.0)
	session.pop_text(heat.verdict(cooked) if heat != null else "Folded!", piece.position, CookSession.mood_of(score))
