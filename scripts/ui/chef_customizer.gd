# ChefCustomizer: make your chef. Pages for Body, Face, Hair, Clothes,
# Accessories and Face Paint (a new chef first gets a Start page to pick one
# of the presets in data/presets/ to work from), with the chef beside them (drag to turn them, or
# switch on Spin to have them turn slowly) and changing as you pick. Done saves the look on the
# account (Accounts.set_appearance), which redresses that player's chef.
# Opened by the AccountPicker for a new chef, by the ChefWardrobe in the
# restaurant, and from the debug panel. Pauses the game while it's up. Works
# with mouse, keyboard or gamepad (focus moves between the buttons).
class_name ChefCustomizer
extends CanvasLayer

signal finished(saved: bool)

const PAGES := ["Body", "Face", "Hair", "Clothes", "Accessories", "Face Paint"]
const START_PAGE := "Start"
const FACE_PAGES := ["Face", "Face Paint"]
const FEATURE_NAMES := { "eyes": "Eyes", "brows": "Eyebrows", "nose": "Nose", "mouth": "Mouth" }
const SLOT_NAMES := { "top": "Tops", "bottom": "Bottoms", "dress": "Dresses", "shoes": "Shoes", "apron": "Aprons", "hat": "Hats", "glasses": "Glasses", "face_accessory": "Face accessories" }
const MAX_FACE_PAINT := 3
const SPIN_SPEED := 0.5  # Radians a second while spinning and nobody's turning them.
const BODY_VIEW := [Vector3(0, 1.0, 3.6), Vector3(0, 0.85, 0)]  # Camera position, looking at.
const FACE_VIEW := [Vector3(0, 1.3, 2.4), Vector3(0, 1.22, 0)]
const INK := Color(0.3, 0.22, 0.15)
const PAPER := Color(0.99, 0.95, 0.86)

var account_id := ""
var can_cancel := true
var look: CharacterAppearance
var spinning := false  # The Spin toggle under the preview: off to start with.
var preset_id := ""  # The preset picked on the Start page (new chefs only).

var _chef: ChefModel
var _pivot := Node3D.new()
var _camera := Camera3D.new()
var _layout := BoxContainer.new()
var _page_box := VBoxContainer.new()
var _scroll := ScrollContainer.new()
var _title := Label.new()
var _tabs: Array[Button] = []
var _refreshers: Array[Callable] = []  # Bring the buttons up to date with the look.
var _page := ""
var _pages: Array = PAGES.duplicate()
var _dragging := false
var _was_paused := false


# Opens it for `account_id`'s chef; `finished` says whether they saved.
static func open(parent: Node, for_account: String, cancel_allowed := true) -> ChefCustomizer:
	var customizer := ChefCustomizer.new()
	customizer.account_id = for_account
	customizer.can_cancel = cancel_allowed
	parent.add_child(customizer)
	return customizer


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	look = Accounts.appearance_of_account(account_id).copy()
	if not Accounts.has_appearance(account_id) and not Wardrobe.presets().is_empty():
		_pages.push_front(START_PAGE)  # A new chef: pick where to start from.
		use_preset(Wardrobe.presets()[0])
	_was_paused = get_tree().paused
	get_tree().paused = true
	_build()
	_aim(BODY_VIEW, 1.0)
	get_viewport().size_changed.connect(_fit)
	_fit()
	show_page(_pages[0])
	_tabs[0].grab_focus()


func _process(delta: float) -> void:
	if spinning and not _dragging:
		_pivot.rotation.y += SPIN_SPEED * delta


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and can_cancel:
		get_viewport().set_input_as_handled()
		close(false)


func close(save: bool) -> void:
	if save:
		Accounts.set_appearance(account_id, look)
	get_tree().paused = _was_paused
	finished.emit(save)
	queue_free()


func show_page(page: String) -> void:
	_page = page
	for tab in _tabs:
		tab.set_pressed_no_signal(tab.text == page)
	for child in _page_box.get_children():
		child.queue_free()
	_refreshers.clear()
	match page:
		START_PAGE:
			_start_page()
		"Body":
			_body_page()
		"Face":
			_face_page()
		"Hair":
			_hair_page()
		"Clothes":
			_clothes_page()
		"Accessories":
			_accessories_page()
		"Face Paint":
			_face_paint_page()
	_refresh()
	_scroll.scroll_vertical = 0
	var view: Array = FACE_VIEW if page in FACE_PAGES else BODY_VIEW
	var tween := create_tween()
	tween.tween_method(func(t: float): _aim(view, t), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_SINE)


