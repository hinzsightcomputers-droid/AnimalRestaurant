# PlayerVisual: gives each player their own color (a ring at their feet) and
# a name tag (their chef name, or "P1".."P4" before they've picked one) so
# players can tell themselves apart, both shown once there's more than one
# player. The body itself is the ChefModel. Display only.
class_name PlayerVisual
extends Node3D

const COLORS := [
	Color(0.45, 0.68, 0.9),   # Player 1: blue
	Color(0.95, 0.55, 0.65),  # Player 2: pink
	Color(0.55, 0.8, 0.45),   # Player 3: green
	Color(0.98, 0.78, 0.35),  # Player 4: yellow
]

const APRON_REWARD := "patchwork_apron"
const APRON_PATCHES := [  # Rows from the top, each patch a different fabric.
	[Color(0.35, 0.5, 0.8), Color(0.95, 0.82, 0.35)],
	[Color(0.85, 0.35, 0.3), Color(0.5, 0.72, 0.45), Color(0.92, 0.6, 0.72)],
	[Color(0.98, 0.9, 0.7), Color(0.4, 0.3, 0.55), Color(0.55, 0.78, 0.85)],
	[Color(0.75, 0.55, 0.3), Color(0.35, 0.5, 0.8), Color(0.85, 0.35, 0.3)],
]

const APRON_FRONT := 0.36  # How far in front of the chef's middle the patches sit.

var _apron: Node3D
var _ring := MeshInstance3D.new()

@onready var player: Player = get_parent()
@onready var chef: ChefModel = $Chef
@onready var tag: Label3D = $Tag


static func color_for(player_index: int) -> Color:
	return COLORS[player_index % COLORS.size()]


func _ready() -> void:
	var color := color_for(player.player_index)
	_build_ring(color)
	tag.modulate = color.lightened(0.3)
	Accounts.player_account_changed.connect(_refresh_tag)
	_refresh_tag()
	_apron = _build_apron()
	player.held_item_changed.connect(func(item): chef.carrying = item != null)  # Arms up to hold it.
	GameState.unlocks_changed.connect(_refresh_apron)
	_refresh_apron()


# Stitches' patchwork apron (his big moment's reward): every chef wears it once it's unlocked.
func _refresh_apron() -> void:
	_apron.visible = APRON_REWARD in GameState.unlocks


# A flat ring on the floor around their feet, in their color.
func _build_ring(color: Color) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.36
	mesh.outer_radius = 0.42
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	_ring.mesh = mesh
	_ring.scale.y = 0.15
	_ring.position.y = 0.02
	add_child(_ring)


# Mismatched patches on the front of the tunic, with a strap around the neck,
# riding on the chef's spine so it moves with them. (In the character's own
# unscaled space: the tunic's front is about 0.33 out.)
# The blue is his old blanket, the stars, the scarf from his first day...
func _build_apron() -> Node3D:
	var apron := Node3D.new()
	var patch_size := Vector2(0.2, 0.17)
	for row in APRON_PATCHES.size():
		for column in APRON_PATCHES[row].size():
			var patch := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(patch_size.x - 0.012, patch_size.y - 0.012, 0.03)
			var material := StandardMaterial3D.new()
			material.albedo_color = APRON_PATCHES[row][column]
			mesh.material = material
			patch.mesh = mesh
			var x: float = (column - (APRON_PATCHES[row].size() - 1) * 0.5) * patch_size.x
			var y: float = 1.12 - row * patch_size.y
			patch.position = Vector3(x, y, APRON_FRONT - absf(x) * 0.25)  # Curving back a little at the sides.
			patch.rotation.y = x * 0.6
			apron.add_child(patch)
	var strap := MeshInstance3D.new()
	var strap_mesh := TorusMesh.new()
	strap_mesh.inner_radius = 0.3
	strap_mesh.outer_radius = 0.34
	var strap_material := StandardMaterial3D.new()
	strap_material.albedo_color = Color(0.55, 0.38, 0.25)
	strap_mesh.material = strap_material
	strap.mesh = strap_mesh
	strap.position = Vector3(0.0, 1.27, 0.06)
	strap.rotation.x = deg_to_rad(-20.0)
	apron.add_child(strap)
	chef.attach("spine", apron, Transform3D.IDENTITY)
	return apron


func _refresh_tag(_changed_index: int = -1) -> void:
	var account := Accounts.account_of(player.player_index)
	tag.text = account.get("name", "P%d" % (player.player_index + 1))


# The tag and ring only matter once there's more than one player.
func _process(_delta: float) -> void:
	tag.visible = InputSetup.active_players().size() > 1
	_ring.visible = tag.visible
