# HeadTurn: turns a model's head to look at the nearest chef within reach, on
# top of whatever its animation is doing (a little at a time, and only so far
# round), and back to straight ahead once they've walked off. Added to a model
# with HeadTurn.attach(model). The head is a "head" node (the blocky models) or,
# on a rigged model, its head bone (HEAD_BONES); a model with neither is left be.
class_name HeadTurn
extends Node

const REACH := 3.0                  # Chefs further off than this aren't looked at.
const MAX_YAW := deg_to_rad(65.0)   # Furthest round it turns, either way.
const MAX_PITCH := deg_to_rad(25.0) # Furthest up or down.
const SPEED := 6.0                  # How quickly it turns.
const EYE_HEIGHT := 1.0             # Looks at a chef's face, about this far up.
const HEAD_BONES := ["mixamorig_Head", "Head", "head"]

var _model: Node3D
var _head: Node3D            # A "head" node, or null for a rigged model's bone.
var _skeleton: Skeleton3D
var _bone := -1
var _rest := Basis()     # The head without an animation (for a model that has none).
var _animated := false
var _turn := Vector2.ZERO  # Yaw, pitch: where it's turned now.


static func attach(model: Node3D) -> HeadTurn:
	var head := model.find_child("head", true, false) as Node3D
	var players := model.find_children("*", "AnimationPlayer", true, false)
	var turn := HeadTurn.new()
	turn.name = "HeadTurn"
	turn._model = model
	if head == null or head is Skeleton3D:
		# A rigged model: turn its head bone, after the animation has posed it.
		var skeletons := model.find_children("*", "Skeleton3D", true, false)
		if skeletons.is_empty() or players.is_empty():
			return null
		turn._skeleton = skeletons[0]
		for bone_name in HEAD_BONES:
			turn._bone = turn._skeleton.find_bone(bone_name)
			if turn._bone >= 0:
				break
		if turn._bone < 0:
			return null
		turn._animated = true
		(players[0] as AnimationMixer).mixer_applied.connect(turn._apply)
		model.add_child(turn)
		return turn
	turn._head = head
	turn._rest = head.basis
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


func _head_position() -> Vector3:
	if _head != null:
		return _head.global_position
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(_bone).origin


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
	var local := _model.global_basis.orthonormalized().inverse() * (nearest.global_position + Vector3.UP * EYE_HEIGHT - _head_position())
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
	if _head != null:
		var head := _head.global_transform
		_head.global_transform = Transform3D(turn * head.basis, head.origin)
		return
	# The bone: its turned rotation in the world, back into its parent's frame.
	var to_world := _skeleton.global_basis.orthonormalized()
	var parent := _skeleton.get_bone_parent(_bone)
	var parent_basis := to_world * (_skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis())
	var world := turn * to_world * _skeleton.get_bone_global_pose(_bone).basis.orthonormalized()
	_skeleton.set_bone_pose_rotation(_bone, (parent_basis.inverse() * world).get_rotation_quaternion())
