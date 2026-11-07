# GameData (autoload): loads game content (dishes, species, reactions, regulars,
# dialogue, upgrades, townsfolk) from JSON files in res://data/. Each regular has their own
# file in res://data/characters/, so adding one only means adding a file. Other
# scripts ask GameData for content instead of hard-coding it. This is the starting
# content; what changes during play (like a regular's memory) lives in GameState.
extends Node

const DISHES_PATH := "res://design/menu/dishes.json"
const DISH_KITCHEN_PATH := "res://data/dish_kitchen.json"
const DRINKS_PATH := "res://design/menu/drinks.json"
const DRINK_KITCHEN_PATH := "res://data/drink_kitchen.json"
const SERVICE_PATH := "res://data/service.json"
const SPECIES_PATH := "res://data/species.json"
const REACTIONS_PATH := "res://data/reactions.json"
const REGULARS_PATH := "res://data/regulars.json"
const CHARACTERS_DIR := "res://data/characters"
const DIALOGUE_PATH := "res://data/dialogue.json"
const UPGRADES_PATH := "res://data/upgrades.json"
const PHONE_PATH := "res://data/phone.json"
const TOWNSFOLK_DIR := "res://data/townsfolk"
const GOSSIP_PATH := "res://data/gossip.json"
const SCENES_PATH := "res://data/scenes.json"
const DAY_PATH := "res://data/day.json"
const TIME_PATH := "res://data/time.json"
const FISH_PATH := "res://data/fish.json"
const FORAGE_PATH := "res://data/forage.json"
const TRIPS_PATH := "res://data/trips.json"
const HOUSES_PATH := "res://data/houses.json"
const DIFFICULTY_PATH := "res://data/difficulty.json"
const RATING_PATH := "res://data/rating.json"
const DECOR_PATH := "res://data/decor.json"

