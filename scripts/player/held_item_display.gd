# HeldItemDisplay: shows what something is holding (a plate or an ingredient
# crate, and a label above it). Works for a Player or a PassCounter: anything
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


func _ready() -> void:
	food.material_override = _food_material
	crate_contents.material_override = _contents_material
	holder.held_item_changed.connect(_on_held_item_changed)
	_on_held_item_changed(holder.held_item)


func _on_held_item_changed(item: RefCounted) -> void:
	var dish := item as CookedDish
	var ingredients := item as Ingredients
	plate.visible = dish != null
	crate.visible = ingredients != null
	label.visible = item != null
	if _look != null:
		_look.queue_free()
		_look = null
	if _ingredients_model != null:
		_ingredients_model.queue_free()
		_ingredients_model = null
	if dish != null:
		_look = dish.show_look(food.get_parent(), Vector3(0.0, PLATE_TOP, 0.0), PLATE_RADIUS)
		food.visible = _look == null
		label.text = "%s (%s)" % [dish.dish_name(), CookingMinigame.quality_label(dish.quality)]
		# Better food looks golden, burnt food looks dark.
		_food_material.albedo_color = Color(0.3, 0.2, 0.15).lerp(Color(0.95, 0.7, 0.3), dish.quality)
	elif ingredients != null:
		label.text = ingredients.display_name() + (" (chop first)" if ingredients.needs_chopping() else "")
		_contents_material.albedo_color = ingredients.color()
		var bottom := crate.position - Vector3(0.0, CRATE_SIZE.y * 0.5, 0.0)
		_ingredients_model = ModelFit.place(ingredients.model_path(), crate.get_parent(), bottom, Vector3(CRATE_SIZE.x, 0.0, CRATE_SIZE.z))
		crate.visible = _ingredients_model == null
