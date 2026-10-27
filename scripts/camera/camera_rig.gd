# CameraRig: one player's camera. Camera behavior only; the PlayerView it lives
# in decides where on screen it is shown.
#
# Modes:
#   INTRO  - starts pulled out over the room, then glides in to FOLLOW.
#   FOLLOW - centers on its follow targets (normally just its own player; a shared
#            view gives it several) and pulls back as they spread apart.
#   FOCUS  - zooms in close on a point, e.g. the stove while cooking. Triggered by
#            the player's request_camera_focus() / release_camera_focus(), so
#            stations and conversations never talk to cameras directly.
#
# The rig (this Node3D) sits on the point being looked at; the Camera3D child
# sits at an offset from it, always at the same downward angle.
class_name CameraRig
extends Node3D

enum Mode { INTRO, FOLLOW, FOCUS }

@export var follow_offset := Vector3(0.0, 6.3, 4.5)    # Camera offset while following.
@export var intro_offset := Vector3(0.0, 14.0, 13.0)   # Camera offset at the start of the intro.
@export var intro_look_point := Vector3.ZERO           # What the intro looks at (room center).
@export var focus_offset := Vector3(0.0, 3.2, 2.3)     # Camera offset while zoomed in.
@export var intro_delay := 0.75
@export var intro_duration := 2.0
@export var smoothing := 6.0          # Higher = catches up faster.
@export var zoom_out_after := 2.0     # Targets can be this far from their center before we pull back.
@export var zoom_per_meter := 0.12    # How much further back per extra meter of spread.
@export var max_zoom := 1.8           # Never further than follow_offset * max_zoom.

var mode: Mode = Mode.INTRO
var player: Player = null                 # The player who owns this rig.
var follow_targets: Array[Node3D] = []    # Who FOLLOW keeps in view.
var focus_point := Vector3.ZERO           # What FOCUS looks at.
var intro_blend := 0.0                    # 0 = intro view, 1 = follow view. Tweened.

var _offset := Vector3.ZERO               # Current camera offset (smoothed).

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	# We move the rig ourselves every frame, so physics interpolation stays off.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	global_position = intro_look_point
	_offset = intro_offset
	_place_camera()

	var tween := create_tween()
	tween.tween_interval(intro_delay)
	tween.tween_property(self, "intro_blend", 1.0, intro_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_end_intro)


# Hook the rig up to its owner. Their focus requests drive FOCUS mode.
func set_player(owner_player: Player) -> void:
	player = owner_player
	follow_targets = [owner_player]
	player.camera_focus_requested.connect(focus_on)
	player.camera_focus_released.connect(release_focus)


func set_follow_targets(targets: Array[Node3D]) -> void:
	follow_targets = targets


# Zoom in on `point`. Ignored while the rig is showing several players at once
# (zooming a shared view would hide everyone else).
func focus_on(point: Vector3) -> void:
	focus_point = point
	if follow_targets.size() <= 1:
		mode = Mode.FOCUS


func _end_intro() -> void:
	if mode == Mode.INTRO:
		mode = Mode.FOLLOW


func release_focus() -> void:
	if mode == Mode.FOCUS:
		mode = Mode.FOLLOW


func _process(delta: float) -> void:
	var goal_point := global_position
	var goal_offset := _offset
	match mode:
		Mode.INTRO:
			# The tween already eases the intro, so no extra smoothing here.
			var intro_goal := _follow_goal()
			global_position = intro_look_point.lerp(intro_goal[0], intro_blend)
			_offset = intro_offset.lerp(intro_goal[1], intro_blend)
			_place_camera()
			return
		Mode.FOLLOW:
			var follow := _follow_goal()
			goal_point = follow[0]
			goal_offset = follow[1]
		Mode.FOCUS:
			goal_point = focus_point
			goal_offset = focus_offset

	var weight := 1.0 - exp(-smoothing * delta)
	global_position = global_position.lerp(goal_point, weight)
	_offset = _offset.lerp(goal_offset, weight)
	_place_camera()


# [center of the follow targets, camera offset pulled back to fit them].
func _follow_goal() -> Array:
	var targets := follow_targets.filter(func(t): return is_instance_valid(t))
	if targets.is_empty():
		return [global_position, follow_offset]

	# Interpolated positions keep following smooth on high refresh rate screens.
	var center := Vector3.ZERO
	for target in targets:
		center += target.get_global_transform_interpolated().origin
	center /= targets.size()
	var spread := 0.0
	for target in targets:
		var offset: Vector3 = target.get_global_transform_interpolated().origin - center
		spread = maxf(spread, Vector2(offset.x, offset.z).length())

	var zoom := clampf(1.0 + maxf(spread - zoom_out_after, 0.0) * zoom_per_meter, 1.0, max_zoom)
	return [center, follow_offset * zoom]


func _place_camera() -> void:
	camera.global_position = global_position + _offset
	camera.look_at(global_position, Vector3.UP)
