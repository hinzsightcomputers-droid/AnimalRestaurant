# Guide: for new chefs, an arrow on the floor round each player pointing the
# way to their next step (seat the customer, take their order, clip the
# ticket, get the ingredients...), with a line saying what it is. Each player
# gets their own: what they carry decides it first, then the restaurant's
# most pressing job that another guided player isn't already heading for. The
# arrow follows a walking route (round counters, through the kitchen doorway),
# turning as you go, and goes away once you're there and the prompt shows.
# Who's guided: a new chef (any account until it has finished its first
# customer, or worked a shift), or everyone with the "Guide arrow" setting on.
# A new chef's first customer is followed through their whole visit, from the
# host stand to a clean table, and then the arrow's done (see _follow_lesson). Text and sizes in
# data/service.json "guide".
class_name Guide
extends Node3D

const CELL := 0.25                    # The walking grid's squares (meters).
const AREA := Rect2(-8.0, -12.0, 16.0, 19.0)  # The building, x/z, with a margin.
const BODY_RADIUS := 0.3              # Room a chef needs to walk through.
const BODY_BOTTOM := 0.15             # ...from this far off the floor...
const BODY_TOP := 1.4                 # ...up to here.
const GRID_SECONDS := 20.0            # How often the walking grid is redone (it only changes if furniture does).
const ROUTE_SECONDS := 0.25           # How often each route is redone.
const LOOK_AHEAD := 0.9               # The arrow points at the route this far along.
const ON_TOP := 0.3                   # Closer than this to the step counts as there, whatever's showing.
const CUSTOMER_CELLS := 2               # Squares either side of a standing customer that are in the way.

@export var customer_manager: CustomerManager
@export var delivery_manager: DeliveryManager
@export var day_manager: DayManager
@export var order_board: OrderBoard
@export var view_manager: ViewManager

var _grid := AStarGrid2D.new()
var _grid_left := 0.0
var _arrows := {}   # player_index -> GuideArrow
var _routes := {}   # player_index -> { target, left, points }
var _found := {}    # Furniture type -> the nodes of it (see _all).
var _lessons := {}  # player_index -> their first customer: { customer, table, done? } (see _follow_lesson).
var steps := {}     # player_index -> their step this frame (see next_step), for anyone curious.


func _ready() -> void:
	if GameState.guide_old_save:
		# From before the guide: everyone who's already played knows the way.
		for account in Accounts.accounts:
			GameState.mark_guided(account["id"])
		GameState.guide_old_save = false


static func settings() -> Dictionary:
	return GameData.service.get("guide", {})


# Whether this player is shown the way.
static func guides(player_index: int) -> bool:
	return Settings.guide_always or is_new_chef(player_index)


func _process(delta: float) -> void:
	var serving := DayCycle.is_open() or DayCycle.is_closing() or DayCycle.is_night() or DayCycle.is_new_day_waiting()
	var players: Array = get_tree().get_nodes_in_group(Player.GROUP).filter(func(p): return p is Player)
	players.sort_custom(func(a, b): return a.player_index < b.player_index)
	if serving and players.any(func(p): return guides(p.player_index)):
		_grid_left -= delta
		if _grid_left <= 0.0:
			_grid_left = GRID_SECONDS
			_build_grid(players)
	var claimed := {}
	steps.clear()
	for player: Player in players:
		if serving:
			_follow_lesson(player)
		var arrow := _arrow_for(player)
		var step := next_step(player, claimed) if serving and guides(player.player_index) else {}
		steps[player.player_index] = step
		if step.has("claim"):
			claimed[step["claim"]] = true
		_show(player, arrow, step, delta)
	for index in _arrows.keys():
		if not players.any(func(p): return p.player_index == index):
			_arrows[index].queue_free()
			_arrows.erase(index)
			_routes.erase(index)


