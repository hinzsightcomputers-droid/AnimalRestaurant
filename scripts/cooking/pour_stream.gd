# PourStream: something pouring from a tip (a bottle's nozzle, a jug's spout) to
# where it lands: its head falls first, it thins and wavers, and when it stops
# its tail drops away after it. Call flow() every frame.
class_name PourStream
extends Node3D

const SHADER := preload("res://assets/shaders/stream.gdshader")
const FALL := 2.6          # How quickly the head (and the tail) falls, in drops a second at first...
const FALL_GROWS := 12.0   # ...getting faster.

var landed := false        # Reaching what it pours into.
var _head := 0.0
var _tail := 0.0
var _speed := 0.0
var _was_on := false
var _look := ShaderMaterial.new()
var _mesh := MeshInstance3D.new()


static func make(parent: Node3D, color: Color, thick := 0.006, gloss := 0.8, waver := 1.0) -> PourStream:
	var stream := PourStream.new()
	parent.add_child(stream)
	stream._look.shader = SHADER
	stream.set_color(color)
	stream.set_thick(thick)
	stream._look.set_shader_parameter("gloss", gloss)
	stream._look.set_shader_parameter("waver", waver)
	var tube := CylinderMesh.new()
	tube.top_radius = 1.0
	tube.bottom_radius = 1.0
	tube.height = 1.0
	tube.radial_segments = 14
	tube.rings = 22
	stream._mesh.mesh = tube
	stream._mesh.material_override = stream._look
	stream._mesh.custom_aabb = AABB(Vector3(-0.1, -0.6, -0.1), Vector3(0.2, 0.7, 0.2))
	stream.add_child(stream._mesh)
	stream.visible = false
	return stream


func set_color(color: Color) -> void:
	_look.set_shader_parameter("liquid", color)


func set_thick(thick: float) -> void:
	_look.set_shader_parameter("thick", thick)


# From `tip` down to `land` (it trails off if the tip's moved on), pouring or not.
func flow(tip: Vector3, land: Vector3, on: bool, delta: float) -> void:
	if on and not _was_on:
		_head = 0.0
		_tail = 0.0
		_speed = FALL
	elif not on and _was_on:
		_tail = 0.001
		_speed = FALL
	_was_on = on
	_speed += FALL_GROWS * delta
	_head = minf(_head + _speed * delta, 1.0)
	if not on:
		_tail = minf(_tail + _speed * delta, 1.0)
	visible = _head > 0.0 and _tail < 1.0 and (on or _tail > 0.0)
	landed = visible and _head >= 1.0
	if not visible:
		return
	position = Vector3(land.x, tip.y, land.z)
	_look.set_shader_parameter("sway", Vector2(tip.x - land.x, tip.z - land.z))
	_look.set_shader_parameter("drop", maxf(tip.y - land.y, 0.002))
	_look.set_shader_parameter("head", _head)
	_look.set_shader_parameter("tail", _tail)


# Gone at once when its step ends, or after its tail has dropped.
func finish(land: Vector3) -> void:
	if not visible:
		queue_free()
		return
	var tip := position
	var tween := create_tween()
	tween.tween_method(func(_t: float): flow(tip, Vector3(tip.x, land.y, tip.z), false, get_process_delta_time()), 0.0, 1.0, 0.5)
	tween.tween_callback(queue_free)
