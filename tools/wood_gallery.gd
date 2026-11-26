extends Node3D

# Every woodland piece (WoodPiece) in a row, for a look: the Meshy model where
# it's in, the placeholder where it isn't. SHOTS=<folder> saves wood_gallery.png.
#   godot --resolution 1800x900 res://tools/wood_gallery.tscn


func _ready() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("CFE6F0")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	add_child(env)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 40)
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color("9CC46A")
	plane.material = grass
	ground.mesh = plane
	add_child(ground)
	# Rows: big things at the back, small ones at the front.
	var rows := [
		["wood_cottage_thatch", "wood_cottage_mushroom", "wood_cottage_stump", "wood_cottage_stone", "wood_cottage_mill", "wood_cottage_shop"],
		["wood_tree_oak", "wood_tree_pine", "wood_tree_birch", "wood_tree_fruit", "wood_lantern_post", "wood_well", "wood_cart"],
		["wood_bush_round", "wood_bush_berry", "wood_bush_flower", "wood_rock_big", "wood_rock_flat", "wood_rock_pile", "wood_fern", "wood_flower_patch", "wood_mailbox"],
	]
	var gaps := [6.0, 5.0, 1.8]
	var depths := [-9.0, -1.5, 4.5]
	for r in rows.size():
		var row: Array = rows[r]
		for i in row.size():
			var x: float = (i - (row.size() - 1) / 2.0) * gaps[r]
			WoodPiece.make(row[i], self, Vector3(x, 0, depths[r]))
			var label := Label3D.new()
			label.text = String(row[i]).trim_prefix("wood_") + (" *" if WoodPiece.has_model(row[i]) else "")
			label.font_size = 48 if r < 2 else 28
			label.position = Vector3(x, 0.05, depths[r] + (2.6 if r == 0 else (2.0 if r == 1 else 0.7)))
			label.rotation_degrees.x = -60
			label.modulate = Color.BLACK
			label.outline_size = 0
			add_child(label)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 13, 17)
	camera.rotation_degrees.x = -36
	camera.fov = 55
	add_child(camera)
	await get_tree().create_timer(1.0).timeout
	var shots := OS.get_environment("SHOTS")
	if not shots.is_empty():
		get_viewport().get_texture().get_image().save_png(shots.path_join("wood_gallery.png"))
		camera.position = Vector3(0, 3.2, 9.5)
		camera.rotation_degrees.x = -18
		camera.fov = 50
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png(shots.path_join("wood_gallery_small.png"))
	get_tree().quit()
