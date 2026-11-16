extends Node
## Řídí celou hru: titulní obrazovka, hraní, pauza, výsledky.

const StageScript := preload("res://scripts/stage.gd")
const HudScript := preload("res://scripts/hud.gd")
const BackgroundScript := preload("res://scripts/background.gd")
const Fighter := preload("res://scripts/fighter.gd")
const TouchScript := preload("res://scripts/touch.gd")

enum State { TITLE, PLAYING, PAUSED, RESULTS }

var state := State.TITLE
var stage: StageScript = null
var stage_index := 0
var world: Node
var hud: HudScript
var ui_layer: CanvasLayer
var menu: Control = null
var title_bg: CanvasLayer = null
var ui_theme: Theme
var touch: TouchScript = null

var smoke := false
var smoke_time := 0.0
var smoke_step := 0
var shots_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	smoke = OS.get_cmdline_user_args().has("--smoke")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	ui_theme = Theme.new()
	ui_theme.default_font_size = 12

	world = Node.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)
	hud = HudScript.new()
	hud_layer.add_child(hud)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	if DisplayServer.is_touchscreen_available():
		touch = TouchScript.new()
		touch.setup([
			{"action": "attack", "label": "X", "offset": Vector2(98, 48), "r": 17.0},
			{"action": "jump", "label": "A", "offset": Vector2(62, 22), "r": 17.0},
			{"action": "dodge", "label": "B", "offset": Vector2(26, 48), "r": 17.0},
			{"action": "magic", "label": "Y", "offset": Vector2(62, 82), "r": 15.0},
		], true)
		add_child(touch)

	show_title()
	if shots_dir != "":
		_take_shots()


func _process(delta: float) -> void:
	if smoke:
		_smoke(delta)
	if Input.is_action_just_pressed("pause"):
		if state == State.PLAYING:
			pause()
		elif state == State.PAUSED:
			resume()
	elif state == State.PAUSED and Input.is_action_just_pressed("ui_cancel"):
		resume()


# ---------------------------------------------------------------- obrazovky

func show_title() -> void:
	_set_touch(false)
	state = State.TITLE
	get_tree().paused = false
	_clear_stage()
	if title_bg == null:
		title_bg = CanvasLayer.new()
		title_bg.layer = -10
		title_bg.add_child(BackgroundScript.new())
		add_child(title_bg)
	_show_menu("KLADIVO", "Kovářova pomsta", [
		["Hrát", start_game],
		["Ukončit hru", quit_game],
	], "X – úder (opakuj pro kombo)   A – skok   B – úskok\nY – runová magie   Start – pauza", false)


func start_game() -> void:
	start_stage(0)


func restart_stage() -> void:
	start_stage(stage_index)


func next_stage() -> void:
	start_stage(stage_index + 1)


func start_stage(index: int) -> void:
	stage_index = index
	_close_menu()
	_clear_stage()
	if title_bg != null:
		title_bg.queue_free()
		title_bg = null
	get_tree().paused = false
	stage = StageScript.new()
	stage.stage_index = index
	stage.completed.connect(_on_completed)
	world.add_child(stage)
	hud.stage = stage
	state = State.PLAYING
	_set_touch(true)


func pause() -> void:
	_set_touch(false)
	state = State.PAUSED
	get_tree().paused = true
	Sfx.play("select")
	_show_menu("Pauza", "", [
		["Pokračovat", resume],
		["Začít úroveň znovu", restart_stage],
		["Hlavní menu", show_title],
		["Ukončit hru", quit_game],
	])


func resume() -> void:
	_close_menu()
	get_tree().paused = false
	state = State.PLAYING
	_set_touch(true)


func _on_completed(stats: Dictionary) -> void:
	_set_touch(false)
	state = State.RESULTS
	get_tree().paused = true
	var secs := int(stats["time"])
	var text := "Skóre: %d\nPoražení nepřátelé: %d\nČas: %d:%02d\nPorážky: %d" % [
		stats["score"], stats["kills"], secs / 60, secs % 60, stats["deaths"]]
	var items: Array = []
	var title := "Úroveň dokončena!"
	if stage_index + 1 < StageScript.STAGES.size():
		items.append(["Další úroveň", next_stage])
	else:
		title = "Drak poražen!"
		text += "\n\nVšechny úrovně dokončeny!"
	items.append(["Hrát úroveň znovu", restart_stage])
	items.append(["Hlavní menu", show_title])
	_show_menu(title, text, items)


