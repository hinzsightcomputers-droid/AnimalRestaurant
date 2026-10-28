# PlayerVisual: gives each player their own body color and a name tag (their
# chef name, or "P1".."P4" before they've picked one) so players can tell
# themselves apart. Display only.
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

var _apron: Node3D

@onready var player: Player = get_parent()
@onready var body: MeshInstance3D = $Body
@onready var tag: Label3D = $Tag


static func color_for(player_index: int) -> Color:
	return COLORS[player_index % COLORS.size()]


func _ready() -> void:
	var color := color_for(player.player_index)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	body.material_override = material
	tag.modulate = color.lightened(0.3)
	Accounts.player_account_changed.connect(_refresh_tag)
	_refresh_tag()
	_apron = _build_apron()
	GameState.unlocks_changed.connect(_refresh_apron)
	_refresh_apron()


# Stitches' patchwork apron (his big moment's reward): every chef wears it once it's unlocked.
func _refresh_apron() -> void:
	_apron.visible = APRON_REWARD in GameState.unlocks


# Mismatched patches on the front of the body, with a strap around the neck.
# The blue is his old blanket, the stars, the scarf from his first day...
func _build_apron() -> Node3D:
	var apron := Node3D.new()
	add_child(apron)
	var patch_size := Vector2(0.17, 0.15)
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
			var y: float = 0.95 - row * patch_size.y
			# Follow the capsule's curve: the patches sit just in front of its surface.
			var z := sqrt(maxf(0.0, 0.35 * 0.35 - x * x)) + 0.01
			patch.position = Vector3(x, y, z)
			patch.rotation.y = asin(clampf(x / 0.35, -1.0, 1.0))
			apron.add_child(patch)
	var strap := MeshInstance3D.new()
	var strap_mesh := TorusMesh.new()
	strap_mesh.inner_radius = 0.2
	strap_mesh.outer_radius = 0.23
	var strap_material := StandardMaterial3D.new()
	strap_material.albedo_color = Color(0.55, 0.38, 0.25)
	strap_mesh.material = strap_material
	strap.mesh = strap_mesh
	strap.position = Vector3(0.0, 1.13, 0.06)
	strap.rotation.x = deg_to_rad(-20.0)
	apron.add_child(strap)
	return apron


func _refresh_tag(_changed_index: int = -1) -> void:
	var account := Accounts.account_of(player.player_index)
	tag.text = account.get("name", "P%d" % (player.player_index + 1))


# The tag only matters once there's more than one player.
func _process(_delta: float) -> void:
	tag.visible = InputSetup.active_players().size() > 1
