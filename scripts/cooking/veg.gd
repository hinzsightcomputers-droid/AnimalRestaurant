# Veg: what the peeling and chopping steps (PeelAction, ChopAction) need to draw
# an onion lying on its side: its tip (the dry neck) to the left, its root to the
# right, in its own coordinates (x along it, 0 at the middle).
class_name Veg
extends RefCounted

const ONION_SKIN := Color("#D9973F")   # Golden and papery.
const ONION_FLESH := Color("#F6F0D8")
const ONION_LAYER := Color("#DDE3B4")  # The line between two layers.
const ONION_ROOT := Color("#C9AE7C")


# How far out an onion goes at `t` along it (0 tip, 1 root): a ball, drawn out a
# little at the tip.
static func onion_radius(t: float, radius: float) -> float:
	var ball := sqrt(maxf(1.0 - pow(absf(t * 2.0 - 1.0), 2.0 if t > 0.5 else 1.7), 0.0))
	return maxf(radius * ball, radius * 0.1)


# A whole onion on `parent`.
static func add_onion(parent: Node3D, length: float, radius: float, color: Color) -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.roughness = 0.5
	var bulb := MeshInstance3D.new()
	bulb.mesh = turned(length, func(x): return onion_radius(x / length + 0.5, radius), paint)
	parent.add_child(bulb)
	add_tip(parent, -length * 0.5)
	add_root(parent, length * 0.5)


# Its dry, papery neck at local x.
static func add_tip(parent: Node3D, x: float) -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = ONION_SKIN.darkened(0.15)
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


# The tuft of roots at local x.
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
	paint.albedo_color = ONION_LAYER if line else ONION_FLESH.lightened(0.3)
	paint.roughness = 0.35
	return paint


# A round solid `length` long along x, as far out at each x as `radius_at` says.
static func turned(length: float, radius_at: Callable, material: Material) -> ArrayMesh:
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
				var r: float = radius_at.call(x)
				var slope: float = (radius_at.call(x + 0.001) - radius_at.call(x - 0.001)) / 0.002
				tool.set_normal(Vector3(-slope, cos(corner[1]), sin(corner[1])).normalized())
				tool.add_vertex(Vector3(x, cos(corner[1]) * r, sin(corner[1]) * r))
	for end: float in [-0.5, 0.5]:  # Both ends, flat.
		var x := length * end
		var r: float = radius_at.call(x)
		for spoke in SPOKES:
			var a0 := TAU * spoke / SPOKES
			var a1 := TAU * (spoke + 1) / SPOKES
			var first := a1 if end < 0.0 else a0
			var second := a0 if end < 0.0 else a1
			for point in [Vector3(x, 0.0, 0.0), Vector3(x, cos(second) * r, sin(second) * r), Vector3(x, cos(first) * r, sin(first) * r)]:
				tool.set_normal(Vector3(signf(end), 0.0, 0.0))
				tool.add_vertex(point)
	return tool.commit()
