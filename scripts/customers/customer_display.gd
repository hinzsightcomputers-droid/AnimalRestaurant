# CustomerDisplay: makes a Customer visible. Colors the placeholder body by species,
# shows a speech bubble based on the customer's state, and shows the menu, their
# drink and their meal on the table. A regular with a "model" in their character file
# looks like that model instead (scaled to its height), and so does anyone
# whose species has "models" (one picked at random, at a height in its range),
# walking, sitting and talking with its animations (named in model_animations
# in data/regulars.json). Their head turns to look at a chef nearby (HeadTurn).
# A model without animations bobs along as it walks. A regular's feelings
# (Customer.emote) pop up over their head with a sound and a bounce. How
# their meal came out shows while they eat: their bubble, sparkles rising off a
# perfect plate or smoke off a burnt one, and a happy or sad moment halfway
# through. Display only.
extends Node3D

const DONE_DOTS_SCALE := 3.0  # The "..." of someone done eating, big enough to spot across the room.

@onready var customer: Customer = get_parent()
@onready var bubble: Label3D = $Bubble
@onready var name_tag: Label3D = $NameTag
@onready var meal: Node3D = $Meal
@onready var food: MeshInstance3D = $Meal/Food

const SPEECH_SECONDS := 6.0  # How long a one-off line stays up before the bubble goes back.
const PLATE_TOP := 0.046     # The meal's plate model: its top above its bottom, and its size.
const PLATE_RADIUS := 0.22

const RING_HEIGHT := 2.6  # The WaitRing, above the order bubble (two lines for a long dish name).
const AURA_HEIGHT := 0.12      # Sparkles or smoke start just over the food.
const MID_MEAL := 0.5           # How far through the meal (of eat_duration) they react to it again.

var _food_material := StandardMaterial3D.new()
var _speech_timer := Timer.new()
var _speech_state: Customer.State  # What they were doing when they said it.
var _look: Node3D = null           # A close-up dish as it came out, on their plate.
var _model: Node3D = null          # A regular's own model, instead of the placeholder shapes.
var _animations: AnimationPlayer = null
var _walk_time := 0.0
var _body := Node3D.new()          # Holds the model: hops and droops with their feelings.
var _emotions := EmotionPlayer.new()  # On top of their head (the placeholder's, unless a model moves it).
var _menu_card: MeshInstance3D = null  # On the table until they've ordered their food.
var _drink: DrinkModel = null          # The drink they were brought, beside their plate.
var _aura: CPUParticles3D = null       # Sparkles or smoke over their plate while they eat.


func _ready() -> void:
	_apply_species_color()
	_emotions.position.y = 1.5
	_load_model()
	add_child(_emotions)
	var ring := WaitRing.new()  # Over the order bubble while they wait for their food.
	ring.customer = customer
	ring.position.y = RING_HEIGHT
	add_child(ring)
	food.material_override = _food_material
	customer.state_changed.connect(_on_state_changed)
	customer.spoke.connect(_on_spoke)
	customer.talking_changed.connect(_on_talking_changed)
	customer.emoted.connect(func(_customer, emotion): _emotions.play_emotion(emotion))
	_speech_timer.one_shot = true
	_speech_timer.timeout.connect(_on_speech_timer_timeout)
	add_child(_speech_timer)
	_on_state_changed(customer)
	_play_pop_in()


