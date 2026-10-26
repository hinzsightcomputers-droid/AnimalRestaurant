# CustomerDisplay: makes a Customer visible. Colors the placeholder body by species,
# shows a speech bubble based on the customer's state, and shows their meal on
# the table while eating. Display only.
extends Node3D

@onready var customer: Customer = get_parent()
@onready var bubble: Label3D = $Bubble
@onready var meal: Node3D = $Meal
@onready var food: MeshInstance3D = $Meal/Food

var _food_material := StandardMaterial3D.new()


func _ready() -> void:
	_apply_species_color()
	food.material_override = _food_material
	customer.state_changed.connect(_on_state_changed)
	_on_state_changed(customer)
	_play_pop_in()


func _on_state_changed(_customer: Customer) -> void:
	var dish_name: String = customer.dish.get("name", "something")
	meal.visible = customer.state == Customer.State.EATING
	bubble.visible = true

	match customer.state:
		Customer.State.ARRIVING, Customer.State.GONE:
			bubble.visible = false
		Customer.State.WAITING_TO_ORDER:
			bubble.text = "Ready to order!"
		Customer.State.WALKING_TO_SEAT, Customer.State.WAITING_FOR_FOOD:
			bubble.text = "%s, please!" % dish_name
		Customer.State.EATING:
			bubble.text = "Nom nom..."
			# Same look as the plate the player carried: golden = good, dark = burnt.
			_food_material.albedo_color = Color(0.3, 0.2, 0.15).lerp(Color(0.95, 0.7, 0.3), customer.served_quality)
		Customer.State.LEAVING:
			bubble.text = "\"%s\"\n+$%d" % [customer.reaction_line, customer.payment]


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