# Starts over from a preset (data/presets/), wearing anything unlocked that's
# worn straight away.
func use_preset(preset: Dictionary) -> void:
	preset_id = preset["id"]
	look = CharacterAppearance.from_dict(preset["look"])
	for item_id in Wardrobe.auto_wear_ids():
		look.wear(item_id)
	if _chef != null:
		_chef.apply_appearance(look)


# Picks something for every part at random.
func randomize_look() -> void:
	var looks := Wardrobe.looks()
	look.body_shape = looks.get("body_shapes", [{ "id": "standard" }]).pick_random()["id"]
	look.skin_color = Color(String(looks.get("skin_colors", ["#f1c7a0"]).pick_random()))
	look.hair_color = Color(String(looks.get("hair_colors", ["#5a3a22"]).pick_random()))
	look.eye_color = Color(String(looks.get("eye_colors", ["#3b2a20"]).pick_random()))
	for feature in CharacterAppearance.FEATURES:
		var parts := Wardrobe.face_parts(feature)
		if not parts.is_empty():
			look.set_feature(feature, parts.pick_random()["id"], Vector2.ZERO, 1.0)
	look.face_paint.clear()
	if randf() < 0.4 and not Wardrobe.face_parts("face_paint").is_empty():
		look.face_paint.append(Wardrobe.face_parts("face_paint").pick_random()["id"])
	for slot in ["hair", "hat", "glasses"]:
		look.take_off(slot)
		var choices := Wardrobe.of_slot(slot)
		if not choices.is_empty() and randf() < (0.9 if slot == "hair" else 0.3):
			look.wear(choices.pick_random()["id"])
	var dresses := Wardrobe.of_slot("dress")
	if not dresses.is_empty() and randf() < 0.25:
		look.wear(dresses.pick_random()["id"])
	else:
		for slot in ["top", "bottom"]:
			var choices := Wardrobe.of_slot(slot)
			if not choices.is_empty():
				look.wear(choices.pick_random()["id"])
	_changed()
	show_page(_page)


func _changed() -> void:
	_chef.apply_appearance(look)
	_refresh()


func _refresh() -> void:
	for refresh in _refreshers:
		refresh.call()


# --- Pages ---

func _start_page() -> void:
	_heading("Start from")
	_label("Pick one, then change anything you like.", 16)
	var row := _row()
	for preset in Wardrobe.presets():
		var id: String = preset["id"]
		var button := _option(row, preset.get("name", id), func(): use_preset(preset), func(): return preset_id == id)
		button.custom_minimum_size = Vector2(170, 64)
	var next := _button(_page_box, "Next: Body", show_page.bind("Body"))
	next.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func _body_page() -> void:
	_heading("Body shape")
	var row := _row()
	for shape in Wardrobe.looks().get("body_shapes", []):
		var id: String = shape["id"]
		_option(row, shape.get("name", id), func(): look.body_shape = id, func(): return look.body_shape == id)
	_heading("Skin")
	_colors("skin_colors", func(): return look.skin_color, func(color): look.skin_color = color)


func _face_page() -> void:
	for feature in CharacterAppearance.FEATURES:
		_heading(FEATURE_NAMES[feature])
		var row := _row()
		for part in Wardrobe.face_parts(feature):
			var id: String = part["id"]
			_option(row, part.get("name", id), func(): look.set_feature(feature, id), func(): return look.feature_id(feature) == id)
		var spacing: bool = feature in ["eyes", "brows"]
		_slider("Up / down", -0.08, 0.08, func(): return look.feature_offset(feature).y,
			func(value): look.set_feature(feature, "", Vector2(look.feature_offset(feature).x, value)))
		if spacing:
			_slider("Apart", -0.05, 0.08, func(): return look.feature_offset(feature).x,
				func(value): look.set_feature(feature, "", Vector2(value, look.feature_offset(feature).y)))
		_slider("Size", 0.7, 1.4, func(): return look.feature_scale(feature), func(value): look.set_feature(feature, "", null, value))
		if feature == "eyes":
			_label("Eye color", 18)
			_colors("eye_colors", func(): return look.eye_color, func(color): look.eye_color = color)
	_heading("Try a face")
	var faces := _row()
	for expression in ["happy", "surprised", "sad", "focused"]:
		_button(faces, expression.capitalize(), func(): _chef.face.set_expression(expression, 1.5))
	_button(faces, "Blink", func(): _chef.face.blink())


