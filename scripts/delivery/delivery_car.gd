# DeliveryCar: the restaurant's own little delivery cart, parked out front by
# the lane (data/phone.json "drive": parked_at). During the night shift a chef
# can drive deliveries instead of waiting for Delivery Duck: bring a bagged
# delivery over and put it in the back ("Put ... in the cart": its courier
# goes home), as many as you like, then climb in ("Drive the deliveries") for
# DeliveryDrive. Other chefs carry on at the restaurant meanwhile. Bags in the
# cart (or out on a drive) keep the night going, as a waiting courier does.
class_name DeliveryCar
extends Node3D

var manager: DeliveryManager
var loaded: Array[TakeoutBag] = []
var driver := -1  # The chef out driving, or -1.

var interactable := Interactable.new()
var _bags_shown: Array[Node3D] = []


func settings() -> Dictionary:
	return GameData.phone_settings.get("drive", {})


func _ready() -> void:
	var at: Array = settings().get("parked_at", [10.6, 8.1])
	position = Vector3(float(at[0]), 0.0, float(at[1]))
	rotation.y = deg_to_rad(float(settings().get("parked_turn", 180.0)))
	add_child(build_look())
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 1.6, 2.6)
	shape.shape = box
	shape.position.y = 0.8
	body.add_child(shape)
	add_child(body)
	interactable.radius = 2.0
	interactable.prompt_height = 2.0
	interactable.prompt_for_player = _prompt_for
	interactable.interacted.connect(_on_interacted)
	add_child(interactable)
	_refresh_bags()


# Whether it's holding the night up: bags in it, or out on a drive.
func busy() -> bool:
	return not loaded.is_empty() or driver >= 0


func available() -> bool:
	return DayCycle.is_night() and GameState.phone_unlocked and driver < 0


func _prompt_for(player_index: int) -> String:
	var player := Player.find(get_tree(), player_index)
	if player == null or not available() or player.movement_locked:
		return ""
	var bag := player.held_item as TakeoutBag
	if bag != null and bag.is_delivery():
		if manager.is_goodbye(bag.dish.order):
			return ""  # A regular's last order goes with the courier, who brings their note.
		return "Put %s's %s in the cart" % [bag.dish.order.caller.get("name", "?"), bag.contents_name()]
	if player.held_item == null and not loaded.is_empty():
		return "Drive the deliveries (%d)" % loaded.size() if loaded.size() > 1 else "Drive the delivery"
	return ""


func _on_interacted(player_index: int) -> void:
	if _prompt_for(player_index).is_empty():
		return
	var player := Player.find(get_tree(), player_index)
	var bag := player.held_item as TakeoutBag
	if bag != null:
		player.set_held_item(null)
		loaded.append(bag)
		manager.send_home(bag.dish.order)
		GameEvents.announce("%s's %s is in the cart. Load more, or climb in and drive!" % [bag.dish.order.caller.get("name", "?"), bag.contents_name()])
		_refresh_bags()
		return
	_drive(player)


func _drive(player: Player) -> void:
	driver = player.player_index
	var bags := loaded.duplicate()
	loaded.clear()
	_refresh_bags()
	player.movement_locked = true
	var drive := DeliveryDrive.new()
	drive.view_manager = manager.view_manager
	drive.player_index = player.player_index
	drive.bags = bags
	drive.manager = manager
	add_child(drive)
	await drive.shown
	player.visible = false
	await drive.finished
	player.visible = true
	var out := global_transform * Vector3(-1.4, 0.0, 0.0)  # Beside the cart, at the driver's side.
	player.global_position = Vector3(out.x, 0.0, out.z)
	player.ignore_interact_until_released()
	player.movement_locked = false
	driver = -1


# The bags in the back, one little parcel each.
func _refresh_bags() -> void:
	for node in _bags_shown:
		node.queue_free()
	_bags_shown.clear()
	for i in loaded.size():
		var parcel := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3(0.3, 0.32, 0.24)
		parcel.mesh = cube
		parcel.material_override = CottageDressing._paint(Color("E8D2A6"))
		parcel.position = Vector3(-0.3 + (i % 3) * 0.3, 0.98 + (i / 3) * 0.33, -0.75)
		add_child(parcel)
		_bags_shown.append(parcel)


# A little red delivery cart with a striped canopy and the restaurant's name
# on a board (placeholder shapes, merged into one mesh). Front toward +z.
static func build_look() -> Node3D:
	var look := Node3D.new()
	look.name = "Look"
	var shapes := Node3D.new()
	look.add_child(shapes)
	var red := Color("C8423A")
	var wood := Color("8A5A3C")
	var dark := Color("4A3024")
	CottageDressing._box(shapes, Vector3(0, 0.62, 0), Vector3(1.4, 0.36, 2.4), red)  # The body.
	CottageDressing._box(shapes, Vector3(0, 0.82, -0.6), Vector3(1.4, 0.06, 1.2), wood)  # The open back's floor.
	for side in [-1.0, 1.0]:  # Its low sides at the back.
		CottageDressing._box(shapes, Vector3(side * 0.67, 0.98, -0.6), Vector3(0.06, 0.3, 1.2), red)
	CottageDressing._box(shapes, Vector3(0, 0.98, -1.17), Vector3(1.4, 0.3, 0.06), red)
	CottageDressing._box(shapes, Vector3(0, 1.0, 0.55), Vector3(1.2, 0.3, 0.5), wood)  # The seat.
	CottageDressing._box(shapes, Vector3(0, 1.28, 0.35), Vector3(1.2, 0.3, 0.08), wood)  # Its back.
	CottageDressing._box(shapes, Vector3(0, 0.95, 1.05), Vector3(1.3, 0.25, 0.3), red)  # The front.
	var wheel := CottageDressing._cyl(shapes, Vector3(0, 1.2, 0.95), 0.16, 0.16, 0.03, dark)  # Steering wheel.
	wheel.rotation.x = deg_to_rad(60.0)
	for post_x in [-0.62, 0.62]:  # The canopy on four posts.
		for post_z in [-1.1, 0.8]:
			CottageDressing._cyl(shapes, Vector3(post_x, 1.45, post_z), 0.03, 0.03, 1.3, dark)
	for i in 6:  # Red and cream stripes, 25 cm each.
		CottageDressing._box(shapes, Vector3(-0.75 + (i + 0.5) * 0.25, 2.12, -0.15), Vector3(0.25, 0.05, 2.2), Color("D9473F") if i % 2 == 0 else Color("F6E7CF"))
	for x in [-0.72, 0.72]:
		for z in [-0.8, 0.8]:
			var tyre := CottageDressing._cyl(shapes, Vector3(x, 0.32, z), 0.32, 0.32, 0.16, dark)
			tyre.rotation.z = PI / 2.0
			var hub := CottageDressing._cyl(shapes, Vector3(x * 1.08, 0.32, z), 0.12, 0.12, 0.04, Color("F2C14E"))
			hub.rotation.z = PI / 2.0
	for x in [-0.45, 0.45]:  # Headlamps.
		CottageDressing._ball(shapes, Vector3(x, 0.9, 1.22), 0.08, Color("FFE8A8")).material_override = CottageDressing._paint(Color("FFE8A8"), true)
	MeshMerge.merge(shapes)
	return look
