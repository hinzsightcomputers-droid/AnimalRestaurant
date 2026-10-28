# CookSurface: somewhere food sits in a close-up (a griddle, a plate...). Its
# position is the middle of its top; it draws itself as a placeholder slab or
# disc below that (unless the station already has one there: hidden). Steps
# find surfaces by node name ("Griddle", "Plate", "Board").
class_name CookSurface
extends Node3D

@export var size := Vector2(0.6, 0.4)  # Width and depth (a round surface uses the width as its diameter).
@export var round := false
@export var thickness := 0.02
@export var color := Color(0.2, 0.2, 0.22)
@export var hidden := false
@export_range(0.0, 1.0) var ingredient_tint := 0.0  # How much it takes on the ingredients' color (a pot's broth).

var contents: Array[Node3D] = []  # What's been dropped in (e.g. chopped carrots in a pot).
var _material := StandardMaterial3D.new()


func _ready() -> void:
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


# Whether a point (in the session's coordinates) is over this surface. A
# negative margin asks whether something that big fits inside it.
func contains(point: Vector3, margin := 0.0) -> bool:
	var offset := Vector2(point.x - position.x, point.z - position.z)
	if round:
		return offset.length() <= radius() + margin
	return absf(offset.x) <= size.x * 0.5 + margin and absf(offset.y) <= size.y * 0.5 + margin
