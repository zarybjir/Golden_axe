extends Node2D
## Jedna úroveň beat 'em upu: kamera, vlny nepřátel, zásahy, hitstop, předměty.

signal completed(stats: Dictionary)

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const PropScript := preload("res://scripts/props.gd")
const CreatureScript := preload("res://scripts/creature.gd")
const FxScript := preload("res://scripts/fx.gd")
const BackgroundScript := preload("res://scripts/background.gd")
const ParallaxScript := preload("res://scripts/parallax.gd")
const Fighter := preload("res://scripts/fighter.gd")

const LEVEL_LEN := 2000.0
const HALF_W := 240.0
const MAX_TOKENS := 2
const BARRELS := [[300.0, 204.0, "meat"], [640.0, 268.0, "rune"], [1040.0, 212.0, "rune"],
	[1460.0, 262.0, "meat"], [1560.0, 206.0, "rune"]]
## Úrovně za sebou. Poslední vlna s "boss": true úroveň ukončí.
const STAGES := [
	{"name": "Močály", "biome": "swamp", "waves": [
		{"x": 420.0, "enemies": [["goblin", 1], ["goblin", -1], ["goblin", 1]]},
		{"x": 860.0, "enemies": [["rider", 1], ["goblin", -1]]},
		{"x": 1300.0, "enemies": [["skeleton", 1], ["goblin", -1], ["goblin", 1]]},
		{"x": 1760.0, "enemies": [["goblin", 1], ["goblin", -1], ["skeleton", 1], ["goblin", -1]], "boss": true},
	]},
	{"name": "Hřbitov", "biome": "graveyard", "waves": [
		{"x": 420.0, "enemies": [["skeleton", 1], ["skeleton", -1]]},
		{"x": 860.0, "enemies": [["skeleton", 1], ["goblin", -1], ["skeleton", -1]]},
		{"x": 1300.0, "enemies": [["rider", 1], ["skeleton", -1], ["skeleton", 1]]},
		{"x": 1760.0, "enemies": [["ogre", 1], ["skeleton", -1]], "boss": true},
	]},
	{"name": "Džungle", "biome": "jungle", "waves": [
		{"x": 420.0, "enemies": [["goblin", 1], ["goblin", -1], ["goblin", 1], ["goblin", -1]]},
		{"x": 860.0, "enemies": [["rider", 1], ["rider", -1]]},
		{"x": 1300.0, "enemies": [["skeleton", 1], ["goblin", -1], ["skeleton", -1], ["goblin", 1]]},
		{"x": 1760.0, "enemies": [["ogre", 1], ["goblin", -1], ["goblin", 1]], "boss": true},
	]},
	{"name": "Horský průsmyk", "biome": "mountain", "waves": [
		{"x": 420.0, "enemies": [["goblin", 1], ["skeleton", -1], ["goblin", 1]]},
		{"x": 860.0, "enemies": [["rider", 1], ["goblin", -1], ["skeleton", 1]]},
		{"x": 1300.0, "enemies": [["ogre", 1], ["skeleton", -1], ["goblin", -1]]},
		{"x": 1760.0, "enemies": [["dragon", 1], ["goblin", -1]], "boss": true},
	]},
]

var stage_index := 0
var waves: Array = []
var biome := ""
var ground_tex: Texture2D = null

var player: PlayerScript
var fighters: Array = []
var props: Array = []
var fx: FxScript
var cam: Camera2D
var cam_x := HALF_W
var locked := false
var wave_i := 0
var go_sign := false
var hitstop := 0
var shake_t := 0.0
var shake_amt := 0.0
var flash_t := 0.0
var tokens: Array = []
var boss: Node2D = null
var respawn_t := 0

var score := 0
var kills := 0
var deaths := 0
var time := 0.0
var finished := false