func quit_game() -> void:
	get_tree().quit()


func _clear_stage() -> void:
	hud.stage = null
	if stage != null and is_instance_valid(stage):
		stage.queue_free()
	stage = null


func _close_menu() -> void:
	if menu != null and is_instance_valid(menu):
		menu.queue_free()
	menu = null


func _show_menu(title: String, subtitle: String, items: Array, hint: String = "", dim: bool = true) -> void:
	_close_menu()
	menu = Control.new()
	menu.theme = ui_theme
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(menu)
	if dim:
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.6)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		menu.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	center.add_child(box)
	var tl := _label(title, 22 if dim else 40)
	tl.add_theme_color_override("font_color", Color("f0d050"))
	box.add_child(tl)
	if subtitle != "":
		box.add_child(_label(subtitle, 12))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	box.add_child(spacer)
	var first: Button = null
	for item in items:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size = Vector2(170, 0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var cb: Callable = item[1]
		b.pressed.connect(_on_menu_button.bind(cb))
		box.add_child(b)
		if first == null:
			first = b
	if hint != "":
		var h := _label(hint, 9)
		h.modulate = Color(1, 1, 1, 0.85)
		box.add_child(h)
	if first != null:
		first.call_deferred("grab_focus")


func _on_menu_button(cb: Callable) -> void:
	Sfx.play("select")
	cb.call()


func _label(text: String, fsize: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_outline_color", Color("1a120e"))
	l.add_theme_constant_override("outline_size", 6 if fsize > 20 else 3)
	return l


# ---------------------------------------------------------------- automatický test

func _beast() -> Node2D:
	for f in stage.fighters:
		if f.get("rideable") == true:
			return f
	return null


func _smoke(delta: float) -> void:
	smoke_time += delta
	match smoke_step:
		0:
			if smoke_time > 0.5:
				start_game()
				Input.action_press("right")
				smoke_step = 1
		1:
			_mash()
			if smoke_time > 4.0:
				stage.player.runes = 2
				Input.action_press("magic")
				smoke_step = 2
		2:
			Input.action_release("magic")
			_mash()
			if smoke_time > 6.0:
				stage.player.invuln = 0
				stage.player.hp = 1
				stage.player.take_hit(5, 1, false, 0.0)
				smoke_step = 3
		3:
			# hrdina se mezitím mohl i utopit v tůni – počkat, až se oživí
			var down: bool = stage.player.state == Fighter.S.DEAD or stage.player.drown_t > 0
			if smoke_time > 9.0 and not down:
				pause()
				smoke_step = 4
			elif smoke_time > 14.0:
				_smoke_fail("hrdina se neoživil")
		4:
			if smoke_step == 4:
				start_stage(3)
				stage.debug_jump_to_wave(1)
				smoke_step = 5
		5:
			_mash()
			if smoke_time > 12.0:
				var b := _beast()
				if b == null:
					_smoke_fail("ještěr nenalezen")
					return
				if b.rider != null:
					b.rider.take_hit(5, 1, true, 0.0)
				stage.player.pos = b.pos
				stage.player.set_state(Fighter.S.IDLE)
				stage.player.mount_beast(b)
				smoke_step = 6
		6:
			_mash()
			if smoke_time > 14.0:
				stage.debug_jump_to_wave(2)
				smoke_step = 7
		7:
			_mash()
			if smoke_time > 17.0:
				stage.debug_jump_to_wave(3)
				smoke_step = 8
		8:
			_mash()
			if smoke_time > 18.5 and stage.boss != null:
				stage.boss.cooldown = 0
				stage.boss.start_attack("fire")
				smoke_step = 9
		9:
			_mash()
			if smoke_time > 21.0:
				for a in ["stomp", "tail", "bite"]:
					if stage.boss != null:
						stage.boss._end_attack(0)
						stage.boss.start_attack(a)
						for k in 100:
							stage.boss._run_attack()
				smoke_step = 10
		10:
			if smoke_time > 22.0:
				stage.finish()
				smoke_step = 11
		11:
			if smoke_time > 25.0:
				Input.action_release("right")
				Input.action_release("attack")
				if state != State.RESULTS:
					_smoke_fail("úroveň se nedokončila")
				print("SMOKE OK score=%d kills=%d deaths=%d x=%.0f" % [
					stage.score, stage.kills, stage.deaths, stage.player.pos.x])
				get_tree().quit(0)
				smoke_step = 12


func _mash() -> void:
	var ph := fmod(smoke_time, 0.6)
	if ph < 0.05 or (ph > 0.2 and ph < 0.25) or (ph > 0.4 and ph < 0.45):
		Input.action_press("attack")
	else:
		Input.action_release("attack")
	if fmod(smoke_time, 2.3) < 0.05:
		Input.action_press("jump")
	else:
		Input.action_release("jump")
	if fmod(smoke_time + 1.0, 3.1) < 0.05:
		Input.action_press("dodge")
	else:
		Input.action_release("dodge")


func _smoke_fail(reason: String) -> void:
	print("SMOKE FAIL: " + reason)
	get_tree().quit(1)


# ---------------------------------------------------------------- screenshoty

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _tap(action: String) -> void:
	Input.action_press(action)
	await get_tree().create_timer(0.05).timeout
	Input.action_release(action)


func _take_shots() -> void:
	DirAccess.make_dir_recursive_absolute(shots_dir)
	await _wait(1.0)
	_save_shot("1_menu")
	start_game()
	stage.debug_jump_to_wave(0)
	await _wait(2.4)
	await _tap("attack")
	await _wait(0.12)
	await _tap("attack")
	await _wait(0.12)
	_save_shot("2_mocal")
	stage.debug_jump_to_wave(1)
	await _wait(2.4)
	_save_shot("2a_netopyri")
	# topení v tůni (pro kontrolu)
	var pls: Array = stage._pools(stage.cam_x - 230.0, stage.cam_x + 230.0)
	for pl in pls:
		var rr: Rect2 = pl[0]
		if absf(rr.get_center().x - stage.cam_x) < 200.0:
			stage.player.pos = rr.get_center()
			stage.player.set_state(Fighter.S.IDLE)
			await _wait(0.55)
			_save_shot("2d_topeni")
			await _wait(1.5)
			break
	start_stage(1)
	stage.debug_jump_to_wave(0)
	await _wait(2.6)
	_save_shot("2b_hrbitov")
	start_stage(2)
	stage.debug_jump_to_wave(0)
	await _wait(2.6)
	_save_shot("2c_dzungle")
	# nášlapná past a šipka
	stage.player.pos = Vector2(380.0, 250.0)
	stage.player.set_state(Fighter.S.IDLE)
	await _wait(0.85)
	_save_shot("2e_past")
	await _wait(1.6)
	start_stage(3)
	stage.debug_jump_to_wave(1)
	await _wait(2.6)
	_save_shot("3_hora_jezdec")
	var b := _beast()
	if b != null:
		if b.rider != null:
			b.rider.take_hit(5, 1, true, 0.0)
		await _wait(1.0)
		stage.player.pos = b.pos
		stage.player.set_state(Fighter.S.IDLE)
		stage.player.mount_beast(b)
		# Pro snímek: odklidit ostatní nepřátele, aby hrdinu nikdo neshodil.
		for f in stage.fighters.duplicate():
			if f != stage.player and f != b:
				stage.fighters.erase(f)
				f.queue_free()
		stage.tokens.clear()
		stage.player.invuln = 0
		await _wait(0.5)
		_save_shot("4_jizda")
		await _tap("attack")
		await _wait(0.5)
		_save_shot("4b_jizda_utok")
	stage.debug_jump_to_wave(2)
	await _wait(3.0)
	_save_shot("5_obr")
	stage.debug_jump_to_wave(3)
	await _wait(3.6)
	_save_shot("6_drak")
	if stage.boss != null:
		stage.boss._end_attack(0)
		stage.boss.start_attack("fire")
	await _wait(1.25)
	_save_shot("7_ohen")
	await _wait(1.2)
	stage.player.runes = 1
	stage.player.set_state(Fighter.S.IDLE)
	stage.player.invuln = 0
	await _tap("magic")
	await _wait(0.62)
	_save_shot("8_blesky")
	await _wait(1.2)
	stage.player.runes = 3
	stage.player.set_state(Fighter.S.IDLE)
	stage.player.invuln = 0
	await _tap("magic")
	await _wait(0.95)
	_save_shot("8_magie")
	await _wait(1.0)
	pause()
	await _wait(0.4)
	_save_shot("9_pauza")
	print("SHOTS OK")
	get_tree().quit(0)


func _save_shot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.resize(1440, 900, Image.INTERPOLATE_BILINEAR)
	img.save_png(shots_dir.path_join(shot_name + ".png"))


func _set_touch(on: bool) -> void:
	if touch != null:
		touch.active = on
