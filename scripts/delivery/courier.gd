# Courier: the delivery character (a placeholder capsule with a cap and a bag).
# Comes in for one phoned-in order, waits by the counter however long the
# cooking takes, and leaves once a player hands over the finished dish.
# DeliveryManager decides where it goes and what handing over does; this only
# walks, shows a bubble, and says who can hand it what.
class_name Courier
extends Node3D

signal arrived_outside(courier: Courier)  # Walked back out the door after the pickup.

var order: Order
var walk_speed := 2.2
var leaving := false

var interactable := Interactable.new()
var _bubble := Label3D.new()
var _path: Array[Vector3] = []
var _bag: MeshInstance3D


func setup(for_order: Order, settings: Dictionary) -> void:
	order = for_order
	walk_speed = settings.get("walk_speed", walk_speed)
	_build(Color(settings.get("color", "#f2d24b")))


func _ready() -> void:
	interactable.prompt = "Hand over"
	interactable.radius = 1.3
	interactable.priority = 1  # Over anything it's standing near.
	interactable.prompt_for_player = _prompt_for
	add_child(interactable)
	_show_waiting()


# "Hand over" for whoever carries this order's plate, nothing for anyone else
# (pressing with free hands would only say what it's waiting for).
func _prompt_for(player_index: int) -> String:
	if leaving or is_walking():
		return ""
	var player := Player.find(get_tree(), player_index)
	if player == null:
		return ""
	var plate := player.held_item as CookedDish
	return interactable.prompt if plate != null and plate.order == order else ""


func walk_to(points: Array[Vector3]) -> void:
	_path = points.duplicate()


func is_walking() -> bool:
	return not _path.is_empty()


# Took the food: say thanks (and what it paid) and head out along `points`.
func leave(points: Array[Vector3], paid: int) -> void:
	leaving = true
	_bag.visible = true
	_bubble.text = "Thanks! +$%d" % paid
	walk_to(points)


func _show_waiting() -> void:
	_bubble.text = "Pickup:\n%s for %s" % [order.dish.get("name", "?"), order.caller.get("name", "?")]


func _physics_process(delta: float) -> void:
	if _path.is_empty():
		return
	var offset := _path[0] - global_position
	var step := walk_speed * delta
	if offset.length() <= step:
		global_position = _path[0]
		_path.pop_front()
		if _path.is_empty():
			if leaving:
				arrived_outside.emit(self)
			else:
				rotation.y = PI  # Face the counter.
		return
	global_position += offset.normalized() * step
	if Vector2(offset.x, offset.z).length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(offset.x, offset.z), 10.0 * delta)


# Placeholder look: a yellow capsule with a cap and a bag (the bag shows once it has the food).
func _build(color: Color) -> void:
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = color
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.1
	capsule.material = body_material
	body.mesh = capsule
	body.position.y = 0.55
	add_child(body)

	var cap_material := StandardMaterial3D.new()
	cap_material.albedo_color = Color(0.85, 0.3, 0.25)
	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.24
	cap_mesh.bottom_radius = 0.27
	cap_mesh.height = 0.12
	cap_mesh.material = cap_material
	cap.mesh = cap_mesh
	cap.position.y = 1.12
	add_child(cap)
	var brim := MeshInstance3D.new()
	var brim_mesh := BoxMesh.new()
	brim_mesh.size = Vector3(0.3, 0.03, 0.2)
	brim_mesh.material = cap_material
	brim.mesh = brim_mesh
	brim.position = Vector3(0.0, 1.07, 0.3)
	add_child(brim)

	var bag_material := StandardMaterial3D.new()
	bag_material.albedo_color = Color(0.93, 0.88, 0.76)
	_bag = MeshInstance3D.new()
	var bag_mesh := BoxMesh.new()
	bag_mesh.size = Vector3(0.28, 0.34, 0.2)
	bag_mesh.material = bag_material
	_bag.mesh = bag_mesh
	_bag.position = Vector3(0.36, 0.55, 0.0)
	_bag.visible = false
	add_child(_bag)

	_bubble.position.y = 1.65
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.modulate = Color(0.25, 0.18, 0.12)
	_bubble.outline_modulate = Color(1, 0.98, 0.92)
	_bubble.font_size = 32
	_bubble.outline_size = 14
	add_child(_bubble)
