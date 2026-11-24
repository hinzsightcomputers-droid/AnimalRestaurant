# TipInAction: tip what's on a board (its contents, e.g. grated cheese) into a
# pot: press over the pot and the board lifts over and lets it all slide in.
# Nothing to score: it's the moment before folding in. What lands goes on the
# pot's stack too, so a StirAction with melt melts it.
class_name TipInAction
extends CookAction

@export var from_surface := "Board"
@export var into := "Pot"
@export var lift := 0.2

var _tipping := false
var _cue: Node3D


func _init() -> void:
	weight = 0.0


func view_point() -> Vector3:
	return session.surface(into).position


func cursor_height() -> float:
	return session.surface(into).position.y


func uses_cursor() -> bool:
	return not _tipping


func _begin() -> void:
	_cue = session.make_ring(session.surface(into).radius() * 0.6, Color(0.6, 1.0, 0.55, 0.9))
	_cue.position = session.surface(into).position + Vector3(0.0, 0.06, 0.0)


func end() -> void:
	_cue.queue_free()


func update(_delta: float, input: CookInput) -> void:
	if _tipping:
		return
	_cue.scale = Vector3(1.0, 0.3, 1.0) * (1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.008))
	if not input.just_pressed:
		return
	if session.surface(into).contains(input.cursor, 0.06):
		_tip()
	else:
		session.pop_text("Over the pot!", session.surface(into).position, 0)


# For a reel: over the pot and in.
func scripted_hold(delta: float, input: CookInput) -> bool:
	return not _tipping and input.move_to(session.surface(into).position, delta) and not input.held


func _tip() -> void:
	_tipping = true
	_cue.visible = false
	var board := session.surface(from_surface)
	var pot := session.surface(into)
	var home := board.position
	var side := 1.0 if home.x >= pot.position.x else -1.0
	var over := pot.position + Vector3(side * (board.size.x * 0.5 + pot.radius() * 0.3), lift, 0.0)
	var tween := board.create_tween()
	tween.tween_property(board, "position", Vector3(home.x, over.y, home.z), 0.2).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(board, "position", over, 0.25).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(board, "rotation:z", deg_to_rad(40.0) * side, 0.2)
	tween.tween_callback(_let_fall.bind(board, pot))
	tween.tween_interval(0.35 + board.contents.size() * 0.008)
	tween.tween_property(board, "rotation:z", 0.0, 0.15)
	tween.tween_property(board, "position", Vector3(home.x, over.y, home.z), 0.2)
	tween.tween_property(board, "position", home, 0.15)
	tween.tween_callback(finish.bind(1.0))


func _let_fall(board: CookSurface, pot: CookSurface) -> void:
	var i := 0
	for bit in board.contents:
		if not is_instance_valid(bit):
			continue
		bit.reparent(pot)
		pot.contents.append(bit)
		var spot := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * pot.radius() * 0.6
		var fall := bit.create_tween()
		fall.tween_interval(i * 0.008)
		fall.tween_property(bit, "position", Vector3(spot.x, pot.depth * 0.5 + 0.02 + randf() * 0.01, spot.y), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		session.stack_push(into, bit, pot.position, 0.0)
		i += 1
	board.contents.clear()
	session.play_sound("plop", pot.position, -6.0, 0.9)
