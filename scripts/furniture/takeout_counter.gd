# TakeoutCounter: where things are bagged to go (TakeoutBag). A cooked dish
# has to be bagged here before the courier takes it, or before it can be
# given to a regular at their house. After hours, free hands can also pack
# one thing from the pantry, or order a dish to go: its ticket goes in your
# pocket and it's cooked the usual way (ticket wheel, freezer, stove), then
# bagged here. Carrying a bag here unpacks it again. Settings in
# data/service.json "takeout".
class_name TakeoutCounter
extends Station

@export var order_board: OrderBoard
@export var view_manager: ViewManager

var _busy := {}  # player_index -> true while they're choosing.


func _ready() -> void:
	super._ready()
	interactable.prompt_for_player = _prompt_for
	interactable.priority = 2  # Over a courier waiting close by (they want the bag first).
	var stack := Node3D.new()  # Flat bags ready on the counter.
	stack.position = Vector3(0.3, 0.92, 0.0)
	visual.add_child(stack)
	for i in 2:
		var bag := TakeoutBag.make_model(0.8)
		bag.position = Vector3(i * -0.25, 0.0, 0.0)
		stack.add_child(bag)
	_add_sign()


# A little signboard on a post at the end of the counter, turned to face the
# camera whichever way the counter's placed.
func _add_sign() -> void:
	var sign := Node3D.new()
	sign.position = Vector3(-0.3, 0.92, 0.15)
	visual.add_child(sign)
	sign.global_rotation = Vector3.ZERO
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.36, 0.22)
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.02
	post_mesh.bottom_radius = 0.025
	post_mesh.height = 0.45
	post_mesh.material = wood
	post.mesh = post_mesh
	post.position.y = 0.225
	sign.add_child(post)
	var board := MeshInstance3D.new()
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(0.86, 0.26, 0.04)
	var cream := StandardMaterial3D.new()
	cream.albedo_color = Color(0.98, 0.93, 0.8)
	board_mesh.material = cream
	board.mesh = board_mesh
	board.position.y = 0.58
	sign.add_child(board)
	var trim := MeshInstance3D.new()
	var trim_mesh := BoxMesh.new()
	trim_mesh.size = Vector3(0.92, 0.32, 0.03)
	trim_mesh.material = wood
	trim.mesh = trim_mesh
	trim.position = Vector3(0.0, 0.58, -0.01)
	sign.add_child(trim)
	var words := Label3D.new()
	words.text = settings().get("sign", "TAKEOUT")
	words.font_size = 64
	words.pixel_size = 0.0028
	words.outline_size = 0
	words.modulate = Color(0.8, 0.22, 0.16)
	words.position = Vector3(0.0, 0.58, 0.025)
	sign.add_child(words)


static func settings() -> Dictionary:
	return GameData.service.get("takeout", {})


func _prompt_for(player_index: int) -> String:
	var player := Player.find(get_tree(), player_index)
	if player == null or _busy.has(player_index):
		return ""
	if player.held_item is CookedDish:
		return settings().get("bag_prompt", "Bag it to go")
	if player.held_item is TakeoutBag and not player.held_item.is_delivery():  # A delivery bag is for the courier.
		return settings().get("unpack_prompt", "Unpack the bag")
	if player.held_item == null and DayCycle.doors_open():
		return settings().get("pack_prompt", "Pack a takeout bag")
	return ""


func _on_interacted(player_index: int) -> void:
	var player := Player.find(get_tree(), player_index)
	if _prompt_for(player_index).is_empty():
		return
	var held := player.held_item
	if held is CookedDish:
		bag_dish(player)
	elif held is TakeoutBag:
		_unpack(player, held)
	else:
		_pack(player)
	_play_bounce()
	used.emit(self, player_index)


# Bags the dish they're carrying. A dish cooked to go is done with the order board now.
func bag_dish(player: Player) -> void:
	var dish := player.held_item as CookedDish
	player.set_held_item(TakeoutBag.of_dish(dish))
	if dish.order != null and dish.order.caller.get("kind", "") == "takeout":
		order_board.remove_order(dish.order)
	_rustle()
	GameEvents.announce("Bagged the %s to go." % dish.dish_name())


