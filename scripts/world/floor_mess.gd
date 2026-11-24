# FloorMess: something on the floor to clean up: a spill by the stoves, peelings
# by a chopping board, crumbs round a table (see FloorCare). Any chef with free
# hands stands by it and holds interact: out comes a mop (a broom for crumbs)
# and it shrinks away. Two chefs at it are twice as quick; letting go keeps
# what's been done. It never slows anyone down or upsets a customer.
class_name FloorMess
extends Node3D

const GROUP := "floor_mess"
const REACH := 1.6            # A chef further off than this has stopped.
const KINDS := {              # The prompt, its colors, and how many bits are in it.
	"spill": { "prompt": "Mop up (hold)", "colors": ["#FFF8E8", "#9CCBE8", "#6E3F22"], "bits": 0 },
	"peelings": { "prompt": "Sweep up (hold)", "colors": ["#E07228", "#8DBE3E", "#C98A4E"], "bits": 16 },
	"crumbs": { "prompt": "Sweep up (hold)", "colors": ["#F0D9A8", "#E0B878", "#FBEBC8"], "bits": 22 },
}

signal cleaned(mess: FloorMess, player_index: int)

var kind := "spill"
var seconds := 1.6            # Of one chef cleaning.

var _left := 1.0
var _moppers := {}            # Player -> its mop.
var _look := Node3D.new()
var _interactable := Interactable.new()
var _time := 0.0
var _swish: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group(GROUP)
	add_child(_look)
	_build()
	_look.scale = Vector3.ONE * 0.05
	create_tween().tween_property(_look, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_interactable.prompt = KINDS[kind]["prompt"]
	_interactable.radius = 1.0
	_interactable.prompt_height = 0.7
	_interactable.priority = -1  # Anything else in reach comes first.
	_interactable.prompt_for_player = _prompt_for
	_interactable.interacted.connect(_start)
	add_child(_interactable)
	_swish = AudioStreamPlayer3D.new()
	_swish.stream = CookSounds.get_sound("drizzle")
	_swish.volume_db = -14.0
	add_child(_swish)


func _exit_tree() -> void:
	for player in _moppers.keys():
		_stop(player)


func is_cleaning() -> bool:
	return not _moppers.is_empty()


func _prompt_for(player_index: int) -> String:
	var player := Player.find(get_tree(), player_index)
	return _interactable.prompt if player != null and player.held_item == null else ""


func _start(player_index: int) -> void:
	var player := Player.find(get_tree(), player_index)
	if player == null or player.held_item != null or player in _moppers or player.movement_locked or _left <= 0.0:
		return
	player.movement_locked = true
	player.interactor.lock_to(_interactable)
	var mop := _make_mop()
	add_child(mop)
	_moppers[player] = mop


func _stop(player: Variant) -> void:
	var mop: Node3D = _moppers[player]
	_moppers.erase(player)
	mop.queue_free()
	if is_instance_valid(player):
		player.movement_locked = false
		player.interactor.unlock()


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_time += delta
	for player in _moppers.keys():
		if not is_instance_valid(player) or not player.input.is_interact_pressed() or player.global_position.distance_to(global_position) > REACH:
			_stop(player)
	if _swish.playing != is_cleaning():
		_swish.playing = is_cleaning()
	if not is_cleaning():
		return
	var last := -1
	for player: Player in _moppers:
		_left -= delta / seconds
		last = player.player_index
		_swing(player, _moppers[player])
	_look.scale = Vector3(maxf(_left, 0.02), 1.0, maxf(_left, 0.02))
	if _left <= 0.0:
		_finish(last)


# The mop's head goes to and fro over the mess, its handle leaning to the chef.
func _swing(player: Player, mop: Node3D) -> void:
	var to_chef := player.global_position - global_position
	to_chef.y = 0.0
	if to_chef.length() < 0.2:
		to_chef = CameraRig.screen_to_world(Vector3(0.0, 0.0, 0.2))
	var side := to_chef.normalized().rotated(Vector3.UP, PI * 0.5)
	var at := global_position + side * sin(_time * 9.0) * 0.28 * maxf(_left, 0.35)
	var top := player.global_position + Vector3.UP * 0.75 - to_chef.normalized() * 0.15
	mop.global_position = at + Vector3.UP * 0.03
	mop.global_basis = Basis(Quaternion(Vector3.UP, (top - at).normalized()))
	player.visual.rotation.y = lerp_angle(player.visual.rotation.y, atan2(-to_chef.x, -to_chef.z), 0.2)


func _finish(player_index: int) -> void:
	for player: Player in _moppers.keys():
		player.ignore_interact_until_released()
		_stop(player)
	_swish.stop()
	_interactable.enabled = false
	remove_from_group(GROUP)
	cleaned.emit(self, player_index)
	_sparkle()
	var ding := AudioStreamPlayer3D.new()
	ding.stream = CookSounds.get_sound("ding")
	ding.volume_db = -10.0
	ding.pitch_scale = 1.5
	add_child(ding)
	ding.play()
	_look.visible = false
	await get_tree().create_timer(1.0).timeout
	queue_free()


func _sparkle() -> void:
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 0.9
	sparks.amount = 14
	sparks.lifetime = 0.7
	sparks.direction = Vector3.UP
	sparks.spread = 60.0
	sparks.initial_velocity_min = 0.6
	sparks.initial_velocity_max = 1.3
	sparks.gravity = Vector3(0.0, -1.5, 0.0)
	var dot := SphereMesh.new()
	dot.radius = 0.025
	dot.height = 0.05
	dot.material = _paint(Color(1.0, 0.98, 0.85))
	sparks.mesh = dot
	sparks.position.y = 0.1
	add_child(sparks)
	sparks.emitting = true


# A puddle of overlapping flat blobs, or a scatter of bits.
func _build() -> void:
	var colors: Array = KINDS[kind]["colors"]
	if KINDS[kind]["bits"] == 0:
		var paint := _paint(Color(String(colors.pick_random())))
		paint.roughness = 0.2
		for i in 6:
			var blob := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			var radius := randf_range(0.12, 0.2) if i > 0 else 0.26
			disc.top_radius = radius
			disc.bottom_radius = radius
			disc.height = 0.012
			disc.radial_segments = 24
			disc.material = paint
			blob.mesh = disc
			var out := Vector2.from_angle(TAU * i / 5.0 + randf_range(-0.3, 0.3)) * (randf_range(0.16, 0.27) if i > 0 else 0.0)
			blob.position = Vector3(out.x, 0.012, out.y)
			blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_look.add_child(blob)
	var paints := colors.map(func(c): return _paint(Color(String(c))))
	for i in int(KINDS[kind]["bits"]):
		var bit := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.07, 0.015, 0.03) if kind == "peelings" else Vector3.ONE * randf_range(0.03, 0.06)
		box.material = paints[i % paints.size()]
		bit.mesh = box
		var out := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * 0.4
		bit.position = Vector3(out.x, 0.02, out.y)
		bit.rotation = Vector3(randf_range(-0.3, 0.3), randf() * TAU, randf_range(-0.3, 0.3))
		_look.add_child(bit)


func _make_mop() -> Node3D:
	var mop := Node3D.new()
	var handle := MeshInstance3D.new()
	var stick := CylinderMesh.new()
	stick.top_radius = 0.022
	stick.bottom_radius = 0.022
	stick.height = 1.1
	stick.material = KitchenProps.handle_wood()
	handle.mesh = stick
	handle.position.y = 0.6
	mop.add_child(handle)
	var broom := kind != "spill"
	var head := KitchenProps.soft_block(Vector3(0.3, 0.1, 0.12) if broom else Vector3(0.28, 0.09, 0.2), KitchenProps.BRASS if broom else Color("#EDE6D6"))
	head.position.y = 0.05
	mop.add_child(head)
	return mop


static func _paint(color: Color) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.roughness = 0.8
	return paint
