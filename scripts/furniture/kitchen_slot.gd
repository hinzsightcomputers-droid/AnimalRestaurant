# KitchenSlot: room in the kitchen for one more station (a stove, a chopping
# board or an oven: this node's child), bought in the end-of-day shop as the
# upgrade `upgrade_id`. Until then the station is kept out of the kitchen and a
# plain counter stands in its spot; once it's bought, the station takes the
# counter's place. With dish_id instead, it comes in once that dish is on the
# menu (the microwave, bought along with Mochi).
class_name KitchenSlot
extends Node3D

const COUNTER_MODEL := "res://design/assets/KayKit_Bits_Bundle1_1.1/Restaurant Bits/Assets/gltf/kitchencounter_straight_A.gltf"

@export var upgrade_id := ""
@export var dish_id := ""                  # Or: in once this dish is unlocked.
@export var counter_size := Vector3(1.4, 0.9, 0.8)  # The stand-in counter: the station's footprint.

var _station: Node3D = null
var _counter := StaticBody3D.new()


func _ready() -> void:
	_station = get_child(0)
	var look := ModelFit.new()
	look.size = counter_size
	look.stretch = true
	look.model = load(COUNTER_MODEL)
	_counter.add_child(look)
	var shape := BoxShape3D.new()
	shape.size = counter_size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = counter_size.y * 0.5
	_counter.add_child(collision)
	_counter.name = "Counter"
	GameState.upgrades_changed.connect(_refresh)
	GameState.unlocks_changed.connect(_refresh)
	_refresh()


# Station or counter, whichever's owned.
func _refresh() -> void:
	var owned := GameData.is_unlocked(dish_id) if not dish_id.is_empty() else GameState.has_upgrade(upgrade_id)
	var station_in := _station.get_parent() == self
	if owned and not station_in:
		remove_child(_counter)
		add_child(_station)
	elif not owned and station_in:
		remove_child(_station)
		add_child(_counter)
	elif not owned and _counter.get_parent() == null:
		add_child(_counter)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:  # Whichever one's out of the tree goes too.
		for node in [_station, _counter]:
			if is_instance_valid(node) and node.get_parent() == null:
				node.free()
