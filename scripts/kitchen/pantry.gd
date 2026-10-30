# Pantry: the kitchen's store of things the chefs caught or gathered after
# hours (GameState.pantry, item id -> how many). A dish whose kitchen data
# has "uses" (e.g. { "fish": 1 }) needs that many of a kind: it's only on the
# menu while there are enough, and each order takes them when it's placed
# (the commonest first, so a rare catch isn't the first in the pot). Nothing
# here is ever sold for money. The first fish (or first of a forage item)
# also puts dishes "unlock": "found" on the menu (unlock_found). Pure logic.
class_name Pantry
extends RefCounted


# What kind of thing an item is, e.g. "fish" for any fish.
static func kind_of(item_id: String) -> String:
	if not GameData.get_fish(item_id).is_empty():
		return GameData.fishing_settings.get("pantry_kind", "fish")
	return GameData.get_forage(item_id).get("kind", item_id)


# e.g. "Bluegill" or "Acorn".
static func item_name(item_id: String) -> String:
	return _info(item_id).get("name", item_id.capitalize())


static func add(item_id: String, amount := 1) -> void:
	GameState.pantry[item_id] = int(GameState.pantry.get(item_id, 0)) + amount


# How many of a kind there are, e.g. count("fish").
static func count(kind: String) -> int:
	var total := 0
	for item_id in GameState.pantry:
		if kind_of(item_id) == kind:
			total += int(GameState.pantry[item_id])
	return total


# What a dish needs from the pantry, e.g. { "fish": 1 } ({} for most dishes).
static func needs_of(dish: Dictionary) -> Dictionary:
	return dish.get("uses", {})


static func can_make(dish: Dictionary) -> bool:
	var needs := needs_of(dish)
	for kind in needs:
		if count(kind) < int(needs[kind]):
			return false
	return true


# Takes what a dish needs; returns the item ids taken (fewer if it ran out).
static func take_for(dish: Dictionary) -> Array[String]:
	var taken: Array[String] = []
	var needs := needs_of(dish)
	for kind in needs:
		for i in int(needs[kind]):
			var item := _commonest(kind)
			if item.is_empty():
				break
			GameState.pantry[item] = int(GameState.pantry[item]) - 1
			if GameState.pantry[item] <= 0:
				GameState.pantry.erase(item)
			taken.append(item)
	return taken


# The item of a kind there's most of (rarer ones last), or "".
static func _commonest(kind: String) -> String:
	var best := ""
	for item_id in GameState.pantry:
		if kind_of(item_id) != kind or int(GameState.pantry[item_id]) <= 0:
			continue
		if best.is_empty() or _rank(item_id) < _rank(best) or _rank(item_id) == _rank(best) and GameState.pantry[item_id] > GameState.pantry[best]:
			best = item_id
	return best


# 0 for common things, higher for rarer ones.
static func _rank(item_id: String) -> int:
	return ["common", "uncommon", "rare"].find(_info(item_id).get("rarity", "common"))


# e.g. "3 Bluegill, 1 Catfish", or "empty".
static func describe() -> String:
	var parts := PackedStringArray()
	for item_id in GameState.pantry:
		parts.append("%d %s" % [GameState.pantry[item_id], item_name(item_id)])
	return ", ".join(parts) if not parts.is_empty() else "empty"


# Dishes with "unlock": "found" and this unlocked_by (e.g. "first_fish",
# "first_acorn") go on the menu; `made_with` finishes the announcement
# ("made with what you catch!").
static func unlock_found(trigger: String, made_with: String) -> void:
	for dish in GameData.dishes:
		if dish.get("unlock", "") == "found" and dish.get("unlocked_by", "") == trigger and not dish["id"] in GameState.unlocks:
			GameState.unlocks.append(dish["id"])
			GameEvents.announce("%s is on the menu now, %s" % [dish.get("name", "A new dish"), made_with])
	GameState.unlocks_changed.emit()


# Debug: take the dishes unlocked by `trigger` back off the menu.
static func relock_found(trigger: String) -> void:
	for dish in GameData.dishes:
		if dish.get("unlock", "") == "found" and dish.get("unlocked_by", "") == trigger:
			GameState.unlocks.erase(dish["id"])
	GameState.unlocks_changed.emit()


# A fish or a forage item from the data, or {}.
static func _info(item_id: String) -> Dictionary:
	var fish := GameData.get_fish(item_id)
	return fish if not fish.is_empty() else GameData.get_forage(item_id)
