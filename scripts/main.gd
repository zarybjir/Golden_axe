extends Node
## Řídí celou hru: titulní obrazovka, hraní, pauza, výsledky.

const StageScript := preload("res://scripts/stage.gd")
const HudScript := preload("res://scripts/hud.gd")
const BackgroundScript := preload("res://scripts/background.gd")
const Fighter := preload("res://scripts/fighter.gd")
const TouchScript := preload("res://scripts/touch.gd")
const TitleScript := preload("res://scripts/title.gd")
const GateScript := preload("res://scripts/gate_scene.gd")

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
var lives := -1            # zbývající životy na celou hru (-1 = neomezeně)
var gate_layer: CanvasLayer = null   # scéna vstupu do paláce
var rebinding := ""        # akce, pro kterou se právě čeká na klávesu/tlačítko
var rebind_t := 0.0

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
	if OS.get_cmdline_user_args().has("--zombietest"):
		_zombie_test()
	if OS.get_cmdline_user_args().has("--heavytest"):
		_heavy_test()


func _process(delta: float) -> void:
	if rebind_t > 0.0:
		rebind_t -= delta
	if rebinding != "":
		return
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
	Sfx.play_music("title")
	if title_bg == null:
		title_bg = CanvasLayer.new()
		title_bg.layer = -10
		title_bg.add_child(TitleScript.new())
		add_child(title_bg)
	_show_menu("HAMMER", "The Blacksmith's Revenge", [
		["Play", start_game],
		["Difficulty: %s" % Settings.DIFF_NAMES[Settings.difficulty], _cycle_difficulty],
		["Stage select", show_stage_select],
		["Controls", show_controls],
		["Quit", quit_game],
	], _controls_hint(), false, 1)


func _cycle_difficulty() -> void:
	Settings.cycle_difficulty()
	_show_title_menu_at(1)


func _show_title_menu_at(focus: int) -> void:
	show_title()
	_focus_item(focus)


func _difficulty_text() -> String:
	match Settings.difficulty:
		"hard":
			return "Hard: 3 lives, tougher monsters."
		"hell":
			return "Hell: one life, monsters tougher and stronger."
	return "Easy: unlimited lives."


func _controls_hint() -> String:
	return _difficulty_text() + "\nKeys can be changed in Controls."


# ---------------------------------------------------------------- ovládání

func show_controls(focus: int = 0) -> void:
	rebinding = ""
	var items: Array = []
	for a in Settings.ACTIONS:
		items.append(["%s:  %s  |  %s" % [Settings.ACTION_NAMES[a], Settings.key_text(a), Settings.pad_text(a)],
			_start_rebind.bind(a)])
	items.append(["Reset to defaults", _reset_controls])
	items.append(["Back", _controls_back])
	_show_menu("Controls", "Keyboard  |  Gamepad", items,
		"Select an action, then press the new key or gamepad button.", state != State.TITLE, 2)
	_focus_item(focus)


func _controls_back() -> void:
	if state == State.PAUSED:
		pause()
	else:
		show_title()


func _start_rebind(action: String) -> void:
	rebinding = action
	rebind_t = 0.25
	_show_menu("Controls", "", [], "Press a new key or gamepad button for\n%s" % Settings.ACTION_NAMES[action], state != State.TITLE)


func _reset_controls() -> void:
	Settings.reset_controls()
	show_controls(Settings.ACTIONS.size())


func _input(event: InputEvent) -> void:
	if rebinding == "" or rebind_t > 0.0 or not event.is_pressed() or event.is_echo():
		return
	var a := rebinding
	if event is InputEventKey:
		Settings.bind_key(a, event.physical_keycode)
	elif event is InputEventJoypadButton:
		Settings.bind_pad(a, event.button_index)
	else:
		return
	get_viewport().set_input_as_handled()
	Sfx.play("select")
	rebinding = ""
	show_controls(Settings.ACTIONS.find(a))


func _focus_item(i: int) -> void:
	if menu == null:
		return
	var buttons := menu.find_children("*", "Button", true, false)
	if i >= 0 and i < buttons.size():
		(buttons[i] as Button).call_deferred("grab_focus")


func show_stage_select() -> void:
	var items: Array = []
	for i in StageScript.STAGES.size():
		items.append(["%d. %s" % [i + 1, StageScript.STAGES[i]["name"]], _start_from.bind(i)])
	items.append(["Back", show_title])
	_show_menu("Stage select", "", items, "", false)


func _start_from(i: int) -> void:
	lives = Settings.lives()
	start_stage(i)


