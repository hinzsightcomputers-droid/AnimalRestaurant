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
@export var ledge_color := Color(0.55, 0.36, 0.22)

var contents: Array[Node3D] = []  # What's been dropped in (e.g. chopped carrots in a pot).
var _material := StandardMaterial3D.new()
var _home := Vector3.ZERO


func _ready() -> void:
	_home = position
	if ledge != Vector3.ZERO:
		_build_ledge()
	if slides_in:
		visible = false
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


func tint(new_color: Color) -> void:
	color = new_color
	_material.albedo_color = new_color


func radius() -> float:
	return size.x * 0.5


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
	position = _home + Vector3(distance, 0.0, 0.0)
	create_tween().tween_property(self, "position", _home, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# A wooden counter top under it, its top just below this surface's bottom.
func _build_ledge() -> void:
	var slab := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = ledge
	var wood := StandardMaterial3D.new()
	wood.albedo_color = ledge_color
	wood.roughness = 0.8
	mesh.material = wood
	slab.mesh = mesh
	slab.position.y = -thickness - ledge.y * 0.5
	add_child(slab)