# Each dish, from the menu (design/menu/dishes.json): { id, name, origin,
# description, ingredients, steps, base_price, cook_time, tags, unlock,
# unlock_cost }, plus how it looks and cooks from data/dish_kitchen.json: model,
# dirty_model?, recipe?, station?, cook_speed?, ingredient: { name, color, model?, chop? }.
# "chop" ({ name, chops }) means the ingredient goes to the chopping board first.
# "unlock": "start" dishes are on the menu from day 1, "upgrade" ones once
# bought in the end-of-day shop, "scene" ones once a big moment unlocks them,
# "found" ones once something is found after hours (the first fish: see
# Fishing) (see is_unlocked()). "uses" is what it takes from the Pantry.
var dishes: Array[Dictionary] = []
# Each drink, from design/menu/drinks.json: { id, name, type, description,
# prep (grab | pour | brew), temperature, base_price, tags, unlock, unlock_cost },
# plus color and vessel from data/drink_kitchen.json. Unlocked like dishes.
var drinks: Array[Dictionary] = []
var drink_settings: Dictionary = {}
# The steps of a walk-in's visit: townsfolk lines per step, how long regulars
# stay, the delivery question (data/service.json).
var service: Dictionary = {}
# Each species: { id, name, color, models?, height? }. Those with "models" (and
# a [min, max] "height") are the ones who walk in off the street; the rest are
# for regulars and callers.
var species: Array[Dictionary] = []
# Satisfaction tuning plus a "reactions" list: { id, min_satisfaction, payment_percent, lines }
var reactions: Dictionary = {}
# Each regular's whole character file, by id: profile (name, species, tastes...),
# stage_names, tone_reactions, starting "memory" and their own dialogue "lines".
var characters: Dictionary = {}
# Starting state of each regular: their profile (id, name, species, color?,
# personality, favorite_dish, disliked_dish, referral_only, ...) plus every memory
# field (memory_defaults in regulars.json, then their own "memory"). See
# memory_fields() for which fields change during play and get saved.
var regulars: Array[Dictionary] = []
# Tuning shared by all regulars (visit chance, stages, name learning...).
var regular_settings: Dictionary = {}
# Memory every regular has, e.g. relationship, rude_streak, seen_lines.
var memory_defaults: Dictionary = {}
# Each line: { event, priority, conditions, text }. Shared lines from dialogue.json,
# then each regular's own lines (with a "regular" condition added).
var dialogue: Array[Dictionary] = []
# Each upgrade: { id, name, price, description, bonus?: { key: amount }, multiplier?: { key: factor } }.
# See GameState.upgrade_bonus / upgrade_multiplier for the keys.
var upgrades: Array[Dictionary] = []
# The difficulty levels and when Hard unlocks (data/difficulty.json).
var difficulty: Dictionary = {}
# The star rating's thresholds, the critic and their wording (data/rating.json, see Rating).
var rating: Dictionary = {}
# What decor there is, where it can go and how it scores (data/decor.json, see Decor).
var decor: Dictionary = {}
# The day each shop item arrives in stock, by id (see in_stock()).
var shop_arrivals: Dictionary = {}
# Phone tuning: ring and gap timings, voicemail size, who calls, the courier.
var phone_settings: Dictionary = {}
# The named townsfolk who walk in and come and go, one file each in
# data/townsfolk/ (see _template.json there and Townsfolk): { id, name, species,
# model?, color?, name_color, personality, resident, favorite_dish,
# favorite_drink, seating, lines: { <step>: [...], eating, seasonal }, phone? }.
var townsfolk: Array[Dictionary] = []
# Those of them who phone in orders (a "phone" block): { id, name, species,
# name_color, personality, night_only, usual_order, lines: [{ part: greeting |
# order | chat, text, choices? }] }.
var callers: Array[Dictionary] = []
# Big moment scenes: { id, name, regular, conditions, staging, done, steps } (see BigMoments).
var scenes: Array[Dictionary] = []
var scene_settings: Dictionary = {}
# How a day runs: its phases (Breakfast, Lunch, Dinner), who comes in each,
# their lighting, and the closing lighting (see DayManager, DayPlan).
var day_settings: Dictionary = {}
# The real clock in words: hour blocks (early_morning... late_night) and which
# weekdays are the weekend (see GameClock.hour_block, GameClock.weekday_id).
var time_settings: Dictionary = {}
# Fish you can catch ({ id, name, habitat, seasons, hours, rarity, size_cm,
# difficulty, color, belly, description }) and how fishing plays (data/fish.json).
var fish: Array[Dictionary] = []
var fishing_settings: Dictionary = {}
# Things to gather after hours, from data/forage.json: { id, name, seasons,
# hours, where, rarity, kind, pantry, shape, color, accent, description }, and
# how foraging works (forage_settings: spots, spawn chance, rarity weights).
var forage: Array[Dictionary] = []
var forage_settings: Dictionary = {}
# Trips in Cheddar's car to the beach (data/trips.json): the car, the drive, the beach.
var trips: Dictionary = {}
# The regulars' houses across the street (data/houses.json): where, how they look, visits and gifts.
var houses: Dictionary = {}


func _ready() -> void:
	dishes = _load_list(DISHES_PATH, "dishes")
	var kitchen: Dictionary = _load_dictionary(DISH_KITCHEN_PATH).get("dishes", {})
	for dish in dishes:
		dish.merge(kitchen.get(dish["id"], {}))
	drinks = _load_list(DRINKS_PATH, "drinks")
	var drink_kitchen := _load_dictionary(DRINK_KITCHEN_PATH)
	drink_settings = drink_kitchen.get("settings", {})
	for drink in drinks:
		drink.merge(drink_kitchen.get("drinks", {}).get(drink["id"], {}))
	service = _load_dictionary(SERVICE_PATH)
	species = _load_list(SPECIES_PATH, "species")
	reactions = _load_dictionary(REACTIONS_PATH)
	var regulars_file := _load_dictionary(REGULARS_PATH)
	regular_settings = regulars_file.get("settings", {})
	memory_defaults = regulars_file.get("memory_defaults", {})
	dialogue = _load_list(DIALOGUE_PATH, "lines")
	_load_characters()
	upgrades = _load_list(UPGRADES_PATH, "upgrades")
	shop_arrivals = _load_dictionary(UPGRADES_PATH).get("arrives", {})
	difficulty = _load_dictionary(DIFFICULTY_PATH)
	rating = _load_dictionary(RATING_PATH)
	decor = _load_dictionary(DECOR_PATH)
	phone_settings = _load_dictionary(PHONE_PATH).get("settings", {})
	_load_townsfolk()
	_load_gossip()
	for line in dialogue:
		_add_dish_condition(line)
	scenes = _load_list(SCENES_PATH, "scenes")
	scene_settings = _load_dictionary(SCENES_PATH).get("settings", {})
	day_settings = _load_dictionary(DAY_PATH)
	time_settings = _load_dictionary(TIME_PATH)
	fish = _load_list(FISH_PATH, "fish")
	fishing_settings = _load_dictionary(FISH_PATH).get("settings", {})
	forage = _load_list(FORAGE_PATH, "items")
	forage_settings = _load_dictionary(FORAGE_PATH).get("settings", {})
	trips = _load_dictionary(TRIPS_PATH)
	houses = _load_dictionary(HOUSES_PATH)


