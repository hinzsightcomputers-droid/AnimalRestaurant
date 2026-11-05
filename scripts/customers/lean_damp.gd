# LeanDamp: holds a rigged model's back straighter than its animation says, while
# `active`. Sit and stand clips are made for people, who lean well forward; on a
# big-headed toy that's a face on the table. The legs still do what the clip says;
# the hips, back and head keep only `keep` of it. Eases in and out. Added to a model
# with LeanDamp.attach(model, keep); does nothing for a model without the bones.
class_name LeanDamp
extends Node

const BONES := ["mixamorig_Hips", "mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2", "mixamorig_Neck", "mixamorig_Head"]
const EASE_SPEED := 6.0  # How quickly it comes on and goes off.

var active := false

var _skeleton: Skeleton3D
var _bones: Array[int] = []
var _keep := 1.0
var _amount := 0.0  # 0 = the clip as it is, 1 = fully held back.


static func attach(model: Node3D, keep: float) -> LeanDamp:
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if skeletons.is_empty() or players.is_empty():
		return null
	var damp := LeanDamp.new()
	damp.name = "LeanDamp"
	damp._skeleton = skeletons[0]
	damp._keep = keep
	for bone_name in BONES:
		var bone: int = damp._skeleton.find_bone(bone_name)
		if bone >= 0:
			damp._bones.append(bone)
	(players[0] as AnimationMixer).mixer_applied.connect(damp._apply)
	model.add_child(damp)
	return damp


func _process(delta: float) -> void:
	_amount = move_toward(_amount, 1.0 if active else 0.0, EASE_SPEED * delta)


func _apply() -> void:
	if _amount <= 0.0:
		return
	var weight := lerpf(1.0, _keep, _amount)
	for bone in _bones:
		var rest := _skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		_skeleton.set_bone_pose_rotation(bone, rest.slerp(_skeleton.get_bone_pose_rotation(bone), weight))
