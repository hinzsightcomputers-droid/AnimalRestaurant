# StreetIntro: the start screen. The restaurant seen from across the street,
# lights off and the sign saying closed, while animals stroll past. The sky
# follows the real local time (morning, day, evening, or night after 7pm). Press
# start and the chef walks up, unlocks the door, goes in, closes it, flips the
# sign to open and the lights come on; then a circle wipe opens on the
# restaurant. Pressing again skips ahead. F4 previews the other times of day.
# After closing on the same day it's After Hours (see DayCycle): the prompt
# says so, and the chef unlocks the door and goes in but leaves the sign on
# closed.
# It fades in from black, coming after the LogoSplash. The main theme (started
# on the splash) slowly fades out once the lights come on, reaching silence as
# the circle wipe closes to black.
extends Node3D

const MAIN_SCENE := "res://scenes/main.tscn"
const CAMERA_START := Vector3(0, 2.6, 11.5)
const CAMERA_LOOK_START := Vector3(0, 2.0, 0)
const CAMERA_CLOSE := Vector3(1.0, 2.2, 8.4)
const CAMERA_LOOK_CLOSE := Vector3(1.0, 1.6, 0)
const CHEF_SPEED := 2.0
const FADE_IN_SECONDS := 1.2
const LIGHTS_HOLD_SECONDS := 1.4  # Looking at the lit-up restaurant before the circle wipe.
const WIPE_CLOSE_SECONDS := 0.9   # The circle wipe closing to black (see IrisTransition).
# Where the chef walks: up the sidewalk to the door, in, aside so the door can
# close, then to the sign in the right-hand window.
const DOOR_OUTSIDE := Vector3(0, 0, 1.0)
const DOOR_INSIDE := Vector3(0, 0, -1.1)
const BESIDE_DOOR := Vector3(1.2, 0, -1.1)
const AT_SIGN := Vector3(3.2, 0, -0.75)
# Between the planters and the street lamps at the curb.
const WALKER_LANES := [{ "z": 1.3, "direction": 1.0 }, { "z": 1.85, "direction": -1.0 }]
const WALKER_DIR := "res://design/characters/Extras/"  # Every model in here strolls past.
const WALKER_HEIGHT := [0.9, 1.15]
const WALKER_STRIDE := 1.2  # Meters a second their walk animation is made for.
const WALKER_EDGE := 13.0  # Walkers appear and disappear this far left/right.

# How each time of day looks. sun_angles: [pitch, yaw] in degrees. walker_gap:
# seconds between passers-by [min, max]. window_chance: how many of the
# neighbors' windows are lit.
const LOOKS := {
	"morning": {
		"sky_top": Color(0.45, 0.66, 0.92), "sky_horizon": Color(0.98, 0.84, 0.7), "ground": Color(0.6, 0.55, 0.5),
		"sun_color": Color(1, 0.9, 0.75), "sun_energy": 1.1, "sun_angles": [-25, -40],
		"ambient": Color(1, 0.93, 0.85), "ambient_energy": 0.55,
		"street_lights": 0.0, "window_chance": 0.0, "walker_gap": [1.5, 3.5], "moon": false, "glow": 0.8,
	},
	"day": {
		"sky_top": Color(0.3, 0.55, 0.9), "sky_horizon": Color(0.75, 0.86, 0.95), "ground": Color(0.55, 0.55, 0.52),
		"sun_color": Color(1, 0.97, 0.9), "sun_energy": 1.3, "sun_angles": [-55, -20],
		"ambient": Color(1, 0.97, 0.92), "ambient_energy": 0.6,
		"street_lights": 0.0, "window_chance": 0.0, "walker_gap": [1.2, 3.0], "moon": false, "glow": 0.8,
	},
	"evening": {
		"sky_top": Color(0.32, 0.35, 0.6), "sky_horizon": Color(1.0, 0.6, 0.38), "ground": Color(0.4, 0.32, 0.3),
		"sun_color": Color(1, 0.62, 0.38), "sun_energy": 0.9, "sun_angles": [-10, 40],
		"ambient": Color(1, 0.8, 0.7), "ambient_energy": 0.4,
		"street_lights": 0.9, "window_chance": 0.5, "walker_gap": [2.0, 4.5], "moon": false, "glow": 0.6,
	},
	"night": {
		"sky_top": Color(0.02, 0.03, 0.09), "sky_horizon": Color(0.08, 0.1, 0.22), "ground": Color(0.03, 0.03, 0.05),
		"sun_color": Color(0.6, 0.7, 1.0), "sun_energy": 0.25, "sun_angles": [-40, 30],
		"ambient": Color(0.45, 0.5, 0.8), "ambient_energy": 0.22,
		"street_lights": 1.8, "window_chance": 0.6, "walker_gap": [4.0, 8.0], "moon": true, "glow": 0.9,
	},
}
const LOOK_ORDER := ["morning", "day", "evening", "night"]

