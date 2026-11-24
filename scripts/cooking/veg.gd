# Veg: the vegetables on the chopping board (PeelAction, ChopAction): how each
# looks, whole and chopped, lying along x (0 at its middle): an onion's tip and a
# carrot's green top to the left.
class_name Veg
extends RefCounted

const SKIN := {
	"onion": Color("#D9973F"),   # Golden and papery.
	"potato": Color("#A8713C"),
	"celery": Color("#A6CC5A"),
}
const FLESH := {
	"onion": Color("#F6F0D8"),
	"potato": Color("#F2DF9A"),
	"celery": Color("#B4D66C"),
}
const ONION_LAYER := Color("#DDE3B4")  # The line between two layers.
const ONION_ROOT := Color("#C9AE7C")


# How far out it goes at `t` along it (0 left end, 1 right).
static func radius_at(kind: String, t: float, radius: float, taper: float) -> float:
	var u := absf(t * 2.0 - 1.0)
	match kind:
		"onion":  # A ball, drawn out a little at the tip.
			return maxf(radius * sqrt(maxf(1.0 - pow(u, 2.0 if t > 0.5 else 1.7), 0.0)), radius * 0.1)
		"potato":  # Long and blunt, a little fatter at one end.
			return maxf(radius * pow(maxf(1.0 - pow(u, 2.5), 0.0), 0.45) * (1.0 - 0.12 * t), radius * 0.06)
	return radius * (1.0 - taper * t)


# A whole round one (an onion, a potato) on `parent`.
static func add_whole(parent: Node3D, kind: String, length: float, radius: float, taper: float, color: Color) -> void:
	var body := MeshInstance3D.new()
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.roughness = 0.55
	body.mesh = turned(length, func(x): return radius_at(kind, x / length + 0.5, radius, taper), paint)
	parent.add_child(body)
	if kind == "onion":
		add_tip(parent, -length * 0.5)
		add_root(parent, length * 0.5)


# One chopped bit of it, about `radius` across, lying flat.
static func chopped_mesh(kind: String, radius: float) -> Mesh:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = FLESH[kind]
	paint.roughness = 0.5
	match kind:
		"onion":  # A ring.
			var ring := TorusMesh.new()
			ring.outer_radius = radius * randf_range(1.0, 1.3)
			ring.inner_radius = ring.outer_radius * 0.6
			ring.rings = 18
			ring.ring_segments = 8
			ring.material = paint
			return ring
		"celery":  # A little crescent, on its side.
			return stalk(0.012, radius * 0.95, radius * 0.95, FLESH[kind], true)
	var cube := BoxMesh.new()
	cube.size = Vector3(1.5, 0.8, 1.35) * radius * randf_range(0.85, 1.05)
	cube.material = paint
	return cube


# An onion's dry, papery neck at local x.
static func add_tip(parent: Node3D, x: float) -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = (SKIN["onion"] as Color).darkened(0.15)
	paint.roughness = 0.9
	for i in 3:
		var wisp := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0015
		mesh.bottom_radius = 0.005
		mesh.height = 0.024
		mesh.radial_segments = 8
		mesh.material = paint
		wisp.mesh = mesh
		wisp.rotation = Vector3(0.0, (i - 1) * 0.35, PI * 0.5)
		wisp.position = Vector3(x - 0.008, 0.0, (i - 1) * 0.004)
		parent.add_child(wisp)


# An onion's tuft of roots at local x.
static func add_root(parent: Node3D, x: float) -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = ONION_ROOT
	paint.roughness = 0.9
	for i in 6:
		var hair := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0008
		mesh.bottom_radius = 0.0016
		mesh.height = 0.016
		mesh.radial_segments = 6
		mesh.material = paint
		hair.mesh = mesh
		var out := Vector2.from_angle(TAU * i / 6.0)
		hair.rotation = Vector3(0.0, out.y * 0.5, -PI * 0.5 + out.x * 0.5)
		hair.position = Vector3(x + 0.004, out.x * 0.004, out.y * 0.004)
		parent.add_child(hair)


static func onion_paint(line: bool) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = ONION_LAYER if line else (FLESH["onion"] as Color).lightened(0.3)
	paint.roughness = 0.35
	return paint


