@tool
# CozyProp: the little lived-in things that dress the restaurant (jars and
# crocks on the counters, a spice rack and drying herbs on the kitchen wall,
# fairy lights and a plate rail round the dining room, a rug runner down the
# kitchen). Pure looks: nothing is solid or usable, and none of it is shop
# decor, so the dining room's floor stays free for what the chefs place.
# Built from simple shapes in the room's warm colors; shows in the editor.
#
# Counter things stand on this node (put it on the counter top). Wall things
# hang with their back on this node and face +z. `length` stretches the long
# ones (plate_rail, fairy_lights, runner) along x.
class_name CozyProp
extends Node3D

const KINDS := ["jars", "crock", "fruit_bowl", "bread", "herb_pots", "plates", "teapot", "cake_dome",
	"spice_rack", "utensil_rail", "herb_bundles", "plate_rail", "fairy_lights", "runner"]

@export_enum("jars", "crock", "fruit_bowl", "bread", "herb_pots", "plates", "teapot", "cake_dome",
	"spice_rack", "utensil_rail", "herb_bundles", "plate_rail", "fairy_lights", "runner") var kind := "jars":
	set(value):
		kind = value
		_rebuild()
@export var length := 2.0:
	set(value):
		length = value
		_rebuild()

const WOOD := Color("8A5A3C")
const LIGHT_WOOD := Color("C49A6C")
const DARK_WOOD := Color("5E3B28")
const CREAM := Color("F4EAD5")
const RED := Color("D9473F")
const PEACH := Color("F2B58A")
const SAGE := Color("9DB58A")
const LEAF := Color("5E9A4A")
const TERRACOTTA := Color("C2643C")
const GLASS := Color(0.85, 0.93, 0.92, 0.55)
const COPPER := Color("C47A45")
const IRON := Color("4A4440")
const GOLD := Color("F2C14E")
const BLUE := Color("7FA7C9")

