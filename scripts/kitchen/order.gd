# Order: one dish a customer has asked for, and how far along it is.
class_name Order
extends RefCounted

enum State { WAITING, COOKING, READY }

var customer: Customer
var dish: Dictionary  # From data/dishes.json
var state: State = State.WAITING


func _init(for_customer: Customer, ordered_dish: Dictionary) -> void:
	customer = for_customer
	dish = ordered_dish
