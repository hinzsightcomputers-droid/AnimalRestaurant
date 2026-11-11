extends Node

# The week bot (see README.md). One restaurant day per run, played by
# following the Guide's arrow like a new player: opening, every meal, closing,
# the summary and shop, then a while of after hours. Run through run_day.sh or
# run_week.sh, which carry the TEST save from day to day (never the real one).
# Logs and screenshots go to the folder in the WEEK_BOT_OUT environment
# variable (else user://week_bot/). Args: --day=N (the clock is set N-1 days
# ahead, like changing the console's date), --speed=2 (game speed),
# --seconds=1500 (most game seconds for the day), --after=120 (game seconds of
# after hours).
# Light on memory: at most MAX_SHOTS screenshots, at key moments only.

var OUT := ""
const MAX_SHOTS := 12
var driver := false
var t := 0.0
var shots := 0
var log_lines := PackedStringArray()
var presses := 0
var last_hint := ""
var last_box := ""
var stuck := 0.0
var last_progress := 0.0
var day := 1
var seconds := 1500.0
var after := 120.0
var main: Node
var chef: Player
var guide: Guide
var cm: CustomerManager
var day_tag := ""
var step_title := ""
var step_began := 0.0
var stuck_shot := false
var slow_noted := false


func note(text: String) -> void:
	var line := "[%6.1f] %s" % [t, text]
	print(line)
	log_lines.append(line)
	last_progress = t
	if log_lines.size() % 50 == 0:  # Saved as it goes, so a run cut short still leaves its log.
		var f := FileAccess.open(OUT + day_tag + "_log.txt", FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(log_lines))


func find_all(root: Node, test: Callable, out: Array) -> Array:
	if test.call(root):
		out.append(root)
	for child in root.get_children():
		find_all(child, test, out)
	return out


func shot(name: String) -> void:
	if shots >= MAX_SHOTS:
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "%s_%02d_%s.png" % [day_tag, shots, name.validate_filename().left(30)])
	shots += 1


func tick(s: float) -> void:
	await get_tree().create_timer(s, true, false, false).timeout  # Game time (scaled).
	t += s


func key(code: Key) -> void:
	presses += 1
	for down in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame
		await get_tree().physics_frame
		await get_tree().physics_frame


func hold_key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	await get_tree().process_frame


func _ready() -> void:
	if not driver:
		var d: Node = get_script().new()
		d.driver = true
		d.name = "Driver"
		get_tree().root.add_child.call_deferred(d)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	var speed := 2.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--day="):
			day = int(a.get_slice("=", 1))
		if a.begins_with("--speed="):
			speed = float(a.get_slice("=", 1))
		if a.begins_with("--seconds="):
			seconds = float(a.get_slice("=", 1))
		if a.begins_with("--after="):
			after = float(a.get_slice("=", 1))
	OUT = OS.get_environment("WEEK_BOT_OUT").replace("\\", "/")
	if OUT.is_empty():
		OUT = ProjectSettings.globalize_path("user://week_bot/")
	if not OUT.ends_with("/"):
		OUT += "/"
	day_tag = "d%d" % day
	DirAccess.make_dir_recursive_absolute(OUT)
	for f in DirAccess.get_files_at(OUT):
		if f.begins_with(day_tag + "_"):
			DirAccess.remove_absolute(OUT + f)
	GameClock.set_offset_days(day - 1)
	Engine.time_scale = speed
	note("DAY RUN %d  speed x%.1f  date %s (%s)" % [day, speed, GameClock.today(), GameClock.weekday_id()])
	GameEvents.message.connect(func(text): note("MSG " + text))
	get_tree().change_scene_to_file.call_deferred("res://scenes/intro/logo_splash.tscn")
	while t < 80.0 and not _in_restaurant():
		await tick(0.5)
		await intro_step()
	note("in the restaurant: game day %d  money $%d  stars %d  phase %s" % [GameState.day_number, GameState.money, GameState.stars, DayCycle.phase_name()])
	_grab_nodes()
	Settings.guide_always = true  # The "Guide arrow" setting: the arrow stays on after the tutorial.
	await shot("morning")
	note("RATING " + Rating.page_text().replace("\n", " / "))
	# The day: follow the arrow until the summary screen.
	while t < seconds and not _summary_open():
		await tick(0.3)
		if not is_instance_valid(main) or get_tree().current_scene != main:  # A new scene (opening up the new day).
			await tick(1.0)
			if _in_restaurant():
				_grab_nodes()
				note("scene reloaded: phase %s" % DayCycle.phase_name())
			continue
		await play_step()
		if t - last_progress > 90.0:
			note("STUCK? 90s with nothing happening. Step: '%s'  phase %s  %s" % [last_hint, DayCycle.phase_name(), ArrivalPacing.debug_line(cm.status()) if DayCycle.is_open() else ""])
			if not stuck_shot:
				stuck_shot = true
				await shot("stuck")
	if _summary_open():
		await do_summary()
		await after_hours()
	else:
		note("OUT OF TIME before closing (phase %s)" % DayCycle.phase_name())
		await shot("out_of_time")
	SaveGame.save_game()
	note("END OF RUN: game day %d  money $%d  stars %d  menu %d  community %d  decor %d  presses %d" % [GameState.day_number, GameState.money, GameState.stars, Rating.menu_size(), Rating.community(), Decor.score(), presses])
	var f := FileAccess.open(OUT + day_tag + "_log.txt", FileAccess.WRITE)
	f.store_string("\n".join(log_lines))
	f.close()
	Engine.time_scale = 1.0
	get_tree().quit()


