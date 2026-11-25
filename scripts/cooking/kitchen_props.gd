# KitchenProps: the close-ups' shared tools and materials, in the Art Style
# Guide's look (chunky and rounded, warm wood handles, soft sage steel, cream
# and palette accents), so every station's knife, whisk and boards match. Each
# builder returns a new Node3D that isn't in the tree yet; the comment says
# where its origin is, which is what the actions move about.
class_name KitchenProps
extends RefCounted

const WOOD := preload("res://assets/shaders/wood.gdshader")
const OAK := preload("res://assets/shaders/oak.gdshader")
const SOUP := preload("res://assets/shaders/soup.gdshader")

const STEEL := Color("#D9DDD6")        # Blades and wires: light, a touch warm.
const SAGE_STEEL := Color("#A9B3A4")   # Spines, bolsters, rims: the guide's sage steel.
const HANDLE_WOOD := Color("#90523C")  # The guide's warm wood.
const BRASS := Color("#FFD15C")        # Lantern yellow.
const CREAM := Color("#FBD6A0")


static func steel(color := STEEL) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.6
	material.roughness = 0.3
	return material


static func handle_wood() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = HANDLE_WOOD
	material.roughness = 0.7
	return material


# A cutting board's oak, with faint knife marks: brown enough that orange, yellow,
# white and green food all stand out on it.
static func board_wood() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = OAK
	material.set_shader_parameter("knife_marks", 1.0)
	return material


# Oak for things (the dish rack): the same, uncut.
static func oak() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = OAK
	return material


# An oak rack for `slots` plates standing side by side `step` apart along x, its
# origin the middle of its bottom: two rails front and back with pegs between the
# plates, on a frame with rounded ends and brass studs. Plates `reach` in radius
# stand on RACK_FLOOR.
const RACK_FLOOR := 0.042
static func dish_rack(slots: int, step: float, reach: float) -> Node3D:
	var rack := Node3D.new()
	var wood := oak()
	wood.set_shader_parameter("figure", 0.12)
	var long := (slots - 1) * step
	var add := func(mesh: Mesh, at: Vector3, turn: Vector3, material: Material) -> void:
		var part := MeshInstance3D.new()
		part.mesh = mesh
		part.material_override = material
		part.position = at
		part.rotation = turn
		rack.add_child(part)
	var half := reach * 0.62  # The plates rest on two bars this far front and back.
	var bar_y := RACK_FLOOR + reach - sqrt(reach * reach - half * half)
	for way: float in [-1.0, 1.0]:
		add.call(_rod(0.009, long + 0.1), Vector3(0.0, bar_y - 0.011, way * half), Vector3(0.0, 0.0, PI * 0.5), wood)  # What they stand on.
		add.call(PlaceAction.rounded_block(Vector3(long + 0.1, 0.03, 0.026), 0.009), Vector3(0.0, 0.036, way * (reach + 0.016)), Vector3.ZERO, wood)  # Along the front and back.
		for i in slots + 1:  # A peg either side of every plate, leaning in a little.
			var peg_x := -long * 0.5 + (i - 0.5) * step
			add.call(_rod(0.0055, 0.105), Vector3(peg_x, 0.036 + 0.05, way * (reach * 0.9)), Vector3(way * -0.16, 0.0, 0.0), wood)
		# The ends: an arch of wood, on feet.
		var end_x := way * (long * 0.5 + 0.058)
		add.call(_arch(reach + 0.016, 0.112, 0.028, 0.024), Vector3(end_x, 0.04, 0.0), Vector3.ZERO, wood)
		add.call(PlaceAction.rounded_block(Vector3(0.026, 0.03, reach * 2.0 + 0.06), 0.009), Vector3(end_x, 0.036, 0.0), Vector3.ZERO, wood)
		for front: float in [-1.0, 1.0]:
			add.call(PlaceAction.rounded_block(Vector3(0.036, 0.034, 0.036), 0.01), Vector3(end_x, 0.015, front * (reach + 0.012)), Vector3.ZERO, wood)
			var stud := SphereMesh.new()
			stud.radius = 0.0075
			stud.height = 0.009
			var brass := steel(BRASS)
			add.call(stud, Vector3(end_x, 0.037, front * (reach + 0.031)), Vector3(PI * 0.5, 0.0, 0.0), brass)
	return rack