@onready var environment: Environment = $WorldEnvironment.environment
@onready var sun: DirectionalLight3D = $Sun
@onready var camera: Camera3D = $Camera
@onready var moon: MeshInstance3D = $Moon
@onready var chef: Node3D = $Chef
@onready var chef_model: Node3D = $Chef/Model
@onready var key: MeshInstance3D = $Chef/Model/Key
@onready var door_hinge: Node3D = $Restaurant/DoorHinge
@onready var sign_pivot: Node3D = $Inside/SignPivot
@onready var walkers: Node3D = $Walkers
@onready var title_ui: CanvasLayer = $TitleUI
@onready var prompt_label: Label = $TitleUI/Prompt
@onready var clock_label: Label = $TitleUI/Clock
@onready var name_label: Label3D = $Restaurant/NameLabel

const NAME_PIXEL_SIZE := 0.0045
const NAME_FITS_LETTERS := 17  # Longer names shrink to fit the board.

var _look_name := ""
var _look: Dictionary = {}
var _camera_look := CAMERA_LOOK_START  # Where the camera points; tweened with its position.
var _started := false
var _leaving := false
var _time := 0.0
var _next_walker := 0.0
var _walker_models: Array[PackedScene] = []
var _setup: RestaurantSetup = null  # Open while the restaurant is being named.


func _ready() -> void:
	camera.position = CAMERA_START
	_apply_look(look_for_hour(GameClock.now_local()["hour"]))
	_fade_in()
	_load_walker_models()
	if not GameState.restaurant_name.is_empty():
		_paint_sign(GameState.restaurant_name, Color(GameState.restaurant_color))
	if _after_hours():
		prompt_label.text = "Closed for today. Press E, Enter, or (A) to head in after hours"
	elif GameState.date == GameClock.today():
		prompt_label.text = "Press E, Enter, or (A) to carry on with %s" % DayCycle.phase_name().to_lower()
	# A few people already out walking, so the street isn't empty at first.
	for i in 3:
		_spawn_walker(randf_range(-WALKER_EDGE + 2.0, WALKER_EDGE - 2.0))


# Today's already been and closed: going in for After Hours, not to open up.
func _after_hours() -> bool:
	return GameState.date == GameClock.today() and DayCycle.is_after_hours()


# Comes in from black after the logo.
func _fade_in() -> void:
	var cover := ColorRect.new()
	cover.color = IrisTransition.COLOR
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.add_child(cover)
	add_child(layer)
	var tween := create_tween()
	tween.tween_property(cover, "color:a", 0.0, FADE_IN_SECONDS).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(layer.queue_free)


# Morning 6-10, day 10-17, evening 17-19, night from 7pm.
static func look_for_hour(hour: int) -> String:
	if hour >= 19 or hour < 6:
		return "night"
	if hour >= 17:
		return "evening"
	if hour >= 10:
		return "day"
	return "morning"


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F4:
		_apply_look(LOOK_ORDER[(LOOK_ORDER.find(_look_name) + 1) % LOOK_ORDER.size()])
		return
	if _setup != null or not _is_start_press(event):
		return
	get_viewport().set_input_as_handled()
	_take_over_player_one(InputSetup.device_of_interact_press(event))
	if not _started and GameState.restaurant_name.is_empty():
		_name_restaurant()  # First time: name it before opening up.
	elif not _started:
		_started = true
		_play_opening()
	else:
		_leave()  # Skip the rest.


# Starting on a gamepad makes it Player 1's, so whoever pressed start with
# one plays with it (the keyboard stays WASD).
func _take_over_player_one(device: String) -> void:
	if not device.begins_with("pad_") or InputSetup.is_device_used(device) or InputSetup.active_players() != [0]:
		return
	InputSetup.assign_device(0, device)


# The naming panel, with the sign on the building changing as they type.
func _name_restaurant() -> void:
	title_ui.visible = false
	_setup = RestaurantSetup.new()
	_setup.changed.connect(_paint_sign)
	add_child(_setup)
	await _setup.done
	_setup = null
	_started = true
	_play_opening()


