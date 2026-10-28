# CookRecipe: a close-up dish as data, a .tres in data/recipes/. Its steps are
# CookActions with their settings, played in order by a CookSession. A dish in
# data/dishes.json uses one with "recipe": "<file name>"; dishes without one
# keep the stirring minigame.
class_name CookRecipe
extends Resource

const FOLDER := "res://data/recipes/"

@export var display_name := ""
@export var pieces := 2                 # How many pieces the dish is made of, e.g. pancakes in the stack.
@export var serve_on := "Plate"         # The surface the finished dish is on: it's carried and served looking like that ("" = the dish's model).
@export var scene: PackedScene          # The close-up to cook it in; empty = the station's usual one.
@export var steps: Array[CookAction] = []


# The recipe a dish uses, or null.
static func for_dish(dish: Dictionary) -> CookRecipe:
	var recipe_id: String = dish.get("recipe", "")
	if recipe_id.is_empty():
		return null
	var path := FOLDER + recipe_id + ".tres"
	return load(path) as CookRecipe if ResourceLoader.exists(path) else null


# The dish's quality from its steps' qualities, weighted by each step's weight.
static func combine(actions: Array[CookAction]) -> float:
	var total := 0.0
	var weights := 0.0
	for action in actions:
		if action.weight > 0.0:
			total += action.quality * action.weight
			weights += action.weight
	return total / weights if weights > 0.0 else 0.0
