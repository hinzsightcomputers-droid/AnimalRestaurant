# PlayerVisual: gives each player their own body color and a "P1".."P4" tag so
# players can tell themselves apart. Display only.
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


func _ready() -> void:
	var color: Color = COLORS[player.player_index % COLORS.size()]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	body.material_override = material
	tag.text = "P%d" % (player.player_index + 1)
	tag.modulate = color.lightened(0.3)


# The tag only matters once there's more than one player.
func _process(_delta: float) -> void:
	tag.visible = InputSetup.active_players().size() > 1