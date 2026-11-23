# Makes the playtest restaurants: slot 2 empty (a brand-new restaurant, the
# real first day), slot 3 opening on day 5 and slot 4 opening on day 7, as a
# group of 4 would have them. Each is played forward a day at a time: a day's
# takings (EARNINGS, an estimate for 4 players on Normal) and then the
# end-of-day shop, buying from WISHLIST whatever's in stock that day and
# affordable, the way a group would. Regulars get the friendship of a few visits
# each and the phone is up (a customer asks about delivery in the first days).
# Saved with no date, so opening one starts its day fresh.
# Run with a throwaway APPDATA, then copy save_3.json and save_4.json over.
extends Node

const EARNINGS := 190            # A day's takings for 4 players (estimate; tune after the playtest).
const SERVICE := 0.78            # Average satisfaction a day.
const RESERVE := 120            # Money they keep back (so the shop still has a choice in it).
const WISHLIST := [              # What a group buys first, in order.
	"third_stove", "sharp_knife", "ticket_rail", "cherry_pie", "third_board", "food_tray",
	"soft_pretzel", "pupsi", "comfy_cushions", "croissant", "dr_salt", "banana_milk",
	"steady_stove", "pork_dumplings", "apple_cider", "second_oven", "hotteok", "fawnta",
	"big_drink_tray", "bubble_tea", "root_bear", "omurice", "mr_dibs", "gander_ale",
]


func _ready() -> void:
	for target in [5, 7]:
		_make(target, 3 if target == 5 else 4)
	get_tree().quit()


func _make(target_day: int, slot: int) -> void:
	GameState.apply_save_data({})
	GameState.reset_regulars()
	GameState.money = 0
	GameState.upgrades.clear()
	GameState.unlocks.clear()
	GameState.service_history.clear()
	GameState.restaurant_name = "Playtest Day %d" % target_day
	GameState.difficulty = "normal"
	for day in range(1, target_day):
		GameState.day_number = day
		GameState.money += EARNINGS + (day - 1) * 15  # A little more each day as the menu grows.
		GameState.service_history.append(SERVICE)
		GameState.money -= RESERVE  # Spend only above the reserve.
		for id in WISHLIST:
			_buy(id)
		GameState.money += RESERVE
	GameState.day_number = target_day - 1
	GameState.date = ""
	GameState.phase_done.clear()
	GameState.delivery_asked = true
	GameState.phone_unlocked = true
	for id in GameState.regulars:
		RegularMemory.set_relationship(GameState.regulars[id], (target_day - 1) * 2 + randi_range(-2, 2))
	var data := GameState.to_save_data()
	data.erase("guided")  # An old hand's restaurant: the Guide won't walk anyone through the basics.
	data["date"] = ""
	SafeFile.write_json(SaveGame.path(slot), data)
	print("PLAYTEST slot %d: opens on day %d with $%d; upgrades %s; menu %s" % [slot, target_day, GameState.money, GameState.upgrades, GameState.unlocks])


func _buy(id: String) -> void:
	if GameState.has_upgrade(id) or id in GameState.unlocks:
		return
	if GameData.dishes.any(func(d): return d["id"] == id):
		GameState.buy_dish(id)
	elif GameData.drinks.any(func(d): return d["id"] == id):
		GameState.buy_drink(id)
	else:
		GameState.buy_upgrade(id)