# A forage item from data/forage.json, or {}.
func get_forage(item_id: String) -> Dictionary:
	for entry in forage:
		if entry["id"] == item_id:
			return entry
	return {}


# A fish from data/fish.json, or {}.
func get_fish(fish_id: String) -> Dictionary:
	for entry in fish:
		if entry["id"] == fish_id:
			return entry
	return {}


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


func get_drink(drink_id: String) -> Dictionary:
	for drink in drinks:
		if drink["id"] == drink_id:
			return drink
	return {}


# The end of the day a shop item (upgrade, dish or drink) turns up in the shop.
func arrival_day(item_id: String) -> int:
	return int(shop_arrivals.get(item_id, 1))


# Whether the shop has it today: it arrives a few at a time (data/upgrades.json "arrives").
func in_stock(item_id: String) -> bool:
	return arrival_day(item_id) <= GameState.day_number


func get_upgrade(upgrade_id: String) -> Dictionary:
	for upgrade in upgrades:
		if upgrade["id"] == upgrade_id:
			return upgrade
	push_error("Unknown upgrade id: %s" % upgrade_id)
	return {}


func get_scene(scene_id: String) -> Dictionary:
	for scene in scenes:
		if scene["id"] == scene_id:
			return scene
	return {}


func get_caller(caller_id: String) -> Dictionary:
	for caller in callers:
		if caller["id"] == caller_id:
			return caller
	return {}


# The dishes on the menu right now: the unlocked ones the pantry has enough
# for (see Pantry), or just the debug panel's forced dish.
func menu() -> Array[Dictionary]:
	if not GameState.forced_dish.is_empty():
		return dishes.filter(func(d): return d["id"] == GameState.forced_dish)
	return dishes.filter(func(d): return is_unlocked(d["id"]) and Pantry.can_make(d))


# The drinks customers can order right now: the unlocked ones.
func drink_menu() -> Array[Dictionary]:
	return drinks.filter(func(d): return is_unlocked(d["id"]))


# The drinks the end-of-day shop sells, bought or not.
func shop_drinks() -> Array[Dictionary]:
	return drinks.filter(func(d): return d.get("unlock", "") == "upgrade")


# A drink for a townsfolk to order: sometimes water, else anything else unlocked.
func random_drink() -> Dictionary:
	var others := drink_menu().filter(func(d): return d["id"] != "water")
	if others.is_empty() or randf() < drink_settings.get("townsfolk_water_chance", 0.15):
		return get_drink("water")
	return others.pick_random()


# True for a "start" dish or drink, or one bought in the shop or unlocked by a scene
# (its id is in GameState.unlocks).
func is_unlocked(dish_id: String) -> bool:
	for item in dishes + drinks:
		if item["id"] == dish_id:
			return item.get("unlock", "start") == "start" or dish_id in GameState.unlocks
	return false


# The dishes the end-of-day shop sells ("upgrade" ones), bought or not.
func shop_dishes() -> Array[Dictionary]:
	return dishes.filter(func(d): return d.get("unlock", "") == "upgrade")


func random_dish() -> Dictionary:
	var on_menu := menu()
	return on_menu.pick_random() if not on_menu.is_empty() else {}


# A species for someone walking in: one with a model, if there are any.
func random_species() -> Dictionary:
	var modeled := species.filter(func(entry): return not entry.get("models", []).is_empty())
	var pool := modeled if not modeled.is_empty() else species
	return pool.pick_random() if not pool.is_empty() else {}


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


# Fields of this regular that change during play and get saved: the shared
# memory_defaults plus their own extras (e.g. Cheddar's nickname).
func memory_fields(regular_id: String) -> Array:
	var fields := memory_defaults.keys()
	for key in characters.get(regular_id, {}).get("memory", {}):
		if not key in fields:
			fields.append(key)
	return fields