func _ready() -> void:
	var st: Dictionary = STAGES[stage_index]
	waves = st["waves"]
	biome = st["biome"]
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	if ParallaxScript.has_biome(biome):
		# Hrubé retro pozadí ve vrstvách s paralaxou
		ground_tex = load("res://art/bg/%s/ground.png" % biome)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var back := ParallaxScript.new()
		back.biome = biome
		bg_layer.add_child(back)
		var fg_layer := CanvasLayer.new()
		fg_layer.layer = 4
		add_child(fg_layer)
		var front := ParallaxScript.new()
		front.biome = biome
		front.mode = "front"
		fg_layer.add_child(front)
	else:
		ground_tex = load("res://art/bg/%s_ground.webp" % biome)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var bg := BackgroundScript.new()
		bg.biome = biome
		bg.level_len = LEVEL_LEN
		bg_layer.add_child(bg)

	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()

	player = PlayerScript.new()
	player.stage = self
	player.pos = Vector2(90, 236)
	add_child(player)
	fighters.append(player)

	for b in BARRELS:
		var pr := PropScript.new()
		pr.kind = "barrel"
		pr.content = b[2]
		pr.stage = self
		pr.pos = Vector2(b[0], b[1])
		add_child(pr)
		props.append(pr)

	fx = FxScript.new()
	fx.z_index = 900
	add_child(fx)
	_update_camera()
	popup(String(st["name"]).to_upper(), Vector2(cam_x - 6, 120), Color("f0d050"))


func _physics_process(_delta: float) -> void:
	player.read_input()
	if hitstop > 0:
		hitstop -= 1
		return
	if not finished:
		time += Fighter.DT
	for f in fighters.duplicate():
		if is_instance_valid(f):
			f.tick()
	_clamp_all()
	_pickups()
	_cleanup()
	_player_death()
	_camera_logic()
	_update_camera()
	queue_redraw()


func _process(delta: float) -> void:
	if shake_t > 0.0:
		shake_t -= delta
	if flash_t > 0.0:
		flash_t -= delta
	_update_camera()


func _update_camera() -> void:
	var off := Vector2.ZERO
	if shake_t > 0.0:
		off = Vector2(randf_range(-shake_amt, shake_amt), randf_range(-shake_amt, shake_amt)).round()
	cam.position = Vector2(roundf(cam_x), 150.0) + off


func shake(amount: float, duration: float) -> void:
	if amount >= shake_amt or shake_t <= 0.0:
		shake_amt = amount
	shake_t = maxf(shake_t, duration)


# ---------------------------------------------------------------- kamera a vlny

func _camera_logic() -> void:
	if locked:
		if _living_enemies() == 0:
			locked = false
			var was_boss: bool = waves[wave_i].get("boss", false)
			wave_i += 1
			if was_boss:
				finish()
			else:
				go_sign = true
				Sfx.play("go")
		return
	var target := clampf(player.pos.x + 30.0, HALF_W, LEVEL_LEN - HALF_W)
	if target > cam_x:
		cam_x = minf(cam_x + maxf((target - cam_x) * 0.12, 0.5), target)
		if cam_x > player.pos.x - 60.0:
			pass
	if go_sign and cam_x > (waves[wave_i - 1]["x"] as float) + 80.0:
		go_sign = false
	if wave_i < waves.size() and cam_x >= float(waves[wave_i]["x"]):
		cam_x = float(waves[wave_i]["x"])
		locked = true
		go_sign = false
		_spawn_wave(waves[wave_i])


func _spawn_wave(w: Dictionary) -> void:
	var i := 0
	for e in w["enemies"]:
		var side: int = e[1]
		var at := Vector2(cam_x + side * (HALF_W + 40.0 + i * 40.0), randf_range(Fighter.Y_MIN + 10.0, Fighter.Y_MAX - 10.0))
		var kind: String = e[0]
		if kind == "dragon" or kind == "rider":
			var cr := CreatureScript.new()
			cr.kind = "dragon" if kind == "dragon" else "beast"
			cr.stage = self
			cr.pos = at + Vector2(side * 60.0, 0.0)
			cr.facing = -side
			if kind == "rider":
				var gob := _make_enemy("goblin", at, side)
				gob.mount = cr
				gob.state = Fighter.S.RIDE
				cr.rider = gob
			add_child(cr)
			fighters.append(cr)
			if kind == "dragon":
				boss = cr
				Sfx.play("roar", 0.7)
		else:
			var en := _make_enemy(kind, at, side)
			if kind == "ogre":
				boss = en
				Sfx.play("roar")
		i += 1


