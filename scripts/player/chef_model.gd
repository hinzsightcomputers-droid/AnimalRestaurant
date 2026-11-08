# ChefModel: the chef's body: the shared base body on KayKit's Rig_Medium
# skeleton, dressed from a CharacterAppearance by ChefBuilder (apply_appearance;
# the default chef until then), with a ChefFace, and animated with the KayKit
# Character Animations, which share that skeleton. It stands with its feet on this node, facing +z, and picks its own
# animation from how fast it's moving (idle, walk or run), so whatever moves it
# (a player, the intro's tweens) needn't tell it anything. While `carrying`,
# its arms come up in front of it to hold the plate or crate (a pose made here,
# laid over just the arms so the legs keep walking). Display only.
class_name ChefModel
extends Node3D

const ANIMATIONS := "res://design/animations/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/"
const ANIMATION_FILES := ["Rig_Medium_MovementBasic.glb", "Rig_Medium_General.glb"]
const NATIVE_HEIGHT := 2.27        # The characters' height as modeled.

@export var height := 1.5
@export_group("Animations")
@export var idle := "Idle_A"
@export var walk := "Walking_A"
@export var run := "Running_A"
@export var run_above := 2.4       # Meters a second: faster than this, run.
@export var walk_pace := 1.4       # How fast Walking_A looks right at normal speed...
@export var run_pace := 3.2        # ...and Running_A.
@export_group("Carrying")
## Where the arms point while carrying, in the character's own space (+z is
## forward, +x its left): the upper arms down and a little forward, the
## forearms out in front, hands slightly in. Mirrored for the right arm.
@export var carry_upper_arm := Vector3(0.12, -0.85, 0.4)
@export var carry_forearm := Vector3(-0.2, 0.15, 1.0)
@export var carry_fade := 0.15     # Seconds for the arms to come up or go down.

const ARM_BONES := ["upperarm", "lowerarm", "wrist", "hand", "handslot"]
const SKELETON_PATH := "Rig_Medium/Skeleton3D"

var carrying := false
var look: CharacterAppearance  # What they look like now (see apply_appearance).
var builder := ChefBuilder.new(self)
var face: ChefFace:
	get:
		return builder.face

static var _library: AnimationLibrary = null  # Every animation, loaded once and shared.

var skeleton: Skeleton3D
var _model: Node3D
var _animations := AnimationTree.new()
var _move := ""  # Requested on the first frame.
var _carry_amount := 0.0
var _last := Vector3.ZERO
var _speed := 0.0


func _ready() -> void:
	_model = load(String(ChefBuilder.base_data().get("scene", ""))).instantiate()
	add_child(_model)
	skeleton = _model.find_child("Skeleton3D") as Skeleton3D
	builder.build_base(_model)
	apply_appearance(look if look != null else CharacterAppearance.default_look())
	_model.add_child(_animations)  # Its tracks are "Rig_Medium/Skeleton3D:<bone>", from the model's root.
	_animations.root_node = NodePath("..")
	_animations.add_animation_library("", library())
	_animations.add_animation_library("chef", _carry_library())
	_animations.tree_root = _build_tree()
	_animations.active = true
	_last = global_position


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var moved := global_position - _last
	_last = global_position
	var speed := Vector2(moved.x, moved.z).length() / delta
	_speed = lerpf(_speed, speed, 1.0 - exp(-12.0 * delta))  # Steady, so it doesn't flicker between steps.
	if _speed < 0.3:
		_play("idle", 1.0)
	elif _speed < run_above:
		_play("walk", clampf(_speed / walk_pace, 0.6, 1.6))
	else:
		_play("run", clampf(_speed / run_pace, 0.8, 1.5))
	_carry_amount = move_toward(_carry_amount, 1.0 if carrying else 0.0, delta / carry_fade)
	_animations.set("parameters/carry/blend_amount", smoothstep(0.0, 1.0, _carry_amount))


# Dresses the chef as `new_look` (and sizes them by its body shape).
func apply_appearance(new_look: CharacterAppearance) -> void:
	look = new_look
	if _model == null:
		return  # Not ready yet: _ready() puts it on.
	var shape: Array = Wardrobe.body_shape(look.body_shape).get("scale", [1, 1, 1])
	_model.scale = Vector3(shape[0], shape[1], shape[2]) * height / NATIVE_HEIGHT
	builder.dress(look)


