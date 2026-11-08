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

const SCRIPTED_PACE := 2.5       # A reel doesn't wait around: this much faster while the chef's only waiting on the heat.
const SCRIPTED_DONE := 1.0       # How done a reel's chef lets a side get.

var _seen := {}    # Piece -> its steam, once it's been on the heat.
var _scores: Array[float] = []
var _sizzle: AudioStreamPlayer3D
var _markers := {}  # Piece -> its "Flip!" label.
var _smoking := {}  # Pieces that have started to burn (the cook looks up, startled).


func _begin() -> void:
	_sizzle = session.loop_sound("sizzle", -8.0)
	_sizzle.position = session.surface(surface).position


func uses_cursor() -> bool:
	return false


func update(delta: float, input: CookInput) -> void:
	if input.scripted and (session.current is FlipAction or session.current is PlaceAction):
		delta *= SCRIPTED_PACE
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
				piece.doneness[piece.down_side] += delta * piece.cook_speed / seconds * GameState.difficulty_value("closeup_pace")  # Slower on Easy: more time to flip.
				piece.refresh()
			_update_steam(piece, _seen[piece])
			_update_marker(piece)
		elif _seen.has(piece) and not piece.scores.has("heat") and not piece.surface.is_empty():
			# Off the heat and set down somewhere else: the side that was down is done.
			var score := score(piece.doneness[piece.down_side])
			piece.scores["heat"] = score
			_scores.append(score)
			_seen[piece].emitting = false
		if piece.surface != surface and _markers.has(piece):
			_markers[piece].visible = false
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
	for marker in _markers.values():
		marker.queue_free()
	_markers.clear()


# "Flip!" (whatever the current step wants) bobbing over a piece once the
# side that's down is cooked enough, with a ding when it first shows. It turns
# orange, "Hurry!", once that side's past golden.
func _update_marker(piece: CookPiece) -> void:
	var word := session.current.ready_word(piece) if session.current != null else ""
	var amount: float = piece.doneness[piece.down_side]
	var show := not word.is_empty() and not piece.busy and amount >= perfect_from
	var marker: Label3D = _markers.get(piece)
	if marker == null:
		if not show:
			return
		marker = Label3D.new()
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.no_depth_test = true
		marker.font_size = 64
		marker.outline_size = 18
		marker.pixel_size = session.text_size
		marker.outline_modulate = Color(0.2, 0.12, 0.08)
		session.add_child(marker)
		_markers[piece] = marker
		marker.visible = false
	if show and not marker.visible:
		session.play_sound("ding", piece.position, -10.0, 1.6)
		session.wobble(marker, 0.3)
	marker.visible = show
	if not show:
		return
	var late := amount > perfect_to
	marker.text = "Hurry! %s" % word if late else word
	marker.modulate = Color(1.0, 0.6, 0.3) if late else Color(0.6, 1.0, 0.55)
	var bob := sin(Time.get_ticks_msec() * 0.008) * 0.008
	marker.position = piece.position + Vector3(0.0, piece.thickness + 0.06 + bob, 0.0)


func _update_steam(piece: CookPiece, steam: CPUParticles3D) -> void:
	var amount: float = piece.doneness[piece.down_side]
	steam.emitting = amount > 0.25
	steam.emission_sphere_radius = maxf(piece.radius, 0.01) * 0.7
	if amount > 1.3:
		if not _smoking.has(piece):
			_smoking[piece] = true
			session.react("dish_burning")
		steam.color = Color(0.25, 0.22, 0.2).lerp(Color(0.1, 0.1, 0.1), clampf((amount - 1.3) / 0.4, 0.0, 1.0))
		steam.speed_scale = 1.6
	else:
		steam.color = Color.WHITE
		steam.speed_scale = 0.7 + amount * 0.5


# For a reel: the side that's down is golden.
func scripted_ready(piece: CookPiece) -> bool:
	return piece.doneness[piece.down_side] >= SCRIPTED_DONE


# For a reel: whichever of these needs seeing to first.
static func most_done(pieces: Array) -> CookPiece:
	var most: CookPiece = pieces[0]
	for piece: CookPiece in pieces:
		if piece.doneness[piece.down_side] > most.doneness[most.down_side]:
			most = piece
	return most


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
