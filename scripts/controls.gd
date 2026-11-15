extends Node
## Ovládání (gamepad Legion Go S / Xbox i klávesnice):
##   Pohyb:  levá páčka / D-pad / šipky / WASD
##   Úder:   X  / J
##   Skok:   A  / K, mezerník
##   Úskok:  B  / L, Shift
##   Magie:  Y  / I
##   Pauza:  Start / Esc

func _ready() -> void:
	_action("left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_action("right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_action("up", [KEY_UP, KEY_W], [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_action("down", [KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_action("attack", [KEY_J, KEY_X], [JOY_BUTTON_X], -1, 0.0)
	_action("jump", [KEY_K, KEY_SPACE], [JOY_BUTTON_A], -1, 0.0)
	_action("dodge", [KEY_L, KEY_SHIFT], [JOY_BUTTON_B], -1, 0.0)
	_action("magic", [KEY_I, KEY_C], [JOY_BUTTON_Y], -1, 0.0)
	_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], -1, 0.0)
	_add_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_button("ui_accept", JOY_BUTTON_A)
	_add_button("ui_cancel", JOY_BUTTON_B)


func _action(action_name: String, keys: Array, buttons: Array, axis: int, axis_dir: float) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.3)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action_name, e)
	for b in buttons:
		_add_button(action_name, b)
	if axis >= 0:
		_add_axis(action_name, axis, axis_dir)


func _add_button(action_name: String, button: int) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	InputMap.action_add_event(action_name, e)


func _add_axis(action_name: String, axis: int, dir: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = dir
	InputMap.action_add_event(action_name, e)
