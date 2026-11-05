# DecorRoom: shows the decor that's placed in the restaurant (GameState.decor_placed).
# It has no collision: the rules in Decor keep it out of everyone's way.
class_name DecorRoom
extends Node3D

const GROUP := "decor_room"

var _stations: Array[Node3D] = []


func _ready() -> void:
	add_to_group(GROUP)
	refresh()


# Finds the stations for can_go(): call before moving anything.
func collect_stations() -> void:
	_stations.clear()
	_add_stations(get_tree().current_scene)


func _add_stations(node: Node) -> void:
	if node is Station:
		_stations.append(node)
	for child in node.get_children():
		_add_stations(child)


# Whether floor decor can go at `point`: it fits, it's clear of the stations,
# and it isn't in the furniture.
func can_go(item: Dictionary, point: Vector2, turn: int) -> bool:
	if not Decor.fits(item, point, turn):
		return false
	for station in _stations:
		if Vector2(station.global_position.x, station.global_position.z).distance_to(point) < float(Decor.settings().get("station_gap", 1.1)):
			return false
	var size := Decor.footprint(item, turn)
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, 1.6, size.y)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis.IDENTITY, Vector3(point.x, 0.9, point.y))
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 16):
		if not hit["collider"] is CharacterBody3D:
			return false
	return true


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for placed in GameState.decor_placed:
		var item := Decor.get_item(String(placed.get("id", "")))
		if item.is_empty():
			continue  # Taken out of data/decor.json.
		var node := Decor.build(item)
		add_child(node)
		var spot := int(placed.get("spot", -1))
		if spot >= 0:
			node.position = Decor.spot_position(spot)
			node.rotation_degrees.y = Decor.spot_turn(spot)
		else:
			node.position = Vector3(float(placed["x"]), 0.0, float(placed["z"]))
			node.rotation_degrees.y = int(placed.get("turn", 0))
