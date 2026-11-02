# HeadTurn: turns a model's head to look at the nearest chef within reach, on
# top of whatever its animation is doing (a little at a time, and only so far
# round), and back to straight ahead once they've walked off. Added to a model
# with HeadTurn.attach(model); does nothing for a model without a "head" node.
class_name HeadTurn
extends Node

const REACH := 3.0                  # Chefs further off than this aren't looked at.
const MAX_YAW := deg_to_rad(65.0)   # Furthest round it turns, either way.
const MAX_PITCH := deg_to_rad(25.0) # Furthest up or down.
const SPEED := 6.0                  # How quickly it turns.
const EYE_HEIGHT := 1.0             # Looks at a chef's face, about this far up.

var _model: Node3D
var _head: Node3D
var _rest := Basis()     # The head without an animation (for a model that has none).
var _animated := false
var _turn := Vector2.ZERO  # Yaw, pitch: where it's turned now.


static func attach(model: Node3D) -> HeadTurn:
	var head := model.find_child("head", true, false) as Node3D
	if head == null:
		return null
	var turn := HeadTurn.new()
	turn.name = "HeadTurn"
	turn._model = model
	turn._head = head
	turn._rest = head.basis
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		turn._animated = true
		(players[0] as AnimationMixer).mixer_applied.connect(turn._apply)
	model.add_child(turn)
	return turn


func _process(delta: float) -> void:
	var goal := _goal()
	_turn = _turn.lerp(goal, 1.0 - exp(-SPEED * delta))
	if not _animated:
		_head.basis = _rest
		_apply()


# Yaw and pitch toward the nearest chef in reach, in the model's own frame
# (it faces +z), or zero for none.
func _goal() -> Vector2:
	var nearest: Node3D = null
	var best := REACH
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		var gap: float = (node as Node3D).global_position.distance_to(_model.global_position)
		if gap < best:
			best = gap
			nearest = node
	if nearest == null:
		return Vector2.ZERO
	var local := _model.global_basis.orthonormalized().inverse() * (nearest.global_position + Vector3.UP * EYE_HEIGHT - _head.global_position)
	var yaw := atan2(local.x, local.z)
	if absf(yaw) > MAX_YAW + deg_to_rad(40.0):
		return Vector2.ZERO  # Right behind them: they don't twist round.
	var pitch := -atan2(local.y, Vector2(local.x, local.z).length())
	return Vector2(clampf(yaw, -MAX_YAW, MAX_YAW), clampf(pitch, -MAX_PITCH, MAX_PITCH))


# Turns the head (as the animation left it) by _turn, around the model's own up
# and side, so it's the same whatever the bones in between are doing.
func _apply() -> void:
	if _turn.length_squared() < 0.000001:
		return
	var frame := _model.global_basis.orthonormalized()
	var turn := frame * Basis.from_euler(Vector3(_turn.y, _turn.x, 0.0)) * frame.inverse()
	var head := _head.global_transform
	_head.global_transform = Transform3D(turn * head.basis, head.origin)