# A wooden arch across z, `half` out to each side and `tall`, its band `wide` and
# `thick` (along x), its foot's middle the origin.
static func _arch(half: float, tall: float, wide: float, thick: float) -> ArrayMesh:
	const PARTS := 32
	const BEVEL := 0.005
	var rings: Array = []
	for k in PARTS + 1:
		var turn := PI * k / PARTS
		var way := Vector2(-cos(turn), pow(sin(turn), 0.55))  # (z, y)
		var outer := Vector2(way.x * half, way.y * tall)
		var inner := Vector2(way.x * (half - wide), way.y * (tall - wide))
		var in_from := (inner - outer).normalized() * BEVEL
		var x := thick * 0.5
		var ring: Array[Vector3] = []
		for corner in [[outer + in_from, x], [outer, x - BEVEL], [outer, BEVEL - x], [outer + in_from, -x], [inner - in_from, -x], [inner, BEVEL - x], [inner, x - BEVEL], [inner - in_from, x]]:
			ring.append(Vector3(corner[1], corner[0].y, corner[0].x))
		rings.append(ring)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in 8:
		tool.set_smooth_group(side)
		for k in PARTS:
			var a: Vector3 = rings[k][side]
			var b: Vector3 = rings[k][(side + 1) % 8]
			var c: Vector3 = rings[k + 1][side]
			var d: Vector3 = rings[k + 1][(side + 1) % 8]
			for p in [a, b, c, b, d, c]:
				tool.add_vertex(p)
	tool.generate_normals()
	return tool.commit()


static func _rod(radius: float, length: float) -> CapsuleMesh:
	var rod := CapsuleMesh.new()
	rod.radius = radius
	rod.height = length
	rod.radial_segments = 16
	rod.rings = 4
	return rod


# A honey butcher-block counter top: planks of slightly different tone.
static func counter_wood() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WOOD
	material.set_shader_parameter("light_wood", Color("#BB8355"))
	material.set_shader_parameter("dark_wood", Color("#9C6941"))
	material.set_shader_parameter("grain", 26.0)
	material.set_shader_parameter("planks", 14.0)
	return material


# A pale pastry board dusted with flour: light enough that dough reads on it.
static func pastry_wood() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WOOD
	material.set_shader_parameter("light_wood", Color("#F4DDB6"))
	material.set_shader_parameter("dark_wood", Color("#E5C597"))
	material.set_shader_parameter("grain", 30.0)
	material.set_shader_parameter("planks", 6.0)
	material.set_shader_parameter("flour", 0.7)
	return material


# Puts `material` on every mesh under `root` (a fitted model, e.g. a KayKit board).
static func dress(root: Node, material: Material) -> void:
	for part in root.find_children("*", "MeshInstance3D", true, false):
		(part as MeshInstance3D).material_override = material
	if root is MeshInstance3D:
		(root as MeshInstance3D).material_override = material