func _on_state_changed(_customer: Customer) -> void:
	var dish_name: String = customer.dish.get("name", "something")
	meal.visible = customer.state == Customer.State.EATING
	bubble.visible = true
	bubble.scale = Vector3.ONE
	if _look != null and not meal.visible:
		_look.queue_free()
		_look = null
	if _aura != null and not meal.visible:
		_aura.queue_free()
		_aura = null

	_update_table_things()
	match customer.state:
		Customer.State.ARRIVING, Customer.State.GONE, Customer.State.FOLLOWING, Customer.State.WALKING_TO_SEAT:
			bubble.visible = false
		Customer.State.WAITING_BY_DOOR:
			bubble.text = "..."
		Customer.State.WAITING_TO_BE_SEATED:
			bubble.text = "Table, please!"  # A regular's greeting is said in the dialogue box when you seat them.
		Customer.State.WAITING_DRINK_ORDER:
			bubble.text = "Ready for a drink!"
		Customer.State.WAITING_FOR_DRINK:
			bubble.text = "The usual, please!" if customer.drink_secret else "%s, please!" % customer.drink.get("name", "A drink")
		Customer.State.WAITING_FOOD_ORDER:
			bubble.text = "Ready to order!"
		Customer.State.WAITING_FOR_FOOD:
			# A regular already said everything in the dialogue box; the order board has their dish.
			bubble.visible = not customer.is_regular()
			bubble.text = "%s, please!" % dish_name
		Customer.State.EATING:
			var tier := CookingMinigame.quality_label(customer.served_quality).to_lower()
			var own := Townsfolk.eating_line(customer.townsfolk_id, tier) if customer.is_townsfolk() else ""
			bubble.text = own if not own.is_empty() else String(GameData.service.get("townsfolk", {}).get("eating", {}).get(tier, "Nom nom..."))
			if _aura == null:
				_start_aura(tier)
				_react_mid_meal(tier)
			# Same look as the plate the player carried: golden = good, dark = burnt.
			_food_material.albedo_color = Color(0.3, 0.2, 0.15).lerp(Color(0.95, 0.7, 0.3), customer.served_quality)
			if _look == null and customer.served_dish != null:  # The real thing, the way it was cooked.
				_look = customer.served_dish.show_look(meal, Vector3(0.0, PLATE_TOP, 0.0), PLATE_RADIUS)
			food.visible = _look == null
		Customer.State.DONE_EATING:
			bubble.text = "..."  # Come and chat: that's when they ask for the bill.
			bubble.scale = Vector3.ONE * DONE_DOTS_SCALE
		Customer.State.WANTS_BILL:
			bubble.text = "Check, please!"
		Customer.State.LEAVING:
			bubble.visible = false  # Their goodbye was in the dialogue box; what they paid is announced.

	_update_name_tag()


# Sparkles rising off a perfect plate, grey smoke off a burnt one; nothing
# in between.
func _start_aura(tier: String) -> void:
	if tier != "perfect" and tier != "burnt":
		return
	var perfect := tier == "perfect"
	_aura = CPUParticles3D.new()
	_aura.amount = 14 if perfect else 12
	_aura.lifetime = 1.8 if perfect else 2.0
	_aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_aura.emission_sphere_radius = PLATE_RADIUS * 0.6
	_aura.direction = Vector3.UP
	_aura.spread = 20.0
	_aura.initial_velocity_min = 0.1 if perfect else 0.06
	_aura.initial_velocity_max = 0.35 if perfect else 0.18
	_aura.gravity = Vector3.ZERO
	_aura.scale_amount_min = 0.6
	_aura.scale_amount_max = 1.4 if perfect else 2.6
	var fade := Gradient.new()  # In, then out.
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.25, Color.WHITE)
	fade.set_color(fade.get_point_count() - 1, Color(1.0, 1.0, 1.0, 0.0))
	_aura.color_ramp = fade
	var dot := SphereMesh.new()
	dot.radius = 0.055 if perfect else 0.06
	dot.height = dot.radius * 2.0
	dot.radial_segments = 6
	dot.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.9, 0.35) if perfect else Color(0.25, 0.23, 0.22, 0.7)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true  # So the fade works.
	dot.material = material
	_aura.mesh = dot
	_aura.position.y = AURA_HEIGHT
	meal.add_child(_aura)
	_aura.emitting = true


# Halfway through, how it tastes shows again: a happy bounce for a perfect
# dish, a sad droop for a burnt one.
func _react_mid_meal(tier: String) -> void:
	var feeling: StringName = {"perfect": &"joyful", "burnt": &"sad"}.get(tier, &"")
	if feeling == &"":
		return
	while is_instance_valid(customer) and customer.state == Customer.State.EATING and customer.meal_left() > 1.0 - MID_MEAL:
		await get_tree().process_frame
	if is_instance_valid(customer) and customer.state == Customer.State.EATING:
		customer.emote(feeling)


