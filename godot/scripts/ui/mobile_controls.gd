extends CanvasLayer
class_name MobileControls

## Browser / Touch Control Layer.
##
## SWTOR-inspired mobile RPG HUD foundation:
## - compact left joystick
## - bottom-centered primary action hotbar
## - visually separated utility slots
## - framed dark panels and readable slot colors
##
## Buttons route through the same InputMap actions as keyboard controls.

const MAX_RADIUS: float = 56.0
const DEAD_ZONE: float = 0.18
const PRIMARY_SLOT_SIZE: Vector2 = Vector2(48, 48)
const UTILITY_SLOT_SIZE: Vector2 = Vector2(62, 38)
const SLOT_GAP: float = 6.0
const JOYSTICK_SIZE: Vector2 = Vector2(128, 128)
const KNOB_SIZE: Vector2 = Vector2(54, 54)
const SAFE_MARGIN: float = 16.0
const BOTTOM_SAFE_MARGIN: float = 118.0
const PRIMARY_FONT_SIZE: int = 12
const UTILITY_FONT_SIZE: int = 11

const MOVE_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right"
]
const PRIMARY_ACTIONS: Array = [
	["ATK", &"attack", "1"],
	["HVY", &"heavy_attack", "2"],
	["GRD", &"guard", "3"],
	["CLS", &"class_ability", "4"],
	["USE", &"interact", "5"],
]
const UTILITY_ACTIONS: Array = [
	["JUMP", &"jump"],
	["RUN", &"sprint"],
	["CRAFT", &"craft"],
	["PLACE", &"place_build"],
]

var _joystick_base: Panel
var _joystick_knob: Panel
var _dragging: bool = false


func _ready() -> void:
	layer = 20
	_build_joystick()
	_build_primary_hotbar()
	_build_utility_bar()


func _build_joystick() -> void:
	_joystick_base = Panel.new()
	_joystick_base.name = "JoystickBase"
	_joystick_base.custom_minimum_size = JOYSTICK_SIZE
	_joystick_base.size = JOYSTICK_SIZE
	_joystick_base.modulate = Color(0.75, 0.9, 1.0, 0.52)
	_joystick_base.anchor_left = 0.0
	_joystick_base.anchor_top = 1.0
	_joystick_base.anchor_right = 0.0
	_joystick_base.anchor_bottom = 1.0
	_joystick_base.offset_left = SAFE_MARGIN
	_joystick_base.offset_top = -JOYSTICK_SIZE.y - BOTTOM_SAFE_MARGIN
	_joystick_base.offset_right = SAFE_MARGIN + JOYSTICK_SIZE.x
	_joystick_base.offset_bottom = -BOTTOM_SAFE_MARGIN
	add_child(_joystick_base)

	_joystick_knob = Panel.new()
	_joystick_knob.name = "JoystickKnob"
	_joystick_knob.custom_minimum_size = KNOB_SIZE
	_joystick_knob.size = KNOB_SIZE
	_joystick_knob.modulate = Color(0.95, 1.0, 1.0, 0.92)
	_joystick_knob.position = JOYSTICK_SIZE * 0.5 - KNOB_SIZE * 0.5
	_joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joystick_base.add_child(_joystick_knob)

	_joystick_base.gui_input.connect(_on_joystick_input)


func _build_primary_hotbar() -> void:
	var frame := PanelContainer.new()
	frame.name = "PrimaryHotbarFrame"
	frame.modulate = Color(0.82, 0.95, 1.0, 0.96)
	add_child(frame)

	var width := (PRIMARY_SLOT_SIZE.x * PRIMARY_ACTIONS.size()) + (SLOT_GAP * (PRIMARY_ACTIONS.size() - 1)) + 20.0
	var height := PRIMARY_SLOT_SIZE.y + 20.0
	frame.custom_minimum_size = Vector2(width, height)
	frame.size = Vector2(width, height)
	frame.anchor_left = 0.5
	frame.anchor_top = 1.0
	frame.anchor_right = 0.5
	frame.anchor_bottom = 1.0
	frame.offset_left = -width * 0.5
	frame.offset_top = -height - BOTTOM_SAFE_MARGIN
	frame.offset_right = width * 0.5
	frame.offset_bottom = -BOTTOM_SAFE_MARGIN

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	frame.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "PrimaryHotbar"
	row.add_theme_constant_override("separation", int(SLOT_GAP))
	margin.add_child(row)

	for entry in PRIMARY_ACTIONS:
		_add_hotbar_slot(row, entry[0], entry[1], entry[2], PRIMARY_SLOT_SIZE, PRIMARY_FONT_SIZE, true)


