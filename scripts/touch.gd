extends CanvasLayer
## Dotykové ovládání pro mobil: virtuální páčka v levé části obrazovky,
## tlačítka vpravo dole a pauza v pravém horním rohu.
## Zobrazí se jen na zařízení s dotykovou obrazovkou.

var buttons: Array = []      # [{"action", "label", "offset" (od pravého dolního rohu), "r"}]
var eight_dir := true        # false = páčka jen doleva/doprava + dolů
var active := false:
	set(v):
		active = v
		if not v:
			_release_all()
		if draw_node != null:
			draw_node.queue_redraw()

var stick_touch := -1
var stick_origin := Vector2.ZERO
var stick_vec := Vector2.ZERO
var btn_touch := {}
var draw_node: Node2D

const STICK_R := 26.0


func _ready() -> void:
	layer = 20
	draw_node = Node2D.new()
	add_child(draw_node)
	draw_node.draw.connect(_draw_ui)


func setup(btns: Array, eight: bool) -> void:
	buttons = btns
	eight_dir = eight


func _size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _btn_pos(b: Dictionary) -> Vector2:
	var off: Vector2 = b["offset"]
	return _size() - off


func _pause_pos() -> Vector2:
	return Vector2(_size().x - 14.0, 14.0)


func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if t.position.distance_to(_pause_pos()) < 16.0:
				_tap_pause()
				return
			if t.position.x < _size().x * 0.45 and stick_touch == -1:
				stick_touch = t.index
				stick_origin = t.position
				stick_vec = Vector2.ZERO
				_apply_stick()
			else:
				var best := ""
				var best_d := 1e9
				for b in buttons:
					var d := t.position.distance_to(_btn_pos(b))
					if d < float(b["r"]) * 1.5 and d < best_d:
						best_d = d
						best = b["action"]
				if best != "":
					btn_touch[t.index] = best
					Input.action_press(best)
		else:
			if t.index == stick_touch:
				stick_touch = -1
				stick_vec = Vector2.ZERO
				_apply_stick()
			if btn_touch.has(t.index):
				Input.action_release(btn_touch[t.index])
				btn_touch.erase(t.index)
		draw_node.queue_redraw()
	elif event is InputEventScreenDrag:
		var dr := event as InputEventScreenDrag
		if dr.index == stick_touch:
			var v := (dr.position - stick_origin) / STICK_R
			if v.length() > 1.0:
				# Páčka "táhne" střed za prstem, aby se nemusel vracet.
				stick_origin = dr.position - v.normalized() * STICK_R
				v = v.normalized()
			stick_vec = v
			_apply_stick()
			draw_node.queue_redraw()


func _tap_pause() -> void:
	var e := InputEventAction.new()
	e.action = "pause"
	e.pressed = true
	Input.parse_input_event(e)
	var e2 := InputEventAction.new()
	e2.action = "pause"
	e2.pressed = false
	Input.call_deferred("parse_input_event", e2)


func _apply_stick() -> void:
	var v := stick_vec
	_axis("right", v.x)
	_axis("left", -v.x)
	_axis("down", v.y)
	if eight_dir:
		_axis("up", -v.y)


func _axis(action: String, value: float) -> void:
	if not InputMap.has_action(action):
		return
	if value > 0.3:
		Input.action_press(action, clampf(value, 0.0, 1.0))
	else:
		Input.action_release(action)


func _release_all() -> void:
	stick_touch = -1
	stick_vec = Vector2.ZERO
	for a in ["left", "right", "up", "down"]:
		if InputMap.has_action(a):
			Input.action_release(a)
	for k in btn_touch:
		Input.action_release(btn_touch[k])
	btn_touch.clear()


func _draw_ui() -> void:
	if not active:
		return
	var font := ThemeDB.fallback_font
	var s := _size()
	# Páčka
	var c := stick_origin if stick_touch != -1 else Vector2(56, s.y - 52)
	draw_node.draw_circle(c, STICK_R + 4.0, Color(0, 0, 0, 0.22))
	draw_node.draw_arc(c, STICK_R + 4.0, 0.0, TAU, 32, Color(1, 1, 1, 0.35), 1.5)
	draw_node.draw_circle(c + stick_vec * STICK_R, 11.0, Color(1, 1, 1, 0.38))
	# Tlačítka
	for b in buttons:
		var p := _btn_pos(b)
		var r: float = b["r"]
		var held: bool = btn_touch.values().has(b["action"])
		draw_node.draw_circle(p, r, Color(1, 1, 1, 0.42) if held else Color(0, 0, 0, 0.25))
		draw_node.draw_arc(p, r, 0.0, TAU, 28, Color(1, 1, 1, 0.45), 1.5)
		var label: String = b["label"]
		draw_node.draw_string(font, p + Vector2(-r, 4), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 10,
			Color(1, 1, 1, 0.85))
	# Pauza
	var pp := _pause_pos()
	draw_node.draw_circle(pp, 10.0, Color(0, 0, 0, 0.3))
	draw_node.draw_rect(Rect2(pp + Vector2(-4, -5), Vector2(3, 10)), Color(1, 1, 1, 0.8))
	draw_node.draw_rect(Rect2(pp + Vector2(1, -5), Vector2(3, 10)), Color(1, 1, 1, 0.8))
