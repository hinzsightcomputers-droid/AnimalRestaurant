# GasRing: a KitchenProps gas ring placed in a scene (a close-up's burner).
class_name GasRing
extends Node3D

@export var radius := 0.2


func _ready() -> void:
	add_child(KitchenProps.gas_ring(radius))
