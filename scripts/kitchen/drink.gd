# Drink: a drink a player is carrying, made at the DrinkStation: which one
# (from GameData.drinks) and how well it was poured (0..1). Any customer who
# ordered that drink can have it.
class_name Drink
extends RefCounted

var drink: Dictionary
var quality: float


func _init(drink_data: Dictionary, poured_quality := 1.0) -> void:
	drink = drink_data
	quality = poured_quality


func id() -> String:
	return drink.get("id", "")


func display_name() -> String:
	return drink.get("name", "Drink")
