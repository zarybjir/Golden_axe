extends Node
## Nastavení hry: obtížnost a přemapování ovládání (klávesnice i ovladač).
## Ukládá se do user://settings.cfg. Výchozí ovládání nastaví controls.gd,
## tady se jen přepíše tím, co si hráč přemapoval.

const PATH := "user://settings.cfg"
const DIFFS := ["easy", "hard", "hell"]
const DIFF_NAMES := {"easy": "Easy", "hard": "Hard", "hell": "Hell"}
## Akce, které jde přemapovat, a jejich názvy v menu.
const ACTIONS := ["attack", "jump", "dodge", "magic", "left", "right", "up", "down", "pause"]
const ACTION_NAMES := {"attack": "Attack", "jump": "Jump", "dodge": "Dodge", "magic": "Rune magic",
	"left": "Move left", "right": "Move right", "up": "Move up", "down": "Move down", "pause": "Pause"}
const PAD_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_START: "Start", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right", JOY_BUTTON_GUIDE: "Guide"}

var difficulty := "easy"
var keys := {}       # akce -> fyzický kód klávesy (přemapováno)
var pads := {}       # akce -> tlačítko ovladače (přemapováno)
var _defaults := {}  # akce -> původní události (pro obnovení výchozího)


func _ready() -> void:
	# Controls (autoload před námi) už nastavil výchozí ovládání
	for a in ACTIONS:
		_defaults[a] = InputMap.action_get_events(a).duplicate()
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		difficulty = str(cf.get_value("game", "difficulty", "easy"))
		if not DIFFS.has(difficulty):
			difficulty = "easy"
		for a in ACTIONS:
			if cf.has_section_key("keys", a):
				keys[a] = int(cf.get_value("keys", a))
			if cf.has_section_key("pad", a):
				pads[a] = int(cf.get_value("pad", a))
	_apply()


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "difficulty", difficulty)
	for a in keys:
		cf.set_value("keys", a, keys[a])
	for a in pads:
		cf.set_value("pad", a, pads[a])
	cf.save(PATH)


# ---------------------------------------------------------------- obtížnost

func cycle_difficulty() -> void:
	difficulty = DIFFS[(DIFFS.find(difficulty) + 1) % DIFFS.size()]
	save()


## Počet životů na celou hru (-1 = neomezeně).
func lives() -> int:
	match difficulty:
		"hard":
			return 3
		"hell":
			return 1
	return -1


## Odolnost nepřátel (násobek zdraví).
func hp_mult() -> float:
	match difficulty:
		"hard":
			return 1.5
		"hell":
			return 2.0
	return 1.0


## Síla nepřátel (násobek poškození hrdiny).
func dmg_mult() -> float:
	return 1.25 if difficulty == "hell" else 1.0


# ---------------------------------------------------------------- ovládání

func bind_key(action: String, keycode: int) -> void:
	keys[action] = keycode
	_apply()
	save()


func bind_pad(action: String, button: int) -> void:
	pads[action] = button
	_apply()
	save()


func reset_controls() -> void:
	keys.clear()
	pads.clear()
	_apply()
	save()


func _apply() -> void:
	for a in ACTIONS:
		InputMap.action_erase_events(a)
		for e in _defaults[a]:
			if e is InputEventKey and keys.has(a):
				continue
			if e is InputEventJoypadButton and pads.has(a):
				continue
			InputMap.action_add_event(a, e)
		if keys.has(a):
			var k := InputEventKey.new()
			k.physical_keycode = keys[a]
			InputMap.action_add_event(a, k)
		if pads.has(a):
			var b := InputEventJoypadButton.new()
			b.button_index = pads[a]
			InputMap.action_add_event(a, b)


## Klávesy přiřazené akci (text do menu).
func key_text(action: String) -> String:
	var out: Array = []
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			out.append(OS.get_keycode_string(e.physical_keycode))
	return " / ".join(out) if not out.is_empty() else "-"


## Tlačítka ovladače přiřazená akci.
func pad_text(action: String) -> String:
	var out: Array = []
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton:
			out.append(PAD_NAMES.get(e.button_index, "Button %d" % e.button_index))
		elif e is InputEventJoypadMotion:
			out.append("Stick")
	return " / ".join(out) if not out.is_empty() else "-"