# Where this player should go next and why: { target (Interactable), key, hint, claim? },
# or {} when there's nothing for them. `claimed` holds jobs another player was
# already sent to.
func next_step(player: Player, claimed: Dictionary) -> Dictionary:
	var index := player.player_index
	var held := player.held_item
	var leading := customer_manager.leading(index)
	if leading != null:
		return _nearest(player, _tables().filter(func(t): return not t.interactable.prompt_for(index).is_empty()),
				"lead", { "name": leading.display_name })
	if held is CookedDish:
		var order: Order = held.order
		if order.customer != null and is_instance_valid(order.customer):
			return _step(order.customer.interactable, "serve", { "name": order.customer.display_name })
		return _step(_spot(TakeoutCounter), "bag")
	if held is TakeoutBag:
		var courier := delivery_manager.courier_for(held.dish.order) if held.is_delivery() else null
		return _step(courier.interactable, "courier") if courier != null else {}
	if held is Ingredients:
		if held.needs_chopping():
			return _step(_spot(ChoppingBoard), "chop", { "verb": held.chop_verb() })
		var stations := _all(CookingStation).filter(func(s): return s.makes(held.order.dish))
		return _nearest(player, stations, "cook", { "station": CookingStation.station_of(held.order.dish), "dish": held.order.dish.get("name", "it") })
	if held is Drink:
		var drink_id: String = held.drink.get("id", "")
		return _nearest(player, _customers(Customer.State.WAITING_FOR_DRINK).filter(func(c): return c.drink.get("id", "") == drink_id), "give_drink")
	if held is Receipt:
		return _nearest(player, _customers(Customer.State.WANTS_BILL), "give_bill")
	if held is DishBin:
		var dirty := _tables().filter(func(t): return not t.dishes.is_empty())
		if not held.is_full() and not dirty.is_empty():
			return _nearest(player, dirty, "clear")
		return _step(_spot(Sink), "wash" if not held.dishes.is_empty() else "bin_back")
	if held != null:
		return {}

	# Free hands: the most pressing job nobody else is heading for.
	if DayCycle.is_new_day_waiting():
		return _step(customer_manager.order_counter.interactable, "open_up")
	var wheel := _first(TicketWheel) as TicketWheel
	if not player.tickets.is_empty() and wheel != null and not TicketWheel.is_full(get_tree()):
		return _step(wheel.interactable, "clip")
	# The first customer comes first; while they sit, eat or wait, the arrow shows
	# what else needs doing (so a new chef isn't left standing while others wait).
	var lesson_wait := {}
	if _lessons.has(index) and not _lessons[index].get("done", false):
		var lesson_step := _lesson_step(player)
		if lesson_step.is_empty() or lesson_step.has("target"):
			return lesson_step
		lesson_wait = lesson_step
	var phone := _first(Phone) as Phone
	var jobs: Array[Array] = []  # Most pressing first; each a list of { target, hint, claim }.
	jobs.append([_job(phone.interactable if phone != null and phone.is_ringing() else null, "phone", "phone")])
	var front: Array = []
	for customer in _customers(Customer.State.WAITING_DRINK_ORDER) + _customers(Customer.State.WAITING_FOOD_ORDER):
		var hint := "drink_order" if customer.state == Customer.State.WAITING_DRINK_ORDER else "food_order"
		front.append(_job(customer.interactable, hint, customer, { "name": customer.display_name }))
	for customer in _customers(Customer.State.DONE_EATING):
		front.append(_job(customer.interactable, "bill_chat", customer, { "name": customer.display_name }))
	var counter := customer_manager.order_counter.interactable
	for bill in customer_manager.bills_to_print():
		front.append(_job(counter, "print_bill", "bill_%d" % bill))
	if customer_manager.next_to_seat() != null:
		var waiting := _customers(Customer.State.WAITING_TO_BE_SEATED).filter(func(c): return not c.is_walking())
		for i in waiting.size():  # One chef per customer in line.
			front.append(_job(counter, "seat", "seat_%d" % i))
	jobs.append(front)
	var pass_counter := _first(PassCounter) as PassCounter
	jobs.append([_job(pass_counter.interactable if pass_counter != null and pass_counter.held_item != null else null, "pick_up", "pass")])
	var freezer := _first(Freezer) as Freezer
	jobs.append([_job(freezer.interactable if freezer != null and order_board.next_to_gather() != null else null, "freezer", "freezer")])
	var drinks := _first(DrinkStation) as DrinkStation
	jobs.append([_job(drinks.interactable if drinks != null and not drinks.interactable.prompt_for(index).is_empty() else null, "make_drink", "drinks")])
	var sink := _first(Sink) as Sink
	var cleaning: Array = []
	for table in _tables():
		if not table.dishes.is_empty() and sink != null and sink.bins_here > 0:
			cleaning.append(_job(sink.interactable, "take_bin", table))
		elif table.dishes.is_empty() and not table.spills.is_empty():
			cleaning.append(_job(table.interactable, "wipe", table))
	jobs.append(cleaning)
	jobs.append([_job(counter if day_manager.bell_ready() else null, "ring_bell", "bell")])
	for level in jobs:
		var open := level.filter(func(job): return job["target"] != null and not claimed.has(job["claim"]))
		if not open.is_empty():
			open.sort_custom(func(a, b): return _distance(player, a["target"]) < _distance(player, b["target"]))
			if lesson_wait.is_empty():
				return open[0]
			var meanwhile: Dictionary = open[0].duplicate()
			var first: Customer = _lessons[index]["customer"] if is_instance_valid(_lessons[index]["customer"]) else null
			meanwhile["hint"] = String(settings().get("meanwhile", "{job} (then back to {name})")).format({ "job": meanwhile["hint"], "name": first.display_name if first != null else "" })
			return meanwhile
	return lesson_wait


