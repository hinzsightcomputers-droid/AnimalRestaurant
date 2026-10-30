# Forage: what's growing where today, and what picking it does. Each spot in
# data/forage.json (spots) gets something each restaurant day, or nothing
# (spawn_chance): rolled from the date, the spot and the debug panel's salt,
# so it's the same all day and after a restart. It's picked from the items
# that grow where the spot is (oak, pine, meadow, pond) this season, weighted
# by rarity. Once picked a spot stays empty until 5 AM (GameState.forage_today).
# A find goes to the Forage Log, and into the Pantry if it's food; never into
# money. The first of each item puts dishes "unlocked_by": "first_<id>" on
# the menu (the first acorn: Acorn Cookies). Pure logic, plus a model for an item.
class_name Forage
extends RefCounted


# The restaurant day foraging is on (5 AM to 5 AM).
static func today() -> String:
	return GameClock.today()


static func spots() -> Array:
	return GameData.forage_settings.get("spots", [])


# The item at a spot today ({} if nothing grows there today, it's been picked,
# or it isn't its hour).
static func item_at(spot_index: int) -> Dictionary:
	if is_picked(spot_index):
		return {}
	var item := rolled_at(spot_index)
	var hours: Array = item.get("hours", [])
	if not hours.is_empty() and not Fishing.hour_block() in hours:
		return {}
	return item


# What today's roll put at a spot, picked or not, whatever the hour ({} = nothing).
static func rolled_at(spot_index: int) -> Dictionary:
	var spot_list := spots()
	if spot_index < 0 or spot_index >= spot_list.size():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/%s/%d/%d" % [today(), GameClock.season(), spot_index, _today_state().get("salt", 0)])
	if rng.randf() >= float(GameData.forage_settings.get("spawn_chance", 0.65)):
		return {}
	var weights: Dictionary = GameData.forage_settings.get("rarity_weights", {})
	var pool := growing(String(spot_list[spot_index].get("where", "")))
	var total := 0.0
	for item in pool:
		total += float(weights.get(item.get("rarity", "common"), 1.0))
	var roll := rng.randf() * total
	for item in pool:
		roll -= float(weights.get(item.get("rarity", "common"), 1.0))
		if roll <= 0.0:
			return item
	return pool.back() if not pool.is_empty() else {}


# The items that grow at `where` this season (hours aside).
static func growing(where: String) -> Array[Dictionary]:
	var season := GameClock.season()
	var found: Array[Dictionary] = []
	for item in GameData.forage:
		var seasons: Array = item.get("seasons", [])
		if where in item.get("where", []) and (seasons.is_empty() or season in seasons):
			found.append(item)
	return found


static func is_picked(spot_index: int) -> bool:
	return spot_index in _today_state().get("picked", [])


# `player_index` picked what's at a spot: into the Forage Log (and the pantry
# if it's food), said out loud, and saved. Returns the item ({} if there was nothing).
static func pick(spot_index: int, player_index: int) -> Dictionary:
	var item := item_at(spot_index)
	if item.is_empty():
		return {}
	_today_state()["picked"].append(spot_index)
	record_find(item["id"], player_index)
	return item


# One more of an item found by `player_index`. Returns whether it's new to the log.
static func record_find(item_id: String, player_index: int) -> bool:
	var item := GameData.get_forage(item_id)
	var chef := Accounts.id_of(player_index)
	var is_new := not GameState.forage_log.has(item_id)
	var entry: Dictionary = GameState.forage_log.get_or_add(item_id, {
		"found": 0, "first_date": today(), "first_by": chef, "by": {} })
	entry["found"] = int(entry["found"]) + 1
	if not chef.is_empty():
		entry["by"][chef] = int(entry["by"].get(chef, 0)) + 1
	var food := bool(item.get("pantry", true))
	if food:
		Pantry.add(item_id)
	var who := Accounts.name_of(player_index)
	if is_new:
		GameEvents.announce("%s found %s! New in the Forage Log." % [who, a_name(item)])
	else:
		GameEvents.announce("%s found %s.%s" % [who, a_name(item), " It's in the pantry." if food else ""])
	if is_new:
		Pantry.unlock_found("first_" + item_id, "made with what you gather!")
	SaveGame.save_game()
	return is_new


# "an Acorn", "a Chestnut", "some Pine Needles".
static func a_name(item: Dictionary) -> String:
	var name: String = item.get("name", "something")
	if name.ends_with("s"):
		return "some " + name
	return ("an " if name.left(1).to_lower() in ["a", "e", "i", "o", "u"] else "a ") + name


# Today's picks, started fresh on a new day.
static func _today_state() -> Dictionary:
	if GameState.forage_today.get("date", "") != today():
		GameState.forage_today = { "date": today(), "picked": [], "salt": 0 }
	return GameState.forage_today


# Debug: everything grows back, rolled again (different from before).
static func debug_respawn() -> void:
	var state := _today_state()
	state["picked"] = []
	state["salt"] = int(state.get("salt", 0)) + 1
	SaveGame.save_game()


# Debug: every item in the log once, or none (also emptying the pantry of
# forage and taking the forage dishes back off the menu).
static func debug_fill_log(player_index := 0) -> void:
	for item in GameData.forage:
		if not GameState.forage_log.has(item["id"]):
			record_find(item["id"], player_index)


static func debug_clear_log() -> void:
	GameState.forage_log.clear()
	for item in GameData.forage:
		GameState.pantry.erase(item["id"])
		Pantry.relock_found("first_" + item["id"])
	SaveGame.save_game()


