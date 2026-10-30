# ServiceStreak: the restaurant's run of good serves (a dish cooked well enough,
# brought quickly enough), shared by everyone in the kitchen. Each serve in the
# run after the first adds to that customer's tip; a poor or slow serve ends
# it. Starts again each day. Settings in data/reactions.json "streak".
class_name ServiceStreak
extends RefCounted

static var count := 0  # Good serves in a row so far.


static func settings() -> Dictionary:
	return GameData.reactions.get("streak", {})


# Whether this serve keeps the run going.
static func is_good(quality: float, wait_seconds: float) -> bool:
	return quality >= float(settings().get("min_quality", 0.7)) \
			and wait_seconds <= float(settings().get("max_wait_seconds", 75.0)) + GameState.upgrade_bonus("patient_seconds")


# A dish just reached its table: the run grows or ends. Returns the new count (0 = ended).
static func record(quality: float, wait_seconds: float) -> int:
	count = count + 1 if is_good(quality, wait_seconds) else 0
	return count


# The extra tip (percent of the bill) for the serve that made a run this long.
static func tip_percent(run: int) -> float:
	if run < 2:
		return 0.0
	return minf(float(settings().get("tip_percent_per_step", 5)) * (run - 1), float(settings().get("max_tip_percent", 25)))


static func reset() -> void:
	count = 0
