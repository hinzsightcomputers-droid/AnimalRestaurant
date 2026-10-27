# CameraZoomSettings: how close and from what angle a CameraRig zooms in on
# something (the stove, a dirty table, a customer you're talking to...).
# A Resource, so each station can have its own settings, tweakable in the Inspector.
class_name CameraZoomSettings
extends Resource

@export var distance := 3.6            # Meters from the camera to the point it looks at.
@export_range(10.0, 89.0) var pitch_degrees := 40.0  # How steeply it looks down (follow view is ~55).
@export_range(-90.0, 90.0) var yaw_degrees := 0.0    # Swing around to the side (0 = straight from the front).
@export var duration := 0.4            # Seconds to tween in (and back out).


# The camera's position relative to the point it looks at.
func offset() -> Vector3:
	var pitch := deg_to_rad(pitch_degrees)
	var yaw := deg_to_rad(yaw_degrees)
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
