extends "res://tools/soup_mac_check.gd"

# The woodland outdoors: pictures from a free camera of the lane out front,
# the restaurant from across it, the regulars' houses, and the back garden.
# Run like soup_mac_check, with SHOTS=<folder>:
#   godot --resolution 1600x900 res://tools/woodland_check.tscn

const VIEWS := [
	["wood_01_front.png", Vector3(5.0, 6.0, 26.0), Vector3(5.0, 1.5, 8.0)],
	["wood_02_lane_left.png", Vector3(-6.0, 4.0, 13.0), Vector3(-16.0, 1.5, 17.0)],
	["wood_03_lane_right.png", Vector3(14.0, 4.0, 12.5), Vector3(20.0, 1.5, 17.0)],
	["wood_04_above.png", Vector3(0.0, 34.0, 26.0), Vector3(0.0, 0.0, 4.0)],
	["wood_05_houses.png", Vector3(15.0, 5.0, 16.0), Vector3(14.0, 1.5, 5.6)],
	["wood_06_garden.png", Vector3(0.0, 8.0, -1.0), Vector3(-5.0, 0.5, -13.0)],
	["wood_07_cheddar.png", Vector3(-12.5, 4.0, 14.5), Vector3(-12.5, 1.5, 5.6)],
]


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(3.0).timeout
	for i in 10:
		if Player.find(get_tree(), 0) != null:
			break
		await _key(KEY_ENTER, 0.1)
		await get_tree().create_timer(0.5).timeout
	await _pick_accounts()
	await get_tree().create_timer(1.0).timeout
	var rig: CameraRig = _find(main, func(n): return n is CameraRig)[0]
	rig.set_process(false)  # Hold still: the camera's ours now.
	rig.set_physics_process(false)
	var camera := rig.camera
	camera.fov = 55.0
	camera.top_level = true
	for chef in _find(main, func(n): return n is Player):
		chef.global_position = Vector3(2.0, 0.0, 0.0)  # Out of the way, inside.
	for view in VIEWS:
		camera.look_at_from_position(view[1], view[2])
		await get_tree().create_timer(0.4).timeout
		await _shot(view[0])
		print("CHECK %s: %d draw calls, %d objects, %d fps" % [view[0], RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), Engine.get_frames_per_second()])
	get_tree().quit()
