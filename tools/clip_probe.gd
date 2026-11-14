extends Node3D

# For one model (MODEL=res://...glb): the hips' height through each clip
# (to find where a sit or stand happens, for clip_parts), and pictures of
# the clips named in SHOTS_OF (comma separated) at a few moments, into SHOTS.
#   MODEL=... SHOTS=<folder> SHOTS_OF=Walk_to_Sit godot --resolution 800x800 res://tools/clip_probe.tscn

func _ready() -> void:
	var model: Node3D = (load(OS.get_environment("MODEL")) as PackedScene).instantiate()
	add_child(model)
	var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var hips := -1
	for name in ["mixamorig_Hips", "Hips", "hips", "Pelvis"]:
		hips = skeleton.find_bone(name)
		if hips >= 0:
			break
	var head := -1
	for name in ["mixamorig_Head", "Head", "head"]:
		head = skeleton.find_bone(name)
		if head >= 0:
			break
	var camera := Camera3D.new()
	add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.8, 0.85, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	add_child(env)
	var shots := OS.get_environment("SHOTS_OF").split(",", false)
	for anim in player.get_animation_list():
		var length := player.get_animation(anim).length
		var line := []
		player.play(anim)
		var t := 0.0
		while t <= length + 0.001:
			player.seek(t, true)
			skeleton.force_update_all_bone_transforms()
			var y := (skeleton.global_transform * skeleton.get_bone_global_pose(hips)).origin.y if hips >= 0 else 0.0
			var hy := (skeleton.global_transform * skeleton.get_bone_global_pose(head)).origin.y if head >= 0 else 0.0
			var fz: Vector3 = (skeleton.global_transform.basis * skeleton.get_bone_global_pose(hips).basis).z if hips >= 0 else Vector3.ZERO
			var hp: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(hips)).origin if hips >= 0 else Vector3.ZERO
			line.append("%.1f:%.3f/%.3f face%.0f at(%.2f,%.2f)" % [t, y, hy, rad_to_deg(atan2(fz.x, fz.z)), hp.x, hp.z])
			t += 0.25 if length > 3.0 else 0.1
		print("CLIP %s %.1fs hips/head: %s" % [anim, length, " ".join(line)])
		if anim in shots:
			var box := AABB()
			for m in model.find_children("*", "MeshInstance3D", true, false):
				box = m.global_transform * m.get_aabb() if box.size == Vector3.ZERO else box.merge(m.global_transform * m.get_aabb())
			for i in 5:
				player.seek(length * i / 4.0, true)
				skeleton.force_update_all_bone_transforms()
				var mid := Vector3(0, 0.5, 0)
				var size := 1.0
				var hip_at := (skeleton.global_transform * skeleton.get_bone_global_pose(hips)).origin if hips >= 0 else Vector3.ZERO
				var tall := maxf(hip_at.y * 2.2, 0.01)
				camera.position = Vector3(tall * 1.2, tall * 0.6, tall * 1.6)
				camera.look_at(Vector3(0, tall * 0.45, 0))
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/%s_%d.png" % [anim.validate_filename(), i])
	get_tree().quit()