func _grab_nodes() -> void:
	main = get_tree().current_scene
	guide = find_all(main, func(n): return n is Guide, []).front()
	cm = find_all(main, func(n): return n is CustomerManager, []).front()


func _in_restaurant() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.name == "Main" and not get_tree().paused and Player.find(get_tree(), 0) != null


func intro_step() -> void:
	var root := get_tree().root
	var edits := find_all(root, func(n): return n is LineEdit and n.is_visible_in_tree() and n.editable, [])
	if not edits.is_empty() and edits[0].text.is_empty():
		edits[0].text = "Sunny Spoon" if String(get_tree().current_scene.name) == "StreetIntro" else "Robin"
		edits[0].text_changed.emit(edits[0].text)
		edits[0].text_submitted.emit(edits[0].text)
		return
	for b in find_all(root, func(n): return n is Button and n.is_visible_in_tree() and not n.disabled and ("played" in n.text or n.text in ["Paint the sign", "Open the restaurant", "Done", "OK", "I'd rather not say"]), []):
		note("intro: pressed '%s'" % b.text.replace("\n", " "))
		b.pressed.emit()
		return
	if not get_tree().get_nodes_in_group(ConversationBox.GROUP).is_empty():
		var text := box_text()
		if text != last_box:
			last_box = text
			note("BOX " + text)
		await key(KEY_E)
		return
	var scene := get_tree().current_scene
	if scene != null and scene.name in ["LogoSplash", "StreetIntro"]:
		await key(KEY_ENTER)


func box_text() -> String:
	var parts := PackedStringArray()
	for box in get_tree().get_nodes_in_group(ConversationBox.GROUP):
		for n in find_all(box, func(n): return (n is Label or n is RichTextLabel) and n.is_visible_in_tree(), []):
			var text: String = n.get_parsed_text() if n is RichTextLabel else n.text
			if not text.strip_edges().is_empty() and not text.begins_with("Hold [") and not text.begins_with("[E]"):
				parts.append(text.strip_edges().replace("\n", " / "))
	return " | ".join(parts)


func _summary_screen() -> Node:
	for n in find_all(get_tree().root, func(n): return n.get_script() != null and String(n.get_script().resource_path).ends_with("summary_screen.gd"), []):
		return n
	return null


func _summary_open() -> bool:
	var s := _summary_screen()
	return s != null and s.visible


