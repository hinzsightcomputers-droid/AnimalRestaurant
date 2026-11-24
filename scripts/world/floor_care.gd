# FloorCare: messes on the floor for whoever has a moment (FloorMess). Cooking
# sometimes leaves a spill, chopping some peelings, and customers some crumbs;
# and when a meal's customers have all gone, a few more turn up, so there's
# something for everyone to help with. A meal that ends with every floor clean
# (and at least one thing cleaned) earns a little when the bell's rung. Numbers
# and words in data/service.json "floor_care". Never required.
class_name FloorCare
extends Node3D

const GROUP := "floor_care"
const TRIES := 24
const CLEAR_RADIUS := 0.3     # Room a mess needs.
const APART := 0.9            # Between messes.
const FLOOR_Y := 0.01
const SEEN_FROM := Vector3(0.0, 0.9, 1.0)  # Toward the camera (as the screen sees it)...
const SEEN_LENGTH := 2.2                   # ...and how far to look for furniture in the way.

var cleaned_this_meal := 0


func _ready() -> void:
	add_to_group(GROUP)


static func settings() -> Dictionary:
	return GameData.service.get("floor_care", {})


static func find(tree: SceneTree) -> FloorCare:
	return tree.get_first_node_in_group(GROUP) as FloorCare


# A dish was cooked at this station (quality 0..1: a messy cook spills more).
static func cooked(station: Node3D, quality: float) -> void:
	_chance(station, "spill", lerpf(float(settings().get("messy_cook_chance", 0.8)), float(settings().get("cook_chance", 0.4)), quality))


static func chopped(station: Node3D) -> void:
	_chance(station, "peelings", float(settings().get("chop_chance", 0.25)))


# A customer got up from this table.
static func left(table: Node3D) -> void:
	_chance(table, "crumbs", float(settings().get("leave_chance", 0.25)))


static func _chance(near: Node3D, kind: String, chance: float) -> void:
	var care := find(near.get_tree())
	if care != null and not ReelSandbox.active() and randf() < chance and care.count() < int(settings().get("most", 4)):
		var spot := near.get_node_or_null("Interactable") as Node3D
		care.add_mess(kind, (spot if spot != null else near).global_position)


func count() -> int:
	return get_tree().get_nodes_in_group(FloorMess.GROUP).size()


# The meal's customers have all gone: some to sweep up, by how many chefs there are.
func end_of_meal() -> void:
	var tables := {}
	for node in get_tree().get_nodes_in_group(CustomerManager.SEAT_GROUP):
		if node is Seat and node.table != null:
			tables[node.table] = true
	var places := tables.keys()
	places.shuffle()
	var wanted := int(settings().get("end_base", 1)) + int(settings().get("end_per_player", 1)) * InputSetup.active_players().size()
	for i in mini(wanted - count(), places.size()):
		add_mess("crumbs", places[i].global_position)


# On to the next meal (or closing): paid for clean floors.
func settle() -> void:
	if cleaned_this_meal > 0 and count() == 0:
		var pay := int(settings().get("clean_bonus", 6)) + cleaned_this_meal * int(settings().get("each", 1))
		GameState.add_money(pay)
		GameEvents.announce(String(settings().get("bonus_text", "Spotless floors! +${money}")).format({ "money": pay }))
	cleaned_this_meal = 0


# A mess on a free bit of floor round here, as far from anything to use as it
# can be (so it's in nobody's way). False if there's no room.
func add_mess(kind: String, near: Vector3) -> bool:
	var best := Vector3.INF
	var best_room := 0.0
	for i in TRIES:
		var out := Vector2.from_angle(randf() * TAU) * randf_range(0.7, 1.9)
		var at := Vector3(near.x + out.x, FLOOR_Y, near.z + out.y)
		if not _free(at):
			continue
		var room := INF
		for other in get_tree().get_nodes_in_group(Interactable.GROUP):
			room = minf(room, Vector2(other.global_position.x - at.x, other.global_position.z - at.z).length())
		if room > best_room:
			best_room = room
			best = at
	if best == Vector3.INF:
		return false
	var mess := FloorMess.new()
	mess.kind = kind
	mess.seconds = float(settings().get("seconds", 1.6))
	mess.position = best
	mess.rotation.y = randf() * TAU
	mess.cleaned.connect(_on_cleaned)
	add_child(mess)
	return true


# Indoors, nothing standing there or hiding it from the camera, and no other mess.
func _free(at: Vector3) -> bool:
	if RestaurantGrounds.outdoors(at):
		return false
	for mess in get_tree().get_nodes_in_group(FloorMess.GROUP):
		if mess.global_position.distance_to(at) < APART:
			return false
	var ball := SphereShape3D.new()
	ball.radius = CLEAR_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.transform.origin = at + Vector3.UP * (CLEAR_RADIUS + 0.15)
	query.collision_mask = 1
	var chefs: Array[RID] = []
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		chefs.append(player.get_rid())
	query.exclude = chefs
	var space := get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false
	var from := at + Vector3.UP * 0.1
	var sight := PhysicsRayQueryParameters3D.create(from, from + CameraRig.screen_to_world(SEEN_FROM).normalized() * SEEN_LENGTH, 1, chefs)
	return space.intersect_ray(sight).is_empty()


func _on_cleaned(_mess: FloorMess, player_index: int) -> void:
	cleaned_this_meal += 1
	if player_index >= 0:
		GameState.record_chef_action(player_index, "mopped")
