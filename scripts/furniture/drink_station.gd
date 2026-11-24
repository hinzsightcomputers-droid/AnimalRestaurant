# DrinkStation: a drink machine on the drinks counter. There are two:
#   the fountain (prep "pour" in design/menu/drinks.json): water, every pop and
#     everything else cold;
#   the brewer (prep "brew"): everything hot. Hot chocolate gets a handful of
#     mini marshmallows after (its "topping" in data/drink_kitchen.json).
# Both work the same way. Walk up with room in your hands while someone's waiting
# on one of its drinks, and you're at the machine, a glass under its taps. Left
# and right slide the glass to a tap (every drink it has is there: it's up to you
# to pick the one they asked for; who's waiting for what is on the sign). Hold
# interact and it pours while you hold it: let go as it reaches the line. The
# closer, the better; too far and it spills over. Let go early and you can top it
# up. The back button (InputSetup.back_hint) pours out what's in the glass, or
# steps away from an empty one. Then it goes in your hands (a Drink) to carry.
# A drink nobody's waiting for can be poured out here too.
class_name DrinkStation
extends Station

enum Pour { NONE, CHOOSE, FILLING, SETTLE, TOPPING, TOPPED }

const GROUP := "drink_stations"
const LINE := 0.8              # The fill line, as a fraction of the glass.
const ENOUGH := 0.62           # Filled less than this (of the line), it isn't done yet: hold again.
const STEP_FIRST := 0.32       # Holding left or right, seconds before the glass moves on again...
const STEP_AFTER := 0.16       # ...and between moves after that.
const SETTLE_SECONDS := 0.55   # A look at it before it's picked up.
const TOPPED_SECONDS := 1.3
const WORDS_AT := Vector3(0.0, 1.66, 0.12)      # Over the machine...
const WORDS_CLOSE := Vector3(0.0, 1.225, 0.2)  # ...and, close in on the glass, over that.
const WORDS_SIZE := 0.00095
const WORDS_CLOSE_SIZE := 0.00036
const CUP_SCALE := 1.2
const DROP_EVERY := 0.07       # Seconds between marshmallows falling in.

@export var brewer := false
@export var machine_width := 1.3
@export var view_manager: ViewManager

var _pourer: Player = null     # Who's at it.
var _pour := Pour.NONE
var _pour_drink: Dictionary = {}  # What's being (or been) poured into the glass.
var _drinks: Array = []        # What the taps give, left to right.
var _tap := 0
var _fill := 0.0
var _wait := 0.0
var _ready_for_press := false  # They've let go of interact since the last step.
var _stick_way := 0
var _stick_wait := 0.0
var _left_to_drop := 0
var _was_locked := false
var _cup: DrinkModel = null
var _stand: Node3D = null      # The glass and its line: slides along the taps.
var _glug: AudioStreamPlayer3D

@onready var machine: DrinkMachine = $Visual/Machine
@onready var status_label: Label3D = $StatusLabel


func _ready() -> void:
	super._ready()
	add_to_group(GROUP)
	interactable.prompt_for_player = _prompt_for
	_glug = AudioStreamPlayer3D.new()
	_glug.stream = CookSounds.get_sound("pour")
	_glug.volume_db = -8.0
	_glug.unit_size = 6.0
	add_child(_glug)
	_show_taps()


# Whether a drink is made here.
func makes(drink: Dictionary) -> bool:
	return (drink.get("prep", "pour") == "brew") == brewer


# Whether player `index` could make something here that's waited for.
func has_work_for(index: int) -> bool:
	var player := Player.find(get_tree(), index)
	return player != null and _pourer == null and player.tray_room("drinks") and not _drinks_to_make().is_empty()


# A station with something to make for this player, or null.
static func with_work_for(tree: SceneTree, index: int) -> DrinkStation:
	for station: DrinkStation in tree.get_nodes_in_group(GROUP):
		if station.has_work_for(index):
			return station
	return null


