@tool
# WoodGround: a flat strip of tiling ground for the woodland outdoors (the dirt
# path, the mossy cobbles: design/woodland/textures), `size` meters across
# (x, z) with its texture repeating every `tile` meters. Centered on this node.
class_name WoodGround
extends MeshInstance3D

@export var texture: Texture2D:
	set(value):
		texture = value
		_rebuild()
@export var size := Vector2(10.0, 2.0):
	set(value):
		size = value
		_rebuild()
@export var tile := 2.0:
	set(value):
		tile = value
		_rebuild()
@export var tint := Color.WHITE:
	set(value):
		tint = value
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	var plane := PlaneMesh.new()
	plane.size = size
	var paint := StandardMaterial3D.new()
	paint.albedo_texture = texture
	paint.albedo_color = tint
	paint.roughness = 1.0
	paint.uv1_scale = Vector3(size.x / maxf(tile, 0.01), size.y / maxf(tile, 0.01), 1.0)
	paint.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	plane.material = paint
	mesh = plane
