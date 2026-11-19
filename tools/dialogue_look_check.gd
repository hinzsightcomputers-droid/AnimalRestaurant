extends Node

# Pictures of the dialogue box: a line waiting to continue (name tag and the
# bobbing arrow), a question with replies, and narration (no name tag).
# Run (not headless) with APPDATA pointing at a copy of a save and SHOTS=<folder>:
#   godot --resolution 1280x720 res://tools/dialogue_look_check.tscn


func _ready() -> void:
	var back := ColorRect.new()  # Stands in for the warm room behind the box.
	back.color = Color("#90523C")
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var box := ConversationBox.open(screen, 0, "mabel")
	await get_tree().process_frame
	box.tell("Mabel", "Oh, these pancakes smell wonderful, dear. Is that real maple syrup?", &"happy")
	await _until(box.is_waiting)
	await get_tree().create_timer(0.3).timeout
	await _shot("dialogue_tell.png")
	box.ask("Mabel", "Would you put a little extra butter on mine?", ["Of course!", "Just a little.", "Butter's extra today."])
	await _until(box.is_choosing)
	await get_tree().create_timer(0.3).timeout
	await _shot("dialogue_ask.png")
	box.tell("", "(She hums while she waits.)")
	await _until(box.is_waiting)
	await get_tree().create_timer(0.3).timeout
	await _shot("dialogue_narration.png")
	get_tree().quit()


func _until(done: Callable) -> void:
	var give_up := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < give_up:
		if done.call():
			return
		await get_tree().process_frame


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/" + file)
