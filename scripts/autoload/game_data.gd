# GameData (autoload): loads game content (dishes, species, reactions, regulars,
# dialogue, upgrades, phone callers) from JSON files in res://data/. Each regular has their own
# file in res://data/characters/, so adding one only means adding a file. Other
# scripts ask GameData for content instead of hard-coding it. This is the starting
# content; what changes during play (like a regular's memory) lives in GameState.
extends Node

const DISHES_PATH := "res://data/dishes.json"
const SPECIES_PATH := "res://data/species.json"
const REACTIONS_PATH := "res://data/reactions.json"
const REGULARS_PATH := "res://data/regulars.json"
const CHARACTERS_DIR := "res://data/characters"
const DIALOGUE_PATH := "res://data/dialogue.json"
const UPGRADES_PATH := "res://data/upgrades.json"
const PHONE_PATH := "res://data/phone.json"
const CALLERS_PATH := "res://data/callers.json"
const GOSSIP_PATH := "res://data/gossip.json"
const SCENES_PATH := "res://data/scenes.json"

# Each dish: { id, name, price, cook_speed, ingredient: { name, color, chop? }, unlock? }.
# "chop" ({ name, chops }) means the ingredient goes to the chopping board first.
# A dish with "unlock" is only on the menu once that reward is unlocked (see menu()).
var dishes: Array[Dictionary] = []
# Each species: { id, name, color }
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
# Phone tuning: ring and gap timings, voicemail size, who calls, the courier.
var phone_settings: Dictionary = {}
# Townsfolk who phone in orders: { id, name, species, name_color, personality,
# usual_order, lines: [{ part: greeting | order | chat, text, choices? }] }.
var callers: Array[Dictionary] = []
# Big moment scenes: { id, name, regular, conditions, staging, done, steps } (see BigMoments).
var scenes: Array[Dictionary] = []
var scene_settings: Dictionary = {}


func _ready() -> void:
	dishes = _load_list(DISHES_PATH, "dishes")
	species = _load_list(SPECIES_PATH, "species")
	reactions = _load_dictionary(REACTIONS_PATH)
	var regulars_file := _load_dictionary(REGULARS_PATH)
	regular_settings = regulars_file.get("settings", {})
	memory_defaults = regulars_file.get("memory_defaults", {})
	dialogue = _load_list(DIALOGUE_PATH, "lines")
	_load_characters()
	upgrades = _load_list(UPGRADES_PATH, "upgrades")
	phone_settings = _load_dictionary(PHONE_PATH).get("settings", {})
	callers = _load_list(CALLERS_PATH, "callers")
	_load_gossip()
	scenes = _load_list(SCENES_PATH, "scenes")
	scene_settings = _load_dictionary(SCENES_PATH).get("settings", {})


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


# The dishes on the menu right now: everything, except dishes still waiting for their unlock.
func menu() -> Array[Dictionary]:
	return dishes.filter(func(d): return not d.has("unlock") or d["unlock"] in GameState.unlocks)


func random_dish() -> Dictionary:
	var on_menu := menu()
	return on_menu.pick_random() if not on_menu.is_empty() else {}


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
	if "[last_rude_line]" in text and not conditions.has("has_rude_line"):
		conditions["has_rude_line"] = true
	if "[restaurant]" in text and not conditions.has("has_restaurant_name"):
		conditions["has_restaurant_name"] = true
	return result