func _unpack(player: Player, bag: TakeoutBag) -> void:
	if bag.dish != null:
		player.set_held_item(bag.dish)
	else:
		Pantry.add(bag.item_id)
		player.set_held_item(null)
		GameEvents.announce("Put the %s back in the pantry." % bag.contents_name())
	_rustle()


# After hours: something from the pantry, or a dish ordered to go.
func _pack(player: Player) -> void:
	var index := player.player_index
	_busy[index] = true
	player.movement_locked = true
	player.interactor.lock_to(interactable)
	var box := ConversationBox.open(ConversationBox.parent_for(view_manager, index, self), index)
	var ids: Array = GameState.pantry.keys().filter(func(item_id): return int(GameState.pantry[item_id]) > 0)
	ids.sort_custom(func(a, b): return Pantry.item_name(a) < Pantry.item_name(b))
	var choices: Array = ids.map(func(item_id): return { "id": item_id, "label": "%s (%d)" % [Pantry.item_name(item_id), int(GameState.pantry[item_id])] })
	var dishes := GameData.menu()
	if not dishes.is_empty():
		choices.append({ "cook": true, "label": settings().get("cook", "Cook something to go") })
	if choices.is_empty():
		await box.tell("", settings().get("nothing", "(Nothing to pack.)"))
	else:
		var picked := await _pick(box, settings().get("ask", "What goes in the bag?"), choices)
		if picked.get("cook", false):
			var dish_choices: Array = dishes.map(func(dish): return { "dish": dish, "label": dish.get("name", "?") })
			var dish_pick := await _pick(box, settings().get("cook_ask", "Which dish?"), dish_choices)
			if dish_pick.has("dish"):
				box.close()
				box = null
				await _order_to_go(player, dish_pick["dish"])
		elif picked.has("id"):
			var item_id: String = picked["id"]
			GameState.pantry[item_id] = int(GameState.pantry[item_id]) - 1
			if GameState.pantry[item_id] <= 0:
				GameState.pantry.erase(item_id)
			player.set_held_item(TakeoutBag.of_item(item_id))
			_rustle()
			GameEvents.announce("Packed the %s to go." % Pantry.item_name(item_id))
	if box != null:
		box.close()
	player.movement_locked = false
	player.interactor.unlock()
	player.ignore_interact_until_released()
	_busy.erase(index)


# A page of choices at a time; returns the one picked, or {} for Never mind.
func _pick(box: ConversationBox, question: String, choices: Array) -> Dictionary:
	var per_page := maxi(int(settings().get("per_page", 4)), 1)
	var pages := ceili(choices.size() / float(per_page))
	var page := 0
	while true:
		var shown := choices.slice(page * per_page, (page + 1) * per_page)
		var options: Array = shown.map(func(choice): return choice["label"])
		if pages > 1:
			options.append(settings().get("more", "More..."))
		options.append(settings().get("never_mind", "Never mind"))
		var picked := await box.ask("", question, options)
		if picked < shown.size():
			return shown[picked]
		if pages > 1 and picked == shown.size():
			page = (page + 1) % pages
			continue
		return {}
	return {}


# An order of our own, to go: the ticket's written into their pocket like a phoned-in one.
func _order_to_go(player: Player, dish: Dictionary) -> void:
	var order := order_board.add_delivery(dish, { "kind": "takeout", "name": settings().get("to_go_name", "To go"), "regular_id": "" })
	GameEvents.announce("%s to go: clip the ticket on the wheel and cook it, then bag it here." % dish.get("name", "A dish"))
	await TicketPopup.write(view_manager, player, order)


func _rustle() -> void:
	var sound := AudioStreamPlayer3D.new()
	sound.stream = CookSounds.get_sound("whoosh")
	sound.pitch_scale = 1.6
	sound.volume_db = -6.0
	sound.position = Vector3(0.0, 1.0, 0.0)
	add_child(sound)
	sound.play()
	sound.finished.connect(sound.queue_free)