# --- The first customer -----------------------------------------------------

# A new chef's first customer is theirs from greeting to a clean table: the
# Guide follows that one visit all the way (see _lesson_step) then the arrow
# is done with them for good. Not for those who only see the arrow because of
# the setting (it carries on with whatever's most pressing for them).
func _follow_lesson(player: Player) -> void:
	var index := player.player_index
	if not _lessons.has(index):
		if not is_new_chef(index):
			return
		var customer := customer_manager.greeting(index)
		if customer == null:
			customer = customer_manager.leading(index)
		if customer != null:
			_lessons[index] = { "customer": customer, "table": null }
		return
	var lesson: Dictionary = _lessons[index]
	if lesson.get("done", false):
		if lesson.get("celebrate", false) and not player.movement_locked and not player.in_conversation():
			lesson.erase("celebrate")
			_celebrate(player)
		return
	var customer: Customer = lesson["customer"] if is_instance_valid(lesson["customer"]) else null
	if customer != null and customer.seat != null and customer.seat.table != null:
		lesson["table"] = customer.seat.table
	var left := customer == null or customer.state in [Customer.State.LEAVING, Customer.State.GONE]
	var table: DiningTable = lesson["table"]
	if left and (table == null or (table.dishes.is_empty() and table.spills.is_empty())):
		lesson["done"] = true
		lesson["celebrate"] = true
		GameState.mark_guided(Accounts.id_of(index))  # They know the way now: no more arrow (unless the setting asks).


# Done with the first customer: a box in their view says so, with a chime,
# and waits for them to carry on.
func _celebrate(player: Player) -> void:
	player.movement_locked = true
	var chime := AudioStreamPlayer.new()
	chime.stream = CookSounds.get_sound("ding")
	add_child(chime)
	chime.play()
	chime.finished.connect(chime.queue_free)
	var box := ConversationBox.open(ConversationBox.parent_for(view_manager, player.player_index, self), player.player_index)
	await box.tell(String(settings().get("lesson_done_title", "Tutorial complete!")), String(settings().get("lesson_done", "Now on to the rest of the customers!")))
	box.close()
	if is_instance_valid(player):
		player.movement_locked = false
		player.ignore_interact_until_released()


static func is_new_chef(player_index: int) -> bool:
	var account := Accounts.id_of(player_index)
	if account.is_empty():
		return GameState.day_number <= 1
	return not account in GameState.guided


# The next thing for the lesson's customer, or a "wait" with no target while
# they sit down, eat, or someone else has their dish.
func _lesson_step(player: Player) -> Dictionary:
	var lesson: Dictionary = _lessons[player.player_index]
	var customer: Customer = lesson["customer"] if is_instance_valid(lesson["customer"]) else null
	var words := { "name": customer.display_name if customer != null else "" }
	if customer == null or customer.state in [Customer.State.LEAVING, Customer.State.GONE]:
		var table: DiningTable = lesson["table"]
		var sink := _first(Sink) as Sink
		if table != null and not table.dishes.is_empty() and sink != null:
			return _step(sink.interactable, "take_bin")
		if table != null and not table.spills.is_empty():
			return _step(table.interactable, "wipe")
		return {}
	match customer.state:
		Customer.State.WAITING_TO_BE_SEATED, Customer.State.FOLLOWING, Customer.State.WALKING_TO_SEAT:
			return _wait("wait_sitting", words)
		Customer.State.WAITING_DRINK_ORDER:
			return _lesson_job(customer.interactable, "drink_order", words, customer)
		Customer.State.WAITING_FOR_DRINK:
			var drinks := _first(DrinkStation) as DrinkStation
			if drinks != null and not drinks.interactable.prompt_for(player.player_index).is_empty():
				return _lesson_job(drinks.interactable, "make_drink", words, "drinks")
			return _wait("wait_drink", words)
		Customer.State.WAITING_FOOD_ORDER:
			return _lesson_job(customer.interactable, "food_order", words, customer)
		Customer.State.WAITING_FOR_FOOD:
			return _food_step(customer, words)
		Customer.State.EATING:
			return _wait("wait_eating", words)
		Customer.State.DONE_EATING:
			return _lesson_job(customer.interactable, "bill_chat", words, customer)
		Customer.State.WANTS_BILL:
			if customer_manager.bills_to_print() > 0:
				return _lesson_job(customer_manager.order_counter.interactable, "print_bill", words, "bill_0")
			return _wait("wait_bill", words)
	return {}


