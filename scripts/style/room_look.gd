# RoomLook: the room art pass's colours. The KayKit restaurant pieces (walls,
# floors, counters, cabinets, sink, tables, chairs) all paint from one colour
# sheet; this swaps in a copy moved into the art guide's palette (teal to warm
# wood, orange to honey wood, white to cream, red to brick: made by
# tools/make_warm_atlas.gd). The fridge, ovens and microwave get a second
# sheet where teal goes sage steel instead of wood. Only the look changes. The
# stoves, which are being remade in Meshy, keep theirs. Lives in the room;
# watches the whole restaurant it's part of, including pieces added later (a
# new stage, a bought station).
class_name RoomLook
extends Node

const SHEET := "restaurantbits_extra.png"
const WARM := preload("res://assets/textures/room_warm_atlas.png")
const APPLIANCE_SHEET := preload("res://assets/textures/room_appliance_atlas.png")
const LEFT_ALONE := ["stove"]  # Meshy will replace these.
const APPLIANCES := ["oven", "microwave", "fridge"]

var _warm := {}  # [original material, appliance?] -> its warm copy.
var _root: Node


func _ready() -> void:
	_root = get_parent().get_parent() if get_parent().get_parent() != null else get_parent()
	for mesh in _root.find_children("*", "MeshInstance3D", true, false):
		_dress(mesh)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is MeshInstance3D and _root.is_ancestor_of(node):
		var ref: WeakRef = weakref(node)
		(func(): _dress(ref.get_ref())).call_deferred()  # Once its model has finished setting up (unless it has gone by then).


func _dress(mesh: MeshInstance3D) -> void:
	if not is_instance_valid(mesh) or mesh.mesh == null:
		return
	var model := _model_file(mesh)
	if _named_any(model, LEFT_ALONE):
		return
	var appliance := _named_any(model, APPLIANCES)
	for surface in mesh.mesh.get_surface_count():
		var own := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
		if own == null or own.albedo_texture == null or not own.albedo_texture.resource_path.ends_with(SHEET):
			continue
		var key := [own, appliance]
		if not _warm.has(key):
			var warm := own.duplicate() as StandardMaterial3D
			warm.albedo_texture = APPLIANCE_SHEET if appliance else WARM
			_warm[key] = warm
		mesh.set_surface_override_material(surface, _warm[key])


# The model file (a .gltf or .glb) a mesh came from, lower case, or "".
func _model_file(mesh: Node) -> String:
	var at := mesh
	while at != null and at != _root:
		var file := at.scene_file_path.get_file().to_lower()
		if file.ends_with(".gltf") or file.ends_with(".glb"):
			return file
		at = at.get_parent()
	return ""


func _named_any(file: String, words: Array) -> bool:
	for word in words:
		if word in file:
			return true
	return false
