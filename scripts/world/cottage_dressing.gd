# CottageDressing: the pieces that make the restaurant's outside a woodland
# cottage, as in the concept art: striped scalloped awnings, the carved
# "Dinner Time" sign with its chef's hat, lanterns by the door, flower boxes
# and barrels, an A-frame chalkboard, ivy up the corners, and a cottage roof
# with a smoking stone chimney. Built from simple shapes in the style's warm
# colors (placeholders until there are Meshy models: woodland_exterior_prompts
# section 5), each group merged into one mesh (MeshMerge).
# Used by RestaurantGrounds (the restaurant's real outside, seen only from
# outdoor views) and the start screen. Everything faces +z.
class_name CottageDressing
extends RefCounted

const CREAM := Color("F6E7CF")
const RED := Color("D9473F")
const WOOD := Color("8A5A3C")
const DARK_WOOD := Color("5E3B28")
const SIGN_WOOD := Color("7A4A30")
const LANTERN := Color("FFD27A")
const IRON := Color("3E3530")
const ROOF := Color("8C4A36")
const ROOF_DARK := Color("6E3828")
const STONE := Color("A39A8C")
const LEAF := Color("5E9A4A")
const LEAF_LIGHT := Color("86B85A")
const PINK := Color("F2A0B8")
const PEACH := Color("F2B58A")
const BARREL := Color("9A6440")
const BLACKBOARD := Color("2F3A33")

static var _paints := {}


# A striped, scalloped awning `width` wide sticking out `depth` from the wall,
# its top edge against the wall at `at`.
static func awning(parent: Node3D, at: Vector3, width: float, depth := 0.8, drop := 0.45) -> Node3D:
	var holder := _holder(parent, "Awning", at)
	var stripes := maxi(2, roundi(width / 0.32))
	var stripe := width / stripes
	var slope := atan2(drop, depth)
	var length := sqrt(depth * depth + drop * drop)
	for i in stripes:
		var x := -width / 2.0 + (i + 0.5) * stripe
		var color := RED if i % 2 == 0 else CREAM
		var panel := _box(holder, Vector3(x, -drop / 2.0, depth / 2.0), Vector3(stripe, 0.03, length), color)
		panel.rotation.x = slope
		var scallop := _cyl(holder, Vector3(x, -drop - 0.06, depth), stripe / 2.0, stripe / 2.0, 0.03, color)  # The scalloped edge.
		scallop.rotation.x = PI / 2.0
		scallop.scale = Vector3(1.0, 1.0, 0.75)
	for side in [-1.0, 1.0]:  # The frame's arms.
		var arm := _cyl(holder, Vector3(side * width / 2.0, -drop / 2.0, depth / 2.0), 0.015, 0.015, length, IRON)
		arm.rotation.x = PI / 2.0 - slope
	MeshMerge.merge(holder, false)
	return holder


# The carved sign: a rounded wooden board with a darker rim, the restaurant's
# name (in its color, lightened; cream when there's none), a chef's hat on top
# and a sprig of ivy. Long names shrink to fit. Its Label3D is "Name".
static func sign_board(parent: Node3D, at: Vector3, text := "Dinner Time", width := 2.6, color := Color(0, 0, 0, 0)) -> Node3D:
	var holder := _holder(parent, "SignBoard", at)
	var tall := width * 0.36
	var shapes := Node3D.new()
	holder.add_child(shapes)
	_box(shapes, Vector3(0, 0, 0), Vector3(width - tall, tall + 0.12, 0.1), DARK_WOOD)  # Rim.
	for side in [-1.0, 1.0]:
		var end := _cyl(shapes, Vector3(side * (width - tall) / 2.0, 0, 0), tall / 2.0 + 0.06, tall / 2.0 + 0.06, 0.1, DARK_WOOD)
		end.rotation.x = PI / 2.0
		var face_end := _cyl(shapes, Vector3(side * (width - tall) / 2.0, 0, 0.03), tall / 2.0, tall / 2.0, 0.08, SIGN_WOOD)
		face_end.rotation.x = PI / 2.0
	_box(shapes, Vector3(0, 0, 0.03), Vector3(width - tall, tall, 0.08), SIGN_WOOD)
	# The chef's hat on top: a band and a puffy top.
	_cyl(shapes, Vector3(0, tall / 2.0 + 0.12, 0.02), 0.13, 0.13, 0.12, CREAM)
	for puff in [Vector3(-0.1, tall / 2.0 + 0.27, 0.02), Vector3(0.1, tall / 2.0 + 0.27, 0.02), Vector3(0, tall / 2.0 + 0.33, 0.02)]:
		_ball(shapes, puff, 0.13, CREAM)
	for i in 6:  # Ivy trailing off one end.
		_ball(shapes, Vector3(-width / 2.0 + 0.05 + i * 0.09, tall / 2.0 - 0.02 - (i % 2) * 0.08, 0.08), 0.06, LEAF if i % 2 == 0 else LEAF_LIGHT)
	MeshMerge.merge(shapes, false)
	var label := Label3D.new()
	label.name = "Name"
	label.font_size = 96
	label.outline_size = 18
	holder.add_child(label)
	paint_sign(holder, text, color, width)
	label.position = Vector3(0, -0.02, 0.085)
	label.font = load("res://assets/fonts/fredoka_semibold.tres")
	return holder