# Their dish, wherever it's got to: on the wheel waiting for its ingredients,
# cooking, or ready on the pass.
func _food_step(customer: Customer, words: Dictionary) -> Dictionary:
	var order: Order = null
	for o in order_board.orders:
		if o.customer == customer:
			order = o
	if order == null:
		words["dish"] = "food"
		return _wait("wait_food", words)
	words["dish"] = order.dish.get("name", "it")
	if order.state == Order.State.WAITING and order.on_wheel:
		return _lesson_job(_spot(Freezer), "freezer", words, "freezer")
	var pass_counter := _first(PassCounter) as PassCounter
	if pass_counter != null and pass_counter.held_item is CookedDish and pass_counter.held_item.order == order:
		return _lesson_job(pass_counter.interactable, "pick_up", words, "pass")
	return _wait("wait_food", words)


# Claimed like the same job outside the lesson (see next_step), so nobody else is sent too.
func _lesson_job(target: Interactable, hint: String, words: Dictionary, claim: Variant) -> Dictionary:
	var step := _step(target, hint, words)
	if not step.is_empty():
		step["claim"] = claim
	return step


# Nothing to walk to yet: just the line saying what's happening.
func _wait(hint: String, words: Dictionary) -> Dictionary:
	return { "key": hint, "hint": _hint(hint, words) }


func _job(target: Interactable, hint: String, claim: Variant, words := {}) -> Dictionary:
	return { "target": target, "key": hint, "hint": _hint(hint, words), "claim": claim }


func _step(target: Interactable, hint: String, words := {}) -> Dictionary:
	return { "target": target, "key": hint, "hint": _hint(hint, words) } if target != null else {}


# The nearest of `nodes` (each with an interactable) to the player.
func _nearest(player: Player, nodes: Array, hint: String, words := {}) -> Dictionary:
	if nodes.is_empty():
		return {}
	nodes.sort_custom(func(a, b): return _distance(player, a.interactable) < _distance(player, b.interactable))
	return _step(nodes[0].interactable, hint, words)


func _hint(hint: String, words: Dictionary) -> String:
	return String(settings().get("hints", {}).get(hint, hint)).format(words)


func _distance(player: Player, target: Interactable) -> float:
	return Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(target.global_position.x, target.global_position.z))


func _customers(state: Customer.State) -> Array:
	return customer_manager.get_children().filter(func(c): return c is Customer and c.state == state)


func _tables() -> Array:
	return _all(DiningTable)


# Furniture of one kind (it stays put, so it's found once).
func _all(type: Variant) -> Array:
	if not _found.has(type):
		_found[type] = get_parent().find_children("*", "", true, false).filter(func(n): return is_instance_of(n, type))
	return _found[type].duplicate()


func _first(type: Variant) -> Node:
	var found := _all(type)
	return found[0] if not found.is_empty() else null


# Where a player uses the first piece of furniture of this kind, or null.
func _spot(type: Variant) -> Interactable:
	var found := _first(type)
	return found.interactable if found != null else null


func _arrow_for(player: Player) -> GuideArrow:
	if not _arrows.has(player.player_index):
		var arrow := GuideArrow.new()
		add_child(arrow)
		_arrows[player.player_index] = arrow
	return _arrows[player.player_index]


