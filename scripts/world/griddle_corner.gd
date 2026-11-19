# GriddleCorner: the set dressing round the first stoves, the art pass's
# benchmark corner (see the Art Style Guide): a cream tiled backsplash on the
# wall behind them, capped by a chunky honey-wood trim. Flat on the wall, so it
# never gets in the way of the camera, cooking or walking. The props on and
# above the stoves (pans, jars, the stove itself) come later from Meshy.
# The node sits on the wall's face, at the floor, in the middle of the run.
class_name GriddleCorner
extends Node3D

const TILES := preload("res://assets/shaders/tiles.gdshader")

@export var width := 2.9                 # Along the wall (x).
@export var from_height := 0.9           # The counter top...
@export var to_height := 1.75            # ...up to the trim.
@export var trim_color := Color("#A97251")


func _ready() -> void:
	var tiles := MeshInstance3D.new()
	var panel := BoxMesh.new()
	panel.size = Vector3(width, to_height - from_height, 0.02)
	var material := ShaderMaterial.new()
	material.shader = TILES
	panel.material = material
	tiles.mesh = panel
	tiles.position = Vector3(0.0, (from_height + to_height) * 0.5, 0.01)
	add_child(tiles)
	var trim := MeshInstance3D.new()
	var bar := CapsuleMesh.new()  # Rounded: no sharp corners.
	bar.radius = 0.035
	bar.height = width + 0.07
	bar.radial_segments = 12
	bar.rings = 2
	var wood := StandardMaterial3D.new()
	wood.albedo_color = trim_color
	wood.roughness = 0.7
	bar.material = wood
	trim.mesh = bar
	trim.rotation.z = PI * 0.5
	trim.scale = Vector3(1.0, 1.0, 0.6)  # Flatter against the wall.
	trim.position = Vector3(0.0, to_height + 0.02, 0.02)
	add_child(trim)
