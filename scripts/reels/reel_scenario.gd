# ReelScenario: reads a recording's script from res://reels/<name>.json and
# checks it against the game's data, so a typo is a clear message before anything
# plays, not a broken video. The format is described in reels/README.md.
class_name ReelScenario
extends RefCounted

const DIR := "res://reels/"
const MAIN_SCENE := "res://scenes/main.tscn"
const BEATS := ["walk_in", "line", "choices", "reaction", "serve", "drive", "beach", "walk", "fish", "visit", "wait", "end"]


# Every scenario's name (its file name without .json), sorted.
static func names() -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(DIR):
		if file.ends_with(".json"):
			found.append(file.get_basename())
	found.sort()
	return found


# The scenario, or {} if the file is missing or isn't valid JSON (says why).
static func read(scenario_name: String) -> Dictionary:
	var path := DIR + scenario_name + ".json"
	if not FileAccess.file_exists(path):
		push_error("No reel scenario at %s (there's: %s)" % [path, ", ".join(names())])
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("%s isn't valid JSON" % path)
		return {}
	return parsed


static func meal_index(meal_id: String) -> int:
	var phases: Array = GameData.day_settings.get("phases", [])
	for i in phases.size():
		if phases[i].get("id", "") == meal_id:
			return i
	return -1


# The regular's line with this id, or {}.
static func find_line(regular_id: String, line_id: String) -> Dictionary:
	for line in GameData.characters.get(regular_id, {}).get("lines", []):
		if line.get("id", "") == line_id:
			return line
	return {}


# The reply a beat means, or {}: by its tone, or by how its text starts (not every
# reply has a tone). It's the line's own dictionary, not a copy.
static func choice_of(line: Dictionary, wanted: String) -> Dictionary:
	for choice in line.get("choices", []):
		if choice.get("tone", "") == wanted or (not wanted.is_empty() and String(choice.get("text", "")).begins_with(wanted)):
			return choice
	return {}


# The table spots in the restaurant ("corner", "window"...).
static func table_spots() -> Array[String]:
	var spots: Array[String] = []
	var state: SceneState = load(MAIN_SCENE).get_state()
	for node in state.get_node_count():
		for property in state.get_node_property_count(node):
			if state.get_node_property_name(node, property) == &"spot":
				spots.append(String(state.get_node_property_value(node, property)))
	return spots


# Everything wrong with this scenario, in words. Empty = good to play.
static func problems(scenario: Dictionary) -> Array[String]:
	var found: Array[String] = []
	if meal_index(scenario.get("meal", "")) < 0:
		found.append("meal \"%s\" isn't in data/day.json" % scenario.get("meal", ""))
	var lighting: String = scenario.get("lighting", scenario.get("meal", ""))
	if meal_index(lighting) < 0:
		found.append("lighting \"%s\" isn't a meal in data/day.json" % lighting)
	if scenario.has("hour") and not scenario["hour"] in GameData.trips.get("drive", {}).get("sky", {}):
		found.append("hour \"%s\" isn't an hour block in data/time.json" % scenario["hour"])
	var regular: Dictionary = scenario.get("regular", {})
	_check_regular(regular, found)
	var spots := table_spots()
	var taken: Array[String] = []
	for extra in scenario.get("extras", []):
		_check_extra(extra, spots, taken, found)
	_check_beats(scenario.get("beats", []), String(regular.get("id", "")), spots, taken, found)
	return found


static func _check_regular(regular: Dictionary, found: Array[String]) -> void:
	var id: String = regular.get("id", "")
	if not GameState.regulars.has(id):
		found.append("regular \"%s\" has no file in data/characters/" % id)
		return
	if not regular.has("relationship"):
		found.append("regular needs a relationship")
	elif regular.has("stage"):
		var stage := RegularMemory.stage_of({ "relationship": int(regular["relationship"]) })
		if stage != int(regular["stage"]):
			found.append("relationship %d is stage %d, not stage %d" % [regular["relationship"], stage, regular["stage"]])
	var fields := GameData.memory_fields(id)
	for field in regular.get("memory", {}):
		if not field in fields:
			found.append("\"%s\" isn't a memory field of %s" % [field, id])


static func _check_extra(extra: Dictionary, spots: Array[String], taken: Array[String], found: Array[String]) -> void:
	var table: String = extra.get("table", "")
	if not table in spots:
		found.append("extra's table \"%s\" isn't one of: %s" % [table, ", ".join(spots)])
	elif table in taken:
		found.append("two extras at the %s table" % table)
	taken.append(table)
	var species: String = extra.get("species", "")
	if not GameData.species.any(func(s): return s["id"] == species):
		found.append("extra's species \"%s\" isn't in data/species.json" % species)
	if GameData.get_dish(extra.get("dish", "")).is_empty():
		found.append("extra's dish \"%s\" doesn't exist" % extra.get("dish", ""))


