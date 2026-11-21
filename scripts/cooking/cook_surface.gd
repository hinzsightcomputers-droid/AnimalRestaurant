# CookSurface: somewhere food sits in a close-up (a griddle, a plate...). Its
# position is the middle of its top; it draws itself as a placeholder slab or
# disc below that (unless the station already has one there: hidden). Steps
# find surfaces by node name ("Griddle", "Plate", "Board").
# One with slides_in (the plate beside the griddle) stays out of sight until a
# step first uses it, then slides in from the right (CookSession.bring_in).
class_name CookSurface
extends Node3D

@export var size := Vector2(0.6, 0.4)  # Width and depth (a round surface uses the width as its diameter).
@export var round := false
@export var thickness := 0.02
@export var color := Color(0.2, 0.2, 0.22)
@export var hidden := false
@export_range(0.0, 1.0) var ingredient_tint := 0.0  # How much it takes on the ingredients' color (a pot's broth).
@export var slides_in := false            # Out of sight until a step uses it.
@export var ledge := Vector3.ZERO          # Above zero: a counter top this big (x, thickness, z) under it.
@export_enum("plain", "griddle", "pastry", "tray", "board", "soup") var look := "plain"  # griddle: seasoned warm steel with a heat glow and a raised rim. pastry: a pale floured pastry board. tray: a sheet pan with a rolled rim. board: a light wood cutting board (on its model too, when hidden). soup: a glossy simmering soup (tint changes its color).
@export var depth := 0.0                  # A container (a saucepan, a bowl): how high liquid can come up in it.

var contents: Array[Node3D] = []  # What's been dropped in (e.g. chopped carrots in a pot).
var level := 0.0                  # A container: how full it is (1 = depth).
var liquid: MeshInstance3D = null # Its liquid, once there's some (see fill_to).
var _material := StandardMaterial3D.new()
var _home := Vector3.ZERO
var _soup: ShaderMaterial = null  # look "soup": its surface.


func _ready() -> void:
	_home = position
	if ledge != Vector3.ZERO:
		_build_ledge()
	if slides_in:
		visible = false
	if look == "board":  # A fitted stand-in model gets the wood too (a Meshy board keeps its own).
		for child in get_children():
			if child is ModelFit and not (child as ModelFit).model.resource_path.begins_with("res://design/restaurant/"):
				KitchenProps.dress(child, KitchenProps.board_wood())
	if hidden:
		return
	var mesh_instance := MeshInstance3D.new()
	var material := _material
	material.albedo_color = color
	material.roughness = 0.5
	if round:
		var disc := CylinderMesh.new()
		disc.top_radius = radius()
		disc.bottom_radius = radius() * 0.82
		disc.height = thickness
		disc.material = material
		mesh_instance.mesh = disc
	else:
		var slab := BoxMesh.new()
		slab.size = Vector3(size.x, thickness, size.y)
		slab.material = material
		mesh_instance.mesh = slab
	mesh_instance.position.y = -thickness * 0.5
	add_child(mesh_instance)
	if look == "griddle" and not round:
		_dress_griddle(mesh_instance)
	elif look in ["pastry", "board"]:
		mesh_instance.material_override = KitchenProps.pastry_wood() if look == "pastry" else KitchenProps.board_wood()
		mesh_instance.position.y += 0.003  # Just proud of the counter (or worktop) it sits on, so they don't flicker.
	elif look == "tray" and not round:
		_dress_tray(mesh_instance)
	elif look == "soup":
		var soup := KitchenProps.soup(color)
		soup.set_shader_parameter("radius", radius())
		mesh_instance.material_override = soup
		_soup = soup


# The griddle's look: its top in the griddle shader (the heat glow), set into
# the Meshy griddle (design/restaurant), whose lip runs just outside its edges so
# food never sits under it; without the model, a rounded steel rim instead,
# lower at the front where the spatula comes in.
const GRIDDLE_SHADER := preload("res://assets/shaders/griddle.gdshader")
const GRIDDLE_MODEL := "res://design/restaurant/griddle.glb"
const GRIDDLE_MARGIN := Vector2(0.16, 0.12)  # The model is this much bigger than the cooking top (its lip).
const GRIDDLE_HEIGHT := 0.16                  # How tall it's fitted; the rest sinks into the counter.
const GRIDDLE_LIP := 0.012                    # Its lip stands this far over the cooking top.
const RIM_STEEL := Color("#A9B3A4")  # The style guide's soft sage steel, lit.
func _dress_griddle(top: MeshInstance3D) -> void:
	var shader := ShaderMaterial.new()
	shader.shader = GRIDDLE_SHADER
	shader.set_shader_parameter("size", size)
	top.material_override = shader
	var body := ModelFit.place(GRIDDLE_MODEL, self, Vector3(0.0, GRIDDLE_LIP - GRIDDLE_HEIGHT, 0.0), Vector3(size.x + GRIDDLE_MARGIN.x, GRIDDLE_HEIGHT, size.y + GRIDDLE_MARGIN.y))
	if body != null:
		body.stretch = true
		return
	var steel := StandardMaterial3D.new()
	steel.albedo_color = RIM_STEEL
	steel.roughness = 0.45
	steel.metallic = 0.3
	_add_rim(0.022, [0.03, 0.012, 0.03, 0.03], steel)


