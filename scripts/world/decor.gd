# Decor: the rules for decor (data/decor.json): what the shop has today, what
# counts toward the star rating, where things can go, and how an item is built.
# What's owned is in GameState: decor_stored (id -> how many are in storage) and
# decor_placed ({ id, x, z, turn, spot }; spot is a wall_spots index, or -1 on
# the floor). DecorRoom shows what's placed; DecorateMode places it.
class_name Decor
extends RefCounted


static func settings() -> Dictionary:
	return GameData.decor


static func items() -> Array:
	return settings().get("items", [])


static func get_item(item_id: String) -> Dictionary:
	for item in items():
		if item["id"] == item_id:
			return item
	return {}


# Today's shop: shop_per_day of the items the stars allow, the same all day.
static func stock() -> Array:
	var open := items().filter(func(item): return int(item.get("tier", 1)) <= GameState.stars)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(GameState.date)
	for i in range(open.size() - 1, 0, -1):
		var other := rng.randi_range(0, i)
		var swap = open[i]
		open[i] = open[other]
		open[other] = swap
	return open.slice(0, int(settings().get("shop_per_day", 6)))


# The Decor area of the star rating: points by category (each id up to
# max_copies times, each category up to category_cap), plus set_points a full set.
static func score() -> int:
	var copies := {}
	var categories := {}
	for placed in GameState.decor_placed:
		var item := get_item(String(placed.get("id", "")))
		if item.is_empty():
			continue
		var id: String = item["id"]
		copies[id] = int(copies.get(id, 0)) + 1
		if copies[id] <= int(settings().get("max_copies", 2)):
			var category: String = item.get("category", "")
			categories[category] = int(categories.get(category, 0)) + int(item.get("points", 1))
	var total := 0
	for category in categories:
		total += mini(categories[category], int(settings().get("category_cap", 8)))
	for set_name in _set_names():
		var members := items().filter(func(item): return item.get("set", "") == set_name)
		if members.all(func(item): return copies.has(item["id"])):
			total += int(settings().get("set_points", 4))
	return total


static func _set_names() -> Array:
	var names := []
	for item in items():
		if item.has("set") and not item["set"] in names:
			names.append(item["set"])
	return names


# The grid's squares: its top-left corner and how many there are each way.
static func grid_origin() -> Vector2:
	var grid: Dictionary = settings()["grid"]
	var cell := float(grid["cell"])
	return Vector2(grid["min"][0], grid["min"][1]) - Vector2.ONE * cell * 0.5


static func grid_cells() -> Vector2i:
	var grid: Dictionary = settings()["grid"]
	var cell := float(grid["cell"])
	return Vector2i(roundi((grid["max"][0] - grid["min"][0]) / cell) + 1, roundi((grid["max"][1] - grid["min"][1]) / cell) + 1)


# The middle of where `item` goes nearest `point`: it always fills whole
# squares, so a two-square item sits on a line and a one-square item in a square.
static func snap(item: Dictionary, point: Vector2, turn: int) -> Vector2:
	var cell := float(settings()["grid"]["cell"])
	var size := footprint(item, turn)
	var origin := grid_origin()
	var cells := grid_cells()
	var wide := maxi(roundi(size.x / cell), 1)
	var deep := maxi(roundi(size.y / cell), 1)
	var left := clampi(roundi((point.x - size.x * 0.5 - origin.x) / cell), 0, cells.x - wide)
	var top := clampi(roundi((point.y - size.y * 0.5 - origin.y) / cell), 0, cells.y - deep)
	return origin + Vector2(left * cell + wide * cell * 0.5, top * cell + deep * cell * 0.5)


# Where the cursor goes to be on `item` sitting at `at`: a square, so moving on
# from there goes one square at a time.
static func cursor_on(item: Dictionary, at: Vector2, turn: int) -> Vector2:
	var cell := float(settings()["grid"]["cell"])
	var size := footprint(item, turn)
	var even_x := roundi(size.x / cell) % 2 == 0
	var even_y := roundi(size.y / cell) % 2 == 0
	return at - Vector2(cell * 0.5 if even_x else 0.0, cell * 0.5 if even_y else 0.0)