func start_game() -> void:
	lives = Settings.lives()
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
	stage.lives = lives
	stage.game_over.connect(_on_game_over)
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
	_show_menu("Paused", "", [
		["Resume", resume],
		["Restart stage", restart_stage],
		["Controls", show_controls],
		["Main menu", show_title],
		["Quit", quit_game],
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
	if stats.get("gate", false) and stage != null:
		# po kamenném obrovi: hrdina vejde do brány temného paláce
		_close_gate()
		gate_layer = CanvasLayer.new()
		gate_layer.layer = 8
		var g := GateScript.new()
		var pl = stage.player
		if pl.anim_tex.has("walk"):
			g.setup(pl.anim_tex["walk"], pl.anim_set["walk"]["offsets"], pl.anim_k)
		g.finished.connect(_show_results.bind(stats))
		gate_layer.add_child(g)
		add_child(gate_layer)
		return
	_show_results(stats)


func _close_gate() -> void:
	if gate_layer != null and is_instance_valid(gate_layer):
		gate_layer.queue_free()
	gate_layer = null


func _show_results(stats: Dictionary) -> void:
	var secs := int(stats["time"])
	lives = int(stats.get("lives", lives))
	var text := "Score: %d\nEnemies defeated: %d\nTime: %d:%02d\nDeaths: %d" % [
		stats["score"], stats["kills"], secs / 60, secs % 60, stats["deaths"]]
	if lives >= 0:
		text += "\nLives left: %d" % lives
	var items: Array = []
	var title := "Stage complete!"
	if stage_index + 1 < StageScript.STAGES.size():
		items.append(["Next stage", next_stage])
	else:
		title = "The Dark Palace has fallen!"
		text += "\n\nAll stages complete!"
	items.append(["Play stage again", restart_stage])
	items.append(["Main menu", show_title])
	_show_menu(title, text, items)


## Došly životy: konec hry.
func _on_game_over() -> void:
	Sfx.play_music("")
	_set_touch(false)
	state = State.RESULTS
	get_tree().paused = true
	_show_menu("GAME OVER", "You have no lives left.", [
		["Try again", _retry],
		["Main menu", show_title],
	])


func _retry() -> void:
	lives = Settings.lives()
	restart_stage()


func quit_game() -> void:
	get_tree().quit()


func _clear_stage() -> void:
	_close_gate()
	hud.stage = null
	if stage != null and is_instance_valid(stage):
		stage.queue_free()
	stage = null


func _close_menu() -> void:
	if menu != null and is_instance_valid(menu):
		menu.queue_free()
	menu = null


func _show_menu(title: String, subtitle: String, items: Array, hint: String = "", dim: bool = true, layout: int = 0) -> void:
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
	if layout == 1:
		# úvodní obrazovka: menu vlevo na tmavém přechodu, palác zůstane vidět
		var grad := Gradient.new()
		grad.set_color(0, Color(0, 0, 0, 0.78))
		grad.set_color(1, Color(0, 0, 0, 0.0))
		var gt := GradientTexture2D.new()
		gt.gradient = grad
		gt.fill_to = Vector2(1, 0)
		var shade_l := TextureRect.new()
		shade_l.texture = gt
		shade_l.stretch_mode = TextureRect.STRETCH_SCALE
		shade_l.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		shade_l.anchor_right = 0.62
		shade_l.offset_right = 0
		menu.add_child(shade_l)
		center.anchor_right = 0.42
	menu.add_child(center)
	var compact := layout == 2
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1 if compact else 6)
	center.add_child(box)
	var tl := _label(title, 18 if compact else (22 if dim else 40))
	tl.add_theme_color_override("font_color", Color("f0d050"))
	box.add_child(tl)
	if subtitle != "":
		box.add_child(_label(subtitle, 12))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 2 if compact else 6)
	box.add_child(spacer)
	var first: Button = null
	for item in items:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size = Vector2(260 if compact else 170, 0)
		if compact:
			b.add_theme_font_size_override("font_size", 9)
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
				start_stage(2)   # drak je boss džungle
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
	show_controls()
	await _wait(0.3)
	_save_shot("1b_ovladani")
	show_title()
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
	await _wait(0.75)
	_save_shot("2b0_vylezani")
	await _wait(1.85)
	_save_shot("2b_hrbitov")
	# zombie: po třech zásazích přijde o ruku, pak ji zvedne a mlátí s ní
	for f in stage.fighters:
		if f.get("kind") == "zombie":
			f.pos = stage.player.pos + Vector2(50.0, 0.0)
			for k in 3:
				f.take_hit(6, 1, false, 0.0)
			await _wait(0.45)
			_save_shot("2g_zombie_ruka")
			f.call("_take_arm")
			await _wait(1.2)
			_save_shot("2h_zombie_mlati")
			break
	# nekromant (boss hřbitova): vzývá a mrtví vylézají ze země
	stage.debug_jump_to_wave(3)
	await _wait(2.4)
	for f in stage.fighters:
		if f.get("kind") == "necro":
			f.pos = stage.player.pos + Vector2(140.0, 0.0)
			f.facing = -1
			f.start_move("necro_summon")
			await _wait(0.5)
			_save_shot("2i_nekromant")
			await _wait(1.2)
			_save_shot("2j_nekromant_vyvolal")
			break
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
	stage.debug_jump_to_wave(1)
	await _wait(3.2)
	_save_shot("2f_lianovec")
	start_stage(3)
	stage.debug_jump_to_wave(1)
	await _wait(2.6)
	_save_shot("3_hora_jezdec")
	stage.debug_jump_to_wave(0)
	await _wait(1.6)
	for f in stage.fighters:
		if f.get("kind") == "chamois":
			f.pos = stage.player.pos + Vector2(170.0, 0.0)
			f.facing = -1
			f.start_move("chamois_charge")
			await _wait(0.35)
			_save_shot("3a_kamzik_vzepeti")
			await _wait(0.45)
			_save_shot("3b_kamzik_utok")
			break
	stage.debug_jump_to_wave(1)
	await _wait(2.4)
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
	stage.debug_jump_to_wave(3)
	await _wait(3.0)
	_save_shot("5_obr")
	for f in stage.fighters:
		if f.get("kind") == "golem":
			f.pos = Vector2(stage.cam_x + 120.0, 240.0)
			stage.player.pos = Vector2(stage.cam_x - 100.0, 240.0)
			f.facing = -1
			f.set("throw_target", stage.player.pos)
			f.start_move("golem_throw")
			await _wait(0.4)
			_save_shot("5a_obr_vyrva")
			await _wait(0.9)
			_save_shot("5b_obr_hod")
			break
	# po poražení obra: vstup do brány paláce
	stage.finish()
	await _wait(2.4 + 3.0)
	_save_shot("5c_brana")
	await _wait(3.0)
	start_stage(2)   # drak je boss džungle
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
	# palác: lich střílí zelenou střelu
	start_stage(4)
	stage.debug_jump_to_wave(0)
	await _wait(2.6)
	for f in stage.fighters:
		if f.get("kind") == "lich":
			f.pos = stage.player.pos + Vector2(170.0, 0.0)
			f.facing = -1
			f.start_move("lich_cast")
			await _wait(0.4)
			_save_shot("10_lich_kouzli")
			await _wait(0.45)
			_save_shot("10b_lich_strela")
			break
	stage.debug_jump_to_wave(3)
	await _wait(3.0)
	_save_shot("10c_kral_lichu")
	pause()
	await _wait(0.4)
	_save_shot("9_pauza")
	print("SHOTS OK")
	get_tree().quit(0)


