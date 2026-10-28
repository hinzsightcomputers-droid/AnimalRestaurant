# HeatAction ("wait"): a hot surface cooks whatever's on it, the side facing
# down, each piece on its own slightly different timer. Usually a background
# step, so it keeps cooking while you pour and flip. Steam rises as a side
# cooks and turns to smoke once it's burning.
#
# Its quality is how well the second side was cooked when each piece came off
# (the first side is scored when it's flipped: FlipAction uses score() too).
class_name HeatAction
extends CookAction

@export var surface := "Griddle"
@export var first_side_seconds := 10.0   # Seconds for the first side to be just right.
@export var second_side_seconds := 6.0   # The second side is quicker (the piece is already hot).
@export_range(0.0, 0.5) var timer_variation := 0.15  # Each piece is up to this much faster or slower.
@export_group("Scoring")
@export var raw_at := 0.45       # Doneness that scores 0 for being raw...
@export var perfect_from := 0.9  # ...full marks from here...
@export var perfect_to := 1.15   # ...to here...
@export var burnt_at := 1.6      # ...and 0 again once it's this burnt.

var _seen := {}    # Piece -> its steam, once it's been on the heat.
var _scores: Array[float] = []
var _sizzle: AudioStreamPlayer3D


func _begin() -> void:
	_sizzle = session.loop_sound("sizzle", -8.0)
	_sizzle.position = session.surface(surface).position


func uses_cursor() -> bool:
	return false


func update(delta: float, _input: CookInput) -> void:
	var cooking := 0
	for piece in session.pieces:
		if piece.surface == surface:
			if not _seen.has(piece):
				piece.cook_speed = 1.0 + randf_range(-timer_variation, timer_variation)
				var steam := session.make_steam(piece.spread_to)
				piece.add_child(steam)
				_seen[piece] = steam
			cooking += 1
			if not piece.busy:
				var seconds := second_side_seconds if piece.flipped else first_side_seconds
				piece.doneness[piece.down_side] += delta * piece.cook_speed / seconds
				piece.refresh()
			_update_steam(piece, _seen[piece])
		elif _seen.has(piece) and not piece.scores.has("heat") and not piece.surface.is_empty():
			# Off the heat and set down somewhere else: the side that was down is done.
			var score := score(piece.doneness[piece.down_side])
			piece.scores["heat"] = score
			_scores.append(score)
			_seen[piece].emitting = false
	if cooking > 0 and not _sizzle.playing:
		_sizzle.play()
	elif cooking == 0 and _sizzle.playing:
		_sizzle.stop()
	_sizzle.volume_db = -10.0 + 3.0 * cooking

	var all_poured := session.pieces.size() >= session.recipe.pieces
	if all_poured and _scores.size() >= session.pieces.size():
		finish(average(_scores))


func end() -> void:
	if not done:
		quality = average(_scores)
	_sizzle.stop()
	for steam in _seen.values():
		steam.emitting = false


func _update_steam(piece: CookPiece, steam: CPUParticles3D) -> void:
	var amount: float = piece.doneness[piece.down_side]
	steam.emitting = amount > 0.25
	steam.emission_sphere_radius = maxf(piece.radius, 0.01) * 0.7
	if amount > 1.3:
		steam.color = Color(0.25, 0.22, 0.2).lerp(Color(0.1, 0.1, 0.1), clampf((amount - 1.3) / 0.4, 0.0, 1.0))
		steam.speed_scale = 1.6
	else:
		steam.color = Color.WHITE
		steam.speed_scale = 0.7 + amount * 0.5


# 0..1 for how well a side came out at this doneness.
func score(amount: float) -> float:
	if amount < perfect_from:
		return clampf((amount - raw_at) / (perfect_from - raw_at), 0.0, 1.0)
	if amount <= perfect_to:
		return 1.0
	return clampf(1.0 - (amount - perfect_to) / (burnt_at - perfect_to), 0.0, 1.0)


# A word for a side at this doneness, e.g. "Golden!".
func verdict(amount: float) -> String:
	if amount < raw_at:
		return "Raw!"
	if amount < perfect_from:
		return "A bit pale"
	if amount <= perfect_to:
		return "Golden!"
	if amount < burnt_at:
		return "A bit dark"
	return "Burnt!"
