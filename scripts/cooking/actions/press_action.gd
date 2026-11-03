# PressAction: a meter rising to a green band, scored like seasoning: full
# marks in the band, less the further either side. Two ways:
#   - hold: a spatula presses down on each piece on the surface in turn while
#     you hold the button (a hotteok flattening), the meter rising as it
#     spreads; let go in the band.
#   - not hold: it rises by itself (a saucepan coming up to the boil, its
#     bubbles getting busier and the band where they're just right); press the
#     button in the band to turn the heat off. Left too long, it goes too far.
# The meter rises over rise_seconds (slower on Easy).
class_name PressAction
extends CookAction

@export var surface := "Griddle"           # The pieces on it (hold), or the pot.
@export var hold := true
@export var band := Vector2(0.55, 0.75)
@export var rise_seconds := 1.6            # From empty to full.
@export var flatten := 0.4                 # hold: how much thinner a full press leaves a piece...
@export var widen := 0.25                  # ...and how much wider.
@export var low_word := "Too thick"        # Let go (or pressed) before the band...
@export var high_word := "Too thin!"       # ...and after it.
@export var good_word := "Just right!"
@export var meter_offset := Vector3(0.0, 0.03, 0.17)  # From the piece (or pot), lying flat in front of it.
@export var meter_length := 0.24

var _amount := 0.0
var _scores: Array[float] = []
var _targets: Array = []                   # Pieces (hold), or [the pot].
var _index := 0
var _pressing := false
var _fill: MeshInstance3D
var _spatula: Node3D
var _start := {}                           # Piece -> [radius, thickness, scale y] before pressing.
var _bubble_timer := 0.0
var _hiss: AudioStreamPlayer3D
var _cued := false                         # Not hold: popped good_word as it came into the band.


func view_point() -> Vector3:
	return session.surface(surface).position


func uses_cursor() -> bool:
	return false


func ready_word(piece: CookPiece) -> String:
	return "Press!" if hold and piece in _targets.slice(_index) else ""


func _begin() -> void:
	if hold:
		_targets = session.pieces_on(surface)
		_spatula = session.make_spatula()
		for piece: CookPiece in _targets:
			_start[piece] = [piece.radius, piece.thickness]
	else:
		_targets = [session.surface(surface)]
		_hiss = session.loop_sound("sizzle", -24.0)
		_hiss.position = session.surface(surface).position
		_hiss.play()
	if _targets.is_empty():
		finish(1.0)
		return
	_start_on(0)


func end() -> void:
	if _spatula != null:
		_spatula.queue_free()
	if _fill != null:
		_fill.get_parent().queue_free()
	if _hiss != null:
		_hiss.queue_free()


func update(delta: float, input: CookInput) -> void:
	if _index >= _targets.size():
		return
	var target: Node3D = _targets[_index]
	var rise := delta / rise_seconds * GameState.difficulty_value("closeup_pace")
	if hold:
		var piece := target as CookPiece
		if input.just_pressed and not piece.busy:
			_pressing = true
		if _pressing:
			_amount = minf(_amount + rise, 1.0)
			piece.set_radius(_start[piece][0] * (1.0 + widen * _amount))
			piece.thickness = _start[piece][1] * (1.0 - flatten * _amount)
			piece.scale.y = 1.0 - flatten * _amount
			if not input.held:
				_stop(target)
		var goal := piece.position + Vector3(0.0, piece.thickness + (0.002 if _pressing else 0.05), 0.0)
		_spatula.position = _spatula.position.lerp(goal, 1.0 - exp(-18.0 * delta))
		session.set_status("Press %d of %d: hold, then let go in the green" % [_index + 1, _targets.size()])
	else:
		var pot := target as CookSurface
		_amount = minf(_amount + rise, 1.0)
		_hiss.volume_db = lerpf(-24.0, -6.0, _amount)
		_bubble_timer -= delta
		if _bubble_timer <= 0.0:  # Busier as it heats up.
			_bubble_timer = lerpf(0.5, 0.05, _amount)
			var spot := Vector2.from_angle(randf() * TAU) * randf() * pot.radius() * 0.8
			session.burst(Vector3(pot.position.x + spot.x, pot.liquid_top() + 0.004, pot.position.z + spot.y), pot.liquid_color().lightened(0.3), 3, 0.08 + _amount * 0.12)
		if not _cued and _amount >= band.x:
			_cued = true
			session.pop_text(good_word, pot.position, 1)
		session.set_status("Bubbles: %s" % (low_word if _amount < band.x else (good_word if _amount <= band.y else high_word)))
		if input.just_pressed or _amount >= 1.0:
			_stop(target)
	session.set_meter(_fill, _amount)


func _start_on(index: int) -> void:
	_index = index
	_amount = 0.0
	_pressing = false
	if _fill != null:
		_fill.get_parent().queue_free()
	var target: Node3D = _targets[index]
	_fill = session.make_meter(target.position + meter_offset, meter_length, band, Color(1.0, 0.8, 0.35))


func _stop(target: Node3D) -> void:
	_pressing = false
	var score := _score()
	_scores.append(score)
	var words := low_word if _amount < band.x else (good_word if _amount <= band.y else high_word)
	session.pop_text(words, target.position, CookSession.mood_of(score))
	session.play_sound("clack" if hold else "tick", target.position, -6.0, 1.1)
	if target is CookPiece:
		(target as CookPiece).scores["press"] = score
		session.wobble(target, 0.1)
	if _index + 1 < _targets.size():
		_start_on(_index + 1)
	else:
		_index = _targets.size()
		if _hiss != null:
			_hiss.stop()
		finish(average(_scores))


# Full marks in the band, falling off either side of it (like seasoning).
func _score() -> float:
	if _amount < band.x:
		return clampf(_amount / band.x, 0.0, 1.0) * 0.8
	if _amount <= band.y:
		return 1.0
	return clampf(1.0 - (_amount - band.y) / (1.0 - band.y), 0.0, 1.0) * 0.8
