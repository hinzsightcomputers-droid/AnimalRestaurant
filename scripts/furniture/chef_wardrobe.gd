# ChefWardrobe: the wardrobe at the back of the dining room, by the kitchen. Use
# it to change your chef's look: it opens the full ChefCustomizer (body, face,
# hair, clothes) for the account of whoever used it, so each co-op player
# changes their own chef. Free, any time. Clothes you unlock show up in it
# (Wardrobe "unlock"), and bought ones will later too. Built in code from
# simple shapes (placeholder art: a tall two-door wardrobe).
class_name ChefWardrobe
extends StaticBody3D

const SIZE := Vector3(1.0, 2.0, 0.6)  # Width, height, depth (it faces +z).

var interactable := Interactable.new()
var _visual := Node3D.new()
var _open: ChefCustomizer = null


func _ready() -> void:
	_visual.name = "Visual"
	add_child(_visual)
	_build_look()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = SIZE
	shape.shape = box_shape
	shape.position.y = SIZE.y * 0.5
	add_child(shape)
	interactable.name = "Interactable"
	interactable.prompt = "Change look"
	interactable.radius = 1.1
	interactable.prompt_height = 2.4
	interactable.position = Vector3(0.0, 0.0, SIZE.z * 0.5 + 0.45)
	interactable.prompt_for_player = _prompt_for
	interactable.interacted.connect(open_for)
	add_child(interactable)


# Body, two doors with knobs, a crown on top and little feet.
func _build_look() -> void:
	var wood := Color(0.62, 0.4, 0.26)
	_box(Vector3(SIZE.x, SIZE.y - 0.12, SIZE.z), Vector3(0.0, SIZE.y * 0.5 + 0.04, 0.0), wood)
	_box(Vector3(SIZE.x + 0.08, 0.1, SIZE.z + 0.08), Vector3(0.0, SIZE.y - 0.03, 0.0), wood.darkened(0.2))
	for side in [-1.0, 1.0]:
		var door_x: float = side * SIZE.x * 0.25
		_box(Vector3(SIZE.x * 0.5 - 0.06, SIZE.y - 0.32, 0.03), Vector3(door_x, SIZE.y * 0.5 + 0.03, SIZE.z * 0.5 + 0.01), wood.lightened(0.15))
		_box(Vector3(SIZE.x * 0.5 - 0.2, 0.5, 0.02), Vector3(door_x, SIZE.y * 0.68, SIZE.z * 0.5 + 0.03), wood.lightened(0.28))
		_box(Vector3(SIZE.x * 0.5 - 0.2, 0.5, 0.02), Vector3(door_x, SIZE.y * 0.32, SIZE.z * 0.5 + 0.03), wood.lightened(0.28))
		var knob := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.035
		sphere.height = 0.07
		knob.mesh = sphere
		knob.material_override = _material(Color(0.95, 0.78, 0.35))
		knob.position = Vector3(side * 0.06, SIZE.y * 0.52, SIZE.z * 0.5 + 0.05)
		_visual.add_child(knob)
		for back in [-1.0, 1.0]:
			_box(Vector3(0.1, 0.08, 0.1), Vector3(side * (SIZE.x * 0.5 - 0.08), 0.04, back * (SIZE.z * 0.5 - 0.08)), wood.darkened(0.3))


func _box(box_size: Vector3, at: Vector3, color: Color) -> void:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	box.mesh = mesh
	box.material_override = _material(color)
	box.position = at
	_visual.add_child(box)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material


# "" (not offered) until they've picked a chef, or while it's open.
func _prompt_for(player_index: int) -> String:
	if _open != null or not Accounts.has_account(player_index):
		return ""
	return interactable.prompt


# Opens the customizer for player `player_index`'s chef.
func open_for(player_index: int) -> ChefCustomizer:
	if _open != null or not Accounts.has_account(player_index):
		return null
	_open = ChefCustomizer.open(get_tree().root, Accounts.id_of(player_index))
	_open.finished.connect(func(_saved: bool): _open = null)
	return _open
