@tool
# RoomPanel: one piece of the room's own shell, a box painted with the room
# textures (assets/textures/room, made from the concept pictures in
# design/textures) by room_surface.gdshader: a wall, a floor or a counter.
# Like ModelGrid it sits with its bottom on this node and its middle on this
# node's x and z, shows in the editor, and only the settings are saved. It's
# only the look: walls and floors keep their own collision shapes.
# A wall can have windows: evenly spaced openings along its length, each with
# the window model (design/restaurant, from Meshy: frame, glass and gingham
# curtains) on the room side and a plain frame and glass seen from outdoors.
class_name RoomPanel
extends Node3D

enum Kind { WALL, FLOOR, COUNTER }

const SHADER := preload("res://assets/shaders/room_surface.gdshader")
const TEXTURES := "res://assets/textures/room/%s.png"
const WINDOW_WIDTH := 1.2
const SILL := 0.9      # Bottom of a window opening.
const HEAD := 2.2      # Its top.
const DOOR_HEAD := 2.3  # Top of a doorway.
const FRAME := 0.08
const FRAME_COLOR := Color("71412c")
const GLASS_COLOR := Color("a9d8e6")
const CURTAIN_COLOR := Color("d63c3c")
const WINDOW_MODEL := "res://design/restaurant/window_curtains.glb"
const WINDOW_MODEL_WIDTH := 1.6   # Wider than the opening: the curtains and rod hang over the wall.
const WINDOW_MODEL_BOTTOM := 0.72  # Its sill just under the opening's.
const WINDOW_MODEL_DEPTH := 0.22

@export var kind := Kind.WALL:
	set(value):
		kind = value
		_rebuild()
@export var size := Vector3(2.0, 3.0, 0.3):
	set(value):
		size = value
		_rebuild()
@export var outside := Vector3.ZERO:  # Which face looks outdoors (brick), e.g. (0, 0, 1); zero for none.
	set(value):
		outside = value
		_rebuild()
@export_range(0, 12) var windows := 0:
	set(value):
		windows = value
		_rebuild()

@export var door_width := 0.0:  # A doorway this wide in the middle of a wall (floor to DOOR_HEAD).
	set(value):
		door_width = value
		_rebuild()
@export var kitchen_tiles := false:  # A floor in the kitchen's checker tiles.
	set(value):
		kitchen_tiles = value
		_rebuild()

static var _materials := {}  # Kind -> its ShaderMaterial, shared.


func _ready() -> void:
	_rebuild()


static func material_for(which: Kind) -> ShaderMaterial:
	if _materials.has(which):
		return _materials[which]
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("kind", which)
	match which:
		Kind.WALL:
			material.set_shader_parameter("upper_texture", load(TEXTURES % "wall_plaster"))
			material.set_shader_parameter("lower_texture", load(TEXTURES % "wainscot"))
			material.set_shader_parameter("trim_texture", load(TEXTURES % "wall_trim"))
			material.set_shader_parameter("outside_texture", load(TEXTURES % "brick_outside"))
			material.set_shader_parameter("upper_tile", 2.5)
			material.set_shader_parameter("saturation", 0.75)
		Kind.FLOOR:
			material.set_shader_parameter("upper_texture", load(TEXTURES % "floor_dining"))
			material.set_shader_parameter("upper_tile", 1.6)
			material.set_shader_parameter("saturation", 0.6)
			material.set_shader_parameter("brightness", 1.08)
		Kind.COUNTER:
			material.set_shader_parameter("upper_texture", load(TEXTURES % "counter_top"))
			material.set_shader_parameter("lower_texture", load(TEXTURES % "cabinet_front"))
			material.set_shader_parameter("upper_tile", 1.2)
			material.set_shader_parameter("saturation", 0.7)
	if not Engine.is_editor_hint():
		var style := ToonStyle.style()
		for parameter in style.toon_parameters():
			material.set_shader_parameter(parameter, style.toon_parameters()[parameter])
	_materials[which] = material
	return material


# The kitchen's tiled floor: a floor with the checker tiles.
static func kitchen_floor_material() -> ShaderMaterial:
	if _materials.has("kitchen"):
		return _materials["kitchen"]
	var material := material_for(Kind.FLOOR).duplicate() as ShaderMaterial
	material.set_shader_parameter("upper_texture", load(TEXTURES % "floor_kitchen"))
	material.set_shader_parameter("upper_tile", 2.0)
	material.set_shader_parameter("saturation", 0.8)
	material.set_shader_parameter("brightness", 1.0)
	_materials["kitchen"] = material
	return material


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children(true):
		if String(child.name).begins_with("_Panel"):
			remove_child(child)
			child.queue_free()
	var holder := Node3D.new()
	holder.name = "_Panel"
	add_child(holder, false, Node.INTERNAL_MODE_FRONT)
	var along_x := size.x >= size.z
	var length := size.x if along_x else size.z
	var thick := size.z if along_x else size.x
	if kind == Kind.WALL and door_width > 0.0:
		_strip(holder, along_x, -length / 2.0, -door_width / 2.0, 0.0, size.y, thick)
		_strip(holder, along_x, door_width / 2.0, length / 2.0, 0.0, size.y, thick)
		_strip(holder, along_x, -door_width / 2.0, door_width / 2.0, DOOR_HEAD, size.y, thick)
		return
	if windows <= 0 or kind != Kind.WALL:
		_box(holder, Vector3(0.0, 0.0, 0.0), size)
		return
	# Along the wall's long side: solid piers between the openings, a strip
	# under and over each one.
	var step := length / windows
	var opening := minf(WINDOW_WIDTH, step - 0.2)
	var at := -length / 2.0
	for i in windows:
		var middle := -length / 2.0 + (i + 0.5) * step
		var left := middle - opening / 2.0
		_strip(holder, along_x, at, left, 0.0, size.y, thick)
		_strip(holder, along_x, left, left + opening, 0.0, SILL, thick)
		_strip(holder, along_x, left, left + opening, HEAD, size.y, thick)
		_window(holder, along_x, middle, opening, thick)
		at = left + opening
	_strip(holder, along_x, at, length / 2.0, 0.0, size.y, thick)


