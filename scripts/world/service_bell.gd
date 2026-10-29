# ServiceBell: the little brass bell on the order counter. Once a meal's last
# customer has gone, it bobs to say it wants ringing (see DayManager.bell_ready),
# and ringing it (at the counter, see CustomerManager) starts the next meal.
# Built from simple shapes; the ding is the same chime as Mabel's door bell.
class_name ServiceBell
extends Node3D

const BOB_HEIGHT := 0.025

var wants_ringing := false  # Set by the DayManager while the bell is ready.

var _dome := Node3D.new()
var _ding := AudioStreamPlayer3D.new()
var _time := 0.0
var _ring_time := -1.0  # Seconds since it was rung (-1 = still).


func _ready() -> void:
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.85, 0.66, 0.28)
	brass.metallic = 0.7
	brass.roughness = 0.3
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.2, 0.17, 0.15)

	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.075
	base_mesh.bottom_radius = 0.08
	base_mesh.height = 0.02
	base_mesh.material = dark
	base.mesh = base_mesh
	base.position.y = 0.01
	add_child(base)

	_dome.position.y = 0.02
	add_child(_dome)
	var dome := MeshInstance3D.new()
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 0.06
	dome_mesh.height = 0.06
	dome_mesh.is_hemisphere = true
	dome_mesh.material = brass
	dome.mesh = dome_mesh
	_dome.add_child(dome)
	var knob := MeshInstance3D.new()
	var knob_mesh := SphereMesh.new()
	knob_mesh.radius = 0.012
	knob_mesh.height = 0.024
	knob_mesh.material = brass
	knob.mesh = knob_mesh
	knob.position.y = 0.065
	_dome.add_child(knob)

	_ding.stream = RewardDecorations.chime_stream()
	_ding.unit_size = 10.0
	_ding.pitch_scale = 1.25  # A touch higher than the door bell.
	add_child(_ding)


func _process(delta: float) -> void:
	_time += delta
	var bob := absf(sin(_time * 4.0)) * BOB_HEIGHT if wants_ringing and _ring_time < 0.0 else 0.0
	_dome.position.y = 0.02 + bob
	if _ring_time >= 0.0:
		_ring_time += delta
		_dome.scale = Vector3.ONE * (1.0 + 0.15 * exp(-_ring_time * 8.0) * sin(_ring_time * 40.0))
		if _ring_time > 0.6:
			_ring_time = -1.0
			_dome.scale = Vector3.ONE


func ring() -> void:
	_ring_time = 0.0
	_ding.play()
