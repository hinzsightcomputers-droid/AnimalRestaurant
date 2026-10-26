# Station: shared script for furniture you can use (table, chair, counter, stove).
# Listens to its Interactable child and re-emits `used` so game systems can react.
# For now it only gives feedback; later steps add real behavior per station.
class_name Station
extends StaticBody3D

signal used(station: Station, player_index: int)

@export var display_name := "Station"

@onready var interactable: Interactable = $Interactable
@onready var visual: Node3D = $Visual

var _bounce_tween: Tween


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)


func _on_interacted(player_index: int) -> void:
	print("Player %d used %s" % [player_index, display_name])
	used.emit(self, player_index)
	_play_bounce()


# Quick squash-and-stretch so the player sees the interaction happened.
func _play_bounce() -> void:
	if _bounce_tween != null:
		_bounce_tween.kill()
	visual.scale = Vector3.ONE
	_bounce_tween = create_tween()
	_bounce_tween.tween_property(visual, "scale", Vector3(1.08, 0.9, 1.08), 0.07)
	_bounce_tween.tween_property(visual, "scale", Vector3.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
