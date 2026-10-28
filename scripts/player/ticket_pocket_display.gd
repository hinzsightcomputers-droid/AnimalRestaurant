# TicketPocketDisplay: the order tickets a player is carrying, as a slip of
# paper tucked at their side, with how many when it's more than one. Display only.
extends Node3D

@onready var player: Player = owner

var _slip := MeshInstance3D.new()
var _count := Label3D.new()


func _ready() -> void:
	var paper := BoxMesh.new()
	paper.size = Vector3(0.1, 0.13, 0.004)
	var material := StandardMaterial3D.new()
	material.albedo_color = TicketPopup.PAPER
	paper.material = material
	_slip.mesh = paper
	add_child(_slip)
	_count.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_count.no_depth_test = true
	_count.font_size = 36
	_count.outline_size = 10
	_count.pixel_size = 0.004
	_count.position.y = 0.14
	add_child(_count)
	player.tickets_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	visible = not player.tickets.is_empty()
	_count.text = "x%d" % player.tickets.size()
	_count.visible = player.tickets.size() > 1
	if visible:  # A little flutter as one goes in.
		var tween := create_tween()
		scale = Vector3.ONE * 1.4
		tween.tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
