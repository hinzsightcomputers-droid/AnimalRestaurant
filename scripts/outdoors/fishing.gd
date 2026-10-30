# Fishing: which fish bite where and when, and what a catch does. A fish
# bites if its habitat matches and it's one of its seasons (GameClock.season,
# from the real date and the hemisphere) and hour blocks (the real hour);
# among those, rarity_weights in data/fish.json pick one, so rare fish (only
# in one season and time) stay rare. A catch goes into the kitchen's Pantry
# and the Fish Log (how many, the biggest and who caught it, the first and
# who caught it), never into money. The very first fish puts the dishes
# "unlocked_by": "first_fish" (Fish Stew) on the menu. The debug panel can
# pretend it's another season or hour, or pick the next fish. Pure logic,
# plus a model for a fish.
class_name Fishing
extends RefCounted


# The hour block outdoors: the real one, or the debug panel's.
static func hour_block() -> String:
	return GameState.debug_hour_block if not GameState.debug_hour_block.is_empty() else GameClock.hour_block()


# The fish that bite in `habitat` ("pond" or "beach") right now.
static func biting(habitat: String) -> Array[Dictionary]:
	var season := GameClock.season()
	var hour := hour_block()
	var found: Array[Dictionary] = []
	for fish in GameData.fish:
		if fish.get("habitat", "") != habitat:
			continue
		var seasons: Array = fish.get("seasons", [])
		var hours: Array = fish.get("hours", [])
		if (seasons.is_empty() or season in seasons) and (hours.is_empty() or hour in hours):
			found.append(fish)
	return found


# The fish that takes the bait: the debug panel's pick, or one of those
# biting, weighted by rarity. {} if nothing's biting.
static func pick(habitat: String) -> Dictionary:
	if not GameState.forced_fish.is_empty():
		var forced := GameData.get_fish(GameState.forced_fish)
		GameState.forced_fish = ""
		if not forced.is_empty():
			return forced
	var weights: Dictionary = GameData.fishing_settings.get("rarity_weights", {})
	var pool := biting(habitat)
	var total := 0.0
	for fish in pool:
		total += float(weights.get(fish.get("rarity", "common"), 1.0))
	var roll := randf() * total
	for fish in pool:
		roll -= float(weights.get(fish.get("rarity", "common"), 1.0))
		if roll <= 0.0:
			return fish
	return pool.back() if not pool.is_empty() else {}


# How big this one is, in whole centimeters: most are on the small side.
static func roll_size(fish: Dictionary) -> int:
	var sizes: Array = fish.get("size_cm", [10, 30])
	return roundi(lerpf(float(sizes[0]), float(sizes[1]), pow(randf(), 1.7)))


# A fish was landed by `player_index`: into the pantry and the Fish Log, said
# out loud, and saved. Returns { "new": first of its kind, "biggest": a new
# record for its kind }.
static func record_catch(fish_id: String, size_cm: int, player_index: int) -> Dictionary:
	var fish := GameData.get_fish(fish_id)
	var chef := Accounts.id_of(player_index)
	var first_ever := GameState.fish_log.is_empty()
	var is_new := not GameState.fish_log.has(fish_id)
	var entry: Dictionary = GameState.fish_log.get_or_add(fish_id, {
		"caught": 0, "biggest_cm": 0, "biggest_by": "", "first_date": GameClock.today(), "first_by": chef, "by": {} })
	entry["caught"] = int(entry["caught"]) + 1
	var is_biggest := size_cm > int(entry["biggest_cm"])
	if is_biggest:
		entry["biggest_cm"] = size_cm
		entry["biggest_by"] = chef
	if not chef.is_empty():
		entry["by"][chef] = int(entry["by"].get(chef, 0)) + 1
	Pantry.add(fish_id)
	var who := Accounts.name_of(player_index)
	var name: String = fish.get("name", fish_id)
	if is_new:
		GameEvents.announce("%s caught a %s (%d cm)! New in the Fish Log." % [who, name, size_cm])
	elif is_biggest:
		GameEvents.announce("%s caught a %s (%d cm), the biggest yet!" % [who, name, size_cm])
	else:
		GameEvents.announce("%s caught a %s (%d cm). It's in the pantry." % [who, name, size_cm])
	if first_ever:
		Pantry.unlock_found("first_fish", "made with what you catch!")
	SaveGame.save_game()
	return { "new": is_new, "biggest": is_biggest and not is_new }


# Debug: every fish in the log once (at its biggest), or none (also emptying the
# pantry of fish and taking the fish dishes back off the menu).
static func debug_fill_log(player_index := 0) -> void:
	for fish in GameData.fish:
		if not GameState.fish_log.has(fish["id"]):
			record_catch(fish["id"], int(fish.get("size_cm", [10, 30])[1]), player_index)


static func debug_clear_log() -> void:
	GameState.fish_log.clear()
	for item_id in GameState.pantry.keys():
		if not GameData.get_fish(item_id).is_empty():
			GameState.pantry.erase(item_id)
	Pantry.relock_found("first_fish")
	SaveGame.save_game()


# A simple fish, `length` meters nose to tail, nose along -z: a squashed body,
# a lighter belly, a tail fin and an eye each side.
static func make_model(fish: Dictionary, length: float) -> Node3D:
	var model := Node3D.new()
	var body_color := Color.html(fish.get("color", "#7f8fa6"))
	var belly_color := Color.html(fish.get("belly", "#e0e0d0"))
	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.5
	body_mesh.height = 1.0
	body_mesh.material = _material(body_color)
	body.mesh = body_mesh
	body.scale = Vector3(length * 0.2, length * 0.32, length * 0.8)
	model.add_child(body)
	var belly := MeshInstance3D.new()
	var belly_mesh := SphereMesh.new()
	belly_mesh.radius = 0.5
	belly_mesh.height = 1.0
	belly_mesh.material = _material(belly_color)
	belly.mesh = belly_mesh
	belly.scale = Vector3(length * 0.17, length * 0.2, length * 0.62)
	belly.position = Vector3(0.0, -length * 0.07, -length * 0.02)
	model.add_child(belly)
	var tail := MeshInstance3D.new()
	var tail_mesh := PrismMesh.new()
	tail_mesh.size = Vector3(length * 0.32, length * 0.26, length * 0.03)
	tail_mesh.material = _material(body_color.darkened(0.15))
	tail.mesh = tail_mesh
	tail.rotation = Vector3(PI / 2.0, PI / 2.0, 0.0)  # Fanned out behind, edge-on to the sides.
	tail.position = Vector3(0.0, 0.0, length * 0.48)
	model.add_child(tail)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = length * 0.035
		eye_mesh.height = length * 0.07
		eye_mesh.material = _material(Color(0.08, 0.08, 0.1))
		eye.mesh = eye_mesh
		eye.position = Vector3(side * length * 0.09, length * 0.05, -length * 0.28)
		model.add_child(eye)
	return model


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.35
	return material
