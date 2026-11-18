# Receipt: the bills, printed at the host stand and carried to customers who
# asked for one. Every bill waiting is printed at once (count); any customer
# waiting for their bill can take one.
class_name Receipt
extends RefCounted

var count := 1


func _init(bills := 1) -> void:
	count = maxi(bills, 1)


func display_name() -> String:
	return "The bill" if count == 1 else "%d bills" % count