# The menu card lies on the table from sitting down until they've ordered food;
# the drink they got stands by their plate until they leave.
func _update_table_things() -> void:
	var reading_menu := customer.state in [Customer.State.WAITING_DRINK_ORDER, Customer.State.WAITING_FOR_DRINK, Customer.State.WAITING_FOOD_ORDER]
	if reading_menu and _menu_card == null:
		_menu_card = MeshInstance3D.new()
		var card := BoxMesh.new()
		card.size = Vector3(0.22, 0.012, 0.3)
		_menu_card.mesh = card
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.55, 0.15, 0.12)
		_menu_card.material_override = material
		_menu_card.position = meal.position + Vector3(0.0, 0.01, -0.05)
		_menu_card.rotation_degrees.y = 12.0
		add_child(_menu_card)
	elif not reading_menu and _menu_card != null:
		_menu_card.queue_free()
		_menu_card = null
	var has_drink := customer.is_seated() and not customer.served_drink.is_empty()
	if has_drink and _drink == null:
		_drink = DrinkModel.make(customer.served_drink)
		_drink.position = meal.position + Vector3(0.3, 0.0, -0.1)
		add_child(_drink)
	elif not has_drink and _drink != null:
		_drink.queue_free()
		_drink = null


# A one-off line (served, eating chat) shows for a while, then the bubble goes
# back to whatever fits their state.
func _on_spoke(_customer: Customer) -> void:
	_speech_state = customer.state
	bubble.visible = true
	bubble.scale = Vector3.ONE
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


# Regulars wear a name tag showing how well they know you, e.g. "Stitches - Nervous";
# named townsfolk just their name.
func _update_name_tag() -> void:
	name_tag.visible = (customer.is_regular() or customer.is_townsfolk()) and customer.state != Customer.State.GONE
	if customer.is_townsfolk():
		name_tag.text = customer.display_name
	elif customer.is_regular():
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


func _load_model() -> void:
	var settings := _model_settings()
	var path: String = settings.get("path", "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	_model = load(path).instantiate()
	add_child(_body)
	_body.add_child(_model)
	var height := _bounds(_model).size.y
	if height > 0.0:
		_model.scale = Vector3.ONE * (float(settings.get("height", 1.2)) / height)
	_emotions.body_root = _body
	_emotions.position.y = float(settings.get("height", 1.2)) + 0.1
	for child in get_children():  # The placeholder shapes.
		if child is MeshInstance3D:
			child.visible = false
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	_animations = players[0] if not players.is_empty() else null
	HeadTurn.attach(_model)  # Looks at a chef nearby.


# { path, height }: the regular's (or named townsfolk's) own model, or one of their species'.
func _model_settings() -> Dictionary:
	if customer.is_regular():
		return GameState.regulars[customer.regular_id].get("model", {})
	var own: Dictionary = GameData.get_townsfolk(customer.townsfolk_id).get("model", {}) if customer.is_townsfolk() else {}
	if not own.is_empty():
		return own
	var models: Array = customer.species.get("models", [])
	if models.is_empty():
		return {}
	var height: Array = customer.species.get("height", [1.0, 1.1])
	return { "path": models.pick_random(), "height": randf_range(height[0], height[1]) }


func _process(delta: float) -> void:
	if _model == null:
		return
	var seated := customer.seat != null and not customer.is_walking() and customer.is_seated()
	var animation := "walk" if customer.is_walking() else ("sit" if seated else "idle")
	if customer.talking:
		animation = "sit_talk" if seated else "talk"
	if _animations != null:
		_play(animation)
		return
	# No animations: a little waddle while walking, and sunk into the chair when seated.
	if animation == "walk":
		_walk_time += delta
		_model.position.y = absf(sin(_walk_time * 9.0)) * 0.05
		_model.rotation.z = sin(_walk_time * 9.0) * 0.08
	else:
		_walk_time = 0.0
		_model.position.y = -0.2 if seated else 0.0
		_model.rotation.z = 0.0


# Play one of the model's animations, by what it's for (walk, idle, sit, talk, sit_talk), looping.
func _play(what: String) -> void:
	var names: Dictionary = GameData.regular_settings.get("model_animations", {})
	var animation_name: String = names.get(what, what)
	if not _animations.has_animation(animation_name) or _animations.current_animation == animation_name:
		return
	_animations.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	_animations.play(animation_name, 0.25)


func _bounds(node: Node) -> AABB:
	var box := AABB()
	var first := true
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var part: AABB = mesh.global_transform * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


# Grow from nothing so customers don't just blink into existence.
func _play_pop_in() -> void:
	scale = Vector3.ONE * 0.01
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