# Puts loaded floor decor onto the squares. Anything that no longer fits tries
# the squares beside it, then goes back into storage.
static func settle_on_grid() -> void:
	var cell := float(settings()["grid"]["cell"])
	var loaded: Array = GameState.decor_placed
	GameState.decor_placed = []
	for placed in loaded:
		var item := get_item(String(placed.get("id", "")))
		if item.is_empty() or int(placed.get("spot", -1)) >= 0:
			GameState.decor_placed.append(placed)
			continue
		var turn := int(placed.get("turn", 0))
		var wanted := Vector2(float(placed.get("x", 0.0)), float(placed.get("z", 0.0)))
		var settled := false
		for step in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var at := snap(item, wanted + step * cell, turn)
			if fits(item, at, turn):
				placed["x"] = at.x
				placed["z"] = at.y
				GameState.decor_placed.append(placed)
				settled = true
				break
		if not settled:
			GameState.decor_stored[item["id"]] = int(GameState.decor_stored.get(item["id"], 0)) + 1


# Whether `point` is in a keep_clear rectangle.
static func kept_clear(point: Vector2) -> bool:
	for rect in settings().get("keep_clear", []):
		if point.x >= rect[0] and point.x <= rect[2] and point.y >= rect[1] and point.y <= rect[3]:
			return true
	return false


# An item's [width, depth] once turned.
static func footprint(item: Dictionary, turn: int) -> Vector2:
	var size: Array = item.get("size", [0.5, 0.5])
	return Vector2(size[1], size[0]) if posmod(turn, 180) == 90 else Vector2(size[0], size[1])


# Whether the footprint of `item` at `point`, turned `turn`, stays out of the
# rectangles and off the decor already placed.
static func fits(item: Dictionary, point: Vector2, turn: int) -> bool:
	var size := footprint(item, turn)
	var grid: Dictionary = settings().get("grid", {})
	var low := Vector2(grid["min"][0], grid["min"][1])
	var high := Vector2(grid["max"][0], grid["max"][1])
	var half := size * 0.5
	if point.x - half.x < low.x - 0.25 or point.y - half.y < low.y - 0.25 or point.x + half.x > high.x + 0.25 or point.y + half.y > high.y + 0.25:
		return false
	for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(-half.x, half.y), Vector2(half.x, half.y), Vector2.ZERO]:
		if kept_clear(point + corner * 0.98):
			return false
	var mine := Rect2(point - half, size).grow(-0.01)
	for placed in GameState.decor_placed:
		if int(placed.get("spot", -1)) >= 0:
			continue
		var other := get_item(String(placed["id"]))
		if other.is_empty():
			continue
		var other_size := footprint(other, int(placed.get("turn", 0)))
		var at := Vector2(float(placed["x"]), float(placed["z"]))
		if mine.intersects(Rect2(at - other_size * 0.5, other_size)):
			return false
	return true


static func spot_taken(spot: int) -> bool:
	return GameState.decor_placed.any(func(placed): return int(placed.get("spot", -1)) == spot)


static func spot_position(spot: int) -> Vector3:
	var at: Array = settings().get("wall_spots", [])[spot]["at"]
	return Vector3(at[0], at[1], at[2])


static func spot_turn(spot: int) -> int:
	return int(settings().get("wall_spots", [])[spot].get("turn", 0))


# The item's look: its parts under a new node, bottom middle at the node.
static func build(item: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = String(item.get("id", "Decor"))
	for part in item.get("parts", []):
		var at: Array = part.get("at", [0, 0, 0])
		var position := Vector3(at[0], at[1], at[2])
		if part.has("model"):
			var size: Array = part.get("size", [0, 0, 0])
			if ModelFit.place(String(part["model"]), root, position, Vector3(size[0], size[1], size[2])) == null:
				push_warning("Decor model not found: %s" % part["model"])
			continue
		var mesh_node := MeshInstance3D.new()
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(String(part.get("color", "#ffffff")))
		if part.has("box"):
			var box := BoxMesh.new()
			box.size = Vector3(part["box"][0], part["box"][1], part["box"][2])
			box.material = material
			mesh_node.mesh = box
			position.y += box.size.y * 0.5
		else:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = part["cylinder"][0]
			cylinder.bottom_radius = part["cylinder"][0]
			cylinder.height = part["cylinder"][1]
			cylinder.material = material
			mesh_node.mesh = cylinder
			position.y += cylinder.height * 0.5
		mesh_node.position = position
		root.add_child(mesh_node)
	return root
