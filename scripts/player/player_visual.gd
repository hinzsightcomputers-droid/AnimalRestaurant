# PlayerVisual: gives each player their own color (a ring at their feet) and
# a name tag (their chef name, or "P1".."P4" before they've picked one) so
# players can tell themselves apart, both shown once there's more than one
# player. The body itself is the ChefModel, dressed as their account's chef.
# Display only.
class_name PlayerVisual
extends Node3D

const COLORS := [
	Color(0.45, 0.68, 0.9),   # Player 1: blue
	Color(0.95, 0.55, 0.65),  # Player 2: pink
	Color(0.55, 0.8, 0.45),   # Player 3: green
	Color(0.98, 0.78, 0.35),  # Player 4: yellow
]

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
	Accounts.player_account_changed.connect(_refresh_look)
	Accounts.appearance_changed.connect(_on_appearance_changed)
	_refresh_look()
	_refresh_tag()
	player.held_item_changed.connect(func(item): chef.carrying = item != null)  # Arms up to hold it.
	GameState.unlocks_changed.connect(_refresh_look)  # Locked items (like Stitches' apron) only show once unlocked.


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


func _on_appearance_changed(account_id: String) -> void:
	if account_id == Accounts.id_of(player.player_index):
		_refresh_look()


# Their chef looks the way their account says (the default chef before they pick one).
func _refresh_look(changed_index: int = -1) -> void:
	if changed_index == -1 or changed_index == player.player_index:
		chef.apply_appearance(Accounts.appearance_of(player.player_index))


func _refresh_tag(_changed_index: int = -1) -> void:
	var account := Accounts.account_of(player.player_index)
	tag.text = account.get("name", "P%d" % (player.player_index + 1))


# The tag and ring only matter once there's more than one player.
func _process(_delta: float) -> void:
	tag.visible = InputSetup.active_players().size() > 1
	_ring.visible = tag.visible
