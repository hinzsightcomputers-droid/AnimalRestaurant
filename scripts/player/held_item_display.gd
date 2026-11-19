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
var _label_text := ""  # The label for what's in hand, before any "+2 on the tray".
var _tray_models: Array[Node3D] = []  # A Player tray: the drinks beside the one in hand, the plates stacked on it.
const TRAY_DRINK_STEP := 0.2   # Meters between drinks on a tray.
const TRAY_PLATE_STEP := Vector3(0.0, 0.08, -0.04)  # Each plate on a tray sits on the one before.


func _ready() -> void:
	food.material_override = _food_material
	crate_contents.material_override = _contents_material
	holder.held_item_changed.connect(_on_held_item_changed)
	if holder.has_signal("tray_changed"):
		holder.tray_changed.connect(_show_tray)
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
		label.text = ingredients.display_name() + (" (%s first)" % ingredients.prep_verb().to_lower() if ingredients.needs_chopping() else "")
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
	_label_text = label.text
	_show_tray()


# A Player carrying more on a tray: those too, and "+2" on the label.
func _show_tray() -> void:
	for model in _tray_models:
		model.queue_free()
	_tray_models.clear()
	var tray: Array = holder.get("tray") if holder.get("tray") != null else []
	label.text = _label_text
	if tray.is_empty() or holder.held_item == null:
		return
	var parent := crate.get_parent()
	for i in tray.size():
		var item: RefCounted = tray[i]
		if item is Drink:
			var drink := DrinkModel.make(item.drink)
			drink.scale = Vector3.ONE * 1.4
			parent.add_child(drink)
			var side := -1.0 if i % 2 == 0 else 1.0
			drink.position = crate.position - Vector3(0.0, CRATE_SIZE.y * 0.5, 0.0) + Vector3(side * TRAY_DRINK_STEP * ceili((i + 1) / 2.0), 0.0, 0.0)
			_tray_models.append(drink)
		elif item is CookedDish:
			var copy: Node3D = plate.duplicate()
			copy.visible = true
			for index in plate.get_child_count():  # Not the look of the dish in hand (or one on its way out).
				var original := plate.get_child(index)
				if original != food and index < copy.get_child_count() and (original == _look or original.is_queued_for_deletion()):
					copy.get_child(index).queue_free()
			parent.add_child(copy)
			copy.position = plate.position + TRAY_PLATE_STEP * (i + 1)
			var look: Node3D = item.show_look(copy, Vector3(0.0, PLATE_TOP, 0.0), PLATE_RADIUS)
			var copy_food := copy.get_node_or_null(NodePath(food.name))
			if copy_food != null:
				copy_food.visible = look == null
			_tray_models.append(copy)
	label.text += "  +%d on the tray" % tray.size()


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
