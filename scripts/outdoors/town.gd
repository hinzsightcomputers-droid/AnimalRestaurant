# Town: the regulars' houses (data/houses.json), either side of the
# restaurant with their fronts to the street. Any street scenery standing
# where a house goes (a tree, a bush) is hidden. Also keeps today's visits
# (GameState.house_day): one knock per house per restaurant day, and how much
# friendship gifts have added today.
class_name Town
extends Node3D

const KEEP := ["Grass", "Sidewalk", "Road", "FarSidewalk"]  # Ground, not scenery.
const CLEARANCE := 1.2  # Scenery this close to a house's walls goes.

var houses: Array[House] = []


func _ready() -> void:
	for entry: Dictionary in GameData.houses.get("houses", []):
		var house := House.new()
		house.name = "House_" + String(entry.get("regular", ""))
		house.data = entry
		add_child(house)
		houses.append(house)
	var outside := get_node_or_null("../RestaurantRoom/Outside")
	if outside == null:
		return
	var size: Array = settings().get("size", [4.4, 4.0])
	var half := Vector2(float(size[0]), float(size[1])) / 2.0 + Vector2.ONE * CLEARANCE
	for child in outside.get_children():
		if not child is Node3D or String(child.name) in KEEP:
			continue
		for house in houses:
			var offset := Vector2(child.global_position.x - house.global_position.x, child.global_position.z - house.global_position.z)
			if absf(offset.x) < half.x and absf(offset.y) < half.y + 1.0:  # And its porch.
				child.visible = false


func house_of(regular_id: String) -> House:
	for house in houses:
		if house.regular_id == regular_id:
			return house
	return null


static func settings() -> Dictionary:
	return GameData.houses.get("settings", {})


# Today's visits, started fresh on a new restaurant day.
static func today() -> Dictionary:
	if GameState.house_day.get("date", "") != GameClock.today():
		GameState.house_day = { "date": GameClock.today(), "visited": [], "gift_points": {} }
	return GameState.house_day


static func visited_today(regular_id: String) -> bool:
	return regular_id in today().get("visited", [])


static func mark_visited(regular_id: String) -> void:
	var visited: Array = today().get_or_add("visited", [])
	if not regular_id in visited:
		visited.append(regular_id)


# Friendship gifts can still add for this regular today.
static func gift_points_left(regular_id: String) -> int:
	var given := int(today().get("gift_points", {}).get(regular_id, 0))
	return maxi(int(settings().get("gifts", {}).get("daily_cap", 3)) - given, 0)


static func add_gift_points(regular_id: String, points: int) -> void:
	var gift_points: Dictionary = today().get_or_add("gift_points", {})
	gift_points[regular_id] = int(gift_points.get(regular_id, 0)) + points


# Debug: forget today's visits (and gifts) at every house.
static func reset_today() -> void:
	GameState.house_day = {}
