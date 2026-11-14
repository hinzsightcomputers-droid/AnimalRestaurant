# ToonStyle: puts the art style's soft toon material on the characters and the
# cooking close-ups, and switches the whole look on and off (F7) to compare.
#
# ToonStyle.apply(node) is the helper for any imported model: each lit,
# opaque StandardMaterial3D under it is swapped for a soft toon material with
# the same color and texture.
#
# The game keeps changing its own materials as it runs (a pancake browning, a
# customer's color, an outfit being swapped), so the node in the restaurant
# also watches: whatever lands under a Customer, a Player, a ChefModel or a
# CookSession is converted, and every converted material keeps copying its
# original's color, texture and gloss (every frame in a close-up, ten times a
# second elsewhere). The originals stay where the game left them, untouched.
# Off, everything goes back to its original material, and the glow, ambient
# occlusion, color grade and pendant lamps go off too.
class_name ToonStyle
extends Node

const STYLE_PATH := "res://assets/style/art_style.tres"
const TOON := preload("res://assets/shaders/soft_toon.gdshader")
const TOON_DOUBLE := preload("res://assets/shaders/soft_toon_double.gdshader")
const OUTLINE := preload("res://assets/shaders/soft_toon_outline.gdshader")
const TINT := preload("res://assets/shaders/tint.gdshader")
const FACE := preload("res://assets/shaders/chef_face.gdshader")
const SCOPES := [&"Customer", &"Player", &"ChefModel", &"CookSession"]
const TOGGLE_KEY := KEY_F7
const SLOW_SYNC_SECONDS := 0.1
const SOURCE := &"toon_source"     # Meta on a toon material: a WeakRef to the material it copies.
const FROM_MESH := &"toon_from_mesh"  # Meta on a toon material: its original was the mesh's own (not an override).
const TWINS := [&"toon_twin", &"toon_twin_mesh"]  # Meta on an original: its toon material (as an override, as the mesh's own).
const ORIGINALS := &"toon_originals"  # Meta on a mesh: the override materials its toon ones replaced, {slot: material} (-1: the whole mesh's), so they live on for switching back.
const THIN := &"toon_thin"  # Meta on a mesh in a close-up, and on its toon materials: a thinner outline.
const CLOSE_UP_OUTLINE := 0.5  # Close-ups are seen from very near: half the outline.

@export var world_environment: WorldEnvironment
@export var lamps_group := &"pendant_lamps"
@export var enabled := true:
	set(value):
		enabled = value
		if is_inside_tree():
			_switch()

static var _style: ArtStyle
static var _toons: Array[WeakRef] = []  # Every toon material made, for style changes.

var _meshes: Array[MeshInstance3D] = []
var _fast: Array[MeshInstance3D] = []  # In a close-up: synced every frame.
var _slow_left := 0.0


static func style() -> ArtStyle:
	if _style == null:
		_style = load(STYLE_PATH) as ArtStyle
	return _style


# The helper: every convertible material under `root` gets its soft toon twin.
static func apply(root: Node) -> void:
	for mesh in _all_meshes(root):
		_convert(mesh)


func _ready() -> void:
	style().changed.connect(_on_style_changed)
	get_tree().node_added.connect(_on_node_added)
	for mesh in _all_meshes(get_tree().root):
		_on_node_added(mesh)
	_switch()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == TOGGLE_KEY:
		enabled = not enabled
		GameEvents.announce("New art style %s (F7)" % ("on" if enabled else "off"))
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not enabled:
		return
	_slow_left -= delta
	var slow := _slow_left <= 0.0
	if slow:
		_slow_left = SLOW_SYNC_SECONDS
		_meshes = _meshes.filter(func(m): return is_instance_valid(m) and m.is_inside_tree())
	_fast = _fast.filter(func(m): return is_instance_valid(m) and m.is_inside_tree())
	for mesh in (_meshes if slow else _fast):
		_convert(mesh)


