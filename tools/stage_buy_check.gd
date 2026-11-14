extends Node

# Buying a stage: refused without the stars or the money, then paid for,
# built overnight (the next begin_day) and announced. Headless is fine, with
# APPDATA pointing at a throwaway folder:
#   godot --headless res://tools/stage_buy_check.tscn

func _ready() -> void:
	var ok := true
	GameState.stage = 1
	GameState.stage_building = 0
	GameState.stars = 1
	GameState.money = 5000
	ok = _check("refused at 1 star: %s" % Stages.why_not(Stages.next()), not GameState.buy_stage()) and ok
	GameState.stars = 2
	GameState.money = 100
	ok = _check("refused short of the fee: %s" % Stages.why_not(Stages.next()), not GameState.buy_stage()) and ok
	GameState.money = 1000
	var fee := int(Stages.next().get("fee", 0))
	ok = _check("bought for $%d" % fee, GameState.buy_stage() and GameState.money == 1000 - fee) and ok
	ok = _check("building tonight, not yet built", GameState.stage_building == 2 and GameState.stage == 1 and Stages.grown_left() == 0.0) and ok
	ok = _check("can't book the crew twice: %s" % Stages.why_not(Stages.next()), not GameState.buy_stage()) and ok
	GameState.date = "2000-01-01"  # Yesterday, as far as begin_day knows.
	GameState.begin_day()
	ok = _check("built overnight", GameState.stage == 2 and GameState.stage_building == 0 and GameState.stage_news) and ok
	ok = _check("3 m grown, +%d customers" % Stages.arrival_bonus(), Stages.grown_left() == 3.0 and Stages.arrival_bonus() >= 1) and ok
	GameState.stars = 3
	GameState.money = 99999
	ok = _check("stage 3 isn't sold yet: %s" % Stages.why_not(Stages.next()), not GameState.buy_stage()) and ok
	var saved := GameState.to_save_data()
	ok = _check("saved", int(saved.get("stage", 0)) == 2 and saved.has("stage_building")) and ok
	print("STAGEBUY ", "ALL OK" if ok else "FAILED")
	get_tree().quit(0 if ok else 1)


func _check(what: String, passed: bool) -> bool:
	print("STAGEBUY %s %s" % ["ok  " if passed else "FAIL", what])
	return passed