func _strip(holder: Node3D, along_x: bool, from: float, to: float, bottom: float, top: float, thick: float) -> void:
	if to - from < 0.001 or top - bottom < 0.001:
		return
	var middle := (from + to) / 2.0
	var box := Vector3(to - from, top - bottom, thick) if along_x else Vector3(thick, top - bottom, to - from)
	_box(holder, Vector3(middle, bottom, 0.0) if along_x else Vector3(0.0, bottom, middle), box)


# A box `box` big with its bottom middle at `at` (in this node's terms).
func _box(holder: Node3D, at: Vector3, box: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at + Vector3(0.0, box.y / 2.0, 0.0)
	instance.material_override = kitchen_floor_material() if kitchen_tiles else material_for(kind)
	holder.add_child(instance)
	instance.set_instance_shader_parameter("outside_dir", outside.normalized() if outside != Vector3.ZERO else Vector3.ZERO)
	instance.set_instance_shader_parameter("top_y", global_position.y + size.y)


# A window in an opening: a wood frame and pale glass, and on the room side the
# window model (or, without it, a box curtain each side).
func _window(holder: Node3D, along_x: bool, middle: float, opening: float, thick: float) -> void:
	var tall := HEAD - SILL
	var parts := [  # [middle along, bottom, width along, height, depth, color]
		[middle, SILL, opening, FRAME, thick + 0.04, FRAME_COLOR],
		[middle, HEAD - FRAME, opening, FRAME, thick + 0.04, FRAME_COLOR],
		[middle - opening / 2.0 + FRAME / 2.0, SILL, FRAME, tall, thick + 0.04, FRAME_COLOR],
		[middle + opening / 2.0 - FRAME / 2.0, SILL, FRAME, tall, thick + 0.04, FRAME_COLOR],
		[middle, SILL, FRAME * 0.6, tall, thick * 0.5, FRAME_COLOR],
		[middle, SILL + tall / 2.0 - FRAME * 0.3, opening, FRAME * 0.6, thick * 0.5, FRAME_COLOR],
		[middle, SILL, opening, tall, 0.02, GLASS_COLOR],
	]
	var inside := -outside.normalized() if outside != Vector3.ZERO else (Vector3.BACK if along_x else Vector3.RIGHT)
	var model := ModelFit.place(WINDOW_MODEL, holder, Vector3.ZERO, Vector3(WINDOW_MODEL_WIDTH, 0.0, 0.0))
	if model != null:
		model.max_depth = WINDOW_MODEL_DEPTH
		model.rotation.y = atan2(inside.x, inside.z)  # The model faces +z: turn it to the room.
		var off := (inside.z if along_x else inside.x) * (thick / 2.0 + WINDOW_MODEL_DEPTH / 2.0 - 0.1)
		model.position = Vector3(middle, WINDOW_MODEL_BOTTOM, off) if along_x else Vector3(off, WINDOW_MODEL_BOTTOM, middle)
		if not Engine.is_editor_hint():
			ToonStyle.apply_bare(model)
	for side in [-1.0, 1.0]:  # Box curtains on both faces of the wall, gathered at the sides (only without the model).
		for face in [-1.0, 1.0]:
			if model != null:
				continue
			parts.append([middle + side * (opening / 2.0 - 0.14), SILL + 0.05, 0.26, tall + 0.1, 0.05, CURTAIN_COLOR, face * (thick / 2.0 + 0.04)])
	for part in parts:
		var mesh := BoxMesh.new()
		var width: float = part[2]
		var depth: float = part[4]
		mesh.size = Vector3(width, part[3], depth) if along_x else Vector3(depth, part[3], width)
		var material := StandardMaterial3D.new()
		material.albedo_color = part[5]
		material.roughness = 0.9
		mesh.material = material
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		var offset: float = part[6] if part.size() > 6 else 0.0
		var y: float = part[1] + part[3] / 2.0
		instance.position = Vector3(part[0], y, offset) if along_x else Vector3(offset, y, part[0])
		holder.add_child(instance)
