extends Node3D

# Every dish's served model (data/dish_kitchen.json) on the game's plate, in a
# grid with its name, lit like the room, then one picture. Run (not headless)
# with SHOTS=<folder>:
#   godot --resolution 1920x1080 res://tools/food_check.tscn

const PLATE := "res://design/restaurant/plate.glb"
const PLATE_SIZE := 0.44  # As the customers' and chefs' plates.
const COLUMNS := 5
const STEP := 0.62


func _ready() -> void:
	var dishes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dish_kitchen.json"))["dishes"]
	var i := 0
	for id in dishes:
		var dish: Dictionary = dishes[id]
		var at := Vector3((i % COLUMNS - (COLUMNS - 1) / 2.0) * STEP, 0.0, floorf(i / float(COLUMNS)) * STEP)
		ModelFit.place(PLATE, self, at, Vector3(PLATE_SIZE, 0.046, PLATE_SIZE)).stretch = true
		ModelFit.place(dish.get("model", ""), self, at + Vector3(0.0, 0.03, 0.0), Vector3(PLATE_SIZE * 0.75, 0.0, PLATE_SIZE * 0.75))  # As CookedDish.show_look: 1.5 × the plate's radius.
		var label := Label3D.new()
		label.text = id
		label.font_size = 28
		label.pixel_size = 0.0015
		label.position = at + Vector3(0.0, 0.01, 0.27)
		label.rotation.x = -PI / 2.0
		label.modulate = Color.BLACK
		add_child(label)
		i += 1
	var rows := ceili(i / float(COLUMNS))
	var camera := Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 2.9, (rows - 1) * STEP * 0.5 + 1.9), Vector3(0.0, 0.0, (rows - 1) * STEP * 0.5))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_color = Color("fff1dc")
	add_child(sun)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("e9dcc8")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("fff4e4")
	world.environment.ambient_light_energy = 0.6
	add_child(world)
	for fit in find_children("*", "ModelFit", true, false):
		ToonStyle.apply_bare(fit)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/food_check.png")
	get_tree().quit()
