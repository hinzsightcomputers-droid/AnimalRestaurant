# MicrowaveModel: a placeholder microwave built from boxes (the asset packs
# don't have one): a body, a door with a window on the left that swings open
# on its hinge, a keypad, and a turntable inside that turns while it runs, with
# a light on. Its origin is the middle of its bottom, its door facing +z.
# MicrowaveAction opens, runs and dings it.
class_name MicrowaveModel
extends Node3D

const SIZE := Vector3(0.5, 0.3, 0.36)
const WALL := 0.02

var _door := Node3D.new()                  # The hinge, at the door's left edge.
var _turntable := MeshInstance3D.new()
var _light := OmniLight3D.new()
var _window_material := StandardMaterial3D.new()
var _running := false


func _ready() -> void:
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color(0.92, 0.92, 0.9)
	shell.roughness = 0.4
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.18, 0.18, 0.2)
	var cavity_width := SIZE.x * 0.72
	# The shell: back, top, bottom, two sides, and the keypad panel on the right.
	_box(Vector3(SIZE.x, SIZE.y, WALL), Vector3(0.0, SIZE.y * 0.5, -SIZE.z * 0.5 + WALL * 0.5), shell)
	_box(Vector3(SIZE.x, WALL, SIZE.z), Vector3(0.0, SIZE.y - WALL * 0.5, 0.0), shell)
	_box(Vector3(SIZE.x, WALL, SIZE.z), Vector3(0.0, WALL * 0.5, 0.0), shell)
	_box(Vector3(WALL, SIZE.y, SIZE.z), Vector3(-SIZE.x * 0.5 + WALL * 0.5, SIZE.y * 0.5, 0.0), shell)
	_box(Vector3(SIZE.x - cavity_width - WALL, SIZE.y, SIZE.z), Vector3(SIZE.x * 0.5 - (SIZE.x - cavity_width - WALL) * 0.5, SIZE.y * 0.5, 0.0), shell)
	var pad := _box(Vector3(0.07, 0.16, 0.005), Vector3(SIZE.x * 0.5 - (SIZE.x - cavity_width) * 0.5, SIZE.y * 0.5, SIZE.z * 0.5 + 0.003), dark)
	pad.name = "Keypad"
	# Inside: dark walls and the glass turntable.
	_box(Vector3(cavity_width - WALL, SIZE.y - WALL * 2.0, 0.004), Vector3(-SIZE.x * 0.5 + WALL + cavity_width * 0.5 - WALL * 0.5, SIZE.y * 0.5, -SIZE.z * 0.5 + WALL + 0.003), dark)
	var plate := CylinderMesh.new()
	plate.top_radius = cavity_width * 0.4
	plate.bottom_radius = cavity_width * 0.4
	plate.height = 0.006
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.92, 0.95, 0.7)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plate.material = glass
	_turntable.mesh = plate
	_turntable.position = Vector3(_cavity_x(), WALL + 0.01, 0.0)
	add_child(_turntable)
	_light.light_color = Color(1.0, 0.9, 0.6)
	_light.light_energy = 0.0
	_light.omni_range = 0.4
	_light.position = Vector3(_cavity_x(), SIZE.y * 0.7, 0.0)
	add_child(_light)
	# The door: a frame with a window, hinged on its left edge.
	_door.position = Vector3(-SIZE.x * 0.5, 0.0, SIZE.z * 0.5)
	add_child(_door)
	var frame := StandardMaterial3D.new()
	frame.albedo_color = Color(0.85, 0.85, 0.83)
	var door_width := cavity_width + WALL
	_box(Vector3(door_width, 0.05, 0.02), Vector3(door_width * 0.5, SIZE.y - 0.025, 0.01), frame, _door)
	_box(Vector3(door_width, 0.05, 0.02), Vector3(door_width * 0.5, 0.025, 0.01), frame, _door)
	_box(Vector3(0.05, SIZE.y, 0.02), Vector3(0.025, SIZE.y * 0.5, 0.01), frame, _door)
	_box(Vector3(0.05, SIZE.y, 0.02), Vector3(door_width - 0.025, SIZE.y * 0.5, 0.01), frame, _door)
	_window_material.albedo_color = Color(0.12, 0.14, 0.16, 0.55)
	_window_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_window_material.roughness = 0.1
	_box(Vector3(door_width - 0.1, SIZE.y - 0.1, 0.006), Vector3(door_width * 0.5, SIZE.y * 0.5, 0.01), _window_material, _door)
	var handle := _box(Vector3(0.015, 0.14, 0.02), Vector3(door_width - 0.04, SIZE.y * 0.5, 0.03), dark, _door)
	handle.name = "Handle"


func _process(delta: float) -> void:
	if _running:
		_turntable.rotate_y(delta * 1.6)


func set_open(open: bool, seconds := 0.25) -> void:
	create_tween().tween_property(_door, "rotation:y", -deg_to_rad(100.0) if open else 0.0, seconds).set_trans(Tween.TRANS_SINE)


func set_running(running: bool) -> void:
	_running = running
	create_tween().tween_property(_light, "light_energy", 1.2 if running else 0.0, 0.2)
	_window_material.albedo_color = Color(1.0, 0.85, 0.5, 0.35) if running else Color(0.12, 0.14, 0.16, 0.55)


# The top of the turntable's middle (global).
func inside_point() -> Vector3:
	return to_global(_turntable.position + Vector3(0.0, 0.004, 0.0))


# The middle of the door's front (global).
func front_point() -> Vector3:
	return to_global(Vector3(_cavity_x(), SIZE.y * 0.5, SIZE.z * 0.5))


func _cavity_x() -> float:
	return -SIZE.x * 0.5 + WALL + SIZE.x * 0.72 * 0.5 - WALL * 0.5


func _box(size: Vector3, at: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	box.mesh = mesh
	box.position = at
	parent.add_child(box)
	return box