# Puts a name (and color) on a sign_board.
static func paint_sign(board: Node3D, text: String, color := Color(0, 0, 0, 0), width := 2.6) -> void:
	var label := board.get_node("Name") as Label3D
	label.text = text
	label.pixel_size = width / 800.0 * minf(1.0, 12.0 / maxi(1, text.length()))  # Long names shrink to fit the board.
	label.modulate = CREAM if color.a == 0.0 else color.lightened(0.55)
	label.outline_modulate = DARK_WOOD if color.a == 0.0 else color.darkened(0.6)


# A wall lantern on a curly bracket, glowing warm.
static func lantern(parent: Node3D, at: Vector3) -> Node3D:
	var holder := _holder(parent, "Lantern", at)
	_box(holder, Vector3(0, 0, 0.04), Vector3(0.08, 0.2, 0.08), IRON)  # Wall plate.
	var arm := _cyl(holder, Vector3(0, 0.05, 0.16), 0.015, 0.015, 0.26, IRON)
	arm.rotation.x = PI / 2.0
	_box(holder, Vector3(0, -0.12, 0.28), Vector3(0.18, 0.24, 0.18), LANTERN).material_override = _paint(LANTERN, true)
	_cyl(holder, Vector3(0, 0.03, 0.28), 0.0, 0.15, 0.1, IRON)  # Its little roof.
	_box(holder, Vector3(0, -0.25, 0.28), Vector3(0.2, 0.03, 0.2), IRON)
	MeshMerge.merge(holder, false)
	return holder


# A wooden window box spilling over with flowers.
static func flower_box(parent: Node3D, at: Vector3, width := 1.2) -> Node3D:
	var holder := _holder(parent, "FlowerBox", at)
	_box(holder, Vector3(0, 0.1, 0.12), Vector3(width, 0.2, 0.22), WOOD)
	var count := int(width / 0.12)
	for i in count:
		var x := -width / 2.0 + 0.08 + i * (width - 0.16) / maxf(count - 1, 1)
		_ball(holder, Vector3(x, 0.24, 0.12 + (i % 2) * 0.05), 0.08, LEAF if i % 2 == 0 else LEAF_LIGHT)
		if i % 2 == 1:
			_ball(holder, Vector3(x, 0.3, 0.16), 0.055, [RED, PINK, PEACH, CREAM][i % 4])
	MeshMerge.merge(holder, false)
	return holder


# A half barrel full of flowers, standing on the ground.
static func flower_barrel(parent: Node3D, at: Vector3) -> Node3D:
	var holder := _holder(parent, "FlowerBarrel", at)
	_cyl(holder, Vector3(0, 0.25, 0), 0.34, 0.3, 0.5, BARREL)
	for y in [0.1, 0.4]:
		_cyl(holder, Vector3(0, y, 0), 0.345, 0.335, 0.04, IRON)
	for i in 9:
		var angle := i * TAU / 9.0
		var spot := Vector3(cos(angle) * 0.2, 0.55 + (i % 3) * 0.04, sin(angle) * 0.2)
		_ball(holder, spot, 0.12, LEAF if i % 2 == 0 else LEAF_LIGHT)
		_ball(holder, spot + Vector3(0, 0.1, 0), 0.07, [PINK, CREAM, RED][i % 3])
	_ball(holder, Vector3(0, 0.68, 0), 0.13, LEAF)
	MeshMerge.merge(holder)
	return holder


