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
	# akce druhého hráče existují vždy (tlačítka dostanou až při připojení)
	for a in ["attack", "jump", "dodge", "magic", "left", "right", "up", "down", "pause"]:
		if not InputMap.has_action("p2_" + a):
			InputMap.add_action("p2_" + a, 0.3)


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


# ---------------------------------------------------------------- dva hráči

const P_ACTIONS := ["attack", "jump", "dodge", "magic", "left", "right", "up", "down", "pause"]


## Druhý hráč se připojil na ovladači p2_dev: jeho akce p2_* mají stejné rozložení
## tlačítek jako hráč 1, ale jen z jeho ovladače. Hráč 1 pak bere ovladač p1_dev
## (-1 = žádný ovladač, jen klávesnice).
func assign_pads(p1_dev: int, p2_dev: int) -> void:
	for a in P_ACTIONS:
		var p2a: String = "p2_" + a
		if not InputMap.has_action(p2a):
			InputMap.add_action(p2a, 0.3)
		InputMap.action_erase_events(p2a)
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadButton or e is InputEventJoypadMotion:
				var c: InputEvent = e.duplicate()
				c.device = p2_dev
				InputMap.action_add_event(p2a, c)
				e.device = p1_dev if p1_dev >= 0 else 99


## Zpět na jednoho hráče: hráč 1 bere všechny ovladače.
func reset_pads() -> void:
	for a in P_ACTIONS:
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadButton or e is InputEventJoypadMotion:
				e.device = -1
