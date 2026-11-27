extends Node

# The start screen's opening (door, lights, camera pushing in) as pictures,
# without naming anything: SHOTS=<folder>.

func _ready() -> void:
	var intro: Node = load("res://scenes/intro/street_intro.tscn").instantiate()
	add_child(intro)
	await get_tree().create_timer(2.0).timeout
	intro._play_opening()
	for i in 6:
		await get_tree().create_timer(1.6).timeout
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png("%s/opening_%d.png" % [OS.get_environment("SHOTS"), i])
	get_tree().quit()