# An A-frame chalkboard with a steaming cup drawn on it.
static func chalkboard(parent: Node3D, at: Vector3, turn := 0.0) -> Node3D:
	var holder := _holder(parent, "Chalkboard", at)
	holder.rotation.y = turn
	for side in [-1.0, 1.0]:
		var leaf := Node3D.new()
		leaf.position = Vector3(0, 0.95, 0)
		leaf.rotation.x = side * 0.22
		holder.add_child(leaf)
		_box(leaf, Vector3(0, -0.47, side * 0.03), Vector3(0.66, 0.94, 0.04), WOOD)
		_box(leaf, Vector3(0, -0.45, side * 0.055), Vector3(0.54, 0.74, 0.01), BLACKBOARD)
		# The cup (chalk lines): a cup, a saucer and steam.
		_box(leaf, Vector3(0, -0.52, side * 0.062), Vector3(0.18, 0.14, 0.005), CREAM)
		_box(leaf, Vector3(0, -0.6, side * 0.062), Vector3(0.28, 0.025, 0.005), CREAM)
		for s in [-0.05, 0.05]:
			_box(leaf, Vector3(s, -0.36, side * 0.062), Vector3(0.025, 0.12, 0.005), CREAM)
	MeshMerge.merge(holder)
	return holder


# Ivy climbing `tall` meters up a corner or wall: leafy clumps on a wandering vine.
static func ivy(parent: Node3D, at: Vector3, tall := 2.6, seed_value := 1) -> Node3D:
	var holder := _holder(parent, "Ivy", at)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var y := 0.1
	var x := 0.0
	while y < tall:
		x = clampf(x + rng.randf_range(-0.12, 0.12), -0.3, 0.3)
		_ball(holder, Vector3(x, y, 0.06), rng.randf_range(0.09, 0.14), LEAF if rng.randf() < 0.6 else LEAF_LIGHT, 0.6)
		if rng.randf() < 0.5:
			_ball(holder, Vector3(x + rng.randf_range(-0.2, 0.2), y + 0.06, 0.07), 0.08, LEAF_LIGHT, 0.6)
		y += rng.randf_range(0.12, 0.2)
	MeshMerge.merge(holder, false)
	return holder


# A cottage roof over a footprint (`size` x by z, centered on `at`, which is
# at the top of the walls): two slopes rising `rise` to a ridge running along
# x (or along z when `ridge_along_z`), hanging `overhang` past the walls, with
# rows of shingles and a ridge beam.
static func roof(parent: Node3D, at: Vector3, size: Vector2, rise: float, ridge_along_z := false, overhang := 0.4) -> Node3D:
	var holder := _holder(parent, "Roof", at)
	var shapes := Node3D.new()
	holder.add_child(shapes)
	if ridge_along_z:
		shapes.rotation.y = PI / 2.0
		size = Vector2(size.y, size.x)
	var span := size.y / 2.0 + overhang  # From the ridge down to the eave, flat.
	var length := size.x + overhang * 2.0
	var slope := atan2(rise, size.y / 2.0)
	var face := span / cos(slope)
	for side in [-1.0, 1.0]:
		var panel := _box(shapes, Vector3(0, rise / 2.0 - overhang * tan(slope) / 2.0, side * span / 2.0), Vector3(length, 0.12, face), ROOF)
		panel.rotation.x = side * slope
		var rows := int(face / 0.42)
		for r in rows:  # Shingle rows: a darker lip every row.
			var along := (r + 0.5) * face / rows
			var down := along * sin(slope)
			var out := along * cos(slope)
			var lip := _box(shapes, Vector3(0, rise - down + 0.07, side * out), Vector3(length, 0.05, 0.08), ROOF_DARK)
			lip.rotation.x = side * slope
	var ridge := _cyl(shapes, Vector3(0, rise + 0.08, 0), 0.1, 0.1, length + 0.1, DARK_WOOD)
	ridge.rotation.z = PI / 2.0
	# Gable ends: the triangles under the roof at each end, in plaster with a beam.
	for end in [-1.0, 1.0]:
		var gable := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(size.y, rise, 0.2)
		prism.material = _paint(CREAM)
		gable.mesh = prism
		gable.position = Vector3(end * (size.x / 2.0 - 0.1), rise / 2.0, 0)
		gable.rotation.y = PI / 2.0
		shapes.add_child(gable)
		var beam := _box(shapes, Vector3(end * (size.x / 2.0 - 0.02), rise / 2.0, 0), Vector3(0.06, rise * 0.9, 0.14), DARK_WOOD)
		beam.rotation.y = 0.0
	MeshMerge.merge(shapes)
	return holder


