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
	return quality >= float(settings().get("min_quality", 0.7)) and wait_seconds <= max_wait()


# The longest a dish can take (from ordering) and still keep the run going.
static func max_wait() -> float:
	return (float(settings().get("max_wait_seconds", 75.0)) + GameState.upgrade_bonus("patient_seconds")) * GameState.difficulty_value("patience")


# How long a customer waiting for food has left before a serve can't keep the run going.
static func seconds_left(customer: Customer) -> float:
	return maxf(max_wait() - customer.wait_seconds, 0.0)


# Served in the last few seconds before max_wait: a save, worth a bit extra
# (just_in_time_tip_percent on their bill).
static func in_the_nick_of_time(wait_seconds: float) -> bool:
	return wait_seconds <= max_wait() and wait_seconds > max_wait() - float(settings().get("just_in_time_seconds", 12.0))


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
