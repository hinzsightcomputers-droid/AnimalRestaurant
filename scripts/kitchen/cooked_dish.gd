# CookedDish: a finished plate a player is carrying, with its cooking quality (0..1).
class_name CookedDish
extends RefCounted

var order: Order
var quality: float


func _init(for_order: Order, cooked_quality: float) -> void:
	order = for_order
	quality = cooked_quality


func dish_name() -> String:
	return order.dish.get("name", "Dish")