# A little model of an item, about `size` meters across, sitting on y = 0.
static func make_model(item: Dictionary, size: float) -> Node3D:
	var model := Node3D.new()
	var color := Color.html(item.get("color", "#a07040"))
	var accent := Color.html(item.get("accent", "#5a7a3a"))
	var s := size
	match item.get("shape", ""):
		"acorn":
			_ball(model, color, Vector3(0.0, s * 0.38, 0.0), Vector3(s * 0.62, s * 0.8, s * 0.62))
			_ball(model, accent, Vector3(0.0, s * 0.72, 0.0), Vector3(s * 0.7, s * 0.34, s * 0.7))
			_stick(model, accent, Vector3(0.0, s * 0.9, 0.0), s * 0.04, s * 0.14)
		"nut":
			_ball(model, color, Vector3(0.0, s * 0.32, 0.0), Vector3(s * 0.8, s * 0.64, s * 0.62))
			_ball(model, accent, Vector3(0.0, s * 0.12, 0.0), Vector3(s * 0.5, s * 0.22, s * 0.42))
		"mushroom":
			for i in 3:
				var at := Vector3(s * 0.22 * (i - 1), 0.0, s * 0.12 * (i % 2))
				var tall := s * (0.5 if i == 1 else 0.36)
				_stick(model, accent, at + Vector3(0.0, tall / 2.0, 0.0), s * 0.07, tall)
				_ball(model, color, at + Vector3(0.0, tall, 0.0), Vector3(s * 0.4, s * 0.2, s * 0.4) * (1.0 if i == 1 else 0.75))
		"cone":
			for i in 5:
				var width := s * (0.55 - absf(i - 1.5) * 0.12)
				_ball(model, color if i % 2 == 0 else accent, Vector3(0.0, s * (0.15 + i * 0.16), 0.0), Vector3(width, s * 0.22, width))
		"sprig":
			for i in 3:
				var leaf := _ball(model, color, Vector3(0.0, s * 0.18, 0.0), Vector3(s * 0.22, s * 0.06, s * 0.7))
				leaf.rotation.y = i * TAU / 3.0
				leaf.position = Vector3(sin(leaf.rotation.y), 0.0, cos(leaf.rotation.y)) * s * 0.22 + Vector3(0.0, s * 0.18, 0.0)
			for i in 3:
				_ball(model, accent, Vector3(s * 0.07 * (i - 1), s * 0.3, s * 0.05 * (i % 2)), Vector3.ONE * s * 0.14)
		"flower":
			_stick(model, accent, Vector3(0.0, s * 0.3, 0.0), s * 0.03, s * 0.6)
			for i in 6:
				var angle := i * TAU / 6.0
				_ball(model, color, Vector3(sin(angle) * s * 0.14, s * 0.62, cos(angle) * s * 0.14), Vector3(s * 0.18, s * 0.08, s * 0.18))
			_ball(model, color.darkened(0.25) if color.v > 0.9 else color.lightened(0.3), Vector3(0.0, s * 0.64, 0.0), Vector3.ONE * s * 0.12)
			for side in [-1.0, 1.0]:
				_ball(model, accent, Vector3(side * s * 0.1, s * 0.15, 0.0), Vector3(s * 0.2, s * 0.05, s * 0.08))
		"bulb":
			_ball(model, color, Vector3(0.0, s * 0.2, 0.0), Vector3(s * 0.45, s * 0.4, s * 0.45))
			for i in 3:
				var blade := _stick(model, accent, Vector3(s * 0.05 * (i - 1), s * 0.6, 0.0), s * 0.035, s * 0.6)
				blade.rotation.z = (i - 1) * 0.3
		"berry":
			for i in 5:
				var angle := i * TAU / 5.0
				_ball(model, color, Vector3(sin(angle) * s * 0.17, s * 0.16 + (i % 2) * s * 0.12, cos(angle) * s * 0.17), Vector3.ONE * s * 0.28)
			for i in 2:
				var leaf := _ball(model, accent, Vector3(s * 0.2 * (i * 2 - 1), s * 0.05, -s * 0.15), Vector3(s * 0.3, s * 0.04, s * 0.18))
				leaf.rotation.y = 0.5 * (i * 2 - 1)
		"clover":
			_stick(model, accent, Vector3(0.0, s * 0.2, 0.0), s * 0.025, s * 0.4)
			for i in 4:
				var angle := i * TAU / 4.0 + PI / 4.0
				_ball(model, color, Vector3(sin(angle) * s * 0.13, s * 0.42, cos(angle) * s * 0.13), Vector3(s * 0.26, s * 0.05, s * 0.26))
		_:  # "leaf": a little bunch of leaves.
			for i in 5:
				var leaf := _ball(model, color if i % 2 == 0 else accent, Vector3.ZERO, Vector3(s * 0.18, s * 0.05, s * 0.5))
				leaf.rotation = Vector3(-0.6, i * TAU / 5.0, 0.0)
				leaf.position = Vector3(sin(leaf.rotation.y), 0.0, cos(leaf.rotation.y)) * s * 0.15 + Vector3(0.0, s * 0.15, 0.0)
	if item.get("id", "") == "moonflower":  # It glows a little.
		for node in model.get_children():
			var material: StandardMaterial3D = node.mesh.material
			material.emission_enabled = true
			material.emission = material.albedo_color
			material.emission_energy_multiplier = 0.35
	return model


static func _ball(parent: Node3D, color: Color, at: Vector3, size: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = _material(color)
	node.mesh = mesh
	node.scale = size
	node.position = at
	parent.add_child(node)
	return node


static func _stick(parent: Node3D, color: Color, at: Vector3, radius: float, height: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.material = _material(color)
	node.mesh = mesh
	node.position = at
	parent.add_child(node)
	return node


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	return material
