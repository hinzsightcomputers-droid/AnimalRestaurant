# ReelPlayer: plays a reel scenario (see ReelScenario) in the sandbox (see
# ReelSandbox): sets the state up, opens the restaurant and hands it to the
# ReelDirector. Pick one with -- --scenario=<name>; add --check to only check the
# file and print what it would set up. Refuses to run outside the sandbox, and
# checks at the end that the real game files didn't change.
class_name ReelPlayer
extends Node

signal director_ready(director: ReelDirector)

const CHECK_ARG := "--check"

var quit_when_done := true

var _before := {}


func _ready() -> void:
	if not ReelSandbox.active():
		push_error("A reel has to be started on its own (see reels/README.md), not from inside the game.")
		get_tree().quit(1)
		return
	_before = ReelSandbox.fingerprint()
	var scenario_name := ReelSandbox.scenario_name()
	var scenario := ReelScenario.read(scenario_name)
	if scenario.is_empty():
		get_tree().quit(1)
		return
	var problems := ReelScenario.problems(scenario)
	if not problems.is_empty():
		print("Reel \"%s\" has %d problem(s):" % [scenario_name, problems.size()])
		for problem in problems:
			print("  - ", problem)
		get_tree().quit(1)
		return
	ReelSandbox.set_up(scenario)
	_print_summary(scenario_name, scenario)
	if CHECK_ARG in OS.get_cmdline_user_args():
		_finish(true)
		return
	seed(scenario_name.hash())  # The same reel every time.
	await get_tree().process_frame
	var main: Node = load(ReelScenario.MAIN_SCENE).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var director := ReelDirector.new()
	director.scenario = scenario
	director.main = main
	add_child(director)
	director.finished.connect(_finish)
	director_ready.emit(director)
	director.play()


func _finish(ok: bool) -> void:
	print("Your save and accounts: ", "untouched" if ReelSandbox.fingerprint() == _before else "CHANGED, this is a bug")
	if quit_when_done:
		get_tree().quit(0 if ok else 1)


func _print_summary(scenario_name: String, scenario: Dictionary) -> void:
	var record: Dictionary = GameState.regulars[scenario["regular"]["id"]]
	print("Reel \"%s\": %s" % [scenario_name, scenario.get("title", "")])
	print("  Meal: %s, chef: %s" % [scenario["meal"], Accounts.name_of(0)])
	print("  %s: relationship %d, stage %d (%s), visited %d times" % [record["name"], record["relationship"], RegularMemory.stage_of(record), RegularMemory.stage_name(record), record["times_visited"]])
	print("  Extras: ", ", ".join(scenario.get("extras", []).map(func(e): return "%s at the %s table" % [e["species"], e["table"]])))
	print("  Beats: ", ", ".join(scenario["beats"].map(func(b): return b["do"])))
