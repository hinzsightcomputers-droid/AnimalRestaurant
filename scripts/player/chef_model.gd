# ChefModel: the chef's body: a KayKit Adventurers character (the Ranger, minus
# his quiver) animated with the KayKit Character Animations, which share its
# skeleton. It stands with its feet on this node, facing +z, and picks its own
# animation from how fast it's moving (idle, walk or run), so whatever moves it
# (a player, the intro's tweens) needn't tell it anything. Display only.
class_name ChefModel
extends Node3D

const CHARACTERS := "res://design/assets/KayKit_Adventurers_2.0_FREE/Characters/gltf/"
const ANIMATIONS := "res://design/animations/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/"
const ANIMATION_FILES := ["Rig_Medium_MovementBasic.glb", "Rig_Medium_General.glb"]
const NATIVE_HEIGHT := 2.27        # The characters' height as modeled.

@export var character := "Ranger"
@export var hidden_parts: Array[String] = ["Ranger_Quiver"]
@export var height := 1.5
@export_group("Animations")
@export var idle := "Idle_A"
@export var walk := "Walking_A"
@export var run := "Running_A"
@export var run_above := 2.4       # Meters a second: faster than this, run.
@export var walk_pace := 1.4       # How fast Walking_A looks right at normal speed...
@export var run_pace := 3.2        # ...and Running_A.

static var _library: AnimationLibrary = null  # Every animation, loaded once and shared.

var skeleton: Skeleton3D
var _model: Node3D
var _animations := AnimationPlayer.new()
var _last := Vector3.ZERO
var _speed := 0.0


func _ready() -> void:
	_model = load(CHARACTERS + character + ".glb").instantiate()
	_model.scale = Vector3.ONE * height / NATIVE_HEIGHT
	add_child(_model)
	skeleton = _model.find_child("Skeleton3D") as Skeleton3D
	for part in hidden_parts:
		var node := _model.find_child(part) as Node3D
		if node != null:
			node.visible = false
	_model.add_child(_animations)  # Its tracks are "Rig_Medium/Skeleton3D:<bone>", from the model's root.
	_animations.add_animation_library("", library())
	_animations.play(idle)
	_last = global_position


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var moved := global_position - _last
	_last = global_position
	var speed := Vector2(moved.x, moved.z).length() / delta
	_speed = lerpf(_speed, speed, 1.0 - exp(-12.0 * delta))  # Steady, so it doesn't flicker between steps.
	if _speed < 0.3:
		_play(idle, 1.0)
	elif _speed < run_above:
		_play(walk, clampf(_speed / walk_pace, 0.6, 1.6))
	else:
		_play(run, clampf(_speed / run_pace, 0.8, 1.5))


# Puts `node` on a bone so it moves with it; `at` is where it goes in the
# character's own (unscaled) space, in its rest pose.
func attach(bone: String, node: Node3D, at: Transform3D) -> void:
	var holder := BoneAttachment3D.new()
	holder.bone_name = bone
	skeleton.add_child(holder)
	holder.add_child(node)
	node.transform = skeleton.get_bone_global_rest(skeleton.find_bone(bone)).affine_inverse() * at


func _play(animation: String, speed_scale: float) -> void:
	_animations.speed_scale = speed_scale
	if _animations.current_animation != animation:
		_animations.play(animation, 0.2)


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