static var _paints := {}


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children(true):
		if String(child.name).begins_with("_Prop"):
			remove_child(child)
			child.queue_free()
	var at := Node3D.new()
	at.name = "_Prop"
	add_child(at, false, Node.INTERNAL_MODE_FRONT)
	match kind:
		"jars":  # Three glass jars of beans, pasta and flour with wooden lids.
			var fills := [Color("B5523B"), Color("F0D27A"), CREAM]
			for i in 3:
				var x := -0.16 + i * 0.16
				var tall: float = [0.22, 0.17, 0.26][i]
				_cyl(at, Vector3(x, tall * 0.35, 0), 0.06, 0.06, tall * 0.7, fills[i])
				_cyl(at, Vector3(x, tall / 2.0, 0), 0.065, 0.065, tall, GLASS).material_override = _glass()
				_cyl(at, Vector3(x, tall + 0.015, 0), 0.07, 0.07, 0.03, LIGHT_WOOD)
		"crock":  # A crock of wooden spoons and a whisk.
			_cyl(at, Vector3(0, 0.1, 0), 0.08, 0.07, 0.2, BLUE)
			_cyl(at, Vector3(0, 0.195, 0), 0.085, 0.085, 0.02, CREAM)
			for i in 4:
				var spoon := Node3D.new()
				spoon.position = Vector3(0, 0.12, 0)
				spoon.rotation = Vector3(0.25 * cos(i * 1.7), 0, 0.25 * sin(i * 1.7))
				at.add_child(spoon)
				_cyl(spoon, Vector3(0, 0.14, 0), 0.008, 0.008, 0.28, LIGHT_WOOD if i != 2 else Color("B0B0B0"))
				_ball(spoon, Vector3(0, 0.29, 0), 0.025 if i != 2 else 0.035, LIGHT_WOOD if i != 2 else Color("B0B0B0"), 1.4)
		"fruit_bowl":  # A bowl heaped with apples, oranges and a pear.
			_cyl(at, Vector3(0, 0.05, 0), 0.17, 0.1, 0.1, CREAM)
			var fruit := [[Vector3(-0.07, 0.12, 0.02), RED], [Vector3(0.07, 0.12, -0.03), Color("F29A3A")], [Vector3(0.0, 0.12, 0.08), RED],
				[Vector3(0.01, 0.2, -0.01), Color("F29A3A")], [Vector3(0.05, 0.13, 0.08), Color("B8C94A")]]
			for f in fruit:
				_ball(at, f[0], 0.055, f[1])
		"bread":  # A board with a crusty loaf and a couple of slices.
			_box(at, Vector3(0, 0.015, 0), Vector3(0.42, 0.03, 0.26), LIGHT_WOOD)
			var loaf := _ball(at, Vector3(-0.04, 0.08, 0), 0.1, Color("D08A44"), 0.75)
			loaf.scale = Vector3(1.6, 1.0, 1.0)
			for i in 2:
				_box(at, Vector3(0.13 + i * 0.03, 0.07, 0), Vector3(0.02, 0.1, 0.13), Color("F2DDB0"))
		"herb_pots":  # Three little pots of herbs.
			for i in 3:
				var x := -0.15 + i * 0.15
				_cyl(at, Vector3(x, 0.05, 0), 0.055, 0.04, 0.1, TERRACOTTA)
				for j in 3:
					_ball(at, Vector3(x + 0.025 * cos(j * 2.1 + i), 0.13 + j * 0.015, 0.025 * sin(j * 2.1 + i)), 0.04, LEAF if (i + j) % 2 == 0 else SAGE)
		"plates":  # A stack of plates and a mug.
			for i in 6:
				_cyl(at, Vector3(0, 0.012 + i * 0.024, 0), 0.13, 0.11, 0.02, CREAM if i % 2 == 0 else Color("EFE3CC"))
			_cyl(at, Vector3(0.2, 0.05, 0.02), 0.04, 0.04, 0.1, RED)
		"teapot":  # A round teapot with a spout.
			_ball(at, Vector3(0, 0.09, 0), 0.09, SAGE, 0.9)
			_ball(at, Vector3(0, 0.17, 0), 0.025, CREAM)
			var spout := _cyl(at, Vector3(0.1, 0.11, 0), 0.012, 0.022, 0.1, SAGE)
			spout.rotation_degrees.z = -50.0
			var handle := _torus(at, Vector3(-0.09, 0.1, 0), 0.025, 0.045, SAGE)
			handle.rotation_degrees.x = 90.0
		"cake_dome":  # A cake on a stand under a glass dome.
			_cyl(at, Vector3(0, 0.05, 0), 0.03, 0.05, 0.1, CREAM)
			_cyl(at, Vector3(0, 0.105, 0), 0.15, 0.15, 0.015, CREAM)
			_cyl(at, Vector3(0, 0.16, 0), 0.11, 0.11, 0.1, Color("F6C9C9"))
			_cyl(at, Vector3(0, 0.215, 0), 0.112, 0.112, 0.012, CREAM)
			_ball(at, Vector3(0, 0.235, 0), 0.025, RED)
			var dome := _ball(at, Vector3(0, 0.12, 0), 0.15, GLASS)
			dome.scale = Vector3(1.0, 1.2, 1.0)
			dome.material_override = _glass()
		"spice_rack":  # Two little shelves of spice jars.
			_box(at, Vector3(0, 0.25, 0.01), Vector3(0.7, 0.5, 0.02), WOOD)
			for row in 2:
				_box(at, Vector3(0, 0.03 + row * 0.24, 0.07), Vector3(0.7, 0.025, 0.12), LIGHT_WOOD)
				for i in 6:
					var spice: Color = [RED, Color("E8B04A"), Color("7A9A3A"), Color("8A4A2A"), PEACH, Color("C9A0D0")][(i + row * 2) % 6]
					_cyl(at, Vector3(-0.27 + i * 0.108, 0.1 + row * 0.24, 0.07), 0.035, 0.035, 0.11, spice)
					_cyl(at, Vector3(-0.27 + i * 0.108, 0.165 + row * 0.24, 0.07), 0.037, 0.037, 0.02, DARK_WOOD)
		"utensil_rail":  # A copper rail with a ladle, a whisk, a spatula and two little pans.
			var rail := _cyl(at, Vector3(0, 0, 0.06), 0.012, 0.012, 1.1, COPPER)
			rail.rotation_degrees.z = 90.0
			for x in [-0.55, 0.55]:
				_box(at, Vector3(x, 0, 0.03), Vector3(0.03, 0.03, 0.06), COPPER)
			for i in 5:
				var x := -0.42 + i * 0.21
				_cyl(at, Vector3(x, -0.06, 0.06), 0.004, 0.004, 0.1, IRON)
				match i:
					0, 4:  # Pans hang by their handles.
						_cyl(at, Vector3(x, -0.2, 0.07), 0.012, 0.012, 0.18, DARK_WOOD)
						var pan := _cyl(at, Vector3(x, -0.38, 0.08), 0.1, 0.1, 0.04, COPPER)
						pan.rotation_degrees.x = 90.0
					1:  # Ladle.
						_cyl(at, Vector3(x, -0.24, 0.07), 0.008, 0.008, 0.3, Color("B0B0B0"))
						_ball(at, Vector3(x, -0.4, 0.08), 0.045, Color("B0B0B0"), 0.7)
					2:  # Whisk.
						_cyl(at, Vector3(x, -0.18, 0.07), 0.012, 0.012, 0.14, DARK_WOOD)
						var loops := _ball(at, Vector3(x, -0.33, 0.07), 0.045, Color("C8C8C8"))
						loops.scale = Vector3(0.8, 1.8, 0.8)
					3:  # Spatula.
						_cyl(at, Vector3(x, -0.2, 0.07), 0.01, 0.01, 0.2, LIGHT_WOOD)
						_box(at, Vector3(x, -0.35, 0.07), Vector3(0.08, 0.12, 0.012), LIGHT_WOOD)
		"herb_bundles":  # Bunches of herbs drying upside down from a twine line.
			var line := _cyl(at, Vector3(0, 0, 0.05), 0.006, 0.006, 1.0, Color("C8B48A"))
			line.rotation_degrees.z = 90.0
			for i in 5:
				var x := -0.4 + i * 0.2
				var green: Color = [SAGE, LEAF, Color("7FA06A"), Color("B79AC9"), LEAF][i]  # One's lavender.
				_cyl(at, Vector3(x, -0.06, 0.05), 0.005, 0.005, 0.12, Color("C8B48A"))
				_cyl(at, Vector3(x, -0.14, 0.05), 0.015, 0.015, 0.06, Color("A0805A"))
				_cyl(at, Vector3(x, -0.22, 0.05), 0.012, 0.04, 0.12, green)  # Tied at the stems, fanning out to the leaves.
				_ball(at, Vector3(x, -0.3, 0.05), 0.045, green, 0.9)
				_ball(at, Vector3(x - 0.02, -0.27, 0.06), 0.03, green.darkened(0.15))
				_ball(at, Vector3(x + 0.02, -0.28, 0.04), 0.03, green.lightened(0.1))
		"plate_rail":  # A high shelf with plates stood up along it, and jugs between.
			var long := maxf(length, 0.6)
			_box(at, Vector3(0, 0, 0.08), Vector3(long, 0.03, 0.16), WOOD)
			_box(at, Vector3(0, 0.07, 0.15), Vector3(long, 0.015, 0.015), DARK_WOOD)  # The lip the plates lean on.
			for x in [-long / 2.0 + 0.15, long / 2.0 - 0.15]:
				_box(at, Vector3(x, -0.08, 0.05), Vector3(0.03, 0.14, 0.1), DARK_WOOD)
			var count := int(long / 0.34)
			for i in count:
				var x := -long / 2.0 + 0.2 + i * (long - 0.4) / maxf(count - 1, 1)
				if i % 3 == 1:
					_cyl(at, Vector3(x, 0.09, 0.08), 0.05, 0.06, 0.15, [BLUE, CREAM, PEACH][i % 3])  # A jug.
				else:
					var plate := _cyl(at, Vector3(x, 0.13, 0.09), 0.11, 0.11, 0.015, CREAM if i % 2 == 0 else Color("E8C8A8"))
					plate.rotation_degrees.x = 75.0
					var rim := _cyl(at, Vector3(x, 0.13, 0.1), 0.07, 0.07, 0.016, [RED, BLUE, SAGE][i % 3])
					rim.rotation_degrees.x = 75.0
		"fairy_lights":  # A string of warm bulbs, drooping between pins.
			var long := maxf(length, 0.6)
			var swags := maxi(1, roundi(long / 1.4))
			var bulbs := int(long / 0.18)
			var cord_points := 24 * swags
			for i in cord_points:  # The cord, in short bits.
				var t0 := float(i) / cord_points
				var t1 := float(i + 1) / cord_points
				var a := _swag(t0, long, swags)
				var b := _swag(t1, long, swags)
				var bit := _cyl(at, (a + b) / 2.0, 0.004, 0.004, a.distance_to(b), Color("3E5A3A"))
				bit.rotation.z = -atan2(b.x - a.x, b.y - a.y)  # Lay the bit along a -> b.
			var colors := [Color("FFD27A"), Color("FFB36B"), Color("FFE8A8")]
			for i in bulbs:
				var spot := _swag((i + 0.5) / bulbs, long, swags) - Vector3(0, 0.03, 0)
				_ball(at, spot, 0.022, colors[i % 3], 1.3).material_override = _paint(colors[i % 3], true)
		"runner":  # A striped rag rug, lying flat.
			var long := maxf(length, 0.6)
			_box(at, Vector3(0, 0.004, 0), Vector3(long, 0.008, 0.8), CREAM)  # Thin: floor messes (0.018 up) still show on top.
			var stripes := int(long / 0.3)
			for i in stripes:
				var x := -long / 2.0 + (i + 0.5) * long / stripes
				_box(at, Vector3(x, 0.0065, 0), Vector3(long / stripes * 0.45, 0.008, 0.66), [RED, PEACH, SAGE, RED][i % 4])
			for z in [-0.36, 0.36]:
				_box(at, Vector3(0, 0.0065, z), Vector3(long, 0.008, 0.04), RED)
	MeshMerge.merge(at, false)  # One mesh, a surface per color; small things cast no shadow.