# Puts `node` on a bone so it moves with it; `at` is where it goes in the
# character's own (unscaled) space, in its rest pose.
func attach(bone: String, node: Node3D, at: Transform3D) -> void:
	var holder := BoneAttachment3D.new()
	holder.bone_name = bone
	skeleton.add_child(holder)
	holder.add_child(node)
	node.transform = skeleton.get_bone_global_rest(skeleton.find_bone(bone)).affine_inverse() * at


# "idle", "walk" or "run", at `speed_scale` times its normal pace.
func _play(move: String, speed_scale: float) -> void:
	_animations.set("parameters/pace/scale", speed_scale)
	if move != _move:
		_move = move
		_animations.set("parameters/move/transition_request", move)


# Idle / walk / run (cross-fading, at a pace), with the carry pose laid over
# just the arms by "carry"'s blend amount.
func _build_tree() -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	var move := AnimationNodeTransition.new()
	move.xfade_time = 0.2
	for state in [["idle", idle], ["walk", walk], ["run", run]]:
		var clip := AnimationNodeAnimation.new()
		clip.animation = state[1]
		tree.add_node(state[0], clip)
		move.add_input(state[0])
	tree.add_node("move", move)
	for i in 3:
		tree.connect_node("move", i, ["idle", "walk", "run"][i])
	tree.add_node("pace", AnimationNodeTimeScale.new())
	tree.connect_node("pace", 0, "move")
	var pose := AnimationNodeAnimation.new()
	pose.animation = "chef/Carry"
	tree.add_node("carry_pose", pose)
	var carry := AnimationNodeBlend2.new()
	carry.filter_enabled = true
	for side in [".l", ".r"]:
		for bone in ARM_BONES:
			carry.set_filter_path(NodePath(SKELETON_PATH + ":" + bone + side), true)
	tree.add_node("carry", carry)
	tree.connect_node("carry", 0, "pace")
	tree.connect_node("carry", 1, "carry_pose")
	tree.connect_node("output", 0, "carry")
	return tree


# The carry pose: each arm's upper arm and forearm turned from the rest pose
# (arms out to the sides) to point along carry_upper_arm and carry_forearm.
func _carry_library() -> AnimationLibrary:
	var animation := Animation.new()
	animation.length = 1.0
	animation.loop_mode = Animation.LOOP_LINEAR
	var chest := skeleton.get_bone_global_rest(skeleton.find_bone("chest")).basis
	for side in [1.0, -1.0]:
		var suffix := ".l" if side > 0.0 else ".r"
		var mirror := Vector3(side, 1.0, 1.0)
		var upper := skeleton.find_bone("upperarm" + suffix)
		var lower := skeleton.find_bone("lowerarm" + suffix)
		var upper_rest := skeleton.get_bone_global_rest(upper).basis
		var lower_rest := skeleton.get_bone_global_rest(lower).basis
		var upper_pose := Basis(Quaternion(upper_rest.y.normalized(), (carry_upper_arm * mirror).normalized())) * upper_rest
		var lower_pose := Basis(Quaternion(lower_rest.y.normalized(), (carry_forearm * mirror).normalized())) * lower_rest
		for bone in [[upper, chest.inverse() * upper_pose], [lower, upper_pose.inverse() * lower_pose]]:
			var track := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track, NodePath(SKELETON_PATH + ":" + skeleton.get_bone_name(bone[0])))
			animation.rotation_track_insert_key(track, 0.0, (bone[1] as Basis).get_rotation_quaternion())
	var carry_library := AnimationLibrary.new()
	carry_library.add_animation("Carry", animation)
	return carry_library


static func library() -> AnimationLibrary:
	if _library != null:
		return _library
	_library = AnimationLibrary.new()
	for file in ANIMATION_FILES:
		var scene: Node = load(ANIMATIONS + file).instantiate()
		var source := scene.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
		for animation_name in source.get_animation_list():
			if not _library.has_animation(animation_name):
				var animation := source.get_animation(animation_name)
				animation.loop_mode = Animation.LOOP_NONE if animation_name.begins_with("Jump") else Animation.LOOP_LINEAR
				_library.add_animation(animation_name, animation)
		scene.free()
	return _library
