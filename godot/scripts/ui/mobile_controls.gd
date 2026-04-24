extends CanvasLayer
class_name MobileControls

## Stage 8.6 — Browser / Touch Control Layer.
##
## Builds a minimal on-screen control overlay (left thumbstick + right action
## buttons) for the existing test world. Inputs are routed through the same
## Godot InputMap actions as the keyboard, so all existing systems
## (ThirdPersonController, gather/craft/place handlers) react identically
## whether the input came from keys or the touchscreen.
##
## The UI is built programmatically so the .tscn stays small and only needs
## to add this single CanvasLayer node.

const MAX_RADIUS: float = 80.0
const DEAD_ZONE: float = 0.18
const BUTTON_SIZE: Vector2 = Vector2(120, 72)
const BUTTON_GAP: float = 14.0
const JOYSTICK_SIZE: Vector2 = Vector2(200, 200)
const KNOB_SIZE: Vector2 = Vector2(80, 80)
const SCREEN_MARGIN: float = 32.0
const BUTTON_FONT_SIZE: int = 22

const MOVE_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right"
]
const ACTION_BUTTONS: Array = [
	["Jump",     &"jump"],
	["Sprint",   &"sprint"],
	["Interact", &"interact"],
	["Craft",    &"craft"],
	["Place",    &"place_build"],
]

var _joystick_base: Panel
var _joystick_knob: Panel
var _dragging: bool = false


func _ready() -> void:
	layer = 5
	_build_joystick()
	_build_action_buttons()


func _build_joystick() -> void:
	_joystick_base = Panel.new()
	_joystick_base.name = "JoystickBase"
	_joystick_base.custom_minimum_size = JOYSTICK_SIZE
	_joystick_base.size = JOYSTICK_SIZE
	_joystick_base.modulate = Color(1.0, 1.0, 1.0, 0.55)
	_joystick_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT, true)
	_joystick_base.position = Vector2(SCREEN_MARGIN, -JOYSTICK_SIZE.y - SCREEN_MARGIN)
	add_child(_joystick_base)

	_joystick_knob = Panel.new()
	_joystick_knob.name = "JoystickKnob"
	_joystick_knob.custom_minimum_size = KNOB_SIZE
	_joystick_knob.size = KNOB_SIZE
	_joystick_knob.modulate = Color(1.0, 1.0, 1.0, 0.85)
	_joystick_knob.position = JOYSTICK_SIZE * 0.5 - KNOB_SIZE * 0.5
	_joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joystick_base.add_child(_joystick_knob)

	_joystick_base.gui_input.connect(_on_joystick_input)


func _build_action_buttons() -> void:
	var stack := VBoxContainer.new()
	stack.name = "ActionButtons"
	stack.add_theme_constant_override("separation", int(BUTTON_GAP))
	add_child(stack)

	var total_h: float = (BUTTON_SIZE.y + BUTTON_GAP) * float(ACTION_BUTTONS.size())
	stack.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT, true)
	stack.size = Vector2(BUTTON_SIZE.x, total_h)
	stack.position = Vector2(-BUTTON_SIZE.x - SCREEN_MARGIN, -total_h - SCREEN_MARGIN)

	for entry in ACTION_BUTTONS:
		var label: String = entry[0]
		var action: StringName = entry[1]
		_add_action_button(stack, label, action)


func _add_action_button(parent: Node, label: String, action: StringName) -> void:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = BUTTON_SIZE
	btn.modulate = Color(1.0, 1.0, 1.0, 0.85)
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