func _paint_sign(restaurant_name: String, color: Color) -> void:
	name_label.text = restaurant_name
	name_label.modulate = color.lightened(0.35)
	name_label.outline_modulate = color.darkened(0.75)
	name_label.pixel_size = NAME_PIXEL_SIZE * minf(1.0, float(NAME_FITS_LETTERS) / maxi(1, restaurant_name.length()))


func _is_start_press(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept") or not InputSetup.device_of_interact_press(event).is_empty():
		return true
	for player_index in InputSetup.MAX_PLAYERS:
		if event.is_action_pressed(InputSetup.action_name(player_index, "interact")):
			return true
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT


func _process(delta: float) -> void:
	_time += delta
	camera.look_at(_camera_look)
	prompt_label.modulate.a = 0.6 + 0.4 * sin(_time * 3.0)
	clock_label.text = _clock_text()
	_update_walkers(delta)


# --- The opening ------------------------------------------------------------

func _play_opening() -> void:
	title_ui.visible = false
	var push := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	push.tween_property(camera, "position", CAMERA_CLOSE, 9.0)
	push.tween_property(self, "_camera_look", CAMERA_LOOK_CLOSE, 9.0)

	await _walk_to(DOOR_OUTSIDE)
	await _turn_to(PI)  # Face the door.
	await _unlock()
	await _swing_door(true)
	await _walk_to(DOOR_INSIDE)
	await _walk_to(BESIDE_DOOR)
	await _turn_to(0.0)
	await _swing_door(false)
	if not _after_hours():  # After hours the sign stays on closed.
		await _walk_to(AT_SIGN)
		await _turn_to(0.0)  # Face the window (and us).
		await _flip_sign()
	await _lights_on()
	Music.fade_out(LIGHTS_HOLD_SECONDS + WIPE_CLOSE_SECONDS)
	await get_tree().create_timer(LIGHTS_HOLD_SECONDS).timeout
	_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	Music.fade_out(WIPE_CLOSE_SECONDS)  # Sooner if the opening was skipped.
	IrisTransition.change_scene(get_tree(), MAIN_SCENE, WIPE_CLOSE_SECONDS)


func _walk_to(point: Vector3) -> void:
	var direction := point - chef.position
	if direction.length() < 0.01:
		return
	await _turn_to(atan2(direction.x, direction.z))
	var tween := create_tween()
	tween.tween_property(chef, "position", point, direction.length() / CHEF_SPEED)
	await tween.finished


# Turn to face an angle (0 = toward the street), the short way round.
func _turn_to(angle: float) -> void:
	var target := chef.rotation.y + wrapf(angle - chef.rotation.y, -PI, PI)
	var tween := create_tween()
	tween.tween_property(chef, "rotation:y", target, 0.2)
	await tween.finished


func _unlock() -> void:
	key.visible = true
	var tween := create_tween()
	tween.tween_interval(0.3)
	tween.tween_property(key, "rotation:z", PI / 2.0, 0.25)
	await tween.finished
	_pop_text("*click*", Vector3(0.5, 1.5, 0.4), Color(1, 0.95, 0.7))
	await get_tree().create_timer(0.35).timeout
	key.visible = false
	key.rotation.z = 0.0


# The door swings inward on its hinge.
func _swing_door(open: bool) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(door_hinge, "rotation:y", deg_to_rad(95.0) if open else 0.0, 0.6 if open else 0.45)
	await tween.finished
	if not open:
		_pop_text("*thunk*", Vector3(0, 2.0, 0.5), Color(1, 0.95, 0.85))


func _flip_sign() -> void:
	var tween := create_tween()
	tween.tween_property(chef_model, "position:y", 0.18, 0.12)  # A little hop to reach it.
	tween.tween_property(sign_pivot, "rotation:y", PI, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(chef_model, "position:y", 0.0, 0.2)
	await tween.finished


# The pendant lamps come on one after another and the windows glow.
func _lights_on() -> void:
	var lights := $Inside/Lights.get_children()
	var tween := create_tween().set_parallel()
	for i in lights.size():
		tween.tween_property(lights[i], "light_energy", 1.8, 0.25).set_delay(i * 0.18)
	var pendant: StandardMaterial3D = $Inside/PendantMiddle.material_override
	tween.tween_property(pendant, "emission_energy_multiplier", 3.0, 0.3)
	var glass: StandardMaterial3D = $Restaurant/GlassLeft.material_override
	tween.tween_property(glass, "emission_energy_multiplier", _look["glow"], 0.6).set_delay(0.2)
	tween.tween_property(glass, "albedo_color:a", 0.22, 0.6).set_delay(0.2)
	await tween.finished


# A word that floats up and fades, like "*click*".
func _pop_text(text: String, at: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.pixel_size = 0.005
	label.modulate = color
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at
	add_child(label)
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", at.y + 0.5, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


# --- Time of day -------------------------------------------------------------

func _apply_look(look_name: String) -> void:
	_look_name = look_name
	_look = LOOKS[look_name]
	var sky: ProceduralSkyMaterial = environment.sky.sky_material
	sky.sky_top_color = _look["sky_top"]
	sky.sky_horizon_color = _look["sky_horizon"]
	sky.ground_horizon_color = _look["sky_horizon"]
	sky.ground_bottom_color = _look["ground"]
	environment.ambient_light_color = _look["ambient"]
	environment.ambient_light_energy = _look["ambient_energy"]
	sun.light_color = _look["sun_color"]
	sun.light_energy = _look["sun_energy"]
	sun.rotation_degrees = Vector3(_look["sun_angles"][0], _look["sun_angles"][1], 0)
	# At night the "sun" is moonlight: no sun disc in the sky, the moon instead.
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY if _look["moon"] else DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	moon.visible = _look["moon"]

	for light in $Street/StreetLights.get_children():
		light.light_energy = _look["street_lights"]
	var bulb: StandardMaterial3D = $Street/LampBulbLeft.material_override
	bulb.emission_energy_multiplier = 3.0 if _look["street_lights"] > 0.0 else 0.0
	for window in $Neighbors/Windows.get_children():
		var material: StandardMaterial3D = window.material_override.duplicate()
		material.emission_energy_multiplier = randf_range(0.8, 1.6) if randf() < _look["window_chance"] else 0.0
		window.material_override = material
	if _started:  # The lights are already on: match the glow to the new time.
		var glass: StandardMaterial3D = $Restaurant/GlassLeft.material_override
		glass.emission_energy_multiplier = _look["glow"]


func _clock_text() -> String:
	var now := GameClock.now_local()
	var shown := "%s  %s" % [GameClock.describe_date(GameClock.calendar_date()), GameClock.describe_time(now)]
	if _look_name != look_for_hour(now["hour"]):
		shown += "  (previewing %s, F4)" % _look_name
	return shown


# --- Passers-by --------------------------------------------------------------

func _load_walker_models() -> void:
	for file in DirAccess.get_files_at(WALKER_DIR):
		var clean := file.trim_suffix(".import").trim_suffix(".remap")  # Exported games list the .import.
		if clean.get_extension() == "glb" and ResourceLoader.exists(WALKER_DIR + clean):
			var scene: PackedScene = load(WALKER_DIR + clean)
			if not _walker_models.has(scene):
				_walker_models.append(scene)


# One of the extras strolling along one of the lanes, starting at `x`, or at
# the edge they walk in from, its walk animation in step with its speed.
func _spawn_walker(x := INF) -> void:
	if _walker_models.is_empty():
		return
	var lane: Dictionary = WALKER_LANES.pick_random()
	if is_inf(x):
		x = -WALKER_EDGE * lane["direction"]
	var speed := randf_range(0.9, 1.5)
	var walker := Node3D.new()
	walkers.add_child(walker)
	var model: Node3D = _walker_models.pick_random().instantiate()
	walker.add_child(model)
	model.scale = Vector3.ONE * randf_range(WALKER_HEIGHT[0], WALKER_HEIGHT[1]) / ModelFit._bounds(model, Transform3D.IDENTITY).size.y
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var animations: AnimationPlayer = players[0]
		if animations.has_animation("walk"):
			animations.get_animation("walk").loop_mode = Animation.LOOP_LINEAR
			animations.play("walk")
			animations.speed_scale = speed / WALKER_STRIDE
			animations.seek(randf() * animations.current_animation_length)  # Not all in step.
	walker.position = Vector3(x, 0, lane["z"])
	walker.rotation.y = PI / 2.0 * lane["direction"]  # Nose along the way they're walking.
	walker.set_meta("velocity", lane["direction"] * speed)


func _update_walkers(delta: float) -> void:
	_next_walker -= delta
	if _next_walker <= 0.0:
		_spawn_walker()
		_next_walker = randf_range(_look["walker_gap"][0], _look["walker_gap"][1])
	for walker in walkers.get_children():
		var velocity: float = walker.get_meta("velocity")
		walker.position.x += velocity * delta
		if absf(walker.position.x) > WALKER_EDGE + 0.5:
			walker.queue_free()
