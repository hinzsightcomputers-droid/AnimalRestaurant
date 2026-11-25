# PotLiquid: the liquid in a pot or a bowl (CookSurface.liquid, and a soup pot's
# surface), drawn by pot_liquid.gdshader and moved by springs: it rocks when it's
# knocked, rings out from what lands in it, and dips and swirls as it's stirred.
# What floats in it (float_thing) rides on it, tips with it and goes round with it.
class_name PotLiquid
extends MeshInstance3D

const SHADER := preload("res://assets/shaders/pot_liquid.gdshader")
const ROCK := 130.0        # How stiffly it comes back level (heavier pots, slower)...
const ROCK_CALM := 3.2     # ...and how quickly it settles.
const BOB := 150.0
const BOB_CALM := 3.6
const RINGS := 4

static var _net: ArrayMesh = null

var color := Color.WHITE
var reach := 0.12
var spin := 0.0            # Going round (radians a second).
var dragging := false      # A whisk's in it this moment: the spin's its own.
var look := ShaderMaterial.new()
var _tilt := Vector2.ZERO
var _tilt_speed := Vector2.ZERO
var _saddle := Vector2.ZERO
var _saddle_speed := Vector2.ZERO
var _heave := 0.0
var _heave_speed := 0.0
var _dip := 0.0
var _turn := 0.0
var _twist := 0.0
var _drops: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]
var _next := 0
var _boil := 0.0
var _boil_to := 0.0
var _floats := {}          # Node -> [velocity up and down, how far it's sunk, its own phase].
var _time := randf() * 10.0


static func make(new_reach: float, new_color: Color) -> PotLiquid:
	var liquid := PotLiquid.new()
	liquid.reach = new_reach
	if _net == null:
		_net = _make_net()
	liquid.mesh = _net
	liquid.look.shader = SHADER
	liquid.look.set_shader_parameter("radius", new_reach)
	liquid.material_override = liquid.look
	liquid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	liquid.set_color(new_color)
	return liquid


func set_color(new_color: Color) -> void:
	color = new_color
	look.set_shader_parameter("soup", Color(new_color, 1.0))


# clear, thick, oil, foam, glossy: how it looks (the shader's numbers).
func dress(what: Dictionary) -> void:
	for key: String in what:
		look.set_shader_parameter(key, what[key])


func set_boil(to: float) -> void:
	_boil_to = to


# Something lands at a point (its own x and z, in meters), so hard (m of wave).
func splash(point: Vector2, hard := 0.004) -> void:
	_drops[_next] = Vector4(point.x / reach, point.y / reach, 0.0, hard)
	_next = (_next + 1) % RINGS
	_heave_speed += hard * 4.0
	_tilt_speed += point / reach * hard * 7.0


# Knocked: the pot moved, or a ladle went in.
func knock(way: Vector2) -> void:
	_tilt_speed += way
	_saddle_speed += Vector2(way.y, way.x) * 0.4


# Something floating in it from now on (it has to be a child of this, or of the
# surface it's in). sink: how far under it sits.
func float_thing(thing: Node3D, sink := 0.0) -> void:
	_floats[thing] = [0.0, sink, randf() * TAU]


func sink_thing(thing: Node3D) -> void:
	_floats.erase(thing)


func carries(thing: Node3D) -> bool:
	return _floats.has(thing)


# How high it is at a point (its own x and z in meters).
func height(point: Vector2) -> float:
	var p := point / reach
	var r2 := p.length_squared()
	var y := _tilt.dot(p) * (1.5 - 0.5 * r2) + _heave * (1.0 - 2.0 * r2) + _saddle.x * (p.x * p.x - p.y * p.y) + _saddle.y * 2.0 * p.x * p.y
	y -= _dip * (exp(-r2 * 4.0) - 0.45)
	for drop in _drops:
		if drop.w > 0.0 and drop.z < 1.2:
			var d := p.distance_to(Vector2(drop.x, drop.y))
			var front := drop.z * 1.5
			y += drop.w * sin((d - front) * 24.0) * exp(-pow((d - front) * 5.0, 2.0)) * exp(-drop.z * 2.6)
	return y