func _make_enemy(kind: String, at: Vector2, side: int) -> Node2D:
	var en := EnemyScript.new()
	en.kind = kind
	en.stage = self
	en.pos = at
	en.facing = -side
	add_child(en)
	fighters.append(en)
	return en


## Ještěr bez jezdce poblíž hráče (pro nasednutí).
func find_mount(p: Node2D) -> Node2D:
	for f in fighters:
		if f.get("rideable") == true and f.rider == null and f.alive():
			if absf(f.pos.x - p.pos.x) < 40.0 and absf(f.pos.y - p.pos.y) < 16.0:
				return f
	return null


## Plošný zásah (útoky velkých stvoření). x0..x1 je rozsah před útočníkem (záporné = za ním).
func area_hit(att: Node2D, x0: float, x1: float, dy_tol: float, dmg: int, knock: bool, push: float, ground_only: bool = false) -> void:
	for f in fighters:
		if f.team == att.team or f.team == 2 or not f.can_be_hit() or f == att:
			continue
		if ground_only and f.z > 6.0 and f.state != Fighter.S.RIDE:
			continue
		var rel: float = (f.pos.x - att.pos.x) * att.facing
		if rel < x0 or rel > x1 or absf(f.pos.y - att.pos.y) > dy_tol:
			continue
		var dir: int = att.facing if rel >= 0.0 else -att.facing
		f.take_hit(dmg, dir, knock, push)
		var hp_ := Vector2(f.pos.x, f.pos.y - f.z - 22.0 * f.body_scale)
		fx.burst(hp_, Color("fff4c0"), 8, 140.0, 0.22, 0.0, 2.0)
		hitstop = maxi(hitstop, 6 if knock else 3)
		shake(3.0 if knock else 1.5, 0.12)
		Sfx.play("heavy" if knock else "hit")


func debug_jump_to_wave(index: int) -> void:
	for f in fighters.duplicate():
		if f != player:
			f.queue_free()
			fighters.erase(f)
	tokens.clear()
	locked = false
	wave_i = index
	cam_x = float(waves[index]["x"]) - 1.0
	player.pos = Vector2(cam_x + 10.0, 236.0)


func _living_enemies() -> int:
	var n := 0
	for f in fighters:
		if f != player and f.is_foe() and f.state != Fighter.S.DEAD:
			n += 1
	return n


func _clamp_all() -> void:
	var left := cam_x - HALF_W
	var right := cam_x + HALF_W
	player.pos.x = clampf(player.pos.x, left + 10.0, right - 10.0)
	for f in fighters:
		if f == player:
			continue
		if not f.entered and f.pos.x > left + 12.0 and f.pos.x < right - 12.0:
			f.entered = true
		if f.entered and f.state != Fighter.S.DOWN:
			f.pos.x = clampf(f.pos.x, left + 6.0, right - 6.0)
		if f.get("rideable") == true and f.rider == player:
			f.entered = true


# ---------------------------------------------------------------- souboj

func request_token(e: Node2D) -> bool:
	tokens = tokens.filter(func(x: Variant) -> bool: return is_instance_valid(x) and x.has_token)
	if tokens.has(e):
		return true
	if tokens.size() < MAX_TOKENS:
		tokens.append(e)
		return true
	return false


func release_token(e: Node2D) -> void:
	tokens.erase(e)


