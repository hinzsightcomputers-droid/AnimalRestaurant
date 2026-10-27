# CameraRig: one player's camera. Camera behavior only; the PlayerView it lives
# in decides where on screen it is shown.
#
# Modes:
#   INTRO  - starts pulled out over the room, then glides in to FOLLOW.
#   FOLLOW - centers on its follow targets (normally just its own player; a shared
#            view gives it several) and pulls back as they spread apart.
#   FOCUS  - zoom-in state: tweens close to a target position using a
#            CameraZoomSettings (distance, angle, duration). Triggered by the
#            player's request_camera_focus() / release_camera_focus(), so stations
#            and conversations never talk to cameras directly.
#
# The rig (this Node3D) sits on the point being looked at; the Camera3D child
# sits at an offset from it. Every change of mode is a tween from where the
# camera is now to where the new mode wants it.
class_name CameraRig
extends Node3D

enum Mode { INTRO, FOLLOW, FOCUS }

@export var follow_offset := Vector3(0.0, 6.3, 4.5)    # Camera offset while following.
@export var intro_offset := Vector3(0.0, 14.0, 13.0)   # Camera offset at the start of the intro.
@export var intro_look_point := Vector3.ZERO           # What the intro looks at (room center).
@export var intro_delay := 0.75
@export var intro_duration := 2.0
@export var default_zoom: CameraZoomSettings           # Used when a zoom request has no settings.
@export var smoothing := 6.0          # Higher = following catches up faster.
@export var zoom_out_after := 2.0     # Targets can be this far from their center before we pull back.
@export var zoom_per_meter := 0.12    # How much further back per extra meter of spread.
@export var max_zoom := 1.8           # Never further than follow_offset * max_zoom.

var mode: Mode = Mode.INTRO
var player: Player = null                 # The player who owns this rig.
var follow_targets: Array[Node3D] = []    # Who FOLLOW keeps in view.
var focus_point := Vector3.ZERO           # What FOCUS looks at.
var zoom: CameraZoomSettings = null       # Settings of the current (or last) zoom-in.

var _offset := Vector3.ZERO               # Current camera offset from the rig.
var _blend := 1.0                         # 0 -> 1 while tweening into the current mode.
var _from_point := Vector3.ZERO           # Where the tween started.
var _from_offset := Vector3.ZERO
var _tween: Tween = null

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	# We move the rig ourselves every frame, so physics interpolation stays off.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if default_zoom == null:
		default_zoom = CameraZoomSettings.new()
	global_position = intro_look_point
	_offset = intro_offset
	_place_camera()
	_change_mode(Mode.FOLLOW, intro_duration, intro_delay)
	mode = Mode.INTRO  # Shown as INTRO until the glide in finishes.


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
func focus_on(point: Vector3, settings: CameraZoomSettings = null) -> void:
	if follow_targets.size() > 1:
		return
	focus_point = point
	zoom = settings if settings != null else default_zoom
	_change_mode(Mode.FOCUS, zoom.duration)


# Back to following, taking as long as the zoom-in did.
func release_focus() -> void:
	if mode == Mode.FOCUS:
		_change_mode(Mode.FOLLOW, zoom.duration)


func _process(delta: float) -> void:
	var goal := _goal()  # [point, offset]
	if _blend < 1.0:
		# Mid-tween: the tween eases _blend, so no extra smoothing.
		global_position = _from_point.lerp(goal[0], _blend)
		_offset = _from_offset.lerp(goal[1], _blend)
	elif mode == Mode.FOLLOW:
		var weight := 1.0 - exp(-smoothing * delta)
		global_position = global_position.lerp(goal[0], weight)
		_offset = _offset.lerp(goal[1], weight)
	else:
		global_position = goal[0]
		_offset = goal[1]
	_place_camera()


# Start tweening from the current view to `new_mode`'s view.
func _change_mode(new_mode: Mode, duration: float, delay := 0.0) -> void:
	mode = new_mode
	_from_point = global_position
	_from_offset = _offset
	_blend = 0.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	if delay > 0.0:
		_tween.tween_interval(delay)
	_tween.tween_property(self, "_blend", 1.0, maxf(duration, 0.01)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func(): mode = new_mode)


# Where the current mode wants the camera: [point to look at, camera offset].
func _goal() -> Array:
	if mode == Mode.FOCUS:
		return [focus_point, zoom.offset()]
	return _follow_goal()


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

	var pull_back := clampf(1.0 + maxf(spread - zoom_out_after, 0.0) * zoom_per_meter, 1.0, max_zoom)
	return [center, follow_offset * pull_back]


func _place_camera() -> void:
	camera.global_position = global_position + _offset
	camera.look_at(global_position, Vector3.UP)