func _process(delta: float) -> void:
	var step := minf(delta, 1.0 / 30.0)
	_time += step
	_tilt_speed += (-_tilt * ROCK - _tilt_speed * ROCK_CALM) * step
	_tilt += _tilt_speed * step
	_saddle_speed += (-_saddle * ROCK * 1.5 - _saddle_speed * ROCK_CALM * 1.3) * step
	_saddle += _saddle_speed * step
	_heave_speed += (-_heave * BOB - _heave_speed * BOB_CALM) * step
	_heave += _heave_speed * step
	var most := reach * 0.07  # It never leaves the pot, or shows its floor.
	_tilt = _tilt.limit_length(most)
	_heave = clampf(_heave, -most * 0.5, most * 0.5)
	if not dragging:
		spin *= exp(-0.8 * step)
	dragging = false
	_turn += spin * step
	_twist = lerpf(_twist, clampf(spin * 0.35, -3.0, 3.0), 1.0 - exp(-1.2 * step))
	_dip = lerpf(_dip, minf(spin * spin * reach * reach * 0.03, reach * 0.06), 1.0 - exp(-3.0 * step))
	_boil = lerpf(_boil, _boil_to, 1.0 - exp(-1.5 * step))
	for i in RINGS:
		_drops[i].z += step
	for pair in [["tilt", _tilt], ["saddle", _saddle], ["heave", _heave], ["dip", _dip], ["turn", _turn], ["twist", _twist], ["boil", _boil], ["drop_a", _drops[0]], ["drop_b", _drops[1]], ["drop_c", _drops[2]], ["drop_d", _drops[3]]]:
		look.set_shader_parameter(pair[0], pair[1])
	_carry(step)


# What floats in it: rides up and down, tips along the slope, goes round, and
# keeps off the sides.
func _carry(step: float) -> void:
	for thing in _floats.keys():
		if not is_instance_valid(thing) or not thing.is_inside_tree():
			_floats.erase(thing)
			continue
		var node := thing as Node3D
		var state: Array = _floats[thing]
		var here := to_local(node.global_position)
		var flat := Vector2(here.x, here.z)
		flat = flat.rotated(spin * step * lerpf(1.0, 0.75, flat.length() / reach))
		if _boil > 0.3:  # Tossed about on a boil.
			flat += Vector2.from_angle(_time * 1.3 + state[2] * 3.0) * _boil * 0.006 * step
		flat = flat.limit_length(reach * 0.86)
		var rest := height(flat) - float(state[1]) + sin(_time * (2.2 + _boil * 4.0) + state[2]) * (0.0012 + 0.0035 * _boil)
		state[0] += ((rest - here.y) * 190.0 - float(state[0]) * 8.0) * step
		here = Vector3(flat.x, here.y + float(state[0]) * step, flat.y)
		node.global_position = to_global(here)
		node.rotate_y(-spin * step)
		var e := reach * 0.08
		var slope := Vector2(height(flat + Vector2(e, 0.0)) - height(flat - Vector2(e, 0.0)), height(flat + Vector2(0.0, e)) - height(flat - Vector2(0.0, e))) / (2.0 * e)
		var lean := Vector3(slope.y, 0.0, -slope.x) + Vector3(sin(_time * 1.7 + state[2]), 0.0, cos(_time * 1.4 + state[2])) * (0.09 + _boil * 0.2)
		node.rotation.x = lerp_angle(node.rotation.x, lean.x, 1.0 - exp(-5.0 * step))
		node.rotation.z = lerp_angle(node.rotation.z, lean.z, 1.0 - exp(-5.0 * step))


# A round net, 1 in radius, finer toward the middle.
static func _make_net() -> ArrayMesh:
	const ROUND := 56
	const DEEP := 26
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for ring in DEEP + 1:
		for i in ROUND + 1:
			var angle := TAU * i / ROUND
			points.append(Vector3(cos(angle), 0.0, sin(angle)) * ring / DEEP)
			normals.append(Vector3.UP)
	for ring in DEEP:
		for i in ROUND:
			var a := ring * (ROUND + 1) + i
			var b := a + ROUND + 1
			indices.append_array([a, b, a + 1, a + 1, b, b + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-0.2, -0.05, -0.2), Vector3(0.4, 0.1, 0.4))
	return mesh
