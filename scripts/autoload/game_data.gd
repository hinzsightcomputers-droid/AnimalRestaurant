# GameData (autoload): loads game content (dishes, species, reactions, regulars,
# dialogue, upgrades) from JSON files in res://data/. Other scripts ask GameData for content
# instead of hard-coding it. This is the starting content; what changes during
# play (like a regular's memory) lives in GameState.
extends Node

const DISHES_PATH := "res://data/dishes.json"
const SPECIES_PATH := "res://data/species.json"
const REACTIONS_PATH := "res://data/reactions.json"
const REGULARS_PATH := "res://data/regulars.json"
const DIALOGUE_PATH := "res://data/dialogue.json"
const UPGRADES_PATH := "res://data/upgrades.json"

# Each dish: { id, name, price, cook_speed, ingredient: { name, color, chop? } }.
# "chop" ({ name, chops }) means the ingredient goes to the chopping board first.
var dishes: Array[Dictionary] = []
# Each species: { id, name, color }
var species: Array[Dictionary] = []
# Satisfaction tuning plus a "reactions" list: { id, min_satisfaction, payment_percent, lines }
var reactions: Dictionary = {}
# Starting state of each regular: { id, name, species, personality, favorite_dish,
# disliked_dish, relationship, times_visited, last_seen, known_players, served_by,
# last_service_quality }. known_players: account ids whose name they know.
# served_by: account id -> times that chef served them.
var regulars: Array[Dictionary] = []
# Tuning for regulars (visit chance, relationship changes, titles...).
var regular_settings: Dictionary = {}
# Each line: { event, priority, conditions, text }
var dialogue: Array[Dictionary] = []
# Each upgrade: { id, name, price, description, bonus?: { key: amount }, multiplier?: { key: factor } }.
# See GameState.upgrade_bonus / upgrade_multiplier for the keys.
var upgrades: Array[Dictionary] = []


func _ready() -> void:
	dishes = _load_list(DISHES_PATH, "dishes")
	species = _load_list(SPECIES_PATH, "species")
	reactions = _load_dictionary(REACTIONS_PATH)
	regulars = _load_list(REGULARS_PATH, "regulars")
	regular_settings = _load_dictionary(REGULARS_PATH).get("settings", {})
	dialogue = _load_list(DIALOGUE_PATH, "lines")
	upgrades = _load_list(UPGRADES_PATH, "upgrades")


func get_species(species_id: String) -> Dictionary:
	for entry in species:
		if entry["id"] == species_id:
			return entry
	push_error("Unknown species id: %s" % species_id)
	return {}


func get_dish(dish_id: String) -> Dictionary:
	for dish in dishes:
		if dish["id"] == dish_id:
			return dish
	push_error("Unknown dish id: %s" % dish_id)
	return {}


func get_upgrade(upgrade_id: String) -> Dictionary:
	for upgrade in upgrades:
		if upgrade["id"] == upgrade_id:
			return upgrade
	push_error("Unknown upgrade id: %s" % upgrade_id)
	return {}


func random_dish() -> Dictionary:
	return dishes.pick_random() if not dishes.is_empty() else {}


func random_species() -> Dictionary:
	return species.pick_random() if not species.is_empty() else {}


# Reads a JSON file shaped like { "<key>": [ {...}, {...} ] } and returns the list.
func _load_list(path: String, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var parsed := _load_dictionary(path)
	if not parsed.has(key):
		push_error("%s should contain a \"%s\" list" % [path, key])
		return result
	result.assign(parsed[key])
	return result


# Reads a JSON file whose top level is an object { ... }.
func _load_dictionary(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Could not read %s" % path)
		return {}
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("%s should be a JSON object" % path)
		return {}
	return parsed