## Volá útočník v aktivních snímcích svého útoku.
func do_hits(att: Node2D) -> void:
	var mv: Dictionary = att.move
	var reach: float = float(mv["reach"]) * att.body_scale
	var targets: Array = []
	for f in fighters:
		if f.team != att.team and f.can_be_hit() and not att.hit_done.has(f):
			targets.append(f)
	if att.team == 0:
		for pr in props:
			if is_instance_valid(pr) and pr.can_be_hit() and not att.hit_done.has(pr):
				targets.append(pr)
	for f in targets:
		var dx: float = (f.pos.x - att.pos.x) * att.facing
		if mv.get("both", false):
			dx = absf(dx)
		var dy: float = absf(f.pos.y - att.pos.y)
		var width: float = f.hit_w * f.body_scale
		if dx >= -6.0 - width * 0.5 and dx <= reach + width and dy <= 14.0 + f.hit_depth and absf(f.z - att.z) < 70.0:
			att.hit_done.append(f)
			var dmg: int = int(mv["dmg"])
			var knock: bool = mv["knock"]
			f.take_hit(dmg, att.facing, knock, float(mv["push"]))
			var hit_pos := Vector2(f.pos.x - att.facing * 4.0, f.pos.y - f.z - 22.0 * f.body_scale)
			fx.burst(hit_pos, Color("fff4c0"), 8, 140.0, 0.22, 0.0, 2.0)
			fx.burst(hit_pos, Color("d8402e") if att.team == 1 else Color("f0a040"), 5, 90.0, 0.3, 300.0, 2.0)
			hitstop = 7 if knock else 4
			shake(3.0 if knock else 1.5, 0.12)
			Sfx.play("heavy" if knock else "hit", randf_range(0.9, 1.1))
			if att.team == 0:
				score += dmg * 10


func magic_blast(p: Node2D, power: int) -> void:
	flash_t = 0.45
	shake(6.0, 0.5)
	hitstop = 10
	Sfx.play("thunder")
	for f in fighters:
		if f == p or f.team == p.team or not f.alive():
			continue
		if absf(f.pos.x - cam_x) < HALF_W + 10.0:
			var dir := 1 if f.pos.x >= p.pos.x else -1
			f.invuln = 0
			f.take_hit(10 + 14 * power, dir, true, 0.0)
			fx.burst(Vector2(f.pos.x, f.pos.y - 30.0), Color("a0e8ff"), 14, 160.0, 0.5, 0.0, 3.0)
			score += 50 * power


# ---------------------------------------------------------------- předměty, smrt, konec

func spawn_pickup(kind: String, at: Vector2) -> void:
	var pr := PropScript.new()
	pr.kind = kind
	pr.stage = self
	pr.pos = at
	add_child(pr)
	props.append(pr)


func _pickups() -> void:
	if not player.alive() or player.state == Fighter.S.DOWN or player.state == Fighter.S.JUMP:
		return
	for pr in props.duplicate():
		if not is_instance_valid(pr):
			props.erase(pr)
			continue
		if pr.kind == "barrel":
			continue
		if absf(pr.pos.x - player.pos.x) < 26.0 and absf(pr.pos.y - player.pos.y) < 14.0:
			if pr.kind == "meat":
				player.hp = mini(player.hp + 35, player.max_hp)
				popup("+ZDRAVÍ", pr.pos, Color("9ad870"))
			else:
				player.runes = mini(player.runes + 1, 4)
				popup("+RUNA", pr.pos, Color("40d8ff"))
			Sfx.play("pickup")
			fx.burst(Vector2(pr.pos.x, pr.pos.y - 8.0), Color("fff4a0"), 10, 70.0, 0.4, 0.0, 2.0)
			props.erase(pr)
			pr.queue_free()


func _cleanup() -> void:
	for f in fighters.duplicate():
		if f == player:
			continue
		if f.state == Fighter.S.DEAD and f.dead_t > 45:
			if f == boss and f.get("kind") == "dragon":
				fx.burst(Vector2(f.pos.x, f.pos.y - 60.0), Color("f08a30"), 40, 220.0, 0.8, 200.0, 4.0)
			score += int(f.cfg["score"])
			kills += 1
			# Občas po nepříteli zůstane runa nebo maso.
			var roll := randf()
			if roll < 0.18:
				spawn_pickup("rune", f.pos)
			elif roll < 0.3:
				spawn_pickup("meat", f.pos)
			if f == boss:
				boss = null
			fighters.erase(f)
			tokens.erase(f)
			f.queue_free()


func _player_death() -> void:
	if player.state != Fighter.S.DEAD:
		respawn_t = 0
		return
	respawn_t += 1
	if respawn_t == 50:
		deaths += 1
		player.hp = player.max_hp
		player.set_state(Fighter.S.IDLE)
		player.invuln = 120
		popup("ZNOVU DO BOJE!", player.pos + Vector2(-30, -40), Color("f0d050"))
		for f in fighters:
			if f != player and f.alive():
				f.take_hit(0, 1 if f.pos.x >= player.pos.x else -1, true, 0.0)


