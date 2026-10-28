# CustomerDisplay: makes a Customer visible. Colors the placeholder body by species,
# shows a speech bubble based on the customer's state, and shows their meal on
# the table while eating. Display only.
extends Node3D

@onready var customer: Customer = get_parent()
@onready var bubble: Label3D = $Bubble
@onready var name_tag: Label3D = $NameTag
@onready var meal: Node3D = $Meal
@onready var food: MeshInstance3D = $Meal/Food

const SPEECH_SECONDS := 6.0  # How long a one-off line stays up before the bubble goes back.
const PLATE_TOP := 0.02      # The meal's plate model: its top above its middle, and its size.
const PLATE_RADIUS := 0.22

var _food_material := StandardMaterial3D.new()
var _speech_timer := Timer.new()
var _speech_state: Customer.State  # What they were doing when they said it.
var _look: Node3D = null           # A close-up dish as it came out, on their plate.


func _ready() -> void:
	_apply_species_color()
	food.material_override = _food_material
	customer.state_changed.connect(_on_state_changed)
	customer.spoke.connect(_on_spoke)
	customer.talking_changed.connect(_on_talking_changed)
	_speech_timer.one_shot = true
	_speech_timer.timeout.connect(_on_speech_timer_timeout)
	add_child(_speech_timer)
	_on_state_changed(customer)
	_play_pop_in()


func _on_state_changed(_customer: Customer) -> void:
	var dish_name: String = customer.dish.get("name", "something")
	meal.visible = customer.state == Customer.State.EATING
	bubble.visible = true
	if _look != null and not meal.visible:
		_look.queue_free()
		_look = null

	match customer.state:
		Customer.State.ARRIVING, Customer.State.GONE:
			bubble.visible = false
		Customer.State.WAITING_BY_DOOR:
			bubble.text = "..."
		Customer.State.WAITING_TO_ORDER:
			bubble.text = "Ready to order!"  # A regular's greeting is said in the dialogue box when you take their order.
		Customer.State.WALKING_TO_SEAT, Customer.State.WAITING_FOR_FOOD:
			# A regular already said everything in the dialogue box; the order board has their dish.
			bubble.visible = not customer.is_regular()
			bubble.text = "%s, please!" % dish_name
		Customer.State.EATING:
			bubble.text = "Nom nom..."
			# Same look as the plate the player carried: golden = good, dark = burnt.
			_food_material.albedo_color = Color(0.3, 0.2, 0.15).lerp(Color(0.95, 0.7, 0.3), customer.served_quality)
			if _look == null and customer.served_dish != null:  # The real thing, the way it was cooked.
				_look = customer.served_dish.show_look(meal, Vector3(0.0, PLATE_TOP, 0.0), PLATE_RADIUS)
			food.visible = _look == null
		Customer.State.LEAVING:
			bubble.text = "\"%s\"" % customer.reaction_line
			if customer.payment > 0:
				bubble.text += "\n+$%d" % customer.payment

	_update_name_tag()


# A one-off line (served, eating chat) shows for a while, then the bubble goes
# back to whatever fits their state.
func _on_spoke(_customer: Customer) -> void:
	_speech_state = customer.state
	bubble.visible = true
	# In a conversation the dialogue box has the words; the bubble just shows they're talking.
	bubble.text = "..." if customer.talking else _quoted(customer.speech, "")
	_speech_timer.start(SPEECH_SECONDS)


# When a conversation ends, the bubble goes straight back to normal (the dialogue
# box had the words, so nothing lingers over their head).
func _on_talking_changed(_customer: Customer) -> void:
	if not customer.talking:
		_speech_timer.stop()
		_on_state_changed(customer)


func _on_speech_timer_timeout() -> void:
	if customer.state == _speech_state:  # A state change already replaced the line otherwise.
		_on_state_changed(customer)


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