func play_step() -> void:
	chef = Player.find(get_tree(), 0)
	if chef == null:
		return
	if not get_tree().get_nodes_in_group(ConversationBox.GROUP).is_empty():
		var text := box_text()
		if text != last_box:
			last_box = text
			note("BOX " + text)
			await tick(1.0)  # Reading time.
		await key(KEY_E)
		return
	last_box = ""
	for station in find_all(main, func(n): return n is DrinkStation and n._pourer == chef, []):
		await pour_step(station)
		return
	var session := find_all(main, func(n): return n is CookSession, [])
	if not session.is_empty():
		cook_step(session[0])
		return
	if not step_title.is_empty():
		note("   cook step '%s' took %.1fs" % [step_title, t - step_began])
		step_title = ""
	for wheel in find_all(main, func(n): return n is TicketWheel and n._clipper == chef, []):
		await wheel_step(wheel)
		return
	if get_tree().paused:
		var buttons := find_all(get_tree().root, func(n): return n is Button and n.is_visible_in_tree() and not n.disabled, [])
		note("PAUSED with buttons " + str(buttons.map(func(b): return b.text.replace("\n", " ").left(40))))
		await shot("paused")
		for word in ["Continue", "Close", "Done", "OK", "Keep going", "I'd rather not say"]:  # The last: the birthday question.
			for b in buttons:
				if b.text.begins_with(word):
					b.pressed.emit()
					return
		await key(KEY_ESCAPE)
		return
	var step: Dictionary = guide.steps.get(0, {})
	var hint := String(step.get("hint", ""))
	var k := String(step.get("key", ""))
	if hint != last_hint:
		note("STEP %s   (%s)   [%s]" % [hint, k, ArrivalPacing.debug_line(cm.status()) if DayCycle.is_open() else DayCycle.phase_name()])
		last_hint = hint
		if k in ["ring_bell", "open_up"]:
			await shot(k)
	var target: Interactable = step.get("target")
	if target == null or not is_instance_valid(target):
		return
	var to := target.global_position
	var from := chef.global_position
	var away := Vector3(from.x - to.x, 0.0, from.z - to.z)
	if away.length() < 0.05:
		away = Vector3(0, 0, 1)
	if away.length() > 0.95 or chef.interactor.focused != target:
		chef.global_position = Vector3(to.x, from.y, to.z) + away.normalized() * 0.8
		chef.reset_physics_interpolation()
		await get_tree().physics_frame
		await get_tree().physics_frame
	if chef.interactor.focused != target:
		# Something else nearer took the focus (a chair beside a table): walk
		# round it, like a player would, until the target is the one in focus.
		for dist in [0.8, 0.6, 1.0]:
			for i in 8:
				var dir := Vector3(cos(i * TAU / 8.0), 0.0, sin(i * TAU / 8.0))
				chef.global_position = Vector3(to.x, from.y, to.z) + dir * dist
				chef.reset_physics_interpolation()
				await get_tree().physics_frame
				await get_tree().physics_frame
				if chef.interactor.focused == target:
					break
			if chef.interactor.focused == target:
				break
	if chef.interactor.focused == target:
		await key(KEY_E)
		stuck = 0.0
	else:
		stuck += 0.3
		if stuck > 3.0:
			note("can't reach %s (focused %s)" % [target.get_parent().name, chef.interactor.focused.get_parent().name if chef.interactor.focused else "nothing"])
			stuck = -6.0
			chef.global_position = Vector3(to.x, from.y, to.z) - away.normalized() * 0.8


# A pour at the drinks counter: hold E until the fill line, let go.
func pour_step(station: DrinkStation) -> void:
	await hold_key(KEY_E, false)
	await get_tree().create_timer(0.2, true, false, false).timeout
	presses += 1
	await hold_key(KEY_E, true)
	var held := 0.0
	while station._pour != DrinkStation.Pour.NONE and station._fill < DrinkStation.LINE - 0.02 and held < 8.0:
		await get_tree().process_frame
		held += get_process_delta_time()
	await hold_key(KEY_E, false)
	note("   poured %s to %.2f in %.1fs" % [station._pour_drink.get("name", "?"), station._fill, held])
	await tick(0.5)


# A cooking close-up plays itself (scripted input); just note each step's time.
func cook_step(session: CookSession) -> void:
	if not session.input.scripted:
		session.input.scripted = true
		note("CLOSE-UP %s" % (session.recipe.display_name if session.recipe else "?"))
	var title := String(session.current.title) if session.current != null else "(between steps)"
	if title != step_title:
		if not step_title.is_empty():
			note("   cook step '%s' took %.1fs" % [step_title, t - step_began])
		step_title = title
		step_began = t
		slow_noted = false
	elif t - step_began > 20.0 and not slow_noted:  # A step that won't finish: what it's doing, to see why.
		slow_noted = true
		note("   SLOW STEP '%s' (%s): held %s  cursor %s  status '%s'" % [title, session.current.get_script().resource_path.get_file() if session.current else "-", session.input.held, session.input.cursor, session._status])


# Clipping tickets: press E as an empty clip comes to the front.
func wheel_step(wheel: TicketWheel) -> void:
	var waited := 0.0
	while wheel._clipper == chef and waited < 15.0:
		var front := wheel._front_clip()
		if not wheel._tickets.has(front) and absf(wheel._front_offset(front)) < wheel.front_window * 0.6:
			await key(KEY_E)
		await get_tree().process_frame
		waited += get_process_delta_time()
	t += waited