func _on_node_added(node: Node) -> void:
	var mesh := node as MeshInstance3D
	if mesh == null or mesh in _meshes:
		return
	var scope := _scope_of(mesh)
	if scope.is_empty():
		return
	_meshes.append(mesh)
	if scope == &"CookSession":
		_fast.append(mesh)
		mesh.set_meta(THIN, true)
	if enabled:
		_convert.call_deferred(mesh)  # Once the game has finished setting it up.


# Which watched thing `node` is part of, or &"".
static func _scope_of(node: Node) -> StringName:
	var at := node
	while at != null:
		var script := at.get_script() as Script
		while script != null:
			if script.get_global_name() in SCOPES:
				return script.get_global_name()
			script = script.get_base_script()
		at = at.get_parent()
	return &""


static func _all_meshes(root: Node) -> Array:
	var found := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		found.append(root)
	return found


# Gives `mesh` toon materials (or brings them up to date with their originals).
static func _convert(mesh: MeshInstance3D) -> void:
	if not is_instance_valid(mesh) or mesh.mesh == null:
		return
	var thin := mesh.has_meta(THIN)
	var whole := mesh.material_override
	if whole != null:
		if whole.has_meta(SOURCE):
			_sync(whole)
		elif _convertible(whole):
			_keep(mesh, -1, whole)
			mesh.material_override = _toon_for(whole, false, thin)
		elif whole is ShaderMaterial:
			_tune(whole)
		return
	for surface in mesh.mesh.get_surface_count():
		var own := mesh.mesh.surface_get_material(surface)
		var override := mesh.get_surface_override_material(surface)
		if override != null and override.has_meta(SOURCE):
			if override.get_meta(FROM_MESH, false) and _source(override) != own:  # The game changed the mesh's material.
				mesh.set_surface_override_material(surface, _toon_for(own, true, thin) if _convertible(own) else null)
			else:
				_sync(override)
		elif override != null:
			if _convertible(override):
				_keep(mesh, surface, override)
				mesh.set_surface_override_material(surface, _toon_for(override, false, thin))
			elif override is ShaderMaterial:
				_tune(override)
		elif _convertible(own):
			mesh.set_surface_override_material(surface, _toon_for(own, true, thin))
		elif own is ShaderMaterial:
			_tune(own)


# An override the game made for this mesh (a customer's color, say) is held
# only by the mesh, so once its toon twin takes its place nothing else would
# keep it: the mesh holds it instead (a node, so no reference loop).
static func _keep(mesh: MeshInstance3D, slot: int, original: Material) -> void:
	var kept: Dictionary = mesh.get_meta(ORIGINALS, {})
	kept[slot] = original
	mesh.set_meta(ORIGINALS, kept)


# Lit, opaque, ordinary materials. Not see-through ones, unshaded ones, ones
# colored by their vertices (fading emotes) or billboards.
static func _convertible(material: Material) -> bool:
	var standard := material as BaseMaterial3D
	return standard != null and not material.has_meta(SOURCE) \
		and standard.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
		and standard.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED \
		and not standard.vertex_color_use_as_albedo \
		and standard.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED


# The original holds its toon twin; the twin only points back weakly, so
# neither keeps the other alive once the game is done with them.
static func _toon_for(original: Material, from_mesh: bool, thin := false) -> ShaderMaterial:
	var twin: StringName = TWINS[1 if from_mesh else 0]
	var toon: ShaderMaterial = original.get_meta(twin) if original.has_meta(twin) else null
	if toon == null:
		toon = ShaderMaterial.new()
		toon.set_meta(SOURCE, weakref(original))
		toon.set_meta(FROM_MESH, from_mesh)
		toon.set_meta(THIN, thin)
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE
		toon.next_pass = outline
		_style_toon(toon)
		original.set_meta(twin, toon)
		_toons = _toons.filter(func(w): return w.get_ref() != null)
		_toons.append(weakref(toon))
	_sync(toon)
	return toon


static func _source(toon: Material) -> Material:
	var ref := toon.get_meta(SOURCE) as WeakRef if toon.has_meta(SOURCE) else null
	return ref.get_ref() as Material if ref != null else null


