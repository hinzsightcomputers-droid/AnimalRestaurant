# DishBinModel: a grey tub, open at the top, with dishes stacked inside. Its
# origin is the middle of its bottom. Used wherever a dish bin shows: in a
# player's hands, waiting by the sink, and in the clearing and washing close-ups.
class_name DishBinModel
extends Node3D

const DISH_SIZE := 0.24          # How wide a dish is in the bin.
const DISH_STEP := 0.014         # How much higher each stacked dish sits.

@export var size := Vector3(0.4, 0.13, 0.3)
@export var color := Color(0.55, 0.6, 0.66)

var contents := Node3D.new()     # The dishes, bottom first.


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	var wall := 0.012
	_slab(Vector3(size.x, wall, size.z), Vector3(0.0, wall * 0.5, 0.0), material)
	for side in [-1.0, 1.0]:
		_slab(Vector3(wall, size.y, size.z), Vector3(side * (size.x - wall) * 0.5, size.y * 0.5, 0.0), material)
		_slab(Vector3(size.x, size.y, wall), Vector3(0.0, size.y * 0.5, side * (size.z - wall) * 0.5), material)
	contents.position.y = wall
	add_child(contents)


# Shows these dish models stacked inside (replacing what was there).
func set_dishes(models: Array) -> void:
	for child in contents.get_children():
		child.queue_free()
	for model in models:
		var dish := ModelFit.place(model, contents, Vector3.ZERO, Vector3(DISH_SIZE, 0.0, DISH_SIZE))
		if dish != null:
			_settle(dish, contents.get_child_count() - 1)


# Where the next dish goes, in this bin's parent's coordinates.
func next_spot() -> Vector3:
	return transform * (contents.position + _offset(contents.get_child_count()))


# Takes a dish node (already in the scene) and keeps it, on top of the stack.
func add(dish: Node3D) -> void:
	var index := contents.get_child_count()
	dish.reparent(contents)
	_settle(dish, index)


# The top dish, or null.
func top() -> Node3D:
	return contents.get_child(-1) as Node3D if contents.get_child_count() > 0 else null


func _settle(dish: Node3D, index: int) -> void:
	dish.position = _offset(index)
	dish.rotation = Vector3(0.0, index * 0.9, 0.0)


func _offset(index: int) -> Vector3:
	return Vector3(sin(index * 2.3) * 0.02, index * DISH_STEP, cos(index * 2.3) * 0.015)


func _slab(slab_size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = slab_size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	add_child(instance)