# A soup's surface: glossy, with a slow swirl, a darker edge and a few rising
# bubbles. `color` is the soup's; set it again with set_soup_color.
static func soup(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SOUP
	material.set_shader_parameter("soup", color)
	return material


static func set_soup_color(material: Material, color: Color) -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("soup", color)
	elif material is StandardMaterial3D:
		(material as StandardMaterial3D).albedo_color = color


# A rounded handle along +z from `from_z` for `length`, at height `y`.
static func _handle(parent: Node3D, y: float, from_z: float, length: float, radius := 0.011, flat := 0.75) -> MeshInstance3D:
	var handle := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = length
	mesh.radial_segments = 10
	mesh.rings = 3
	mesh.material = handle_wood()
	handle.mesh = mesh
	handle.rotation.x = PI * 0.5
	handle.scale = Vector3(flat, 1.0, 1.0)
	handle.position = Vector3(0.0, y, from_z + length * 0.5)
	parent.add_child(handle)
	return handle


# Two brass rivets through a flat handle at height `y`.
static func _rivets(parent: Node3D, y: float, at_z: Array, half_width: float) -> void:
	var brass := steel(BRASS)
	brass.roughness = 0.35
	for z in at_z:
		for side in [-1.0, 1.0]:
			var rivet := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.0028
			mesh.bottom_radius = 0.0028
			mesh.height = 0.001
			mesh.radial_segments = 8
			mesh.material = brass
			rivet.mesh = mesh
			rivet.rotation.z = PI * 0.5
			rivet.position = Vector3(side * half_width, y, z)
			parent.add_child(rivet)


# A chef's knife, origin at the middle of the blade's edge, the blade along -z
# and the handle toward +z. `blade_length` stretches it (a scraper over a board).
static func knife(blade_length := 0.14, blade_height := 0.04) -> Node3D:
	var root := Node3D.new()
	var blade_steel := steel()
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.003, blade_height, blade_length)
	blade_mesh.material = blade_steel
	blade.mesh = blade_mesh
	blade.position = Vector3(0.0, blade_height * 0.5, -0.01)
	root.add_child(blade)
	var tip := MeshInstance3D.new()  # The rounded point.
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = blade_height * 0.5
	tip_mesh.bottom_radius = blade_height * 0.5
	tip_mesh.height = 0.003
	tip_mesh.radial_segments = 16
	tip_mesh.material = blade_steel
	tip.mesh = tip_mesh
	tip.rotation.z = PI * 0.5
	tip.position = Vector3(0.0, blade_height * 0.5, -0.01 - blade_length * 0.5)
	root.add_child(tip)
	var spine := MeshInstance3D.new()
	var spine_mesh := BoxMesh.new()
	spine_mesh.size = Vector3(0.0045, 0.006, blade_length + 0.01)
	spine_mesh.material = steel(SAGE_STEEL)
	spine.mesh = spine_mesh
	spine.position = Vector3(0.0, blade_height - 0.002, -0.005)
	root.add_child(spine)
	var back := -0.01 + blade_length * 0.5  # Where the blade meets the bolster.
	var bolster := MeshInstance3D.new()
	var bolster_mesh := CylinderMesh.new()
	bolster_mesh.top_radius = 0.009
	bolster_mesh.bottom_radius = 0.011
	bolster_mesh.height = 0.012
	bolster_mesh.radial_segments = 10
	bolster_mesh.material = steel(SAGE_STEEL)
	bolster.mesh = bolster_mesh
	bolster.rotation.x = PI * 0.5
	var grip_y := blade_height * 0.8
	bolster.position = Vector3(0.0, grip_y, back + 0.006)
	root.add_child(bolster)
	_handle(root, grip_y, back + 0.012, 0.095)
	_rivets(root, grip_y, [back + 0.034, back + 0.069], 0.0085)
	return root


# A wooden spoon, origin at the tip of its bowl, the handle straight up.
static func wooden_spoon() -> Node3D:
	var root := Node3D.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("#C98B4E")
	wood.roughness = 0.75
	var bowl := MeshInstance3D.new()  # Rounded and flat, standing on its tip.
	var bowl_mesh := SphereMesh.new()
	bowl_mesh.radius = 0.03
	bowl_mesh.height = 0.06
	bowl_mesh.radial_segments = 20
	bowl_mesh.rings = 10
	bowl_mesh.material = wood
	bowl.mesh = bowl_mesh
	bowl.scale = Vector3(1.0, 1.35, 0.4)
	bowl.position.y = 0.04
	root.add_child(bowl)
	var hollow := MeshInstance3D.new()
	var hollow_mesh := bowl_mesh.duplicate() as SphereMesh
	var shade := wood.duplicate() as StandardMaterial3D
	shade.albedo_color = wood.albedo_color.darkened(0.22)
	hollow_mesh.material = shade
	hollow.mesh = hollow_mesh
	hollow.scale = Vector3(0.74, 1.05, 0.2)
	hollow.position = Vector3(0.0, 0.04, 0.0075)
	root.add_child(hollow)
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.bottom_radius = 0.0075
	handle_mesh.top_radius = 0.0105
	handle_mesh.height = 0.19
	handle_mesh.radial_segments = 12
	handle_mesh.material = wood
	handle.mesh = handle_mesh
	handle.position.y = 0.165
	root.add_child(handle)
	var knob := MeshInstance3D.new()
	var knob_mesh := SphereMesh.new()
	knob_mesh.radius = 0.0105
	knob_mesh.height = 0.021
	knob_mesh.material = wood
	knob.mesh = knob_mesh
	knob.position.y = 0.26
	root.add_child(knob)
	return root