# A stone chimney stack with a cap, and a few soft puffs of smoke rising from it.
static func chimney(parent: Node3D, at: Vector3, tall := 1.6) -> Node3D:
	var holder := _holder(parent, "Chimney", at)
	var shapes := Node3D.new()
	holder.add_child(shapes)
	_box(shapes, Vector3(0, tall / 2.0, 0), Vector3(0.7, tall, 0.7), STONE)
	for i in 7:  # Rounded stones poking out.
		_ball(shapes, Vector3(-0.36 + (i % 2) * 0.72, 0.2 + i * tall / 8.0, -0.2 + fmod(i * 0.37, 0.4)), 0.12, Color("8E8576"), 0.6)
	_box(shapes, Vector3(0, tall + 0.06, 0), Vector3(0.85, 0.12, 0.85), Color("7A7268"))
	MeshMerge.merge(shapes)
	var smoke := CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.position = Vector3(0, tall + 0.2, 0)
	smoke.amount = 10
	smoke.lifetime = 4.0
	smoke.preprocess = 4.0
	smoke.direction = Vector3(0.2, 1, 0)
	smoke.spread = 12.0
	smoke.initial_velocity_min = 0.35
	smoke.initial_velocity_max = 0.55
	smoke.gravity = Vector3(0.05, 0.05, 0)
	smoke.scale_amount_min = 0.5
	smoke.scale_amount_max = 0.8
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.6))
	smoke.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.55))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	smoke.color_ramp = fade
	var puff := SphereMesh.new()
	puff.radius = 0.25
	puff.height = 0.5
	puff.radial_segments = 8
	puff.rings = 4
	var cloud := StandardMaterial3D.new()
	cloud.albedo_color = Color(0.92, 0.9, 0.88)
	cloud.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud.vertex_color_use_as_albedo = true
	cloud.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = cloud
	smoke.mesh = puff
	holder.add_child(smoke)
	return holder


# --- Shapes ----------------------------------------------------------------------

static func _holder(parent: Node3D, label: String, at: Vector3) -> Node3D:
	var holder := Node3D.new()
	holder.name = label
	holder.position = at
	parent.add_child(holder)
	return holder


static func _ball(at: Node3D, spot: Vector3, radius: float, color: Color, squash := 1.0) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0 * squash
	sphere.radial_segments = 10
	sphere.rings = 5
	return _mesh(at, sphere, spot, color)


static func _cyl(at: Node3D, spot: Vector3, top: float, bottom: float, tall: float, color: Color) -> MeshInstance3D:
	var tube := CylinderMesh.new()
	tube.top_radius = top
	tube.bottom_radius = bottom
	tube.height = tall
	tube.radial_segments = 14
	tube.rings = 1
	return _mesh(at, tube, spot, color)


static func _box(at: Node3D, spot: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var cube := BoxMesh.new()
	cube.size = size
	return _mesh(at, cube, spot, color)


static func _mesh(at: Node3D, primitive: PrimitiveMesh, spot: Vector3, color: Color) -> MeshInstance3D:
	primitive.material = _paint(color)
	var mesh := MeshInstance3D.new()
	mesh.mesh = primitive
	mesh.position = spot
	at.add_child(mesh)
	return mesh


static func _paint(color: Color, glow := false) -> StandardMaterial3D:
	var key := color.to_html() + ("g" if glow else "")
	if not _paints.has(key):
		var paint := StandardMaterial3D.new()
		paint.albedo_color = color
		paint.roughness = 0.85
		if glow:
			paint.emission_enabled = true
			paint.emission = color
			paint.emission_energy_multiplier = 1.8
		_paints[key] = paint
	return _paints[key]