# A round solid `length` long along x, as far out at each x as `radius_of` says.
static func turned(length: float, radius_of: Callable, material: Material) -> ArrayMesh:
	const RINGS := 14
	const SPOKES := 24
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	for ring in RINGS:
		var xs := [length * (float(ring) / RINGS - 0.5), length * (float(ring + 1) / RINGS - 0.5)]
		for spoke in SPOKES:
			var a0 := TAU * spoke / SPOKES
			var a1 := TAU * (spoke + 1) / SPOKES
			for corner in [[0, a0], [1, a0], [1, a1], [0, a0], [1, a1], [0, a1]]:
				var x: float = xs[corner[0]]
				var r: float = radius_of.call(x)
				var slope: float = (radius_of.call(x + 0.001) - radius_of.call(x - 0.001)) / 0.002
				tool.set_normal(Vector3(-slope, cos(corner[1]), sin(corner[1])).normalized())
				tool.add_vertex(Vector3(x, cos(corner[1]) * r, sin(corner[1]) * r))
	for end: float in [-0.5, 0.5]:  # Both ends, flat.
		var x := length * end
		var r: float = radius_of.call(x)
		for spoke in SPOKES:
			var a0 := TAU * spoke / SPOKES
			var a1 := TAU * (spoke + 1) / SPOKES
			var first := a1 if end < 0.0 else a0
			var second := a0 if end < 0.0 else a1
			for point in [Vector3(x, 0.0, 0.0), Vector3(x, cos(second) * r, sin(second) * r), Vector3(x, cos(first) * r, sin(first) * r)]:
				tool.set_normal(Vector3(signf(end), 0.0, 0.0))
				tool.add_vertex(point)
	return tool.commit()


# A stick of celery `length` long: a ribbed trough, open at the top, its cut ends
# paler (or standing on end, for a chopped bit: a crescent).
static func stalk(length: float, left_radius: float, right_radius: float, color: Color, on_end := false) -> ArrayMesh:
	const STEPS := 26
	const OPEN := 1.95                # How far round each way from the bottom it goes.
	const THICK := 0.42
	var turn := Basis(Vector3.BACK, PI * 0.5) if on_end else Basis.IDENTITY
	var tools: Array[SurfaceTool] = []
	for shade in [color, color.lightened(0.15), color.lightened(0.15)]:  # Outside, inside, cut ends.
		var paint := StandardMaterial3D.new()
		paint.albedo_color = shade
		paint.roughness = 0.5
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_material(paint)
		tools.append(tool)
	var at := func(end: int, step: int, inner: bool) -> Vector3:
		var angle := lerpf(-OPEN, OPEN, float(step) / STEPS)
		var r := left_radius if end == 0 else right_radius
		var out := r * (1.0 - THICK) if inner else r * (1.0 + 0.05 * cos(angle * 9.0))
		return turn * Vector3((end - 0.5) * length, -cos(angle) * out, sin(angle) * out)
	var quad := func(part: int, points: Array, normal: Vector3) -> void:
		var flipped: bool = (points[1] - points[0]).cross(points[2] - points[0]).dot(normal) > 0.0  # Godot's faces wind clockwise.
		for index in ([0, 2, 1, 0, 3, 2] if flipped else [0, 1, 2, 0, 2, 3]):
			tools[part].set_normal(normal)
			tools[part].add_vertex(points[index])
	for step in STEPS:
		var angle := lerpf(-OPEN, OPEN, (step + 0.5) / STEPS)
		var outward := turn * Vector3(0.0, -cos(angle), sin(angle))
		quad.call(0, [at.call(0, step, false), at.call(1, step, false), at.call(1, step + 1, false), at.call(0, step + 1, false)], outward)
		quad.call(1, [at.call(0, step, true), at.call(1, step, true), at.call(1, step + 1, true), at.call(0, step + 1, true)], -outward)
		for end in 2:
			quad.call(2, [at.call(end, step, false), at.call(end, step + 1, false), at.call(end, step + 1, true), at.call(end, step, true)], turn * Vector3(end * 2.0 - 1.0, 0.0, 0.0))
	for step in [0, STEPS]:
		quad.call(1, [at.call(0, step, false), at.call(1, step, false), at.call(1, step, true), at.call(0, step, true)], turn * Vector3.UP)
	var mesh := ArrayMesh.new()
	for tool in tools:
		tool.commit(mesh)
	return mesh
