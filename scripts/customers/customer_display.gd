# CustomerDisplay: makes a Customer visible. Colors the placeholder body by species,
# shows a speech bubble based on the customer's state, and shows their meal on
# the table while eating. Display only.
extends Node3D

@onready var customer: Customer = get_parent()
@onready var bubble: Label3D = $Bubble
@onready var name_tag: Label3D = $NameTag
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
			bubble.text = _quoted(customer.greeting_line, "Ready to order!")
		Customer.State.WALKING_TO_SEAT, Customer.State.WAITING_FOR_FOOD:
			bubble.text = _quoted(customer.order_line, "%s, please!" % dish_name)
		Customer.State.EATING:
			bubble.text = "Nom nom..."
			# Same look as the plate the player carried: golden = good, dark = burnt.
			_food_material.albedo_color = Color(0.3, 0.2, 0.15).lerp(Color(0.95, 0.7, 0.3), customer.served_quality)
		Customer.State.LEAVING:
			bubble.text = "\"%s\"" % customer.reaction_line
			if customer.payment > 0:
				bubble.text += "\n+$%d" % customer.payment

	_update_name_tag()


# Regulars wear a name tag showing how well they know you, e.g. "Stitches - Nervous".
func _update_name_tag() -> void:
	name_tag.visible = customer.is_regular() and customer.state != Customer.State.GONE
	if customer.is_regular():
		var record: Dictionary = GameState.regulars[customer.regular_id]
		name_tag.text = "%s - %s" % [customer.display_name, RegularMemory.stage_name(record)]


# A regular's own line in quotes, or the generic text if they have none.
func _quoted(line: String, fallback: String) -> String:
	return "\"%s\"" % line if not line.is_empty() else fallback


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