## Test: zombie přijde o ruku a sám si ji dojde zvednout (bez zásahu testu).
func _zombie_test() -> void:
	await _wait(0.5)
	lives = -1
	start_stage(1)
	stage.debug_jump_to_wave(0)
	await _wait(3.0)
	for f in stage.fighters:
		if f.get("kind") == "zombie":
			stage.player.pos = Vector2(stage.cam_x - 150.0, 240.0)
			stage.player.controls = false
			f.pos = Vector2(stage.cam_x + 40.0, 240.0)
			for k in 3:
				f.take_hit(6, 1, false, 0.0)
				await _wait(0.3)
			for i in 40:
				await _wait(0.25)
				print("t=%.2f phase=%d pickup=%d state=%d pos=%s arm=%s" % [i * 0.25, f.z_phase, f.pickup_t, f.state, f.pos, f.arm_pos])
				if f.z_phase == 2:
					break
			await _wait(3.0)
			print("ZOMBIETEST phase=", f.z_phase)
			break
	# obr: po sražující ráně nepadá, odhodí hrdinu a vyrazí
	start_stage(0)
	stage.debug_jump_to_wave(3)
	await _wait(3.0)
	for f in stage.fighters:
		if f.get("kind") == "ogre":
			stage.player.pos = Vector2(stage.cam_x, 240.0)
			f.pos = stage.player.pos + Vector2(30.0, 0.0)
			f.set("incoming_move", "atk3")
			f.take_hit(14, 1, true, 0.0)
			for i in 12:
				await _wait(0.15)
				print("ogre state=%d move=%s hp=%d | hero state=%d hp=%d x=%.0f" % [f.state, f.move_name, f.hp, stage.player.state, stage.player.hp, stage.player.pos.x - f.pos.x])
			print("OGRETEST done")
			break
	get_tree().quit(0)


## Test: podržený úder -> nabití -> silný úder; elitní nepřátelé a role.
func _heavy_test() -> void:
	await _wait(0.5)
	start_stage(0)
	stage.debug_jump_to_wave(0)
	await _wait(2.5)
	Input.action_press("attack")
	for i in 8:
		await _wait(0.12)
		print("hold t=%.2f move=%s st=%d" % [i * 0.12, stage.player.move_name, stage.player.state_t])
	Input.action_release("attack")
	for i in 5:
		await _wait(0.1)
		print("released move=%s st=%d" % [stage.player.move_name, stage.player.state_t])
	var el := 0
	for f in stage.fighters:
		if f.get("elite") == true:
			el += 1
	print("enemies=%d elite=%d tokens=%d" % [stage.fighters.size() - 1, el, stage.tokens.size()])
	print("HEAVYTEST done")
	get_tree().quit(0)


func _save_shot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.resize(1440, 900, Image.INTERPOLATE_BILINEAR)
	img.save_png(shots_dir.path_join(shot_name + ".png"))


func _set_touch(on: bool) -> void:
	if touch != null:
		touch.active = on