# Copies the original's look into its toon material (only what changed).
static func _sync(toon: ShaderMaterial) -> void:
	var original := _source(toon) as BaseMaterial3D
	if original == null:
		return
	var shader := TOON_DOUBLE if original.cull_mode == BaseMaterial3D.CULL_DISABLED else TOON
	if toon.shader != shader:
		toon.shader = shader
		_style_toon(toon)
	_set_param(toon, "base_color", original.albedo_color)
	_set_param(toon, "base_texture", original.albedo_texture)
	_set_param(toon, "roughness", original.roughness)
	_set_param(toon, "gloss", clampf((0.6 - original.roughness) * 1.2, 0.0, 0.6))  # Shiny things get a soft highlight.
	var glow := original.emission_enabled
	_set_param(toon, "emission_color", original.emission if glow else Color.BLACK)
	_set_param(toon, "emission_energy", original.emission_energy_multiplier if glow else 0.0)


static func _set_param(material: ShaderMaterial, parameter: StringName, value: Variant) -> void:
	if material.get_shader_parameter(parameter) != value:
		material.set_shader_parameter(parameter, value)


# The style's toon settings (and outline) into a toon material.
static func _style_toon(toon: ShaderMaterial) -> void:
	for parameter in style().toon_parameters():
		toon.set_shader_parameter(parameter, style().toon_parameters()[parameter])
	toon.set_shader_parameter("toon_amount", 1.0)
	var outline := toon.next_pass as ShaderMaterial
	if outline != null:
		for parameter in style().outline_parameters():
			outline.set_shader_parameter(parameter, style().outline_parameters()[parameter])
		if toon.get_meta(THIN, false):
			outline.set_shader_parameter("outline_thickness", style().outline_thickness * CLOSE_UP_OUTLINE)


# The chef's own shaders (skin, hair, face) already have the toon lighting:
# they just take the style's settings.
static func _tune(material: ShaderMaterial, on := true) -> void:
	if material.shader != TINT and material.shader != FACE:
		return
	var parameters := style().toon_parameters()
	parameters["toon_amount"] = 1.0 if on else 0.0
	for parameter in parameters:
		_set_param(material, parameter, parameters[parameter])
	if material.next_pass is ShaderMaterial:
		_tune(material.next_pass, on)


func _on_style_changed() -> void:
	for ref in _toons:
		if ref.get_ref() != null:
			_style_toon(ref.get_ref())
	for mesh in _meshes:
		if is_instance_valid(mesh):
			for material in _shader_materials(mesh):
				_tune(material, enabled)


# On: toon materials everywhere it watches, and the environment's extras.
# Off: every original material back, the chef's shaders lit plainly.
func _switch() -> void:
	for mesh in _meshes:
		if not is_instance_valid(mesh):
			continue
		if enabled:
			_convert(mesh)
		else:
			_restore(mesh)
		for material in _shader_materials(mesh):
			_tune(material, enabled)
	var environment := world_environment.environment if world_environment != null else null
	if environment != null:
		environment.glow_enabled = enabled
		environment.ssao_enabled = enabled
		environment.adjustment_enabled = enabled
	for lamp in get_tree().get_nodes_in_group(lamps_group):
		lamp.visible = enabled


static func _restore(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null:
		return
	if mesh.material_override != null and mesh.material_override.has_meta(SOURCE):
		mesh.material_override = _source(mesh.material_override)
	for surface in mesh.mesh.get_surface_count():
		var override := mesh.get_surface_override_material(surface)
		if override != null and override.has_meta(SOURCE):
			mesh.set_surface_override_material(surface, null if override.get_meta(FROM_MESH, false) else _source(override))


static func _shader_materials(mesh: MeshInstance3D) -> Array:
	var found := []
	if mesh.material_override is ShaderMaterial:
		found.append(mesh.material_override)
	if mesh.mesh != null:
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			if material is ShaderMaterial and not material in found:
				found.append(material)
	return found
