# DriveView: the drive in Cheddar's car, one shared view for everyone on the
# trip. A little world of its own: Cheddar's car (him inside, at the wheel)
# bowling along a coast road from the side, the lane marks and trees rushing
# past, the sea behind, and the sky the color of the real hour (data/trips.json
# drive.sky). Shown over the whole screen when every player is going, or else
# over each traveler's own view. Each display has a dialogue box for Cheddar's
# chatter (say), and a "skip" hint once the drive can be skipped. CarTrip
# moves the chefs while it covers their views, then closes it.
class_name DriveView
extends Node

const FADE_SECONDS := 0.4
const WRAP := 36.0  # Scenery that goes past -WRAP comes round again at +WRAP.
const TALL_CAMERA_BACK := 11.0

signal shown

var view_manager: ViewManager
var travelers: Array[int] = []
var full_screen := true
var skippable := false

var _viewport := SubViewport.new()
var _layer: CanvasLayer = null
var _displays: Array[Control] = []
var _boxes: Array[ConversationBox] = []
var _moving: Array[Node3D] = []
var _car: Node3D
var _time := 0.0
var _speed := 9.0


func _ready() -> void:
	var settings: Dictionary = GameData.trips.get("drive", {})
	_speed = float(settings.get("speed", 9.0))
	_viewport.own_world_3d = true
	_viewport.size = Vector2i(get_viewport().get_visible_rect().size)
	add_child(_viewport)
	_build_world(settings)
	if full_screen:
		_layer = CanvasLayer.new()
		_layer.layer = 3
		add_child(_layer)
		_displays.append(_make_display(_layer, travelers.front()))
	else:
		for player_index in travelers:
			var view := view_manager.view_for(player_index) if view_manager != null else null
			if view != null:
				_displays.append(_make_display(view, player_index))
	var tween := create_tween().set_parallel()
	for display in _displays:
		display.modulate.a = 0.0
		tween.tween_property(display, "modulate:a", 1.0, FADE_SECONDS)
	tween.chain().tween_callback(shown.emit)


func _process(delta: float) -> void:
	_time += delta
	for node in _moving:
		node.position.x -= _speed * delta
		if node.position.x < -WRAP:
			node.position.x += WRAP * 2.0
	if _car != null:
		_car.position.y = absf(sin(_time * 7.0)) * 0.03
		_car.rotation.z = sin(_time * 3.1) * 0.01


# Cheddar says something in every display's box (it moves on by itself).
func say(text: String, emotion: StringName = &"") -> void:
	for box in _boxes:
		if is_instance_valid(box):
			box.tell(GameState.regulars.get("cheddar", {}).get("name", "Cheddar"), text, emotion)


# Fades out and goes.
func close() -> void:
	var tween := create_tween().set_parallel()
	for display in _displays:
		if is_instance_valid(display):
			tween.tween_property(display, "modulate:a", 0.0, FADE_SECONDS)
	tween.chain().tween_callback(func():
		for display in _displays:
			if is_instance_valid(display):
				display.queue_free()
		queue_free())


func _make_display(parent: Node, player_index: int) -> Control:
	var display := Control.new()
	display.name = "Drive"
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(display)
	var picture := TextureRect.new()
	picture.texture = _viewport.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.add_child(picture)
	if skippable:
		var hint := Label.new()
		hint.text = "Press [%s] to skip the drive" % InputSetup.interact_hint(player_index)
		hint.add_theme_font_size_override("font_size", 18)
		hint.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.05))
		hint.add_theme_constant_override("outline_size", 6)
		hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		hint.position.y += 16.0
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
		display.add_child(hint)
	_boxes.append(ConversationBox.open(display, player_index, "cheddar"))
	return display


func _build_world(settings: Dictionary) -> void:
	var world := Node3D.new()
	_viewport.add_child(world)
	var sky := Color.html(String(settings.get("sky", {}).get(Fishing.hour_block(), "#9fd3f2")))
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = sky
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = sky.lerp(Color.WHITE, 0.5)
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var night := Fishing.hour_block() in ["late_night", "early_morning"]
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	light.light_energy = 0.35 if night else 1.0
	light.light_color = Color(0.7, 0.75, 1.0) if night else Color(1.0, 0.96, 0.9)
	world.add_child(light)

	_box(world, Vector3(0.0, -0.06, -40.0), Vector3(200.0, 0.1, 70.0), Color(0.25, 0.48, 0.66))  # The sea, far behind.
	_box(world, Vector3(0.0, -0.05, -3.5), Vector3(200.0, 0.1, 9.0), Color(0.42, 0.6, 0.3))     # Grass by the road.
	_box(world, Vector3(0.0, -0.04, -7.8), Vector3(200.0, 0.1, 1.2), Color(0.88, 0.8, 0.58))   # A strip of sand.
	_box(world, Vector3(0.0, -0.03, 0.0), Vector3(200.0, 0.1, 3.4), Color(0.3, 0.3, 0.32))     # The road.
	_box(world, Vector3(0.0, -0.05, 8.0), Vector3(200.0, 0.1, 13.0), Color(0.42, 0.6, 0.3))    # Grass this side of it, for a tall view.
	for i in 18:  # Lane marks.
		_moving.append(_box(world, Vector3(-WRAP + i * 4.0, 0.03, 0.0), Vector3(1.6, 0.02, 0.12), Color(0.95, 0.9, 0.7)))
	var nature := "res://design/assets/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/"
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var kinds := ["Tree_1_A_Color1.gltf", "Tree_2_B_Color1.gltf", "Bush_1_A_Color1.gltf", "Tree_3_A_Color1.gltf", "Bush_2_B_Color1.gltf"]
	for i in 14:
		var kind: String = kinds[i % kinds.size()]
		var tall := 3.5 if kind.begins_with("Tree") else 0.9
		var at := Vector3(-WRAP + i * (WRAP * 2.0 / 14.0) + rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-6.5, -3.0))
		var fit := ModelFit.place(nature + kind, world, at, Vector3(0.0, tall, 0.0))
		if fit != null:
			_moving.append(fit)

	_car = Node3D.new()
	world.add_child(_car)
	var car_settings: Dictionary = GameData.trips.get("car", {})
	var body := ModelFit.place(String(car_settings.get("model", "")), _car, Vector3.ZERO, Vector3(0.0, 0.0, float(car_settings.get("length", 3.2))))
	if body != null:
		body.rotation.y = PI / 2.0  # Nose toward +x, the way it's going.

	var camera := Camera3D.new()
	camera.fov = 40.0
	world.add_child(camera)
	if _viewport.size.y > _viewport.size.x:  # A tall view: back a little and centered, or the car doesn't fit.
		camera.look_at_from_position(Vector3(0.0, 2.2, TALL_CAMERA_BACK), Vector3(0.0, 0.3, 0.0))
	else:
		camera.look_at_from_position(Vector3(0.6, 2.0, 8.5), Vector3(0.6, 0.8, 0.0))


func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	node.mesh = mesh
	node.position = at
	parent.add_child(node)
	return node