func _prompt_for(player_index: int) -> String:
	var player := Player.find(get_tree(), player_index)
	if player == null or _pourer != null:
		return ""
	if _unwanted(player.held_item):
		return "Pour out the %s" % player.held_item.display_name()
	if not has_work_for(player_index):
		return ""
	return "Make a hot drink" if brewer else "Pour a drink"


func _on_interacted(player_index: int) -> void:
	var player := Player.find(get_tree(), player_index)
	if player == null or _pourer != null or player.movement_locked:
		return
	if _unwanted(player.held_item):
		GameEvents.announce("Poured out the %s." % player.held_item.display_name())
		player.set_held_item(null)
		_play_bounce()
		return
	if not player.tray_room("drinks"):
		GameEvents.announce("Your hands are full." if Player.tray_kind(player.held_item) != "drinks" else "Your tray is full.")
		return
	if _drinks_to_make().is_empty():
		GameEvents.announce("Nobody's waiting on a %s drink." % ("hot" if brewer else "cold"))
		return
	_play_bounce()
	used.emit(self, player_index)
	_start(player)


# A drink in someone's hands that nobody's waiting for (and nobody's "usual").
func _unwanted(item: RefCounted) -> bool:
	if not item is Drink or not makes(item.drink):
		return false
	for customer in _waiting():
		if customer.drink_secret or customer.drink.get("id", "") == item.id():
			return false
	return true


func _waiting() -> Array[Customer]:
	var waiting: Array[Customer] = []
	for node in get_tree().get_nodes_in_group(Customer.GROUP):
		var customer := node as Customer
		if customer != null and customer.state == Customer.State.WAITING_FOR_DRINK:
			waiting.append(customer)
	return waiting


# The drinks of this machine's that seated customers are waiting for and nobody's
# making or carrying yet, one entry per kind (two lemonades ordered and one
# poured: one left). All of them while someone's "usual" is still to make (a
# regular who didn't say which; a drink in the works that nobody named covers one
# usual).
func _drinks_to_make() -> Array:
	var wanted := []
	var usuals := 0
	for customer in _waiting():
		if customer.drink_secret:
			usuals += 1
		else:
			wanted.append(customer.drink.get("id", ""))
	var made := []
	for station: DrinkStation in get_tree().get_nodes_in_group(GROUP):
		if station._pourer != null and station._fill > 0.0:
			made.append(station._pour_drink.get("id", ""))
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		for held in (node as Player).carried():
			if held is Drink:
				made.append(held.id())
	for id in made:
		if id in wanted:
			wanted.erase(id)
		else:
			usuals -= 1
	var mine: Array = GameData.drink_menu().filter(makes)
	if usuals > 0:
		return mine
	return mine.filter(func(d): return d["id"] in wanted)


# --- At the machine ----------------------------------------------------------------

func _show_taps() -> void:
	_drinks = GameData.drink_menu().filter(makes)
	machine.show_drinks(_drinks, machine_width, brewer)


func _start(player: Player) -> void:
	_show_taps()
	_pourer = player
	_pour = Pour.CHOOSE
	_ready_for_press = false
	_stick_way = 0
	_tap = _drinks.size() / 2  # The middle one.
	player.movement_locked = true
	player.interactor.lock_to(interactable)
	player.hide_from_own_view(true)  # So the chef doesn't block the machine.
	_new_glass()
	_look(0.45)


# Close in on the taps, from straight in front, following the glass along; right
# in on the glass while it fills; or down into it (from_above).
func _look(seconds: float, on_glass := false, from_above := false) -> void:
	var zoom := CameraZoomSettings.new()
	zoom.distance = 0.4 if on_glass else (0.95 if _drinks.size() < 7 else 0.8)
	zoom.pitch_degrees = 38.0 if from_above else (14.0 if on_glass else 10.0)
	zoom.yaw_degrees = rad_to_deg(atan2(global_basis.z.x, global_basis.z.z))
	zoom.duration = seconds
	var middle: float = 0.0 if _drinks.size() < 4 else 0.75 * machine.taps[_tap].x
	var at := Vector3(middle, 0.29, DrinkMachine.TAP_Z)
	if on_glass:
		at = Vector3(machine.taps[_tap].x, 0.17, DrinkMachine.TAP_Z)
	status_label.position = Vector3(machine.taps[_tap].x, WORDS_CLOSE.y + (0.11 if from_above else 0.0), WORDS_CLOSE.z - (0.06 if from_above else 0.0)) if on_glass else WORDS_AT + Vector3(middle, 0.0, 0.0)
	status_label.pixel_size = WORDS_CLOSE_SIZE if on_glass else WORDS_SIZE
	_pourer.request_camera_focus(machine.to_global(at), zoom)


