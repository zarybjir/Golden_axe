extends Node
## Řídí celou hru: titulní obrazovka, hraní, pauza, výsledky.

const StageScript := preload("res://scripts/stage.gd")
const HudScript := preload("res://scripts/hud.gd")
const BackgroundScript := preload("res://scripts/background.gd")
const Fighter := preload("res://scripts/fighter.gd")

enum State { TITLE, PLAYING, PAUSED, RESULTS }

var state := State.TITLE
var stage: StageScript = null
var world: Node
var hud: HudScript
var ui_layer: CanvasLayer
var menu: Control = null
var title_bg: CanvasLayer = null
var ui_theme: Theme

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
	_close_menu()
	_clear_stage()
	if title_bg != null:
		title_bg.queue_free()
		title_bg = null
	get_tree().paused = false
	stage = StageScript.new()
	stage.completed.connect(_on_completed)
	world.add_child(stage)
	hud.stage = stage
	state = State.PLAYING


func pause() -> void:
	state = State.PAUSED
	get_tree().paused = true
	Sfx.play("select")
	_show_menu("Pauza", "", [
		["Pokračovat", resume],
		["Začít znovu", start_game],
		["Hlavní menu", show_title],
		["Ukončit hru", quit_game],
	])


func resume() -> void:
	_close_menu()
	get_tree().paused = false
	state = State.PLAYING


func _on_completed(stats: Dictionary) -> void:
	state = State.RESULTS
	get_tree().paused = true
	var secs := int(stats["time"])
	var text := "Skóre: %d\nPoražení nepřátelé: %d\nČas: %d:%02d\nPorážky: %d\n\nDalší úrovně brzy!" % [
		stats["score"], stats["kills"], secs / 60, secs % 60, stats["deaths"]]
	_show_menu("Vesnice zachráněna!", text, [
		["Hrát znovu", start_game],
		["Hlavní menu", show_title],
	])


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
			if smoke_time > 5.0:
				stage.player.runes = 2
				Input.action_press("magic")
				smoke_step = 2
		2:
			Input.action_release("magic")
			_mash()
			if smoke_time > 7.0:
				stage.player.invuln = 0
				stage.player.hp = 1
				stage.player.take_hit(5, 1, false, 0.0)
				smoke_step = 3
		3:
			if smoke_time > 10.0:
				if stage.player.state == Fighter.S.DEAD:
					_smoke_fail("hrdina se neoživil")
				pause()
				smoke_step = 4
		4:
			if smoke_time > 10.5:
				resume()
				stage.debug_jump_to_wave(3)
				smoke_step = 5
		5:
			_mash()
			if smoke_time > 14.0:
				stage.finish()
				smoke_step = 6
		6:
			if smoke_time > 17.0:
				Input.action_release("right")
				if state != State.RESULTS:
					_smoke_fail("úroveň se nedokončila")
				print("SMOKE OK score=%d kills=%d deaths=%d x=%.0f" % [
					stage.score, stage.kills, stage.deaths, stage.player.pos.x])
				get_tree().quit(0)
				smoke_step = 7


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

func _take_shots() -> void:
	DirAccess.make_dir_recursive_absolute(shots_dir)
	await get_tree().create_timer(1.0).timeout
	_save_shot("1_menu")
	start_game()
	await get_tree().create_timer(0.8).timeout
	_save_shot("2_start")
	# Vlna 1: nepřátelé přicházejí, hrdina mlátí.
	stage.debug_jump_to_wave(0)
	await get_tree().create_timer(2.6).timeout
	await _hold_attack_shot("3_boj", 1.0, 0.27)
	stage.debug_jump_to_wave(2)
	await get_tree().create_timer(2.8).timeout
	_save_shot("4_kostlivci")
	stage.debug_jump_to_wave(3)
	await get_tree().create_timer(3.2).timeout
	_save_shot("5_zlobr")
	stage.player.runes = 3
	Input.action_press("magic")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("magic")
	await get_tree().create_timer(0.36).timeout
	_save_shot("6_magie")
	await get_tree().create_timer(1.0).timeout
	pause()
	await get_tree().create_timer(0.4).timeout
	_save_shot("7_pauza")
	print("SHOTS OK")
	get_tree().quit(0)


func _hold_attack_shot(shot_name: String, dur: float, at: float) -> void:
	Input.action_press("attack")
	await get_tree().create_timer(0.05).timeout
	Input.action_release("attack")
	await get_tree().create_timer(at - 0.05).timeout
	_save_shot(shot_name)
	await get_tree().create_timer(maxf(dur - at, 0.0)).timeout


func _save_shot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(shots_dir.path_join(shot_name + ".png"))