# Every .json in data/characters/, in file name order.
func _load_characters() -> void:
	var files := Array(DirAccess.get_files_at(CHARACTERS_DIR)).filter(func(f): return f.ends_with(".json"))
	files.sort()
	for file_name in files:
		var character := _load_dictionary("%s/%s" % [CHARACTERS_DIR, file_name])
		if not character.has("id"):
			push_error("%s needs an \"id\"" % file_name)
			continue
		characters[character["id"]] = character

		var record := {}
		for key in character:
			if not key in ["stage_names", "tone_reactions", "memory", "lines", "gone"]:
				record[key] = character[key]
		record.merge(memory_defaults.duplicate(true), true)
		record.merge(character.get("memory", {}).duplicate(true), true)
		regulars.append(record)

		for line in character.get("lines", []):
			dialogue.append(_with_token_conditions(line, character["id"]))


func _load_townsfolk() -> void:
	var files := Array(DirAccess.get_files_at(TOWNSFOLK_DIR)).filter(func(f): return f.ends_with(".json") and not f.begins_with("_"))
	files.sort()
	for file_name in files:
		var person := _load_dictionary("%s/%s" % [TOWNSFOLK_DIR, file_name])
		if not person.has("id"):
			push_error("%s needs an \"id\"" % file_name)
			continue
		townsfolk.append(person)
		var phone: Dictionary = person.get("phone", {})
		if not phone.is_empty():
			var caller := { "id": person["id"], "name": person.get("name", "?"), "species": person.get("species", ""), "name_color": person.get("name_color", "#555555"), "personality": person.get("personality", "") }
			caller.merge(phone)
			callers.append(caller)


func get_townsfolk(townsfolk_id: String) -> Dictionary:
	for person in townsfolk:
		if person["id"] == townsfolk_id:
			return person
	return {}


# What regulars say about each other (data/gossip.json): each line is said by
# "teller" about "about", for "kind" or "rude" news. They become "gossip" lines
# for the teller, picked like any other line.
func _load_gossip() -> void:
	for line in _load_list(GOSSIP_PATH, "lines"):
		var entry := line.duplicate(true)
		entry["event"] = "gossip"
		var conditions: Dictionary = entry.get_or_add("conditions", {})
		conditions["gossip_about"] = entry["about"]
		conditions["gossip_kind"] = entry["kind"]
		dialogue.append(_with_token_conditions(entry, entry["teller"]))


# A character's line, only for them, and only when its [tokens] can be filled
# in: [name] and [nickname] need them to know the chef's name, [last_rude_line]
# needs a rude line to quote, and [restaurant] needs the restaurant named.
func _with_token_conditions(line: Dictionary, regular_id: String) -> Dictionary:
	var result := line.duplicate(true)
	var conditions: Dictionary = result.get_or_add("conditions", {})
	conditions["regular"] = regular_id
	var text: String = result.get("text", "")
	if ("[name]" in text or "[nickname]" in text) and not conditions.has("knows_player_name"):
		conditions["knows_player_name"] = true
		result["needs_name"] = true  # Added here, not written in: DialoguePicker can fall back on it.
	if "[last_rude_line]" in text and not conditions.has("has_rude_line"):
		conditions["has_rude_line"] = true
	if "[restaurant]" in text and not conditions.has("has_restaurant_name"):
		conditions["has_restaurant_name"] = true
	return result


# A line that names or orders the regular's favorite or disliked dish, or a
# dish token like [soup], is only said once that dish is unlocked: it gets a
# "dishes_unlocked" condition listing them ("favorite", "disliked", tokens or
# dish ids, see DialoguePicker.dish_id_of). Its choices count too.
func _add_dish_condition(line: Dictionary) -> void:
	var refs := []
	var dish_words: Array = ["favorite", "disliked"] + regular_settings.get("dish_tokens", {}).keys()
	var regex := RegEx.create_from_string("[\\[{]([a-z_ ]+)[\\]}]")
	var entries: Array = [line] + line.get("choices", [])
	for entry in entries:
		if not String(entry.get("dish", "")).is_empty() and not entry["dish"] in refs:
			refs.append(entry["dish"])
		for key in ["text", "reply", "miss_reply"]:
			for found in regex.search_all(String(entry.get(key, ""))):
				var word := found.get_string(1)
				if word in dish_words and not word in refs:
					refs.append(word)
	if not refs.is_empty():
		line.get_or_add("conditions", {})["dishes_unlocked"] = refs
