# Ingredients: what a player carries from the freezer to the stove. Belongs to
# one order, so the stove knows which dish to cook. Some need chopping at the
# chopping board first (the dish's ingredient has a "chop" entry, which can
# name its own close-up, e.g. filleting a fish, and how to say it).
class_name Ingredients
extends RefCounted

var order: Order
var chopped := false
var chop_quality := -1.0  # How well they were chopped (0 to 1), once they are.


func _init(for_order: Order) -> void:
	order = for_order


# e.g. "Frozen Fish", or "Chopped Carrots" once chopped. From the dish's
# "ingredient" in data/dishes.json.
func display_name() -> String:
	if chopped:
		return _chop().get("name", "Chopped " + _ingredient().get("name", "Ingredients"))
	return _ingredient().get("name", "Ingredients")


# The model to carry them as (from data/dishes.json), or "" for the plain crate.
func model_path() -> String:
	if chopped and _chop().has("model"):
		return _chop()["model"]
	return _ingredient().get("model", "")


func color() -> Color:
	if chopped and _chop().has("color"):
		return Color.html(_chop()["color"])
	return Color.html(_ingredient().get("color", "#cccccc"))


# What the chopping board does to them, e.g. "Chop" or "Fillet".
func chop_verb() -> String:
	return _chop().get("verb", "Chop")


# The close-up recipe at the chopping board (data/recipes/), e.g. "filleting".
func chop_recipe() -> String:
	return _chop().get("recipe", "chopping")


# True until they've been chopped, for ingredients that need it.
func needs_chopping() -> bool:
	return not chopped and not _chop().is_empty()


# How many presses at the chopping board (a Sharp Knife takes fewer, but always at least 1).
func chops_needed() -> int:
	return maxi(1, int(_chop().get("chops", 5)) + int(GameState.upgrade_bonus("chops")))


func _ingredient() -> Dictionary:
	return order.dish.get("ingredient", {})


func _chop() -> Dictionary:
	return _ingredient().get("chop", {})
