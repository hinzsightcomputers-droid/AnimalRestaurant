# ChefBuilder: dresses a ChefModel from a CharacterAppearance. Everyone has the
# same base body (data/appearance.json's base_body, on the shared KayKit
# Rig_Medium skeleton), skin colored. On top of it:
#   - clothes and hair made as skinned meshes go under the shared Skeleton3D,
#     so they bend with every animation;
#   - simple shapes (placeholder hair, glasses) ride on a bone (BoneAttachment3D);
#   - body regions an item `hides` are hidden, so they don't poke through;
#   - under a hat, hair is swapped for its `hat_variant`.
# The face is ChefFace's. Build once (build_base), then dress() for each look.
class_name ChefBuilder
extends RefCounted

const TINT := preload("res://assets/shaders/tint.gdshader")

var face := ChefFace.new()
var skin := ShaderMaterial.new()
var hair := ShaderMaterial.new()
var regions := {}  # region -> [MeshInstance3D] of the base body.

var _chef: ChefModel
var _worn: Array[Node] = []  # Everything dress() added, freed on the next dress().


func _init(chef: ChefModel) -> void:
	_chef = chef
	skin.shader = TINT
	hair.shader = TINT
	hair.set_shader_parameter("roughness", 0.6)


static func base_data() -> Dictionary:
	return Wardrobe.looks().get("base_body", {})


# Sets up the base body in `model` (the base_body scene, already in the tree).
func build_base(model: Node3D) -> void:
	var base := base_data()
	for part in base.get("drop", []):
		var node := model.find_child(part)
		if node != null:
			node.get_parent().remove_child(node)
			node.queue_free()
	for region in base.get("regions", {}):
		var meshes: Array = []
		for part in base["regions"][region]:
			var mesh := model.find_child(part) as MeshInstance3D
			if mesh != null:
				mesh.material_override = skin
				meshes.append(mesh)
		regions[region] = meshes
	_chef.add_child(face)
	var head: Dictionary = base.get("head", {})
	var real_head := model.find_child(String(head.get("mesh", "-"))) as MeshInstance3D
	if real_head != null and _put_face_on(real_head):
		return
	# The stand-in head: an ellipsoid, with the face plate over its front.
	var center := _vector(head.get("center", [0, 1.7, 0]))
	var radii := _vector(head.get("radii", [0.55, 0.53, 0.5]))
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radial_segments = 32
	sphere.rings = 16
	ball.mesh = sphere  # Radius 0.5: scaled up to the radii.
	ball.material_override = skin
	_chef.attach("head", ball, Transform3D(Basis.from_scale(radii * 2.0), center))
	var plate_data: Dictionary = Wardrobe.looks().get("face", {}).get("plate", {})
	var plate := MeshInstance3D.new()
	plate.name = "FacePlate"
	plate.mesh = ChefFace.make_plate(center, radii, Vector2(float(plate_data.get("width", 0.9)), float(plate_data.get("height", 0.9))) * 2.0)
	plate.material_override = face.material
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chef.attach("head", plate, Transform3D.IDENTITY)


# A real head draws the face on its surface named "Face" (skin underneath, the
# face over it); the rest of it is skin. False if it has no such surface.
func _put_face_on(head: MeshInstance3D) -> bool:
	var found := false
	for surface in head.mesh.get_surface_count():
		var material := head.mesh.surface_get_material(surface)
		if head.mesh is ArrayMesh and (head.mesh as ArrayMesh).surface_get_name(surface) == "Face" or material != null and material.resource_name == "Face":
			var skin_under := skin.duplicate() as ShaderMaterial
			skin_under.next_pass = face.material
			head.set_surface_override_material(surface, skin_under)
			found = true
		else:
			head.set_surface_override_material(surface, skin)
	return found


func dress(look: CharacterAppearance) -> void:
	for node in _worn:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)  # Out now, so the new pieces keep their names.
			node.queue_free()
	_worn.clear()
	skin.set_shader_parameter("tint", look.skin_color)
	hair.set_shader_parameter("tint", look.hair_color)
	var hidden := {}
	var hat_on := not look.worn("hat").is_empty()
	for id in look.worn_items():
		var item := Wardrobe.get_item(id)
		if item.is_empty():
			push_warning("Chef is wearing %s, which isn't in the wardrobe" % id)
			continue
		if item["slot"] == "hair" and hat_on and item.has("hat_variant"):
			item = Wardrobe.get_item(item["hat_variant"])
		for region in item.get("hides", []):
			hidden[region] = true
		if item.has("mesh"):
			_put_on_mesh(item)
		_put_on_parts(item)
	for region in regions:
		for mesh in regions[region]:
			mesh.visible = not hidden.has(region)
	face.apply(look)


# The item's meshes, moved under the shared skeleton so they're skinned to it.
func _put_on_mesh(item: Dictionary) -> void:
	var mesh_data: Dictionary = item["mesh"]
	var scene := load(String(mesh_data.get("scene", ""))) as PackedScene
	if scene == null:
		push_warning("Wardrobe item %s: can't load %s" % [item["id"], mesh_data.get("scene", "")])
		return
	var source := scene.instantiate()
	var names: Array = mesh_data.get("nodes", [])
	var meshes := source.find_children("*", "MeshInstance3D", true, false).filter(func(mesh): return names.is_empty() or String(mesh.name) in names)
	for mesh: MeshInstance3D in meshes:
		mesh.owner = null
		mesh.get_parent().remove_child(mesh)
		mesh.name = "%s_%s" % [item["id"], mesh.name]
		_chef.skeleton.add_child(mesh)
		mesh.skeleton = NodePath("..")
		if item["slot"] == "hair":
			mesh.material_override = hair
		_worn.append(mesh)
	source.free()


# Simple shapes held by a bone (see Wardrobe "parts").
func _put_on_parts(item: Dictionary) -> void:
	for part in item.get("parts", []):
		var shape := MeshInstance3D.new()
		shape.mesh = _shape(part)
		if part.has("color"):
			var material := StandardMaterial3D.new()
			material.albedo_color = Color.from_string(String(part["color"]), Color.WHITE)
			shape.material_override = material
		elif item["slot"] == "hair":
			shape.material_override = hair
		var basis := Basis.from_euler(_vector(part.get("rotation", [0, 0, 0])) * (PI / 180.0)) * Basis.from_scale(_vector(part.get("scale", [1, 1, 1])))
		_chef.attach(String(part.get("bone", "head")), shape, Transform3D(basis, _vector(part.get("at", [0, 0, 0]))))
		_worn.append(shape.get_parent())


static func _shape(part: Dictionary) -> Mesh:
	if part.has("box"):
		var box := BoxMesh.new()
		box.size = _vector(part["box"])
		return box
	if part.has("cylinder"):
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = float(part["cylinder"][0])
		cylinder.bottom_radius = cylinder.top_radius
		cylinder.height = float(part["cylinder"][1])
		return cylinder
	if part.has("torus"):
		var torus := TorusMesh.new()
		torus.inner_radius = float(part["torus"][0])
		torus.outer_radius = float(part["torus"][1])
		return torus
	var sphere := SphereMesh.new()
	sphere.radius = float(part.get("sphere", 0.5))
	sphere.height = sphere.radius * 2.0
	return sphere


static func _vector(values) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2])) if values is Array and values.size() >= 3 else Vector3.ZERO
