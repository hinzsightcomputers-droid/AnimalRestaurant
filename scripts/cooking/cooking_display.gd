# CookingDisplay: draws the cooking minigame above the stove (bar, sweet spot,
# sliding marker, status text). Display only: it reads the station's minigame.
extends Node3D

const BAR_HALF_WIDTH := 0.8  # Half the width of the Background mesh.

@onready var station: CookingStation = get_parent()
@onready var zone: Node3D = $Zone
@onready var marker: Node3D = $Marker
@onready var status: Label3D = $Status


func _ready() -> void:
	# Moved in _process, so skip physics interpolation.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# Zone mesh is as wide as the whole bar; shrink it to the sweet spot.
	zone.scale.x = CookingMinigame.SWEET_SPOT_HALF_WIDTH
	visible = false


func _process(_delta: float) -> void:
	var minigame := station.minigame
	visible = minigame != null
	if minigame == null:
		return

	marker.position.x = minigame.marker * BAR_HALF_WIDTH
	if minigame.is_finished:
		status.text = "%s! %d%%" % [CookingMinigame.quality_label(minigame.quality), roundi(minigame.quality * 100)]
	else:
		status.text = "Stir %d / %d" % [minigame.scores.size() + 1, CookingMinigame.HITS_NEEDED]