# An empty glass under the tap.
func _new_glass() -> void:
	_fill = 0.0
	_pour_drink = _drinks[_tap]
	if _stand == null:
		_stand = Node3D.new()
		machine.add_child(_stand)
		_stand.position = Vector3(machine.taps[_tap].x, DrinkMachine.TRAY_TOP, DrinkMachine.TAP_Z)
	for child in _stand.get_children():
		child.queue_free()
	_cup = DrinkModel.make(_pour_drink, 0.0)
	_cup.scale = Vector3.ONE * CUP_SCALE
	_stand.add_child(_cup)
	var line := MeshInstance3D.new()  # Where to stop: a thin ring round the glass.
	var ring := TorusMesh.new()
	ring.inner_radius = DrinkModel.rim_radius(_pour_drink) * 0.985
	ring.outer_radius = DrinkModel.rim_radius(_pour_drink) * 1.06
	ring.rings = 36
	line.mesh = ring
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.9, 0.16, 0.12)
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line.material_override = paint
	line.scale = Vector3(1.0, 0.45, 1.0)
	line.position.y = 0.006 + DrinkModel.HEIGHT * DrinkModel.FULL * LINE
	_cup.add_child(line)
	machine.pick(_tap)


func _process(delta: float) -> void:
	if _pourer == null:
		return
	if not is_instance_valid(_pourer):
		_pourer = null
		_clear()
		return
	var tap := machine.taps[_tap]
	_stand.position.x = lerpf(_stand.position.x, tap.x, 1.0 - exp(-16.0 * delta))
	var pressed := _pourer.input.is_interact_pressed()
	if not pressed:
		_ready_for_press = true
	var press := pressed and _ready_for_press
	match _pour:
		Pour.CHOOSE:
			_move(delta)
			if _pour == Pour.NONE:
				return
			if press and absf(_stand.position.x - tap.x) < 0.01:
				if _fill <= 0.0 and _pour_drink != _drinks[_tap]:
					_new_glass()
				_pour = Pour.FILLING
				_look(0.35, true)
		Pour.FILLING:
			var seconds := float(GameData.drink_settings.get("brew_fill_seconds" if brewer else "fill_seconds", 1.8))
			_fill += delta / seconds * LINE
			_cup.set_fill(_fill)
			_cup.pour_in(delta)
			var spill := float(GameData.drink_settings.get("spill_fill", 1.25)) * LINE
			if _fill >= spill:
				_stop_pouring(true)
			elif not pressed:
				_stop_pouring(false)
		Pour.SETTLE:
			_wait -= delta
			if _wait <= 0.0:
				if _pour_drink.get("topping", "") == "marshmallows":
					_pour = Pour.TOPPING
					_ready_for_press = not pressed
					_look(0.4, true, true)
				else:
					_finish()
					return
		Pour.TOPPING:
			if press:
				_pour = Pour.TOPPED
				_left_to_drop = DrinkModel.MARSHMALLOWS
				_wait = TOPPED_SECONDS + DrinkModel.MARSHMALLOWS * DROP_EVERY
				_drop_marshmallows()
		Pour.TOPPED:
			_wait -= delta
			if _wait <= 0.0:
				_finish()
				return
	var pouring := _pour == Pour.FILLING
	machine.pour(_tap, Color(_pour_drink.get("color", "#888888")), _stand.position.y + _cup.level() * CUP_SCALE, pouring)
	if pouring != _glug.playing:
		if pouring:
			_glug.play()
		else:
			_glug.stop()
	if pouring:  # It sounds higher as it fills.
		_glug.pitch_scale = lerpf(0.85, 1.35, clampf(_fill, 0.0, 1.0))
	_show_words()