# A sheet pan: soft light steel with a low rolled rim all round.
func _dress_tray(top: MeshInstance3D) -> void:
	var pan := StandardMaterial3D.new()
	pan.albedo_color = Color("#C9CFC4")
	pan.roughness = 0.4
	pan.metallic = 0.3
	top.material_override = pan
	var rim_steel := pan.duplicate() as StandardMaterial3D
	rim_steel.albedo_color = RIM_STEEL
	_add_rim(0.012, [0.014, 0.014, 0.014, 0.014], rim_steel)


# A rounded rim `rim` thick just outside the edges: back, front, left and right
# `heights` tall.
func _add_rim(rim: float, heights: Array, steel: Material) -> void:
	var sides := [  # [middle x, middle z, length, along x?, height]
		[0.0, -size.y * 0.5 - rim * 0.5, size.x + rim * 2.0, true, heights[0]],
		[0.0, size.y * 0.5 + rim * 0.5, size.x + rim * 2.0, true, heights[1]],
		[-size.x * 0.5 - rim * 0.5, 0.0, size.y, false, heights[2]],
		[size.x * 0.5 + rim * 0.5, 0.0, size.y, false, heights[3]],
	]
	for side in sides:
		var bar := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()  # Rounded ends and edges: chunky, no sharp corners.
		capsule.radius = rim * 0.5
		capsule.height = side[2]
		capsule.radial_segments = 12
		capsule.rings = 2
		capsule.material = steel
		bar.mesh = capsule
		bar.scale = Vector3(side[4] / rim, 1.0, 1.0)  # Taller than it is wide (local x points up after the turn below).
		bar.rotation = Vector3(0.0, 0.0 if side[3] else PI * 0.5, PI * 0.5)
		bar.position = Vector3(side[0], side[4] * 0.5 - thickness * 0.3, side[1])
		add_child(bar)


func tint(new_color: Color) -> void:
	color = new_color
	_material.albedo_color = new_color
	if _soup != null:
		KitchenProps.set_soup_color(_soup, new_color)


func radius() -> float:
	return size.x * 0.5


# A container: its liquid up to `new_level` (of depth), in `liquid_color` if given.
func fill_to(new_level: float, liquid_color = null) -> void:
	level = maxf(new_level, 0.0)
	if liquid == null:
		liquid = MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius() * 0.94
		mesh.bottom_radius = radius() * 0.94
		mesh.height = 0.004
		mesh.radial_segments = 32
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.25
		mesh.material = material
		liquid.mesh = mesh
		liquid.set_meta("food", true)  # Served with the dish (CookSession.snapshot), unlike the surface itself.
		add_child(liquid)
	if liquid_color is Color:
		set_liquid_color(liquid_color)
	liquid.visible = level > 0.001
	liquid.position.y = depth * minf(level, 1.0)


func liquid_color() -> Color:
	return (liquid.mesh.material as StandardMaterial3D).albedo_color if liquid != null else color


func set_liquid_color(new_color: Color) -> void:
	if liquid != null:
		(liquid.mesh.material as StandardMaterial3D).albedo_color = new_color


# The top of its liquid (or of the surface, without any), in the session.
func liquid_top() -> float:
	return position.y + (depth * minf(level, 1.0) if liquid != null and liquid.visible else 0.0)


# The point moved onto this surface if it's off it, at least `inset` in from
# the edge (so something that big stays on it).
func keep_inside(point: Vector3, inset := 0.0) -> Vector3:
	var flat := Vector2(point.x - position.x, point.z - position.z)
	if round:
		flat = flat.limit_length(maxf(radius() - inset, 0.0))
	else:
		var half := (size * 0.5 - Vector2.ONE * inset).max(Vector2.ZERO)
		flat = flat.clamp(-half, half)
	return Vector3(position.x + flat.x, point.y, position.z + flat.y)


# How far the point is from this surface's nearest edge (negative when off it).
func edge_room(point: Vector3) -> float:
	var offset := Vector2(point.x - position.x, point.z - position.z)
	if round:
		return radius() - offset.length()
	return minf(size.x * 0.5 - absf(offset.x), size.y * 0.5 - absf(offset.y))


# Whether a point (in the session's coordinates) is over this surface. A
# negative margin asks whether something that big fits inside it.
func contains(point: Vector3, margin := 0.0) -> bool:
	var offset := Vector2(point.x - position.x, point.z - position.z)
	if round:
		return offset.length() <= radius() + margin
	return absf(offset.x) <= size.x * 0.5 + margin and absf(offset.y) <= size.y * 0.5 + margin


# Out of sight until now (slides_in): slides in from the right, `distance` away.
func slide_in(distance := 0.8, seconds := 0.45) -> void:
	if visible:
		return
	visible = true
	# Only what it draws slides: it stays where it is, so a step can aim at it straight away.
	var shift := [distance]
	for child in get_children():
		if child is Node3D:
			child.position.x += distance
	create_tween().tween_method(func(to: float):
		for child in get_children():
			if child is Node3D:
				child.position.x += to - shift[0]
		shift[0] = to, distance, 0.0, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# A wooden counter top under it, its top just below this surface's bottom.
func _build_ledge() -> void:
	var slab := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = ledge
	mesh.material = KitchenProps.counter_wood()  # Butcher block, like the chopping corner (a flat color reads as orange under the warm light).
	slab.mesh = mesh
	slab.position.y = -thickness - ledge.y * 0.5
	add_child(slab)
