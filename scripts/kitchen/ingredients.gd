# Ingredients: what a player carries from the freezer to the stove. Belongs to
# one order, so the stove knows which dish to cook.
class_name Ingredients
extends RefCounted

var order: Order


func _init(for_order: Order) -> void:
	order = for_order


# e.g. "Frozen Fish", from the dish's "ingredient" in data/dishes.json.
func display_name() -> String:
	return order.dish.get("ingredient", {}).get("name", "Ingredients")


func color() -> Color:
	return Color.html(order.dish.get("ingredient", {}).get("color", "#cccccc"))
