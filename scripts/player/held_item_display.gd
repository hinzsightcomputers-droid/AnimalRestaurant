# HeldItemDisplay: shows what something is holding (a plate, an ingredient
# crate, a dish bin, a drink or the bill, a takeout bag, and a label above it). Works for a Player or a PassCounter: anything
# with `held_item` and a `held_item_changed` signal. Display only.
extends Node3D

@export var holder: Node        # A Player or PassCounter.
@export var plate: Node3D       # The plate model.
@export var food: MeshInstance3D
@export var crate: Node3D       # The ingredient crate model.
@export var crate_contents: MeshInstance3D

@onready var label: Label3D = $Label

const PLATE_TOP := 0.046    # The plate model's top, above its bottom...
const PLATE_RADIUS := 0.22  # ...and its size, for a dish's own look.
const CRATE_SIZE := Vector3(0.42, 0.22, 0.32)  # The plain crate, for an ingredient's own model.

var _food_material := StandardMaterial3D.new()
var _contents_material := StandardMaterial3D.new()
var _look: Node3D = null    # The dish (as it came out, or its model) instead of the plain food.
var _ingredients_model: Node3D = null  # Ingredients' own model instead of the plain crate.
var _bin_model: DishBinModel = null
var _extra: Node3D = null  # A drink or the bill.


func _ready() -> void:
	food.material_override = _food_material
	crate_contents.material_override = _contents_material
	holder.held_item_changed.connect(_on_held_item_changed)
	_on_held_item_changed(holder.held_item)


func _on_held_item_changed(item: RefCounted) -> void:
	var dish := item as CookedDish
	var ingredients := item as Ingredients
	var bin := item as DishBin
	plate.visible = dish != null
	crate.visible = ingredients != null
	label.visible = item != null
	if _look != null:
		_look.queue_free()
		_look = null
	if _ingredients_model != null:
		_ingredients_model.queue_free()
		_ingredients_model = null
	if _bin_model != null:
		_bin_model.queue_free()
		_bin_model = null
	if _extra != null:
		_extra.queue_free()
		_extra = null
	if dish != null:
		_look = dish.show_look(food.get_parent(), Vector3(0.0, PLATE_TOP, 0.0), PLATE_RADIUS)
		food.visible = _look == null
		label.text = "%s (%s)" % [dish.dish_name(), CookingMinigame.quality_label(dish.quality)]
		# Better food looks golden, burnt food looks dark.
		_food_material.albedo_color = Color(0.3, 0.2, 0.15).lerp(Color(0.95, 0.7, 0.3), dish.quality)
	elif ingredients != null:
		label.text = ingredients.display_name() + (" (%s first)" % ingredients.chop_verb().to_lower() if ingredients.needs_chopping() else "")
		if ingredients.chop_quality >= 0.0:
			label.text += " (%s)" % CookingMinigame.quality_label(ingredients.chop_quality)
		_contents_material.albedo_color = ingredients.color()
		var bottom := crate.position - Vector3(0.0, CRATE_SIZE.y * 0.5, 0.0)
		_ingredients_model = ModelFit.place(ingredients.model_path(), crate.get_parent(), bottom, Vector3(CRATE_SIZE.x, 0.0, CRATE_SIZE.z))
		crate.visible = _ingredients_model == null
	elif item is Drink:
		label.text = "%s (%s)" % [item.display_name(), CookingMinigame.quality_label(item.quality)]
		_extra = DrinkModel.make(item.drink)
		_extra.scale = Vector3.ONE * 1.4
		crate.get_parent().add_child(_extra)
		_extra.position = crate.position - Vector3(0.0, CRATE_SIZE.y * 0.5, 0.0)
	elif item is Receipt:
		label.text = item.display_name()
		_extra = _receipt_model()
		crate.get_parent().add_child(_extra)
		_extra.position = crate.position
	elif item is TakeoutBag:
		label.text = item.display_name()
		_extra = TakeoutBag.make_model()
		crate.get_parent().add_child(_extra)
		_extra.position = crate.position - Vector3(0.0, CRATE_SIZE.y * 0.5, 0.0)
	elif bin != null:
		label.text = bin.display_name()
		_bin_model = DishBinModel.new()
		crate.get_parent().add_child(_bin_model)
		_bin_model.position = crate.position - Vector3(0.0, CRATE_SIZE.y * 0.5, 0.0)
		_bin_model.set_dishes(bin.dishes)


# A folded slip of paper.
func _receipt_model() -> Node3D:
	var slip := MeshInstance3D.new()
	var paper := BoxMesh.new()
	paper.size = Vector3(0.16, 0.01, 0.24)
	slip.mesh = paper
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.98, 0.96, 0.9)
	slip.material_override = material
	slip.rotation_degrees = Vector3(-20, 0, 0)
	return slip