func _hair_page() -> void:
	_heading("Hairstyle")
	_slot_options("hair", "None")
	_heading("Hair color")
	_colors("hair_colors", func(): return look.hair_color, func(color): look.hair_color = color)


func _clothes_page() -> void:
	for slot in ["top", "bottom", "dress", "apron", "shoes"]:
		if not Wardrobe.of_slot(slot).is_empty():
			_heading(SLOT_NAMES[slot])
			_slot_options(slot, "None")


func _accessories_page() -> void:
	var any := false
	for slot in Wardrobe.ACCESSORY_SLOTS:
		if not Wardrobe.of_slot(slot).is_empty():
			any = true
			_heading(SLOT_NAMES[slot])
			_slot_options(slot, "None")
	if not any:
		_label("Nothing here yet.", 18)


func _face_paint_page() -> void:
	_heading("Face paint")
	_label("Pick up to %d." % MAX_FACE_PAINT, 16)
	var row := _row()
	for part in Wardrobe.face_parts("face_paint"):
		var id: String = part["id"]
		var button := _option(row, part.get("name", id), func():
			if id in look.face_paint or look.face_paint.size() < MAX_FACE_PAINT:
				look.toggle_face_paint(id), func(): return id in look.face_paint)
		_refreshers.append(func(): button.disabled = not id in look.face_paint and look.face_paint.size() >= MAX_FACE_PAINT)


# One button per item for `slot`, plus "None".
func _slot_options(slot: String, none_text: String) -> void:
	var row := _row()
	_option(row, none_text, func(): look.take_off(slot), func(): return look.worn(slot).is_empty())
	for item in Wardrobe.of_slot(slot):
		var id: String = item["id"]
		_option(row, item.get("name", id), func(): look.wear(id), func(): return look.worn(slot) == id)


# --- Building blocks ---

func _heading(text: String) -> void:
	var label := _label(text, 22)
	label.add_theme_color_override("font_color", Color(0.45, 0.28, 0.16))


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	_page_box.add_child(label)
	return label


func _row() -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	_page_box.add_child(row)
	return row


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


# A choice that shows whether it's the one picked (`is_on`).
func _option(parent: Control, text: String, pick: Callable, is_on: Callable) -> Button:
	var button := _button(parent, text, func():
		pick.call()
		_changed())
	button.toggle_mode = true
	_refreshers.append(func(): button.set_pressed_no_signal(is_on.call()))
	return button


func _slider(text: String, low: float, high: float, value_now: Callable, set_value: Callable) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 120
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", INK)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = (high - low) / 40.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 32
	slider.set_value_no_signal(value_now.call())
	slider.value_changed.connect(func(value):
		set_value.call(value)
		_changed())
	_refreshers.append(func(): slider.set_value_no_signal(value_now.call()))
	row.add_child(slider)
	_page_box.add_child(row)


# Swatches from data/appearance.json's `palette`, then any color you like.
func _colors(palette: String, color_now: Callable, set_color: Callable) -> void:
	var row := _row()
	for hex in Wardrobe.looks().get(palette, []):
		var color := Color(String(hex))
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(44, 44)
		swatch.toggle_mode = true
		swatch.tooltip_text = String(hex)
		for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = color
			style.set_corner_radius_all(22)
			var picked: bool = state in ["pressed", "hover_pressed"]
			style.set_border_width_all(4 if picked else (3 if state == "focus" else 2))
			style.border_color = INK if picked or state == "focus" else color.darkened(0.25)
			swatch.add_theme_stylebox_override(state, style)
		swatch.pressed.connect(func():
			set_color.call(color)
			_changed())
		_refreshers.append(func(): swatch.set_pressed_no_signal(color_now.call().is_equal_approx(color)))
		row.add_child(swatch)
	var custom := ColorPickerButton.new()
	custom.text = "Other..."
	custom.custom_minimum_size = Vector2(100, 44)
	custom.edit_alpha = false
	custom.color_changed.connect(func(color):
		set_color.call(color)
		_changed())
	_refreshers.append(func(): custom.color = color_now.call())
	row.add_child(custom)


# --- Layout ---