## Mělké bažinaté kaluže na cestě (dá se jimi projít).
func _draw_puddles() -> void:
	var step := 230.0
	var t := time
	var first := int(floorf((cam_x - HALF_W - 200.0) / step))
	var last := int(ceilf((cam_x + HALF_W + 200.0) / step))
	for i in range(first, last + 1):
		var r1 := float(absi((i * 73856093) ^ 912367) % 1000) / 1000.0
		var r2 := float(absi((i * 19349663) ^ 4441) % 1000) / 1000.0
		if r1 < 0.2:
			continue
		var w := 90.0 + r2 * 110.0
		var h := 14.0 + r1 * 14.0
		var x := i * step + r2 * 120.0
		var y := 200.0 + r1 * 70.0
		# dithrovaný okraj z obdélníčků 4×2 px
		var row := 0.0
		while row < h:
			var k := absf(row / h - 0.5) * 2.0
			var half := w * 0.5 * sqrt(maxf(1.0 - k * k, 0.0))
			var rx := roundf(x + w * 0.5 - half)
			var rw := roundf(half * 2.0)
			var col := Color("4b5144")
			if row < 3.0 or row > h - 3.0:
				col = Color("1e231c")
			elif row < h * 0.45:
				col = Color("5c6152")
			draw_rect(Rect2(rx, roundf(y + row), rw, 2), col)
			row += 2.0
		# odraz oblohy a chvění hladiny
		draw_rect(Rect2(roundf(x + w * 0.2), roundf(y + h * 0.35), roundf(w * 0.35), 1), Color("4b5144"))
		var sh := fmod(t * 9.0 + i * 5.0, w * 0.5)
		draw_rect(Rect2(roundf(x + w * 0.25 + sh), roundf(y + h * 0.6), 10, 1), Color("8a8a7a"))
		draw_rect(Rect2(roundf(x + w * 0.6 - sh * 0.5), roundf(y + h * 0.75), 6, 1), Color("6b6e60"))
		# rákos na okraji
		for j in 3:
			var rx2 := roundf(x + w * (0.1 + 0.3 * j) + r1 * 6.0)
			draw_rect(Rect2(rx2, roundf(y - 6.0 - j % 2 * 3), 1, 7 + j % 2 * 3), Color("30352c"))


func popup(text: String, at: Vector2, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.position = at + Vector2(-14, -34)
	l.z_index = 1000
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 16.0, 0.8)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


func finish() -> void:
	if finished:
		return
	finished = true
	player.controls = false
	Sfx.play("win")
	await get_tree().create_timer(2.0, false).timeout
	completed.emit({"score": score, "kills": kills, "deaths": deaths, "time": time})


# ---------------------------------------------------------------- kreslení země

func _draw() -> void:
	# Malovaná zem: opakující se pás, posouvá se spolu s postavami.
	if ground_tex == null:
		return
	var retro := ParallaxScript.has_biome(biome)
	var h := 120.0 if retro else 156.0
	var w := float(ground_tex.get_width()) * h / float(ground_tex.get_height())
	var x := floorf((cam_x - HALF_W - 10.0) / w) * w
	while x < cam_x + HALF_W + 10.0:
		draw_texture_rect(ground_tex, Rect2(roundf(x), 300.0 - h, w, h), false)
		x += w
	if retro and biome == "swamp":
		_draw_puddles()
	if retro:
		# Hloubka: v dálce mlha, u diváka stín
		var left := cam_x - HALF_W - 4.0
		for k in 10:
			var y := 300.0 - h + k * 4.0
			draw_rect(Rect2(left, y, HALF_W * 2.0 + 8.0, 4.0), Color(0.42, 0.42, 0.40, 0.26 * (1.0 - k / 10.0)))
		for k in 8:
			var y2 := 300.0 - 32.0 + k * 4.0
			draw_rect(Rect2(left, y2, HALF_W * 2.0 + 8.0, 4.0), Color(0.03, 0.02, 0.02, 0.05 * (k + 1)))