# A balloon whisk, origin at the bottom of the wires, the handle straight up.
static func whisk() -> Node3D:
	var root := Node3D.new()
	var wire := steel()
	wire.metallic = 0.7
	for i in 4:
		var pivot := Node3D.new()
		pivot.rotation.y = i * PI / 4.0
		pivot.scale = Vector3(1.0, 1.6, 1.0)
		pivot.position.y = 0.026 * 1.6
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.0242
		mesh.outer_radius = 0.0272
		mesh.rings = 24
		mesh.ring_segments = 5
		mesh.material = wire
		ring.mesh = mesh
		ring.rotation.x = PI * 0.5  # Standing up.
		pivot.add_child(ring)
		root.add_child(pivot)
	var collar := MeshInstance3D.new()  # Where the wires gather.
	var collar_mesh := CylinderMesh.new()
	collar_mesh.top_radius = 0.009
	collar_mesh.bottom_radius = 0.006
	collar_mesh.height = 0.014
	collar_mesh.radial_segments = 10
	collar_mesh.material = steel(SAGE_STEEL)
	collar.mesh = collar_mesh
	collar.position.y = 0.083 + 0.004
	root.add_child(collar)
	var handle := MeshInstance3D.new()
	var handle_mesh := CapsuleMesh.new()
	handle_mesh.radius = 0.0105
	handle_mesh.height = 0.105
	handle_mesh.radial_segments = 10
	handle_mesh.rings = 3
	handle_mesh.material = handle_wood()
	handle.mesh = handle_mesh
	handle.position.y = 0.083 + 0.011 + 0.0525
	root.add_child(handle)
	return root


# A salt or spice shaker, origin at its middle, upright (cap up): a glass body
# showing what's in it, and a domed cap in `cap_color`.
static func shaker(filling_color: Color, cap_color: Color) -> Node3D:
	var root := Node3D.new()
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.92, 0.96, 1.0, 0.45)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.15
	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.022
	body_mesh.bottom_radius = 0.026
	body_mesh.height = 0.07
	body_mesh.material = glass
	body.mesh = body_mesh
	root.add_child(body)
	var inside := MeshInstance3D.new()
	var inside_mesh := CylinderMesh.new()
	inside_mesh.top_radius = 0.019
	inside_mesh.bottom_radius = 0.022
	inside_mesh.height = 0.04
	var filling := StandardMaterial3D.new()
	filling.albedo_color = filling_color
	inside_mesh.material = filling
	inside.mesh = inside_mesh
	inside.position.y = -0.012
	root.add_child(inside)
	var band := MeshInstance3D.new()  # The cap's screw band.
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.0235
	band_mesh.bottom_radius = 0.0235
	band_mesh.height = 0.01
	band_mesh.radial_segments = 16
	var cap_paint := StandardMaterial3D.new()
	cap_paint.albedo_color = cap_color
	cap_paint.roughness = 0.45
	band_mesh.material = cap_paint
	band.mesh = band_mesh
	band.position.y = 0.037
	root.add_child(band)
	var cap := MeshInstance3D.new()
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.0235
	cap_mesh.height = 0.024
	cap_mesh.is_hemisphere = true
	cap_mesh.material = cap_paint
	cap.mesh = cap_mesh
	cap.position.y = 0.042
	root.add_child(cap)
	return root


# A soft rounded block `size` big (a sponge, a folded cloth): a pill stretched
# to the size, so it has no sharp corners. Origin at its middle.
static func soft_block(size: Vector3, color: Color, roughness := 0.95) -> Node3D:
	var root := Node3D.new()
	root.scale = size
	var part := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0 + 0.6  # Longer than it's round, so the ends are rounded but the sides fairly flat.
	mesh.radial_segments = 16
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	mesh.material = material
	part.mesh = mesh
	part.rotation.z = PI * 0.5  # Lying along x.
	part.scale = Vector3(1.0 / 1.6, 1.0, 1.0)  # Back to 1 m long along x.
	root.add_child(part)
	return root


# A gas ring on the counter: a dark iron grate (`radius` across its middle) and a
# ring of little flames that show round a pan's edge. Origin: the counter under
# its middle; its top is 0.012 up.
static func gas_ring(radius := 0.2) -> Node3D:
	var burner := Node3D.new()
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.16, 0.15, 0.15)
	iron.roughness = 0.6
	var plate := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius * 1.05
	disc.height = 0.012
	disc.material = iron
	plate.mesh = disc
	plate.position.y = 0.006
	burner.add_child(plate)
	var flame := StandardMaterial3D.new()
	flame.albedo_color = Color(1.0, 0.62, 0.2)
	flame.emission_enabled = true
	flame.emission = Color(1.0, 0.5, 0.15)
	flame.emission_energy_multiplier = 2.0
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 12:
		var tongue := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.008
		cone.height = 0.012
		cone.radial_segments = 6
		cone.material = flame
		tongue.mesh = cone
		var spot := Vector2.from_angle(i * TAU / 12.0) * radius * 0.35
		tongue.position = Vector3(spot.x, 0.007, spot.y)
		burner.add_child(tongue)
	return burner