func _build() -> void:
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.45)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_border_width_all(6)
	style.border_color = Color(0.55, 0.38, 0.25)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)
	panel.theme = _theme()
	_layout.add_theme_constant_override("separation", 20)
	panel.add_child(_layout)
	_layout.add_child(_build_preview())

	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.size_flags_stretch_ratio = 1.2
	side.add_theme_constant_override("separation", 12)
	_layout.add_child(side)
	_title.text = "Make your chef" if not Accounts.has_appearance(account_id) else "%s's look" % Accounts.get_account(account_id).get("name", "Chef")
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color(0.45, 0.28, 0.16))
	side.add_child(_title)
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	side.add_child(tabs)
	for page in _pages:
		var tab := Button.new()
		tab.text = page
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(0, 44)
		tab.add_theme_font_size_override("font_size", 18)
		tab.pressed.connect(show_page.bind(page))
		tabs.add_child(tab)
		_tabs.append(tab)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(_scroll)
	_page_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_box.add_theme_constant_override("separation", 10)
	_scroll.add_child(_page_box)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	side.add_child(bottom)
	_button(bottom, "Surprise me", randomize_look)
	if can_cancel:
		_button(bottom, "Cancel", close.bind(false))
	var done := _button(bottom, "Done", close.bind(true))
	done.custom_minimum_size.x = 120


# Buttons in the restaurant's colors, the picked ones dark so you can tell.
func _theme() -> Theme:
	var theme := Theme.new()
	var looks := {
		"normal": [Color(0.91, 0.85, 0.74), Color(0.78, 0.66, 0.5)],
		"hover": [Color(0.95, 0.89, 0.78), Color(0.55, 0.38, 0.25)],
		"pressed": [Color(0.55, 0.36, 0.2), Color(0.4, 0.25, 0.13)],
		"hover_pressed": [Color(0.6, 0.4, 0.23), Color(0.4, 0.25, 0.13)],
		"disabled": [Color(0.9, 0.87, 0.82), Color(0.85, 0.8, 0.72)],
		"focus": [Color(0, 0, 0, 0), Color(0.95, 0.6, 0.2)],
	}
	for state in looks:
		var style := StyleBoxFlat.new()
		style.bg_color = looks[state][0]
		style.border_color = looks[state][1]
		style.set_border_width_all(3 if state == "focus" else 2)
		style.draw_center = state != "focus"
		style.set_corner_radius_all(10)
		style.content_margin_left = 14
		style.content_margin_right = 14
		theme.set_stylebox(state, "Button", style)
	for color_name in ["font_color", "font_hover_color", "font_focus_color"]:
		theme.set_color(color_name, "Button", INK)
	for color_name in ["font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(color_name, "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(0.6, 0.55, 0.5))
	return theme


# The chef on a little rug in their own world, with the Spin toggle under them.
func _build_preview() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.custom_minimum_size = Vector2(260, 300)
	container.gui_input.connect(_on_preview_input)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.93, 0.87, 0.76)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.55
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 25, 0)
	light.shadow_enabled = true
	viewport.add_child(light)
	viewport.add_child(_camera)
	_camera.fov = 40
	var rug := MeshInstance3D.new()
	var rug_mesh := CylinderMesh.new()
	rug_mesh.top_radius = 0.75
	rug_mesh.bottom_radius = 0.75
	rug_mesh.height = 0.03
	var rug_material := StandardMaterial3D.new()
	rug_material.albedo_color = Color(0.75, 0.42, 0.35)
	rug_mesh.material = rug_material
	rug.mesh = rug_mesh
	viewport.add_child(rug)
	viewport.add_child(_pivot)
	_chef = ChefModel.new()
	_chef.look = look
	_pivot.add_child(_chef)
	box.add_child(container)
	var spin := _button(box, "Spin", func(): spinning = not spinning)
	spin.name = "Spin"
	spin.toggle_mode = true
	spin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	spin.custom_minimum_size.x = 120
	return box


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_pivot.rotation.y += event.relative.x * 0.01
	elif event is InputEventScreenDrag:
		_pivot.rotation.y += event.relative.x * 0.01


var _aim_from: Array = BODY_VIEW
var _looking_at: Vector3 = BODY_VIEW[1]


# Moves the camera `t` of the way from where it was to `view`.
func _aim(view: Array, t: float) -> void:
	if t <= 0.0:
		_aim_from = [_camera.position, _looking_at]
	_looking_at = (_aim_from[1] as Vector3).lerp(view[1], t)
	_camera.look_at_from_position((_aim_from[0] as Vector3).lerp(view[0], t), _looking_at)


# Side by side on a wide screen, preview on top on a tall one.
func _fit() -> void:
	var size := get_viewport().get_visible_rect().size
	_layout.vertical = size.y > size.x
