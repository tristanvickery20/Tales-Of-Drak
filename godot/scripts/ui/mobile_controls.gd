extends CanvasLayer
class_name MobileControls

## Stage 8.6 — Browser / Touch Control Layer.
##
## Builds a minimal on-screen control overlay for iPhone/browser testing.
## The overlay is intentionally obvious: left joystick + right action panel.
## Buttons route through the same InputMap actions as keyboard controls.

const MAX_RADIUS: float = 72.0
const DEAD_ZONE: float = 0.18
const BUTTON_SIZE: Vector2 = Vector2(132, 58)
const BUTTON_GAP: float = 10.0
const JOYSTICK_SIZE: Vector2 = Vector2(180, 180)
const KNOB_SIZE: Vector2 = Vector2(72, 72)
const SAFE_MARGIN: float = 28.0
const BOTTOM_SAFE_MARGIN: float = 132.0
const BUTTON_FONT_SIZE: int = 20

const MOVE_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right"
]
const ACTION_BUTTONS: Array = [
	["JUMP",     &"jump"],
	["SPRINT",   &"sprint"],
	["INTERACT", &"interact"],
	["CRAFT",    &"craft"],
	["PLACE",    &"place_build"],
]

var _joystick_base: Panel
var _joystick_knob: Panel
var _dragging: bool = false


func _ready() -> void:
	layer = 20
	_build_joystick()
	_build_action_buttons()


func _build_joystick() -> void:
	_joystick_base = Panel.new()
	_joystick_base.name = "JoystickBase"
	_joystick_base.custom_minimum_size = JOYSTICK_SIZE
	_joystick_base.size = JOYSTICK_SIZE
	_joystick_base.modulate = Color(1.0, 1.0, 1.0, 0.58)
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
	_joystick_knob.modulate = Color(1.0, 1.0, 1.0, 0.9)
	_joystick_knob.position = JOYSTICK_SIZE * 0.5 - KNOB_SIZE * 0.5
	_joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joystick_base.add_child(_joystick_knob)

	_joystick_base.gui_input.connect(_on_joystick_input)


func _build_action_buttons() -> void:
	var stack := VBoxContainer.new()
	stack.name = "ActionButtons"
	stack.add_theme_constant_override("separation", int(BUTTON_GAP))
	stack.modulate = Color(1.0, 1.0, 1.0, 0.96)
	add_child(stack)

	var total_h: float = (BUTTON_SIZE.y * float(ACTION_BUTTONS.size())) + (BUTTON_GAP * float(ACTION_BUTTONS.size() - 1))
	stack.custom_minimum_size = Vector2(BUTTON_SIZE.x, total_h)
	stack.size = Vector2(BUTTON_SIZE.x, total_h)
	stack.anchor_left = 1.0
	stack.anchor_top = 1.0
	stack.anchor_right = 1.0
	stack.anchor_bottom = 1.0
	stack.offset_left = -BUTTON_SIZE.x - SAFE_MARGIN
	stack.offset_top = -total_h - BOTTOM_SAFE_MARGIN
	stack.offset_right = -SAFE_MARGIN
	stack.offset_bottom = -BOTTOM_SAFE_MARGIN

	for entry in ACTION_BUTTONS:
		var label: String = entry[0]
		var action: StringName = entry[1]
		_add_action_button(stack, label, action)


func _add_action_button(parent: Node, label: String, action: StringName) -> void:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = BUTTON_SIZE
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.modulate = Color(0.15, 0.85, 1.0, 0.92) if action == &"interact" else Color(1.0, 1.0, 1.0, 0.88)
	btn.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	btn.button_down.connect(func() -> void: Input.action_press(action))
	btn.button_up.connect(func() -> void: Input.action_release(action))
	parent.add_child(btn)


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