func _build_utility_bar() -> void:
	var frame := PanelContainer.new()
	frame.name = "UtilityBarFrame"
	frame.modulate = Color(1.0, 1.0, 1.0, 0.88)
	add_child(frame)

	var width := (UTILITY_SLOT_SIZE.x * UTILITY_ACTIONS.size()) + (SLOT_GAP * (UTILITY_ACTIONS.size() - 1)) + 18.0
	var height := UTILITY_SLOT_SIZE.y + 16.0
	frame.custom_minimum_size = Vector2(width, height)
	frame.size = Vector2(width, height)
	frame.anchor_left = 0.5
	frame.anchor_top = 1.0
	frame.anchor_right = 0.5
	frame.anchor_bottom = 1.0
	frame.offset_left = -width * 0.5
	frame.offset_top = -height - BOTTOM_SAFE_MARGIN - 78.0
	frame.offset_right = width * 0.5
	frame.offset_bottom = -BOTTOM_SAFE_MARGIN - 78.0

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 8)
	frame.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "UtilityBar"
	row.add_theme_constant_override("separation", int(SLOT_GAP))
	margin.add_child(row)

	for entry in UTILITY_ACTIONS:
		_add_hotbar_slot(row, entry[0], entry[1], "", UTILITY_SLOT_SIZE, UTILITY_FONT_SIZE, false)


func _add_hotbar_slot(parent: Node, label: String, action: StringName, slot_number: String, size: Vector2, font_size: int, primary: bool) -> void:
	var btn := Button.new()
	btn.text = _format_button_text(label, slot_number)
	btn.custom_minimum_size = size
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.tooltip_text = label
	btn.modulate = _button_tint(action, primary)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.pressed.connect(func() -> void:
		Input.action_press(action)
		get_tree().create_timer(0.12).timeout.connect(func():
			Input.action_release(action)
		)
	)
	parent.add_child(btn)

func _format_button_text(label: String, slot_number: String) -> String:
	if slot_number.is_empty():
		return label
	return "%s\n%s" % [label, slot_number]


func _button_tint(action: StringName, primary: bool) -> Color:
	if action == &"interact":
		return Color(0.0, 0.8, 1.0, 0.96)
	if action == &"attack":
		return Color(1.0, 0.25, 0.18, 0.96)
	if action == &"heavy_attack":
		return Color(1.0, 0.45, 0.15, 0.96)
	if action == &"guard":
		return Color(0.25, 0.55, 1.0, 0.96)
	if action == &"class_ability":
		return Color(0.62, 0.32, 1.0, 0.96)
	if primary:
		return Color(0.9, 0.95, 1.0, 0.92)
	return Color(0.75, 0.8, 0.9, 0.82)


func _on_joystick_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			_dragging = true
			_update_joystick(event.position)
		else:
			_dragging = false
			_reset_joystick()
	elif _dragging and (event is InputEventScreenDrag or event is InputEventMouseMotion):
		_update_joystick(event.position)


func _update_joystick(local_pos: Vector2) -> void:
	var center: Vector2 = _joystick_base.size * 0.5
	var delta: Vector2 = local_pos - center
	if delta.length() > MAX_RADIUS:
		delta = delta.normalized() * MAX_RADIUS
	_joystick_knob.position = center + delta - _joystick_knob.size * 0.5

	var nx: float = clamp(delta.x / MAX_RADIUS, -1.0, 1.0)
	var ny: float = clamp(delta.y / MAX_RADIUS, -1.0, 1.0)
	_set_axis_pair(&"move_right", &"move_left", nx)
	_set_axis_pair(&"move_back", &"move_forward", ny)


func _set_axis_pair(positive_action: StringName, negative_action: StringName, value: float) -> void:
	if value > DEAD_ZONE:
		Input.action_press(positive_action, value)
		Input.action_release(negative_action)
	elif value < -DEAD_ZONE:
		Input.action_press(negative_action, -value)
		Input.action_release(positive_action)
	else:
		Input.action_release(positive_action)
		Input.action_release(negative_action)


func _reset_joystick() -> void:
	_joystick_knob.position = _joystick_base.size * 0.5 - _joystick_knob.size * 0.5
	for action in MOVE_ACTIONS:
		Input.action_release(action)
