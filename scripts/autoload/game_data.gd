# GameData (autoload): loads game content (dishes, species) from JSON files in res://data/.
# Other scripts ask GameData for content instead of hard-coding it.
extends Node

const DISHES_PATH := "res://data/dishes.json"
const SPECIES_PATH := "res://data/species.json"

# Each dish: { id, name, price, cook_speed }
var dishes: Array[Dictionary] = []
# Each species: { id, name, color }
var species: Array[Dictionary] = []


func _ready() -> void:
	dishes = _load_list(DISHES_PATH, "dishes")
	species = _load_list(SPECIES_PATH, "species")


func get_dish(dish_id: String) -> Dictionary:
	for dish in dishes:
		if dish["id"] == dish_id:
			return dish
	push_error("Unknown dish id: %s" % dish_id)
	return {}


func random_dish() -> Dictionary:
	return dishes.pick_random() if not dishes.is_empty() else {}


func random_species() -> Dictionary:
	return species.pick_random() if not species.is_empty() else {}


# Reads a JSON file shaped like { "<key>": [ {...}, {...} ] } and returns the list.
func _load_list(path: String, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Could not read %s" % path)
		return result

	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary and parsed.has(key)):
		push_error("%s should contain a \"%s\" list" % [path, key])
		return result

	result.assign(parsed[key])
	return result
