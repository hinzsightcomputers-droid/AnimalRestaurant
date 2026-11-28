extends "res://tools/room_look_check.gd"

# Checks PhotoMode in the whole game: F10 freezes it and hides the UI, the
# free camera moves (keys and the wheel), F12 saves a PNG, and F10 puts it all
# back. Pictures of each step go to SHOTS. Run (not headless) with APPDATA
# pointing at a copy of a save with an account:
#   SHOTS=<folder>  godot --resolution 1280x720 res://tools/photo_mode_check.tscn
# Then a picture from each of the week bot's store-photo angles
# (bot_week.gd PHOTO_ANGLES), to try new ones without a whole day.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = load("res://scenes/main.tscn").instantiate()
	main.process_mode = Node.PROCESS_MODE_PAUSABLE  # This checker isn't: the game still is.
	add_child(main)
	await get_tree().create_timer(3.0).timeout
	for i in 10:
		if Player.find(get_tree(), 0) != null:
			break
		await _key(KEY_ENTER, 0.1)
		await get_tree().create_timer(0.5).timeout
	await _pick_accounts()
	var player: Player = Player.find(get_tree(), 0)
	player.global_position = Vector3(-1.5, 0.0, 0.0)
	await get_tree().create_timer(2.0).timeout
	await _shot("photo_1_game.png")
	var hud: CanvasLayer = _find(main, func(n): return n.name == "HUD")[0]
	var rig: CameraRig = _find(main, func(n): return n is CameraRig)[0]
	var start := rig.camera.global_transform
	await _key(KEY_F10, 0.1)
	await get_tree().create_timer(0.3).timeout
	print("PHOTO on: active=%s paused=%s hud_hidden=%s" % [PhotoMode.active, get_tree().paused, not hud.visible])
	await _shot("photo_2_frozen.png")
	var yaw0: float = PhotoMode._yaw
	await _key(KEY_Q, 0.8)
	print("PHOTO turned: %.2f rad" % (PhotoMode._yaw - yaw0))
	await _key(KEY_W, 0.6)
	for i in 4:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		Input.parse_input_event(wheel)
	var pitch0: float = PhotoMode._pitch
	await _key(KEY_R, 0.4)
	print("PHOTO tilted: %.2f rad (from %.2f)" % [PhotoMode._pitch - pitch0, pitch0])
	await get_tree().create_timer(0.3).timeout
	print("PHOTO moved: %.2f m from start" % rig.camera.global_position.distance_to(start.origin))
	print("PHOTO cam %s fwd %s yaw %.2f pitch %.2f dist %.2f same=%s" % [rig.camera.global_position, -rig.camera.global_basis.z, PhotoMode._yaw, PhotoMode._pitch, PhotoMode._distance, PhotoMode._camera == rig.camera])
	await _shot("photo_3_moved.png")
	var before := DirAccess.get_files_at(PhotoMode.FOLDER).size() if DirAccess.dir_exists_absolute(PhotoMode.FOLDER) else 0
	await _key(KEY_F12, 0.1)
	await get_tree().create_timer(0.8).timeout
	var after := DirAccess.get_files_at(PhotoMode.FOLDER).size()
	print("PHOTO saved: %d new file(s) in %s" % [after - before, ProjectSettings.globalize_path(PhotoMode.FOLDER)])
	await _shot("photo_4_toast.png")
	PhotoMode._help.visible = false
	PhotoMode._toast.visible = false
	var camera: Camera3D = PhotoMode._camera
	var fov := camera.fov
	for angle in preload("res://tools/week_bot/bot_week.gd").PHOTO_ANGLES:
		camera.fov = angle[3]
		PhotoMode.frame(angle[1], angle[2])
		await get_tree().create_timer(0.3).timeout
		await _shot("angle_%s.png" % angle[0])
	camera.fov = fov
	await _key(KEY_F10, 0.1)
	await get_tree().create_timer(0.1).timeout
	print("PHOTO off: active=%s paused=%s hud_visible=%s" % [PhotoMode.active, get_tree().paused, hud.visible])
	await get_tree().create_timer(1.5).timeout
	await _shot("photo_5_back.png")
	print("ROOM done")
	get_tree().quit()
