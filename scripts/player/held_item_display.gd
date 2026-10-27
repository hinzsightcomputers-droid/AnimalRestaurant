# HeldItemDisplay: shows what a player is carrying (a plate or an ingredient
# crate in their hands, and a label above their head). Display only: it listens
# to the Player.
extends Node3D

@export var player: Player
@export var plate: Node3D       # The plate model in the player's hands.
@export var food: MeshInstance3D
@export var crate: Node3D       # The ingredient crate model in the player's hands.
@export var crate_contents: MeshInstance3D

@onready var label: Label3D = $Label

var _food_material := StandardMaterial3D.new()
var _contents_material := StandardMaterial3D.new()


func _ready() -> void:
	food.material_override = _food_material
	crate_contents.material_override = _contents_material
	player.held_item_changed.connect(_on_held_item_changed)
	_on_held_item_changed(player.held_item)


func _on_held_item_changed(item: RefCounted) -> void:
	var dish := item as CookedDish
	var ingredients := item as Ingredients
	plate.visible = dish != null
	crate.visible = ingredients != null
	label.visible = item != null
	if dish != null:
		label.text = "%s (%s)" % [dish.dish_name(), CookingMinigame.quality_label(dish.quality)]
		# Better food looks golden, burnt food looks dark.
		_food_material.albedo_color = Color(0.3, 0.2, 0.15).lerp(Color(0.95, 0.7, 0.3), dish.quality)
	elif ingredients != null:
		label.text = ingredients.display_name()
		_contents_material.albedo_color = ingredients.color()
