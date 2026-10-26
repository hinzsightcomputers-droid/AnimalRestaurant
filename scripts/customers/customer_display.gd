# CustomerDisplay: makes a Customer visible. Colors the placeholder body by species
# and shows a speech bubble based on the customer's state. Display only.
extends Node3D

@onready var customer: Customer = get_parent()
@onready var bubble: Label3D = $Bubble


func _ready() -> void:
	_apply_species_color()
	customer.state_changed.connect(_on_state_changed)
	_on_state_changed(customer)
	_play_pop_in()


func _on_state_changed(_customer: Customer) -> void:
	var dish_name: String = customer.dish.get("name", "something")
	match customer.state:
		Customer.State.ARRIVING:
			bubble.visible = false
		Customer.State.WAITING_TO_ORDER:
			bubble.text = "Ready to order!"
			bubble.visible = true
		Customer.State.WALKING_TO_SEAT, Customer.State.WAITING_FOR_FOOD:
			bubble.text = "%s, please!" % dish_name
			bubble.visible = true


func _apply_species_color() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.html(customer.species.get("color", "#cccccc"))
	for child in get_children():
		if child is MeshInstance3D:
			child.material_override = material


# Grow from nothing so customers don't just blink into existence.
func _play_pop_in() -> void:
	scale = Vector3.ONE * 0.01
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
