# Order: one dish someone has asked for, and how far along it is.
# WAITING (needs ingredients) -> GATHERED (ingredients on the way to the stove)
# -> COOKING -> READY (plate waiting to be served, or picked up for delivery).
# Its ticket goes in the pocket of whoever took it, and the kitchen only starts
# on it once that ticket is clipped on the TicketWheel (on_wheel).
class_name Order
extends RefCounted

enum State { WAITING, GATHERED, COOKING, READY }

var customer: Customer        # Who's eating it here, or null for a delivery.
var caller: Dictionary = {}   # For a delivery: who phoned it in, { kind, id, name, species, regular_id }.
var dish: Dictionary  # From GameData.dishes
var state: State = State.WAITING
var number := 0               # On its ticket, e.g. #3. Counts up through the shift.
var on_wheel := false


func _init(for_customer: Customer, ordered_dish: Dictionary, delivery_caller: Dictionary = {}) -> void:
	customer = for_customer
	dish = ordered_dish
	caller = delivery_caller


func is_delivery() -> bool:
	return customer == null


# "Mouse" for someone eating here, "Pip (delivery)" for a phone order.
func for_name() -> String:
	if is_delivery():
		return "%s (delivery)" % caller.get("name", "?")
	return customer.species.get("name", "?")
