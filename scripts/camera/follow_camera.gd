# FollowCamera: angled third-person camera, Animal Crossing style.
# Starts pulled out showing the whole room, then glides in and follows the target.
# The viewing angle never changes; the camera only slides along with the target.
class_name FollowCamera
extends Camera3D

@export var target: Node3D
@export var follow_offset := Vector3(0.0, 7.0, 7.5)    # Camera position relative to the target while following.
@export var intro_offset := Vector3(0.0, 14.0, 13.0)   # Camera position relative to intro_look_point at the start.
@export var intro_look_point := Vector3.ZERO           # What we look at during the intro (room center).
@export var intro_delay := 0.75
@export var intro_duration := 2.0
@export var follow_smoothing := 6.0  # Higher = camera catches up faster.

# 0 = fully pulled out (intro), 1 = following the target. Animated by a tween.
var intro_blend := 0.0
var _focus := Vector3.ZERO


func _ready() -> void:
	# We move the camera ourselves in _process, so turn off physics interpolation for it.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_focus = intro_look_point
	_place_camera()

	var tween := create_tween()
	tween.tween_interval(intro_delay)
	tween.tween_property(self, "intro_blend", 1.0, intro_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	if target == null:
		return

	# Use the interpolated position so following stays smooth on high refresh rate screens.
	var target_position := target.get_global_transform_interpolated().origin
	var goal_focus := intro_look_point.lerp(target_position, intro_blend)

	if intro_blend < 1.0:
		_focus = goal_focus  # The tween already eases the intro.
	else:
		_focus = _focus.lerp(goal_focus, 1.0 - exp(-follow_smoothing * delta))

	_place_camera()


func _place_camera() -> void:
	global_position = _focus + intro_offset.lerp(follow_offset, intro_blend)
	look_at(_focus, Vector3.UP)