# The summary: what it says, the star progress, then shopping like a new player
# (the Ticket Rail, then the cheapest new dishes and drinks, then a bit of decor,
# then upgrades), placing decor where the decorating rules allow, and out for
# the evening.
func do_summary() -> void:
	var screen := _summary_screen()
	await tick(1.0)
	note("SUMMARY " + String(screen.title_label.text) + " / " + String(screen.body_label.text).replace("\n", " / "))
	await shot("summary")
	note("RATING " + Rating.page_text().replace("\n", " / "))
	note("SHOP money $%d" % GameState.money)
	var bought := PackedStringArray()
	if GameData.in_stock("ticket_rail") and GameState.buy_upgrade("ticket_rail"):
		bought.append("upgrade Ticket Rail ($40)")
	var spent := true
	while spent:
		spent = false
		var menu := []
		for d in GameData.shop_dishes():
			if not GameData.is_unlocked(d["id"]) and GameData.in_stock(d["id"]):
				menu.append([int(d.get("unlock_cost", 999)), "dish", d])
		for d in GameData.drinks:
			if d.get("unlock", "") == "upgrade" and not GameData.is_unlocked(d["id"]) and GameData.in_stock(d["id"]):
				menu.append([int(d.get("unlock_cost", 999)), "drink", d])
		var decor := []
		for item in Decor.stock():
			var have := int(GameState.decor_stored.get(item["id"], 0)) + GameState.decor_placed.filter(func(p): return p["id"] == item["id"]).size()
			if have == 0 and int(item.get("price", 0)) > 0:
				decor.append([int(item["price"]), "decor", item])
		var upgrades := []
		for u in GameData.upgrades:
			if not GameState.has_upgrade(u["id"]) and GameData.in_stock(u["id"]):
				upgrades.append([int(u["price"]), "upgrade", u])
		for group in [menu, decor, upgrades]:
			group.sort_custom(func(a, b): return a[0] < b[0])
			if not group.is_empty() and group[0][0] <= GameState.money:
				var pick: Array = group[0]
				var ok := false
				match pick[1]:
					"dish":
						ok = GameState.buy_dish(pick[2]["id"])
					"drink":
						ok = GameState.buy_drink(pick[2]["id"])
					"decor":
						ok = GameState.buy_decor(pick[2]["id"])
					"upgrade":
						ok = GameState.buy_upgrade(pick[2]["id"])
				if ok:
					bought.append("%s %s ($%d)" % [pick[1], pick[2].get("name", pick[2]["id"]), pick[0]])
					spent = true
					break
	note("BOUGHT " + (", ".join(bought) if not bought.is_empty() else "nothing") + "  -> $%d left" % GameState.money)
	_place_decor()
	note("after shopping: menu %d  decor %d  community %d" % [Rating.menu_size(), Decor.score(), Rating.community()])
	screen.next_button.pressed.emit()
	await tick(1.5)


func _place_decor() -> void:
	var cell := float(Decor.settings()["grid"]["cell"])
	var gap := float(Decor.settings().get("station_gap", 0.6))
	var stations := find_all(main, func(n): return n is Station, []).map(func(s): return Vector2(s.global_position.x, s.global_position.z))
	for id in GameState.decor_stored.keys():
		while int(GameState.decor_stored.get(id, 0)) > 0:
			var item := Decor.get_item(id)
			var placed := false
			if item.get("kind", "floor") == "wall":
				for spot in Decor.settings().get("wall_spots", []).size():
					if not Decor.spot_taken(spot):
						var at := Decor.spot_position(spot)
						GameState.decor_place(id, at.x, at.z, Decor.spot_turn(spot), spot)
						placed = true
						break
			else:
				var cells := Decor.grid_cells()
				for cz in cells.y:
					for cx in cells.x:
						if placed:
							break
						var at := Decor.snap(item, Decor.grid_origin() + Vector2(cx + 0.5, cz + 0.5) * cell, 0)
						if Decor.fits(item, at, 0) and stations.all(func(s): return s.distance_to(at) > gap + 0.5):
							GameState.decor_place(id, at.x, at.y, 0, -1)
							placed = true
			if not placed:
				note("decor: no room for %s" % id)
				break
			note("decor: placed %s" % id)


# After hours: what there is to do (every prompt on offer), then the arrow for
# a while (night calls and deliveries come through the phone).
func after_hours() -> void:
	await tick(2.0)
	_grab_nodes()
	note("AFTER HOURS phase %s" % DayCycle.phase_name())
	await shot("after_hours")
	var offers := {}
	for n in find_all(main, func(n): return n is Interactable, []):
		var p := String(n.prompt_for(0))
		if not p.is_empty():
			offers["%s (%s)" % [p, n.get_parent().name]] = true
	note("ON OFFER: " + ", ".join(offers.keys()))
	var began := t
	last_hint = ""
	while t - began < after:
		await tick(0.3)
		await play_step()
	note("after hours done (%s)" % DayCycle.phase_name())
	await shot("night")
