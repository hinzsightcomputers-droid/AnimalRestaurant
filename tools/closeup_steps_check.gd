extends Node

# Every step of a close-up starts fresh: plays dishes by script with the button
# (and the stick) held down and mashed as each step begins, and checks the
# cursor starts in the middle, where it can be seen, that it can't be pushed out
# of sight, and that nothing left over from the last step counts. At a cutting
# step, cuts one piece on top of another too (it mustn't). Takes pictures. Run
# (not headless) with APPDATA pointing at a copy of a save with an account and
# SHOTS=<folder>; DISHES=<dish ids, comma-separated> (default: pancakes and what's
# cut from dough):
#   godot --resolution 1600x900 res://tools/closeup_steps_check.tscn

const DISHES := "pancakes,croissant,acorn_cookies,cherry_pie,pork_dumplings,apple_strudel,soft_pretzel,egg_tarts,mochi"

var main: Node
var player: Player
var failed := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(3.0).timeout
	for i in 10:
		if Player.find(get_tree(), 0) != null:
			break
		await _key(KEY_ENTER, 0.1)
		await get_tree().create_timer(0.5).timeout
	await _pick_accounts()
	player = Player.find(get_tree(), 0)
	var dishes := {}
	for dish in GameData.dishes:
		dishes[dish["id"]] = dish
	var wanted := OS.get_environment("DISHES") if not OS.get_environment("DISHES").is_empty() else DISHES
	for id in wanted.split(","):
		var dish: Dictionary = dishes.get(id, {})
		var recipe: CookRecipe = CookRecipe.for_dish(dish)
		if recipe == null:
			print("CHECK no close-up for ", id)
			continue
		var at: String = dish.get("station", "stove")
		var stations := _find(main, func(n): return n is CookingStation and n.station_id == at)
		if stations.is_empty():
			print("CHECK no %s for %s: on the stove" % [at, id])
			stations = _find(main, func(n): return n is CookingStation and n.station_id == "stove")
		var station: CookingStation = stations[0]
		player.global_position = station.global_position + station.global_transform.basis.z * 0.9
		await get_tree().create_timer(0.6).timeout
		station.reel_cook(player, recipe, dish)
		await _play(id, station.session)
	print("CHECK %d failed" % failed)
	get_tree().quit()


func _play(id: String, session: CookSession) -> void:
	var last: CookAction = null
	var clock := 0.0
	while is_instance_valid(session) and not session.is_finished and clock < 150.0:
		await get_tree().process_frame
		clock += get_process_delta_time()
		if not is_instance_valid(session) or session.current == null or session.current == last:
			continue
		if last != null:
			print("CHECK %s '%s' %.2f" % [id, last.title, last.quality])
		last = session.current
		session.input.scripted = false
		await _left_over(id, session)
		if is_instance_valid(session) and session.current == last:
			if last is CutAction:
				await _cut_twice(id, session, last)
			await _out_of_sight(id, session)
		session.input.scripted = true
		for i in 30:  # Back where a reel would be, its hand up.
			Input.action_release("p0_interact")
		await _shot("%s_%02d_%s.png" % [id, session.steps.find(last), last.title.to_snake_case().validate_filename()])
	if is_instance_valid(session):
		print("CHECK %s done: %s" % [id, session.steps.map(func(s): return "%s %.2f" % [s.title, s.quality])])
	else:
		print("CHECK %s: gone" % id)
	await get_tree().create_timer(2.5).timeout


# The button held over, then mashed, from the last step, the stick still pushed.
func _left_over(id: String, session: CookSession) -> void:
	var step := session.current
	var before := session.pieces.size()
	var presses := 0
	session.input.new_step(session.input.cursor)
	var middle := session.input.cursor
	Input.action_press("p0_interact")
	Input.action_press("p0_move_right")
	for frame in 40:
		await get_tree().process_frame
		if frame == 15 or frame == 25:
			Input.action_release("p0_interact")
		if frame == 20 or frame == 30:
			Input.action_press("p0_interact")
		if is_instance_valid(session) and session.input.just_pressed:
			presses += 1
	if not is_instance_valid(session):
		return
	Input.action_release("p0_interact")
	Input.action_release("p0_move_right")
	_check("%s '%s': nothing left over counts (%d presses, %d pieces)" % [id, step.title, presses, session.pieces.size() - before], presses == 0 and session.pieces.size() == before)
	if session.current == step:
		await get_tree().create_timer(0.7).timeout  # The view's arrived.
		if not is_instance_valid(session) or session.current != step:
			return
		_check("%s '%s': cursor in the middle (moved %.3f)" % [id, step.title, session.input.cursor.distance_to(middle)], session.input.cursor.distance_to(middle) < 0.02)
		var at := session.input.screen_point(session.input.cursor) if step.aims() else Vector2.INF
		_check("%s '%s': in sight at %s" % [id, step.title, at], at == Vector2.INF or Rect2(0.03, 0.03, 0.94, 0.94).has_point(at))
	await get_tree().create_timer(0.3).timeout


# Pushed as far as it'll go each way, it's still on screen.
func _out_of_sight(id: String, session: CookSession) -> void:
	var step := session.current
	for way in ["p0_move_right", "p0_move_down", "p0_move_left", "p0_move_up"]:
		Input.action_press(way)
		await get_tree().create_timer(1.1).timeout
		Input.action_release(way)
		if not is_instance_valid(session) or session.current != step:
			return
		var at := session.input.screen_point(session.input.cursor)
		if at != Vector2.INF and not Rect2(0.03, 0.03, 0.94, 0.94).has_point(at):
			_check("%s '%s': pushed %s, out of sight at %s" % [id, step.title, way, at], false)
	session.input.cursor = session.clamp_to_bounds(step.view_point())


func _cut_twice(id: String, session: CookSession, cut: CutAction) -> void:
	for i in 2:
		await get_tree().create_timer(0.35).timeout
		Input.action_press("p0_interact")
		await get_tree().create_timer(0.12).timeout
		Input.action_release("p0_interact")
	if not is_instance_valid(session):
		return
	if cut.cookies > 1:
		_check("%s: one on top of another is refused (%d cut, %d refused)" % [id, cut._cut.size(), cut._misses], cut._cut.size() == 1 and cut._misses == 1)
		await _shot("%s_cut_blocked.png" % id)
		Input.action_press("p0_move_right")
		await get_tree().create_timer(0.7).timeout
		Input.action_release("p0_move_right")
		await get_tree().create_timer(0.4).timeout
		await _shot("%s_cut_line.png" % id)


func _check(what: String, ok: bool) -> void:
	if not ok:
		failed += 1
	print("CHECK %s %s" % ["ok  " if ok else "FAIL", what])


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/" + file)


func _pick_accounts() -> void:
	for round in 30:
		var buttons := _find(get_tree().root, func(n): return n is Button and n.is_visible_in_tree() and ("played)" in n.text or n.text == "Done" or "rather not say" in n.text))
		if buttons.is_empty():
			var focus := get_viewport().gui_get_focus_owner()
			if focus is Button and focus.is_visible_in_tree():
				buttons = [focus]
			else:
				return
		buttons[0].pressed.emit()
		await get_tree().create_timer(0.5).timeout


func _key(code: Key, hold: float) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().create_timer(hold).timeout
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)


func _find(n: Node, f: Callable, out := []) -> Array:
	if f.call(n):
		out.append(n)
	for c in n.get_children():
		_find(c, f, out)
	return out
