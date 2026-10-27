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


func _refresh_tag(_changed_index: int = -1) -> void:
	var account := Accounts.account_of(player.player_index)
	tag.text = account.get("name", "P%d" % (player.player_index + 1))


# The tag only matters once there's more than one player.
func _process(_delta: float) -> void:
	tag.visible = InputSetup.active_players().size() > 1