# Points the arrow along the route to the step, or hides it when there's
# nothing to do, they're busy, or they've got there.
func _show(player: Player, arrow: GuideArrow, step: Dictionary, delta: float) -> void:
	var target: Interactable = step.get("target")
	# There once its prompt is the one showing (not something else close by), or right on top of it.
	var arrived := target != null and (player.interactor.focused == target or _distance(player, target) <= ON_TOP)
	if target == null or arrived or player.movement_locked:
		arrow.hide_arrow()
		_routes.erase(player.player_index)
		if target == null and step.has("hint") and not player.movement_locked:  # A wait: just the line.
			arrow.show_hint(player, step["hint"], view_manager.view_for(player.player_index) if view_manager != null else null)
		return
	var route: Dictionary = _routes.get(player.player_index, {})
	route["left"] = float(route.get("left", 0.0)) - delta
	if route.get("target") != target or route["left"] <= 0.0:
		route = { "target": target, "left": ROUTE_SECONDS, "points": _route(player.global_position, target.global_position) }
		_routes[player.player_index] = route
	arrow.point(player, _heading(player.global_position, route["points"], target.global_position), step["hint"],
			view_manager.view_for(player.player_index) if view_manager != null else null)


# Which way to walk: toward the route a little way ahead (straight at the target without one).
func _heading(from: Vector3, points: Array, goal: Vector3) -> Vector3:
	var here := Vector2(from.x, from.z)
	var aim := Vector2(goal.x, goal.z)
	for point: Vector2 in points:
		if here.distance_to(point) >= LOOK_AHEAD:
			aim = point
			break
	var heading := Vector3(aim.x - here.x, 0.0, aim.y - here.y)
	return heading.normalized() if heading.length() > 0.01 else Vector3.FORWARD


# The walking grid: which squares of the building a chef fits in.
func _build_grid(players: Array) -> void:
	_grid.region = Rect2i(0, 0, ceili(AREA.size.x / CELL), ceili(AREA.size.y / CELL))
	_grid.cell_size = Vector2.ONE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	var shape := CylinderShape3D.new()  # From just off the floor to head height, so low chair seats count.
	shape.radius = BODY_RADIUS
	shape.height = BODY_TOP - BODY_BOTTOM
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.exclude = players.map(func(p): return p.get_rid())
	var space := get_world_3d().direct_space_state
	for x in _grid.region.size.x:
		for y in _grid.region.size.y:
			query.transform = Transform3D(Basis(), _world(Vector2i(x, y)) + Vector3(0.0, (BODY_TOP + BODY_BOTTOM) / 2.0, 0.0))
			_grid.set_point_solid(Vector2i(x, y), not space.intersect_shape(query, 1).is_empty())


func _cell(at: Vector3) -> Vector2i:
	return Vector2i(floori((at.x - AREA.position.x) / CELL), floori((at.z - AREA.position.y) / CELL))


func _world(cell: Vector2i) -> Vector3:
	return Vector3(AREA.position.x + (cell.x + 0.5) * CELL, 0.0, AREA.position.y + (cell.y + 0.5) * CELL)


# The nearest square a chef can stand on (a seated customer is in their chair).
func _open_cell(at: Vector3) -> Vector2i:
	var cell := _cell(at)
	for ring in 8:
		var best := Vector2i(-1, -1)
		for dx in range(-ring, ring + 1):
			for dy in range(-ring, ring + 1):
				var c := cell + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == ring and _grid.is_in_boundsv(c) and not _grid.is_point_solid(c):
					if best.x < 0 or _world(c).distance_to(at) < _world(best).distance_to(at):
						best = c
		if best.x >= 0:
			return best
	return cell


# The walking route as floor points (x, z), or [] if there's none.
func _route(from: Vector3, to: Vector3) -> Array:
	if _grid.region.size == Vector2i.ZERO:
		return []
	var start := _open_cell(from)
	var end := _open_cell(to)
	if not _grid.is_in_boundsv(start) or not _grid.is_in_boundsv(end):
		return []
	# Customers on their feet (in line, walking) are in the way too, just for this route.
	var blocked: Array[Vector2i] = []
	for customer in customer_manager.get_children():
		if customer is Customer and not customer.is_seated():
			var at := _cell(customer.global_position)
			for dx in range(-CUSTOMER_CELLS, CUSTOMER_CELLS + 1):
				for dy in range(-CUSTOMER_CELLS, CUSTOMER_CELLS + 1):
					var c := at + Vector2i(dx, dy)
					if c != start and c != end and _grid.is_in_boundsv(c) and not _grid.is_point_solid(c):
						_grid.set_point_solid(c)
						blocked.append(c)
	var path := _grid.get_id_path(start, end, true)
	for c in blocked:
		_grid.set_point_solid(c, false)
	var points: Array = []
	for cell in path:
		var at := _world(cell)
		points.append(Vector2(at.x, at.z))
	return points
