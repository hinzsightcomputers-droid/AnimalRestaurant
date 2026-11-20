extends Node3D

# What's in the decor drop-in folder (design/decor/): for every catalogue row,
# whether its concept picture and its Meshy model are there, then (with
# SHOTS=<folder>, not headless) a picture of each model as the game builds it,
# on a floor square grid with a person-sized post beside it for scale.
#   godot --path . res://tools/decor_drop_check.tscn


func _ready() -> void:
	var rows := 0
	var models := 0
	for file in DirAccess.get_files_at(GameData.DECOR_CATALOGUE_DIR):
		if not file.ends_with(".json"):
			continue
		var theme: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameData.DECOR_CATALOGUE_DIR + file))
		print("DECOR %s (%s)" % [theme.get("set_name", file), file])
		for row in theme.get("items", []):
			var id := String(row["id"])
			var has_model := ResourceLoader.exists(GameData.DECOR_MODEL_DIR + id + ".glb")
			var has_picture := FileAccess.file_exists(GameData.DECOR_MODEL_DIR + id + ".png")
			rows += 1
			models += 1 if has_model else 0
			print("  %-24s picture %-3s model %-3s %s" % [id, "yes" if has_picture else "-", "yes" if has_model else "-", "" if has_model else "(waiting)"])
	print("DECOR %d of %d items have models" % [models, rows])
	var shots := OS.get_environment("SHOTS")
	if shots.is_empty() or DisplayServer.get_name() == "headless":
		get_tree().quit()
		return
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#FBD6A0")
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.6
	add_child(env)
	var camera := Camera3D.new()
	add_child(camera)
	for item in Decor.items().filter(func(i): return i.get("meshy", false)):
		var stage := Node3D.new()
		add_child(stage)
		var floor := MeshInstance3D.new()
		floor.mesh = PlaneMesh.new()
		(floor.mesh as PlaneMesh).size = Vector2(3, 3)
		stage.add_child(floor)
		var post := MeshInstance3D.new()  # A chef is about 1.2 m.
		post.mesh = CylinderMesh.new()
		(post.mesh as CylinderMesh).height = 1.2
		(post.mesh as CylinderMesh).top_radius = 0.05
		(post.mesh as CylinderMesh).bottom_radius = 0.05
		post.position = Vector3(-1.2, 0.6, 0)
		stage.add_child(post)
		stage.add_child(Decor.build(item))
		var height := float(item.get("height", 1.0))
		var reach := maxf(height, float(item["size"][0])) + 0.6
		camera.fov = 45.0
		camera.position = Vector3(reach * 0.7, height * 0.6 + reach * 0.5, reach * 1.3)
		camera.look_at(Vector3(0, height * 0.45, 0))
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shots + "/decor_" + String(item["id"]) + ".png")
		stage.queue_free()
	get_tree().quit()
