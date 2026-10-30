# TakeoutBag: something packed to go at the takeout counter (TakeoutCounter):
# a cooked dish (for the courier, or a gift) or one thing from the pantry (a
# gift). Carried like any other held item.
class_name TakeoutBag
extends RefCounted

var dish: CookedDish = null
var item_id := ""  # A pantry item, when there's no dish.


static func of_dish(cooked: CookedDish) -> TakeoutBag:
	var bag := TakeoutBag.new()
	bag.dish = cooked
	return bag


static func of_item(pantry_item: String) -> TakeoutBag:
	var bag := TakeoutBag.new()
	bag.item_id = pantry_item
	return bag


# What's in it: a dish id, or a pantry item id.
func contents_id() -> String:
	return String(dish.order.dish.get("id", "")) if dish != null else item_id


func contents_name() -> String:
	return dish.dish_name() if dish != null else Pantry.item_name(item_id)


func display_name() -> String:
	return "%s (to go)" % contents_name()


# Someone's phoned-in order, waiting for the courier (not for giving away).
func is_delivery() -> bool:
	return dish != null and dish.order != null and dish.order.is_delivery() and dish.order.caller.get("kind", "") != "takeout"


# A brown paper bag with its top folded over, its bottom at the origin.
static func make_model(scale := 1.0) -> Node3D:
	var bag := Node3D.new()
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.72, 0.55, 0.36)
	paper.roughness = 0.9
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.24, 0.26, 0.16) * scale
	box.material = paper
	body.mesh = box
	body.position.y = 0.13 * scale
	bag.add_child(body)
	var fold := MeshInstance3D.new()
	var fold_box := BoxMesh.new()
	fold_box.size = Vector3(0.245, 0.05, 0.12) * scale
	var darker := paper.duplicate() as StandardMaterial3D
	darker.albedo_color = paper.albedo_color.darkened(0.15)
	fold_box.material = darker
	fold.mesh = fold_box
	fold.position = Vector3(0.0, 0.27 * scale, 0.02 * scale)
	fold.rotation_degrees.x = -20.0
	bag.add_child(fold)
	var sticker := MeshInstance3D.new()
	var sticker_mesh := CylinderMesh.new()
	sticker_mesh.top_radius = 0.035 * scale
	sticker_mesh.bottom_radius = 0.035 * scale
	sticker_mesh.height = 0.004
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.25, 0.2)
	sticker_mesh.material = red
	sticker.mesh = sticker_mesh
	sticker.rotation_degrees.x = 90.0
	sticker.position = Vector3(0.0, 0.17 * scale, 0.082 * scale)
	bag.add_child(sticker)
	return bag
