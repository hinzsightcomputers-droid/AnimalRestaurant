# DishBin: the tub a player carries to clear tables. Holds the dirty dishes
# (their models) until they're washed at the Sink.
class_name DishBin
extends RefCounted

const CAPACITY := 8

var dishes: Array[String] = []  # Model paths of the dirty dishes in it.


func room() -> int:
	return CAPACITY - dishes.size()


func is_full() -> bool:
	return room() <= 0


func display_name() -> String:
	return "Dish bin" if dishes.is_empty() else "Dish bin (%d dirty)" % dishes.size()
