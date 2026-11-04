# Rating: the restaurant's stars, 1 to 5 (data/rating.json). Stars only go up.
# Each one needs four areas: service, menu, community and decor. When they're
# all met the critic joins that day's plan (see DayPlan), and serving them well
# earns the star, given out at closing (ScenePlayer). Serving them badly costs
# nothing: they come back a few days later. What's saved is in GameState: stars,
# service_history, critic_last_day, star_earned and star_awarded_on. Pure logic.
class_name Rating
extends RefCounted

const MAX_STARS := 5
const AREAS := ["service", "menu", "community", "decor"]


static func settings() -> Dictionary:
	return GameData.rating


static func critic_settings() -> Dictionary:
	return settings().get("critic", {})


# What the next star needs, or {} at five stars.
static func next_star() -> Dictionary:
	for entry in settings().get("stars", []):
		if int(entry["star"]) == GameState.stars + 1:
			return entry
	return {}


# Where an area stands now.
static func value(area: String) -> float:
	match area:
		"service":
			return average_service()
		"menu":
			return float(menu_size())
		"community":
			return float(community())
	return 0.0  # Decor: nothing to place yet.


# Average satisfaction over the last service_days days open, 0 with none yet.
static func average_service() -> float:
	var days: Array = GameState.service_history.slice(-int(settings().get("service_days", 7)))
	if days.is_empty():
		return 0.0
	var total := 0.0
	for day in days:
		total += float(day)
	return total / days.size()


# How many dishes and drinks are unlocked (whether or not the pantry can make them today).
static func menu_size() -> int:
	return (GameData.dishes + GameData.drinks).filter(func(item): return GameData.is_unlocked(item["id"])).size()


# Friendship with every regular (a falling-out doesn't take away from the
# rest), plus guest_points for each different townsfolk served.
static func community() -> int:
	var total := 0
	for record in GameState.regulars.values():
		total += maxi(0, int(record["relationship"]))
	var guests := GameState.townsfolk.values().filter(func(state): return int(state.get("visits", 0)) > 0).size()
	return total + guests * int(settings().get("guest_points", 2))


# The areas the next star asks for (a 0 means it doesn't).
static func needed_areas() -> Array:
	var star := next_star()
	return AREAS.filter(func(area): return float(star.get(area, 0)) > 0.0)


# How far an area is toward the next star: 1.0 or more when it's met.
static func progress(area: String) -> float:
	var target := float(next_star().get(area, 0))
	return value(area) / target if target > 0.0 else 1.0


static func ready_for_critic() -> bool:
	return GameState.stars < MAX_STARS and not next_star().is_empty() and not GameState.star_earned \
		and needed_areas().all(func(area): return progress(area) >= 1.0)


# Whether the critic comes today: ready, and not back too soon after their last visit.
static func critic_due() -> bool:
	if not ready_for_critic():
		return false
	if GameState.critic_last_day <= 0:
		return true
	return GameState.day_number - GameState.critic_last_day >= int(critic_settings().get("retry_days", 2))


# The area furthest from the next star ("" when none is short), for regulars to
# comment on: the "rating_needs" condition on a dialogue line.
static func holding_back() -> String:
	var worst := ""
	var lowest := 1.0
	for area in needed_areas():
		if progress(area) < lowest:
			lowest = progress(area)
			worst = area
	return worst


# The named townsfolk playing the critic, or {} for the unnamed one.
static func critic_person() -> Dictionary:
	var id := String(critic_settings().get("townsfolk", ""))
	return {} if id.is_empty() else GameData.get_townsfolk(id)


# The critic paid up. Happy or better earns the star at closing. Returns the news to announce.
static func critic_left(satisfaction: float) -> String:
	var passed := satisfaction >= float(critic_settings().get("pass_satisfaction", 0.6))
	if passed:
		GameState.star_earned = true
		SaveGame.save_game()
	return String(critic_settings().get("passed" if passed else "not_yet", ""))


# The star goes up (at closing). Returns the news.
static func award() -> String:
	GameState.star_earned = false
	GameState.stars = mini(GameState.stars + 1, MAX_STARS)
	GameState.star_awarded_on = GameState.date
	SaveGame.save_game()
	return fill(String(settings().get("awarded", "")))


# {restaurant} and {stars} filled in.
static func fill(text: String) -> String:
	return text.format({ "restaurant": GameState.restaurant_name, "stars": GameState.stars })


# The Rating page: the stars, then each area against the next star.
static func page_text() -> String:
	var lines := PackedStringArray()
	lines.append("%s: %d of %d stars" % [GameState.restaurant_name, GameState.stars, MAX_STARS])
	lines.append("")
	if next_star().is_empty():
		lines.append(String(settings().get("top_hint", "")))
		return "\n".join(lines)
	lines.append("For star number %d:" % (GameState.stars + 1))
	for area in needed_areas():
		lines.append("  %s %s" % ["[done]" if progress(area) >= 1.0 else "[    ]", _area_text(area)])
	if ready_for_critic():
		lines.append("")
		lines.append(String(settings().get("ready_hint", "")))
	return "\n".join(lines)


static func _area_text(area: String) -> String:
	var target = next_star().get(area, 0)
	if area == "service":
		return "Service: %d%% over the last %d days (needs %d%%)" % [roundi(average_service() * 100.0), int(settings().get("service_days", 7)), roundi(float(target) * 100.0)]
	return "%s: %d of %d" % [area.capitalize(), roundi(value(area)), int(target)]
