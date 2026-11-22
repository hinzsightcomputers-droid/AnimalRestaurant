@tool
# ModelFit: shows a model (e.g. one from the KayKit packs in design/Assets) in
# place of placeholder shapes, sized to fit a box: its footprint centered on
# this node and its bottom at this node's height. Shows in the editor too, so
# swapping or resizing a model is just the Inspector. The model isn't saved
# into the scene, only which one and how big.
class_name ModelFit
extends Node3D

@export var model: PackedScene:
	set(value):
		model = value
		_rebuild()
# The box to fit in, in meters. An axis left at 0 just follows the others; all
# zero keeps the model's own size.
@export var size := Vector3.ZERO:
	set(value):
		size = value
		_rebuild()
# Fill the box exactly on every axis that's set (otherwise it keeps its
# proportions and fits the tightest one).
@export var stretch := false:
	set(value):
		stretch = value
		_rebuild()
# Turn the model around before fitting, e.g. 180 if it faces the wrong way.
@export_range(-180.0, 180.0, 90.0) var turn_degrees := 0.0:
	set(value):
		turn_degrees = value
		_rebuild()
# Tip the model forward before fitting: -90 lays down one that was made
# standing up (a rug Meshy built upright).
@export_range(-180.0, 180.0, 90.0) var tilt_degrees := 0.0:
	set(value):
		tilt_degrees = value
		_rebuild()
# At most this deep (meters, front to back) after fitting, squashing it if need
# be: a wall picture made as a deep box still sits flat on the wall. 0: no limit.
@export var max_depth := 0.0:
	set(value):
		max_depth = value
		_rebuild()

# Cut the model off above this share of its height (0: whole): a pot Meshy
# made with its lid on, shown open (meshy_cut.gdshader). Its texture's kept.
@export_range(0.0, 1.0, 0.01) var cut_top := 0.0:
	set(value):
		cut_top = value
		_rebuild()

const CUT_SHADER := preload("res://assets/shaders/meshy_cut.gdshader")

var _instance: Node3D = null


# A ModelFit of the model at `path` (e.g. from data/dish_kitchen.json) added under
# `parent` at `at`, or null if there's no such model.
static func place(path: String, parent: Node3D, at: Vector3, fit_size: Vector3) -> ModelFit:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var fit := ModelFit.new()
	fit.position = at
	fit.size = fit_size
	parent.add_child(fit)
	fit.model = load(path)
	return fit


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	_instance = null
	for child in get_children(true):  # Including a copy's, if this node was duplicated.
		if String(child.name).contains("_Model"):
			remove_child(child)
			child.queue_free()
	if model == null:
		return
	_instance = model.instantiate() as Node3D
	if _instance == null:
		return
	_instance.rotation = Vector3(deg_to_rad(tilt_degrees), deg_to_rad(turn_degrees), 0.0)
	var box := _bounds(_instance, _instance.transform)
	var factor := Vector3.ONE
	if size != Vector3.ZERO and box.size.x > 0.0 and box.size.y > 0.0 and box.size.z > 0.0:
		var ratios := Vector3(
			size.x / box.size.x if size.x > 0.0 else INF,
			size.y / box.size.y if size.y > 0.0 else INF,
			size.z / box.size.z if size.z > 0.0 else INF)
		var uniform := minf(ratios.x, minf(ratios.y, ratios.z))
		if stretch:
			factor = Vector3(
				ratios.x if size.x > 0.0 else uniform,
				ratios.y if size.y > 0.0 else uniform,
				ratios.z if size.z > 0.0 else uniform)
		else:
			factor = Vector3.ONE * uniform
	if max_depth > 0.0 and box.size.z * factor.z > max_depth:
		factor.z = max_depth / box.size.z
	var bottom_middle := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	_instance.transform = Transform3D(Basis.from_scale(factor), -bottom_middle * factor) * _instance.transform
	_instance.name = "_Model"
	add_child(_instance, false, Node.INTERNAL_MODE_FRONT)
	if cut_top > 0.0:
		_cut(box.size.y * factor.y * cut_top)


# Every mesh draws only below `height` (this node's space, its bottom at 0).
func _cut(height: float) -> void:
	for mesh: MeshInstance3D in _instance.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var own := mesh.mesh.surface_get_material(0)
		var cut := ShaderMaterial.new()
		cut.shader = CUT_SHADER
		if own is BaseMaterial3D:
			cut.set_shader_parameter("base_color", own.albedo_color)
			cut.set_shader_parameter("base_texture", own.albedo_texture)
			cut.set_shader_parameter("roughness", own.roughness)
		var to_here := global_transform.affine_inverse() * mesh.global_transform
		cut.set_shader_parameter("height_row", Vector4(to_here.basis.x.y, to_here.basis.y.y, to_here.basis.z.y, to_here.origin.y))
		cut.set_shader_parameter("cut_height", height)
		mesh.material_override = cut


# The bounds of every mesh under `node`, in the space `node`'s transform puts it in.
static func _bounds(node: Node, to_parent: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	var stack := [[node, to_parent]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var current: Node = entry[0]
		var xform: Transform3D = entry[1]
		if current is MeshInstance3D and current.mesh != null:
			var part: AABB = xform * current.mesh.get_aabb()
			box = part if first else box.merge(part)
			first = false
		for child in current.get_children():
			if child is Node3D:
				stack.append([child, xform * child.transform])
			else:
				stack.append([child, xform])
	return box
