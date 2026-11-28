# PendantLamp: a warm lamp hanging on a cord: a dome of warm glass with a
# brass rim, a softly glowing bulb under it, and a warm light (no shadows, so a
# few are cheap even in four-player split screen). Colors come from the
# ArtStyle palette: the glass cream, the bulb and light peach, the cord dark
# wood. `drop` is how far below the node the shade hangs (the node sits at the
# top of the cord).
@tool
class_name PendantLamp
extends Node3D

@export var style: ArtStyle = preload("res://assets/style/art_style.tres"):
	set(value):
		if style != null and style.changed.is_connected(_build):
			style.changed.disconnect(_build)
		style = value
		if style != null:
			style.changed.connect(_build)
		_build()
@export var drop := 0.6:
	set(value):
		drop = value
		_build()
@export var light_energy := 1.0:
	set(value):
		light_energy = value
		_build()
@export var light_range := 4.5:
	set(value):
		light_range = value
		_build()
@export var glow_energy := 4.0:  # How brightly the bulb itself glows (the bloom picks it up).
	set(value):
		glow_energy = value
		_build()

const BRASS := Color("C9A15A")
const NIGHT_BOOST := 2.2  # Brighter once it's dark outside (see DayManager.INDOOR_LIGHTS).
const HONEY := Color("F2B860")  # The glass: warm amber, like the concept art.

var _parts: Array[Node] = []


func _ready() -> void:
	if style != null and not style.changed.is_connected(_build):
		style.changed.connect(_build)
	_build()


func _build() -> void:
	if not is_inside_tree() or style == null:
		return
	for part in _parts:
		if is_instance_valid(part):
			part.queue_free()
	_parts.clear()
	var cord := CylinderMesh.new()
	cord.top_radius = 0.008
	cord.bottom_radius = 0.008
	cord.height = drop
	_add_mesh(cord, _matte(style.dark_wood), Vector3(0.0, -drop * 0.5, 0.0))
	var cap := CylinderMesh.new()  # A brass cap where the cord meets the shade.
	cap.top_radius = 0.025
	cap.bottom_radius = 0.045
	cap.height = 0.06
	_add_mesh(cap, _matte(BRASS), Vector3(0.0, -drop - 0.01, 0.0))
	# A dome of warm glass (like the concept art's lamps), lit from inside, so
	# it reads as a glowing lamp from the camera up above too.
	var shade := SphereMesh.new()
	shade.radius = 0.17
	shade.height = 0.26  # A hemisphere spans 0 to height / 2: a dome 13 cm tall.
	shade.is_hemisphere = true
	shade.radial_segments = 20
	shade.rings = 6
	var glass := StandardMaterial3D.new()
	glass.albedo_color = HONEY
	glass.emission_enabled = true
	glass.emission = HONEY.lerp(style.peach, 0.4)
	glass.emission_energy_multiplier = glow_energy * 0.12
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED  # The inside shows from below.
	glass.roughness = 0.6
	_add_mesh(shade, glass, Vector3(0.0, -drop - 0.17, 0.0))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.16
	rim.outer_radius = 0.18
	rim.rings = 20
	rim.ring_segments = 4
	_add_mesh(rim, _matte(BRASS), Vector3(0.0, -drop - 0.17, 0.0))
	var bulb := SphereMesh.new()
	bulb.radius = 0.07
	bulb.height = 0.14
	var glow := StandardMaterial3D.new()
	glow.albedo_color = style.cream
	glow.emission_enabled = true
	glow.emission = style.peach
	glow.emission_energy_multiplier = glow_energy
	_add_mesh(bulb, glow, Vector3(0.0, -drop - 0.17, 0.0))
	var light := OmniLight3D.new()
	light.light_color = style.peach.lerp(Color.WHITE, 0.35)
	light.light_energy = light_energy
	light.omni_range = light_range
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	light.set_meta("day_energy", light_energy)
	light.set_meta("night_energy", light_energy * NIGHT_BOOST)
	light.light_energy = DayManager.indoor_energy(light) if not Engine.is_editor_hint() else light_energy
	light.add_to_group(DayManager.INDOOR_LIGHTS)
	light.position = Vector3(0.0, -drop - 0.25, 0.0)
	_add(light)


func _matte(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


func _add_mesh(mesh: Mesh, material: Material, at: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.position = at
	_add(instance)


func _add(node: Node3D) -> void:
	add_child(node)  # Not owned: built fresh each time, never saved into the scene.
	_parts.append(node)