# A point on the drooping string: `swags` dips across `long` meters, 12 cm deep.
func _swag(t: float, long: float, swags: int) -> Vector3:
	var x := -long / 2.0 + t * long
	var phase := fmod(t * swags, 1.0)
	return Vector3(x, -0.12 * sin(phase * PI), 0.03)


func _ball(at: Node3D, spot: Vector3, radius: float, color: Color, squash := 1.0) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0 * squash
	sphere.radial_segments = 12
	sphere.rings = 6
	return _mesh(at, sphere, spot, color)


func _cyl(at: Node3D, spot: Vector3, top: float, bottom: float, tall: float, color: Color) -> MeshInstance3D:
	var tube := CylinderMesh.new()
	tube.top_radius = top
	tube.bottom_radius = bottom
	tube.height = tall
	tube.radial_segments = 12
	tube.rings = 1
	return _mesh(at, tube, spot, color)


func _torus(at: Node3D, spot: Vector3, inner: float, outer: float, color: Color) -> MeshInstance3D:
	var ring := TorusMesh.new()
	ring.inner_radius = inner
	ring.outer_radius = outer
	ring.rings = 12
	ring.ring_segments = 6
	return _mesh(at, ring, spot, color)


func _box(at: Node3D, spot: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var cube := BoxMesh.new()
	cube.size = size
	return _mesh(at, cube, spot, color)


func _mesh(at: Node3D, primitive: PrimitiveMesh, spot: Vector3, color: Color) -> MeshInstance3D:
	primitive.material = _paint(color)
	var mesh := MeshInstance3D.new()
	mesh.mesh = primitive
	mesh.position = spot
	at.add_child(mesh)
	return mesh


static func _glass() -> StandardMaterial3D:
	return _paint(GLASS, false, true)


# One shared material per color (glowing, or see-through), so many props stay cheap.
static func _paint(color: Color, glow := false, clear := false) -> StandardMaterial3D:
	var key := color.to_html() + ("g" if glow else "") + ("c" if clear else "")
	if not _paints.has(key):
		var paint := StandardMaterial3D.new()
		paint.albedo_color = color
		paint.roughness = 0.85
		if glow:
			paint.emission_enabled = true
			paint.emission = color
			paint.emission_energy_multiplier = 1.6
		if clear:
			paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			paint.roughness = 0.2
		_paints[key] = paint
	return _paints[key]
