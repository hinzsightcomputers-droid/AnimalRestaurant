# CookedDish: a finished plate a player is carrying, with its cooking quality (0..1).
# A dish cooked as a close-up recipe also keeps how it actually came out (its
# look), so the plate you carry and the one you serve show that. Other dishes
# show their model from data/dishes.json.
class_name CookedDish
extends RefCounted

var order: Order
var quality: float
# The close-up plate's food as plain meshes: [{ mesh, material, transform }],
# placed around the top middle of a plate look_radius wide. Empty otherwise.
var look: Array = []
var look_radius := 0.0


func _init(for_order: Order, cooked_quality: float) -> void:
	order = for_order
	quality = cooked_quality


func dish_name() -> String:
	return order.dish.get("name", "Dish")


# Puts the dish on another plate: `at` is that plate's top middle under
# `parent`, `plate_radius` its size. The close-up look if there is one, else
# the dish's model. Returns the node holding it (free it to take it away), or
# null when there's neither.
func show_look(parent: Node3D, at: Vector3, plate_radius: float) -> Node3D:
	if look.is_empty() or look_radius <= 0.0:
		var width := plate_radius * 1.5
		return ModelFit.place(order.dish.get("model", ""), parent, at, Vector3(width, 0.0, width))
	var holder := Node3D.new()
	holder.position = at
	holder.scale = Vector3.ONE * (plate_radius / look_radius)
	for part in look:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = part["mesh"]
		mesh_instance.material_override = part["material"]
		mesh_instance.transform = part["transform"]
		holder.add_child(mesh_instance)
	parent.add_child(holder)
	return holder
