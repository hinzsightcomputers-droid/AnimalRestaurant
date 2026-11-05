# ReelPlayer: plays a reel scenario (see ReelScenario) in the sandbox (see
# ReelSandbox): sets the state up, opens the restaurant and hands it to the
# ReelDirector. Pick one with -- --scenario=<name>; add --check to only check the
# file and print what it would set up. Refuses to run outside the sandbox, and
# checks at the end that the real game files didn't change.
class_name ReelPlayer
extends Node

signal director_ready(director: ReelDirector)

const SCENE := "res://reels/reel_player.tscn"
const CHECK_ARG := "--check"
const PREVIEW_WINDOW := Vector2i(450, 800)  # 9:16, small enough to fit on a screen.
const VIDEO_SIZE := Vector2i(1080, 1920)    # What the reel renders at, whatever size the window is.

# Which scenario to play when run from the editor (F6), where there's no command
# line. Empty = the first in res://reels/.
@export var preview_scenario := ""

var quit_when_done := true

var _before := {}


# Plays a scenario in a window of its own, a whole separate launch of the game, so
# the running game and its save have nothing to do with it. Returns its process
# id, or -1 if it couldn't start.
static func preview(scenario_name: String) -> int:
	var args := ["--path", ProjectSettings.globalize_path("res://"), SCENE, "--", ReelSandbox.SCENARIO_ARG + scenario_name]
	return OS.create_process(OS.get_executable_path(), args)


func _ready() -> void:
	if not ReelSandbox.active():
		push_error("A reel has to be started on its own (see reels/README.md), not from inside the game.")
		get_tree().quit(1)
		return
	_before = ReelSandbox.fingerprint()
	var scenario_name := ReelSandbox.scenario_name(preview_scenario)
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
	# Windows won't make a window taller than the screen, so the picture is its own size.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	get_window().content_scale_size = VIDEO_SIZE
	if not OS.has_feature("movie"):
		DisplayServer.window_set_size(PREVIEW_WINDOW)
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
