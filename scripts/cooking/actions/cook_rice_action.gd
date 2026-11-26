# CookRiceAction: rice simmering in its pot. Like PressAction without hold (the
# bubbles get busier as the meter rises; press in the band to turn the heat
# off), and as it cooks the water soaks in and the grains swell. Off too soon
# it's still watery and hard; left too long it's mushy and catches.
# RiceInAction puts the raw rice in the pot first (setup_rice).
class_name CookRiceAction
extends PressAction

const RICE := Color(0.97, 0.96, 0.9)

@export var swell := 1.5                   # How much bigger the grains get, cooked.

var _water := 0.0
var _rice: MeshInstance3D


func _init() -> void:
	hold = false
	surface = "RicePot"
	low_word = "Still crunchy"
	high_word = "Mushy!"
	good_word = "Fluffy!"


func _begin() -> void:
	var pot := session.surface(surface)
	_water = pot.level
	_rice = session.context.get("rice")
	super()


func update(delta: float, input: CookInput) -> void:
	super(delta, input)
	var pot := session.surface(surface)
	var soaked := clampf(_amount / band.x, 0.0, 1.0)
	if pot.liquid != null:
		pot.fill_to(lerpf(_water, 0.0, soaked))
		pot.liquid.visible = soaked < 0.98
	if is_instance_valid(_rice):
		_rice.scale = Vector3(lerpf(1.0, 1.08, soaked), lerpf(1.0, swell * 1.6, soaked), lerpf(1.0, 1.08, soaked))  # It puffs up.
		if _amount > band.y:  # Catching on the bottom.
			var material := _rice.mesh.surface_get_material(0) as StandardMaterial3D
			material.albedo_color = RICE.lerp(Color(0.86, 0.74, 0.52), clampf((_amount - band.y) / (1.0 - band.y), 0.0, 1.0))



func end() -> void:
	super()
	var pot := session.surface(surface)
	if pot.liquid != null:  # All soaked in: no water left over the rice.
		pot.liquid.queue_free()
		pot.liquid = null
		pot.level = 0.0


# Raw rice on the bottom of the pot: one mesh of little grains, so it can be
# stirred round and coated (StirAction coat) as one. Kept in the session's
# context "rice" for the steps after.
static func setup_rice(on_session: CookSession, pot: CookSurface, count: int) -> MeshInstance3D:
	var grain := SphereMesh.new()
	grain.radius = 0.0028
	grain.height = 0.0056
	grain.radial_segments = 6
	grain.rings = 3
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var reach := pot.radius() * 0.85
	for i in count:
		var at := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * reach
		var turn := Transform3D(Basis.from_euler(Vector3(randf_range(-0.4, 0.4), randf() * TAU, PI * 0.5)).scaled(Vector3(1.0, 1.0, 2.4)), Vector3(at.x, randf() * 0.006, at.y))
		tool.append_from(grain, 0, turn)
	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.albedo_color = RICE
	material.roughness = 0.55
	material.set_meta(ToonStyle.FOOD, "baked")
	tool.set_material(material)
	var rice := MeshInstance3D.new()
	rice.mesh = tool.commit()
	pot.add_child(rice)
	rice.position = Vector3(0.0, pot.floor_at + 0.003, 0.0)
	pot.contents.append(rice)
	on_session.context["rice"] = rice
	return rice
