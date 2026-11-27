extends Node

# The night delivery drive (DeliveryDrive) on its own, on autopilot: two
# orders (a townsfolk and a regular), the turns, the doorsteps and home.
# Takes a picture every couple of seconds. Run (not headless) with
# SHOTS=<folder>; HOUR=<block> for another time of day (late_night by default):
#   godot --resolution 1920x1080 res://tools/delivery_drive_check.tscn

func _ready() -> void:
	GameState.debug_hour_block = OS.get_environment("HOUR") if not OS.get_environment("HOUR").is_empty() else "late_night"
	var bags: Array = []
	var callers := [
		{ "kind": "townsfolk", "id": "amy", "name": "Amy", "species": "songbird", "regular_id": "" },
		{ "kind": "regular", "id": "mabel", "name": "Mabel", "species": "", "regular_id": "mabel" },
	]
	for caller in callers:
		var order := Order.new(null, GameData.random_dish(), caller)
		bags.append(TakeoutBag.of_dish(CookedDish.new(order, 0.9)))
	var drive := DeliveryDrive.new()
	drive.bags = bags
	drive.autopilot = true
	add_child(drive)
	var shot := 0
	var started := Time.get_ticks_msec()
	while is_instance_valid(drive):
		await get_tree().create_timer(1.6).timeout
		if not is_instance_valid(drive):
			break
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png("%s/drive_%02d.png" % [OS.get_environment("SHOTS"), shot])
		shot += 1
		if Time.get_ticks_msec() - started > 120000:
			print("DRIVE timed out")
			break
	print("DRIVE done in %.1f s, %d shots" % [(Time.get_ticks_msec() - started) / 1000.0, shot])
	get_tree().quit()