# The glass along to the next tap; the back button.
func _move(delta: float) -> void:
	if Input.is_action_just_pressed(InputSetup.action_name(_pourer.player_index, "decor_done")):
		if _fill > 0.0:
			_sound("plop", -6.0, 0.7)
			_new_glass()
			_look(0.3)
		else:
			_leave()
		return
	if _fill > 0.0:
		return  # It's got something in it: no mixing.
	var x := _pourer.input.get_move_vector().x
	var way := int(signf(x)) if absf(x) > 0.5 else 0
	_stick_wait -= delta
	if way == 0:
		_stick_way = 0
	elif way != _stick_way or _stick_wait <= 0.0:
		_stick_wait = STEP_FIRST if way != _stick_way else STEP_AFTER
		_stick_way = way
		var next := clampi(_tap + way, 0, _drinks.size() - 1)
		if next != _tap:
			_tap = next
			machine.pick(_tap)
			_sound("tick", -6.0, 1.2)
			_look(0.25)


func _stop_pouring(spilled: bool) -> void:
	_ready_for_press = false
	_sound("plop", -8.0, 1.2)
	if not spilled and _fill < LINE * ENOUGH:
		_pour = Pour.CHOOSE
		return
	if spilled:
		_cup.jolt(0.12)
		_spill()
	_cup.add_extras(_pour_drink)
	_pour = Pour.SETTLE
	_wait = SETTLE_SECONDS


# How well it was poured (0..1).
func _quality() -> float:
	var spill := float(GameData.drink_settings.get("spill_fill", 1.25)) * LINE
	return 0.2 if _fill >= spill else clampf(1.0 - maxf(absf(_fill - LINE) - 0.015, 0.0) / 0.4, 0.1, 1.0)


func _finish() -> void:
	var player := _pourer
	var quality := _quality()
	player.take(Drink.new(_pour_drink, quality))
	if quality <= 0.2:
		GameEvents.announce("Oops, the %s spilled over!" % _pour_drink["name"])
	else:
		GameEvents.announce("Poured a %s (%s)." % [_pour_drink["name"], CookingMinigame.quality_label(quality)])
	_play_bounce()
	_leave()


func _leave() -> void:
	var player := _pourer
	_pourer = null
	_clear()
	player.ignore_interact_until_released()
	player.movement_locked = false
	player.interactor.unlock()
	player.release_camera_focus()
	player.hide_from_own_view(false)


func _clear() -> void:
	_pour = Pour.NONE
	_fill = 0.0
	_glug.stop()
	machine.pick(-1)
	machine.pour(_tap, Color.WHITE, 0.0, false)
	if _stand != null:
		_stand.queue_free()
		_stand = null
		_cup = null
	status_label.visible = false


