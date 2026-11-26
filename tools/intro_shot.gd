extends Node

# The start screen (street_intro) after a moment, as a picture: SHOTS=<folder>.


func _ready() -> void:
	add_child(load("res://scenes/intro/street_intro.tscn").instantiate())
	await get_tree().create_timer(4.0).timeout
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/intro.png")
	get_tree().quit()
