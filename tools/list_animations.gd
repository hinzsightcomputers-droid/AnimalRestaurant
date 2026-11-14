extends Node

# Prints each model's animations, their lengths, its meshes and its height,
# for every .glb in the folder given by DIR (res:// path). Headless is fine:
#   DIR=res://design/characters/Zakk godot --headless res://tools/list_animations.tscn

func _ready() -> void:
	var dir := OS.get_environment("DIR")
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".glb"):
			continue
		var scene: Node = (load(dir + "/" + file) as PackedScene).instantiate()
		add_child(scene)
		var names := []
		for player in scene.find_children("*", "AnimationPlayer", true, false):
			for anim in player.get_animation_list():
				names.append("%s (%.1fs)" % [anim, player.get_animation(anim).length])
		var meshes := scene.find_children("*", "MeshInstance3D", true, false)
		var box := AABB()
		for m in meshes:
			var b: AABB = m.global_transform * m.get_aabb()
			box = b if box.size == Vector3.ZERO else box.merge(b)
		print("ANIM %s | meshes %s | height %.2f | %s" % [file, meshes.map(func(m): return m.name), box.size.y, ", ".join(names)])
		scene.queue_free()
	get_tree().quit()
