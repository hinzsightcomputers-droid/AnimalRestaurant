# ReelScenario: reads a recording's script from res://reels/<name>.json and
# checks it against the game's data, so a typo is a clear message before anything
# plays, not a broken video. The format is described in reels/README.md.
class_name ReelScenario
extends RefCounted

const DIR := "res://reels/"
const MAIN_SCENE := "res://scenes/main.tscn"
const BEATS := ["walk_in", "line", "choices", "reaction", "serve", "wait", "end"]


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
	var chose := false
	for i in beats.size():
		var beat: Dictionary = beats[i]
		var where := "beat %d (%s)" % [i + 1, beat.get("do", "?")]
		match beat.get("do", ""):
			"walk_in":
				var table: String = beat.get("table", "")
				if not table in spots:
					found.append("%s: table \"%s\" isn't one of: %s" % [where, table, ", ".join(spots)])
				elif table in taken:
					found.append("%s: an extra is already at the %s table" % [where, table])
			"line":
				line = find_line(regular_id, beat.get("line", ""))
				if line.is_empty():
					found.append("%s: %s has no line \"%s\"" % [where, regular_id, beat.get("line", "")])
			"choices":
				_check_choices(beat, line, where, found)
				chose = true
			"reaction":
				if not chose:
					found.append("%s: needs a choices beat before it" % where)
			"serve":
				if GameData.get_dish(beat.get("dish", "")).is_empty():
					found.append("%s: dish \"%s\" doesn't exist" % [where, beat.get("dish", "")])
			"wait":
				if float(beat.get("seconds", 0.0)) <= 0.0:
					found.append("%s: needs seconds" % where)
			"end":
				pass
			_:
				found.append("%s: isn't one of: %s" % [where, ", ".join(BEATS)])


static func _check_choices(beat: Dictionary, line: Dictionary, where: String, found: Array[String]) -> void:
	var tones: Array = line.get("choices", []).map(func(c): return c.get("tone", ""))
	if tones.is_empty():
		found.append("%s: the line before it has no choices" % where)
		return
	var wanted: Array = beat.get("highlight", []).map(func(h): return h.get("tone", ""))
	wanted.append(beat.get("pick", ""))
	for tone in wanted:
		if not tone in tones:
			found.append("%s: no \"%s\" choice (it has: %s)" % [where, tone, ", ".join(tones)])