# Out of the bowl, over the cup, and in a few at a time.
func _drop_marshmallows() -> void:
	var cup := _cup
	var hand := Node3D.new()
	machine.add_child(hand)
	var bit := CapsuleMesh.new()
	bit.radius = DrinkModel.MARSHMALLOW_SIZE * 0.5 * CUP_SCALE
	bit.height = DrinkModel.MARSHMALLOW_SIZE * 1.25 * CUP_SCALE
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(1.0, 0.97, 0.94)
	bit.material = paint
	for i in DrinkModel.MARSHMALLOWS:  # The handful on its way over.
		var one := MeshInstance3D.new()
		one.mesh = bit
		one.position = Vector3(randf_range(-1.0, 1.0), randf_range(-0.5, 0.8), randf_range(-1.0, 1.0)) * 0.018
		one.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
		hand.add_child(one)
	hand.position = machine.bowl_at() + Vector3(0.0, 0.08, 0.0)
	var over := _stand.position + Vector3(0.0, DrinkModel.HEIGHT * CUP_SCALE + 0.1, 0.0)
	var fly := hand.create_tween()
	fly.tween_property(hand, "position", hand.position.lerp(over, 0.5) + Vector3(0.0, 0.1, 0.0), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fly.tween_property(hand, "position", over, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fly.tween_callback(func():
		hand.queue_free()
		for i in DrinkModel.MARSHMALLOWS:
			if not is_instance_valid(cup):
				return
			cup.add_marshmallow(true, 0.07 + randf() * 0.03)
			if i % 2 == 0:
				_sound("plop", -14.0, randf_range(1.5, 1.9))
			await get_tree().create_timer(DROP_EVERY).timeout)


# Over the rim and down the outside.
func _spill() -> void:
	var drops := CPUParticles3D.new()
	drops.one_shot = true
	drops.amount = 22
	drops.lifetime = 0.6
	drops.explosiveness = 0.8
	drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	drops.emission_ring_axis = Vector3.UP
	drops.emission_ring_radius = DrinkModel.RADIUS * CUP_SCALE
	drops.emission_ring_inner_radius = DrinkModel.RADIUS * CUP_SCALE * 0.9
	drops.emission_ring_height = 0.0
	drops.direction = Vector3.UP
	drops.spread = 60.0
	drops.initial_velocity_min = 0.15
	drops.initial_velocity_max = 0.4
	drops.gravity = Vector3(0.0, -2.5, 0.0)
	var drop := SphereMesh.new()
	drop.radius = 0.006
	drop.height = 0.012
	drop.radial_segments = 8
	drop.rings = 4
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(_pour_drink.get("color", "#888888"))
	paint.roughness = 0.2
	drop.material = paint
	drops.mesh = drop
	drops.position = _stand.position + Vector3(0.0, DrinkModel.HEIGHT * CUP_SCALE, 0.0)
	machine.add_child(drops)
	drops.emitting = true
	drops.finished.connect(drops.queue_free)


func _sound(sound: String, volume_db: float, pitch: float) -> void:
	var player := AudioStreamPlayer3D.new()
	player.stream = CookSounds.get_sound(sound)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.unit_size = 6.0
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


# Who's waiting for what, and what to press, over the machine.
func _show_words() -> void:
	var index := _pourer.player_index
	var button := InputSetup.interact_hint(index)
	var back := InputSetup.back_hint(index)
	var lines := []
	match _pour:
		Pour.CHOOSE when _fill <= 0.0:
			lines.append(_wanted_words())
			lines.append("Left and right: choose    Hold %s: pour    %s: step away" % [button, back])
		Pour.CHOOSE:
			lines.append("Not full yet: hold %s to top it up" % button)
			lines.append("%s: pour it out" % back)
		Pour.FILLING:
			lines.append("%s: let go at the line!" % _pour_drink["name"])
		Pour.TOPPING:
			lines.append("Press %s: a handful of mini marshmallows!" % button)
		_:
			lines.append("Perfect!" if _quality() >= 0.95 else ("Spilled over!" if _quality() <= 0.2 else "%s" % CookingMinigame.quality_label(_quality())))
	status_label.text = "\n".join(lines)
	status_label.visible = true


func _wanted_words() -> String:
	var wanted := []
	for customer in _waiting():
		if customer.drink_secret:
			wanted.append("%s: the usual" % customer.display_name)
		elif makes(customer.drink):
			wanted.append("%s: %s" % [customer.display_name, customer.drink.get("name", "a drink")])
	return "Waiting for  " + ",  ".join(wanted)


# For a reel or the bot: what to press next to make what's wanted, "left",
# "right", "pour" (hold till it's at the line), "top" or "" (wait).
func next_move() -> String:
	match _pour:
		Pour.CHOOSE:
			if _fill > 0.0 or not _ready_for_press:
				return "pour" if _ready_for_press else ""
			var wanted := _drinks_to_make()
			if wanted.is_empty() or _drinks[_tap] in wanted:
				return "pour" if absf(_stand.position.x - machine.taps[_tap].x) < 0.01 else ""
			return "right" if _drinks.find(wanted[0]) > _tap else "left"
		Pour.TOPPING:
			return "top"
	return ""
