# TakeOutAction: back to the oven for a tray left baking (a BakeAction with
# leave_in): the camera comes down to the oven door and the bake carries on as
# usual until you press to take it out. Its score is the bake's (give it no
# weight of its own). With side_dish, what's in that container (the cheese
# dip in the saucepan) is served in a little bowl beside the tray once it's out.
class_name TakeOutAction
extends CookAction

@export var side_dish := ""                # A container surface (CookSurface.depth) whose contents go in a bowl.
@export var bowl_at := Vector3(-0.3, 0.0, 0.02)  # From the tray, once it's out.

var _bake: BakeAction


func _init() -> void:
	weight = 0.0
	view_distance = 0.95  # Straight on at the oven door, like the bake.
	view_pitch = 6.0
	view_seconds = 0.8


func view_point() -> Vector3:
	return _bake.oven_front if _bake != null else super.view_point()


func _begin() -> void:
	_bake = session.step_of(BakeAction) as BakeAction
	if _bake == null or _bake.done:
		finish(1.0)
		return
	_bake.claimed = true


func uses_cursor() -> bool:
	return false


func update(_delta: float, _input: CookInput) -> void:
	if _bake.done:
		_serve_side()
		finish(_bake.quality)


# A little bowl of the dip hops over beside the tray.
func _serve_side() -> void:
	var pot := session.surface(side_dish) if not side_dish.is_empty() else null
	if pot == null:
		return
	var bowl := Node3D.new()
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.96, 0.95, 0.92)
	var dish := MeshInstance3D.new()
	var dish_mesh := CylinderMesh.new()
	dish_mesh.top_radius = 0.045
	dish_mesh.bottom_radius = 0.032
	dish_mesh.height = 0.03
	dish_mesh.material = white
	dish.mesh = dish_mesh
	dish.position.y = 0.015
	bowl.add_child(dish)
	var dip := MeshInstance3D.new()
	var dip_mesh := CylinderMesh.new()
	dip_mesh.top_radius = 0.04
	dip_mesh.bottom_radius = 0.04
	dip_mesh.height = 0.004
	var sauce := StandardMaterial3D.new()
	sauce.albedo_color = pot.liquid_color()
	sauce.roughness = 0.2
	dip_mesh.material = sauce
	dip.mesh = dip_mesh
	dip.position.y = 0.028
	bowl.add_child(dip)
	session.add_child(bowl)
	var tray := session.surface(_bake.tray).position
	var spot := tray + bowl_at
	bowl.position = pot.position
	pot.visible = false  # Poured out.
	var hop := bowl.create_tween()
	hop.tween_property(bowl, "position", (pot.position + spot) * 0.5 + Vector3(0.0, 0.15, 0.0), 0.25).set_ease(Tween.EASE_OUT)
	hop.tween_property(bowl, "position", spot, 0.25).set_ease(Tween.EASE_IN)
	hop.tween_callback(session.play_sound.bind("plop", spot, -6.0, 1.2))