static func _check_beats(beats: Array, regular_id: String, spots: Array[String], taken: Array[String], found: Array[String]) -> void:
	if beats.is_empty() or beats.back().get("do", "") != "end":
		found.append("the last beat has to be \"end\"")
	var line := {}  # The line last said, for the choices after it.
	var walked_in := false
	var at_beach := false
	for i in beats.size():
		var beat: Dictionary = beats[i]
		var where := "beat %d (%s)" % [i + 1, beat.get("do", "?")]
		var next: String = beats[i + 1].get("do", "") if i + 1 < beats.size() else ""
		var last: String = beats[i - 1].get("do", "") if i > 0 else ""
		if beat.get("do", "") in ["line", "serve"] and not walked_in:
			found.append("%s: needs a walk_in beat before it" % where)
		if beat.get("do", "") in ["walk", "fish"] and not at_beach:
			found.append("%s: needs a drive or beach beat before it" % where)
		match beat.get("do", ""):
			"walk_in":
				var table: String = beat.get("table", "")
				if not table in spots:
					found.append("%s: table \"%s\" isn't one of: %s" % [where, table, ", ".join(spots)])
				elif table in taken:
					found.append("%s: an extra is already at the %s table" % [where, table])
				walked_in = true
			"line":
				line = find_line(regular_id, beat.get("line", ""))
				if line.is_empty():
					found.append("%s: %s has no line \"%s\"" % [where, regular_id, beat.get("line", "")])
				elif line.has("choices") and next != "choices":
					found.append("%s: this line has replies, so a choices beat has to come next" % where)
			"choices":
				_check_choices(beat, line, where, found)
				if next != "reaction":
					found.append("%s: a reaction beat has to come next" % where)
				line = choice_of(line, beat.get("pick", "")).get("then", {})  # The follow-up, if this reply leads to one.
			"reaction":
				if last != "choices":
					found.append("%s: has to come straight after a choices beat" % where)
				elif not line.is_empty() and next != "choices":
					found.append("%s: that reply leads to a follow-up question, so a choices beat has to come next" % where)
			"serve":
				if GameData.get_dish(beat.get("dish", "")).is_empty():
					found.append("%s: dish \"%s\" doesn't exist" % [where, beat.get("dish", "")])
			"drive":
				var car: Dictionary = GameData.trips.get("car", {})
				if regular_id != car.get("regular", ""):
					found.append("%s: only %s drives, so he has to be the regular" % [where, car.get("regular", "")])
				for line_id in beat.get("lines", []):
					if find_line(regular_id, line_id).is_empty():
						found.append("%s: %s has no line \"%s\"" % [where, regular_id, line_id])
				at_beach = true
			"beach":
				at_beach = true
			"walk":
				var to: Array = beat.get("to", [])
				if to.is_empty() or not to.all(func(point): return point is Array and point.size() == 2):
					found.append("%s: \"to\" has to be a list of [x, z] points on the beach" % where)
			"fish":
				var fish := GameData.get_fish(beat.get("fish", ""))
				if fish.get("habitat", "") != "beach":
					found.append("%s: \"%s\" isn't a fish from the beach" % [where, beat.get("fish", "")])
			"visit":
				for key in ["hello", "inside", "bye"]:
					if beat.has(key) and find_line(regular_id, beat[key]).is_empty():
						found.append("%s: %s has no line \"%s\"" % [where, regular_id, beat[key]])
				for line_id in beat.get("chat", []):
					if find_line(regular_id, line_id).is_empty():
						found.append("%s: %s has no line \"%s\"" % [where, regular_id, line_id])
				if not GameData.houses.get("houses", []).any(func(house): return house.get("regular", "") == regular_id):
					found.append("%s: %s has no house in data/houses.json" % [where, regular_id])
			"wait":
				if float(beat.get("seconds", 0.0)) <= 0.0:
					found.append("%s: needs seconds" % where)
			"end":
				pass
			_:
				found.append("%s: isn't one of: %s" % [where, ", ".join(BEATS)])


static func _check_choices(beat: Dictionary, line: Dictionary, where: String, found: Array[String]) -> void:
	var choices: Array = line.get("choices", [])
	if choices.is_empty():
		found.append("%s: the line before it has no choices" % where)
		return
	var wanted: Array = beat.get("highlight", []).map(func(h): return h.get("tone", ""))
	wanted.append(beat.get("pick", ""))
	for reply in wanted:
		if choice_of(line, reply).is_empty():
			var has: Array = choices.map(func(c): return c.get("tone", c.get("text", "")))
			found.append("%s: no \"%s\" choice (it has: %s)" % [where, reply, ", ".join(has)])
