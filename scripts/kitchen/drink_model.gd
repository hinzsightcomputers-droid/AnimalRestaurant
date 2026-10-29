# DrinkModel: a simple drink to look at: a mug, glass or bottle (the drink's
# "vessel") with the drink inside, filled to `fill` (0..1, the line at 0.8).
# Used in hands, on the DrinkStation, and on the table. `see_through` makes a
# mug glassy too, so you can watch it fill while pouring.
class_name DrinkModel
extends Node3D

const HEIGHT := 0.16
const RADIUS := 0.05

var _liquid := MeshInstance3D.new()
var _liquid_mesh := CylinderMesh.new()
var _vessel := MeshInstance3D.new()
var _fill := 1.0


static func make(drink: Dictionary, fill := 0.8, see_through := false) -> DrinkModel:
	var model := DrinkModel.new()
	model._build(drink, see_through)
	model.set_fill(fill)
	return model


# How wide the rim is, for a ring around it.
static func rim_radius(drink: Dictionary) -> float:
	return RADIUS * (1.1 if drink.get("vessel", "glass") == "mug" else 1.0)


func _build(drink: Dictionary, see_through: bool) -> void:
	var vessel_kind: String = drink.get("vessel", "glass")
	var vessel_material := StandardMaterial3D.new()
	var vessel_mesh := CylinderMesh.new()
	vessel_mesh.height = HEIGHT
	vessel_mesh.top_radius = RADIUS
	vessel_mesh.bottom_radius = RADIUS * (0.85 if vessel_kind == "glass" else 1.0)
	match vessel_kind:
		"mug":
			vessel_material.albedo_color = Color(0.96, 0.93, 0.86)
			vessel_mesh.top_radius = RADIUS * 1.1
			vessel_mesh.bottom_radius = RADIUS * 1.1
			var handle := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.022
			torus.outer_radius = 0.038
			handle.mesh = torus
			handle.material_override = vessel_material
			handle.rotation_degrees = Vector3(90, 0, 0)
			handle.position = Vector3(RADIUS * 1.15, HEIGHT * 0.5, 0.0)
			add_child(handle)
		"bottle":
			vessel_material.albedo_color = Color(drink.get("color", "#888888")).lerp(Color.WHITE, 0.15)
			vessel_mesh.top_radius = RADIUS * 0.45
			var label := MeshInstance3D.new()
			var band := CylinderMesh.new()
			band.height = HEIGHT * 0.3
			band.top_radius = RADIUS * 1.02
			band.bottom_radius = RADIUS * 1.02
			label.mesh = band
			var label_material := StandardMaterial3D.new()
			label_material.albedo_color = Color(0.97, 0.95, 0.9)
			label.material_override = label_material
			label.position.y = HEIGHT * 0.4
			add_child(label)
		_:
			vessel_material.albedo_color = Color(0.85, 0.95, 1.0, 0.35)
			vessel_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var glassy := vessel_kind == "glass" or (see_through and vessel_kind == "mug")
	if glassy and vessel_kind == "mug":
		vessel_material.albedo_color.a = 0.2
		vessel_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_vessel.mesh = vessel_mesh
	_vessel.material_override = vessel_material
	_vessel.position.y = HEIGHT * 0.5
	add_child(_vessel)
	if vessel_kind == "bottle":
		return  # A bottle comes full; you can't see inside.
	var liquid_material := StandardMaterial3D.new()
	liquid_material.albedo_color = Color(drink.get("color", "#888888"))
	_liquid_mesh.top_radius = RADIUS * 0.92
	_liquid_mesh.bottom_radius = vessel_mesh.bottom_radius * 0.92
	_liquid.mesh = _liquid_mesh
	_liquid.material_override = liquid_material
	add_child(_liquid)
	if glassy:
		_vessel.sorting_offset = 1.0  # The see-through glass draws over the drink.


# 0 = empty, 0.8 = the line, 1 = the brim (more spills).
func set_fill(fill: float) -> void:
	_fill = clampf(fill, 0.0, 1.0)
	_liquid.visible = _fill > 0.01
	_liquid_mesh.height = maxf(HEIGHT * 0.96 * _fill, 0.001)
	_liquid.position.y = _liquid_mesh.height * 0.5 + 0.004
