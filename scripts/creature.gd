extends "res://scripts/fighter.gd"
## Velká stvoření složená z dílů: drak (boss) a ještěr, na kterém se dá jezdit.
## Útoky mají dlouhý, dobře čitelný nápřah (stvoření bliká a nad ním je "!").

var kind := "dragon"     # dragon / beast
var prefix := "drg"
var wings := true
var rideable := false
var rider = null
var speed := Vector2(50, 30)
var attack := ""
var atk_t := 0
var cooldown := 120
var anim := 0.0
var moving := false
var head_off := Vector2(30, -44)
var head_target := Vector2(30, -44)
var jaw := 0.0
var rear := 0.0
var tail_swing := 0.0
var neutral_t := 0
var dead_t := 0
var entered := false
var cfg := {"score": 5000}
const DragonData := preload("res://scripts/dragon_data.gd")
var paint := {}          # namalovaný drak: póza -> textura


func _roaring() -> bool:
	# tlama otevřená: chrlení ohně a kousnutí po nápřahu, řev při dupnutí
	return jaw > 0.5 or (attack == "stomp" and atk_t < 48)


## Kde má drak tlamu (ve světě) – odsud chrlí oheň.
func mouth_world() -> Vector2:
	if paint.is_empty():
		return _local_to_world(head_off + Vector2(18, 3))
	var m: Array = DragonData.POSE["roar" if _roaring() else "idle"]
	var w := float(DragonData.POSE["idle"][0])
	var pivot := Vector2(-w * 0.3, 0.0)
	var loc := pivot + (Vector2(float(m[3]), float(m[4])) - pivot).rotated(rear * 0.6 + tail_swing * 0.05)
	return position + Vector2(loc.x * facing, loc.y)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if kind == "beast":
		prefix = "beast"
		wings = false
		rideable = true
		body_scale = 1.6
		max_hp = 9999
		speed = Vector2(95, 60)
		hit_w = 26.0
		hit_depth = 10.0
		display_name = "lizard"
		team = 1 if rider != null else 2
	else:
		team = 1
		body_scale = 2.0
		max_hp = int(round(420 * Settings.hp_mult()))
		hit_w = 34.0
		hit_depth = 18.0
		display_name = "EMBER THE DRAGON"
		armor = true
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		for n in ["idle", "roar"]:
			var path := "res://art/enemy_sprite/drak_%s.png" % n
			if ResourceLoader.exists(path):
				paint[n] = load(path)
	hp = max_hp


func is_foe() -> bool:
	return not rideable


func saddle_z() -> float:
	return 17.0 * body_scale


func can_be_hit() -> bool:
	if rideable:
		return false
	return super.can_be_hit()


func take_hit(dmg: int, dir: int, _knock: bool, _push: float) -> void:
	if rideable:
		return
	hp = maxi(hp - dmg, 0)
	flash = 6
	if hp <= 0:
		attack = ""
		telegraph = false
		set_state(S.DOWN)
		down_t = 0
		facing = -dir
		Sfx.play("roar", 0.7)


func tick() -> void:
	physics_step()
	anim += DT
	moving = false
	if state == S.DOWN or state == S.DEAD:
		rear = lerpf(rear, 0.5, 0.05)
		head_target = Vector2(36, -8)
		jaw = 0.6
		_update_head()
		if state == S.DEAD:
			dead_t += 1
		return
	if rideable:
		_beast_tick()
	else:
		_dragon_ai()
	_update_head()


func _update_head() -> void:
	head_off = head_off.lerp(head_target, 0.25)


# ---------------------------------------------------------------- drak

func _dragon_ai() -> void:
	var p = stage.player
	if attack != "":
		_run_attack()
		return
	head_target = Vector2(30, -44 + sin(anim * 2.0) * 2.0)
	jaw = lerpf(jaw, 0.0, 0.2)
	rear = lerpf(rear, 0.0, 0.2)
	tail_swing = lerpf(tail_swing, 0.0, 0.1)
	cooldown -= 1
	var dx: float = p.pos.x - pos.x
	var dy: float = p.pos.y - pos.y
	facing = 1 if dx > 0.0 else -1
	if not p.alive():
		return
	if cooldown <= 0:
		if absf(dx) < 80.0:
			start_attack("stomp" if randf() < 0.5 else "tail")
			return
		if absf(dx) < 190.0 and absf(dy) < 22.0:
			start_attack("fire" if randf() < 0.6 else "bite")
			return
	_walk(Vector2(p.pos.x - facing * 130.0, p.pos.y))


func _walk(target: Vector2) -> void:
	var d := target - pos
	if d.length() < 3.0:
		return
	pos.x += clampf(d.x, -speed.x * DT, speed.x * DT)
	pos.y += clampf(d.y, -speed.y * DT, speed.y * DT)
	moving = true


func start_attack(a: String) -> void:
	attack = a
	atk_t = 0
	telegraph = true
	if a == "stomp" or a == "fire":
		Sfx.play("roar", 0.8 if kind == "dragon" else 1.3)


func _run_attack() -> void:
	atk_t += 1
	match attack:
		"fire":
			if atk_t < 40:
				head_target = Vector2(16, -60)
				jaw = 0.3
			elif atk_t < 100:
				telegraph = false
				head_target = Vector2(40, -40 + sin(atk_t * 0.3) * 3.0)
				jaw = 1.0
				if atk_t == 40:
					Sfx.play("fire")
				if atk_t % 2 == 0:
					var mouth := mouth_world()
					stage.fx.spray(mouth, Vector2(facing, 0.35), 0.35, 260.0, 3,
						[Color("f0d050"), Color("f08a30"), Color("d8402e")])
				if atk_t % 10 == 0:
					stage.area_hit(self, 30.0, 200.0, 26.0, 6, atk_t == 90, 70.0)
			elif atk_t < 130:
				head_target = Vector2(30, -44)
				jaw = 0.0
			else:
				_end_attack(110)
		"bite":
			if atk_t < 26:
				head_target = Vector2(12, -54)
				jaw = 0.2
			elif atk_t < 34:
				telegraph = false
				head_target = Vector2(60, -24)
				jaw = 1.0
				if atk_t == 28:
					stage.area_hit(self, 20.0, 150.0, 22.0, 16, true, 0.0)
					Sfx.play("heavy", 0.7)
			elif atk_t > 60:
				_end_attack(80)
		"tail":
			if atk_t < 32:
				tail_swing = lerpf(tail_swing, -0.8, 0.15)
				rear = lerpf(rear, 0.1, 0.1)
			elif atk_t < 44:
				telegraph = false
				tail_swing = lerpf(tail_swing, 1.6, 0.35)
				if atk_t == 36:
					stage.area_hit(self, -170.0 if kind == "dragon" else -110.0, 70.0, 30.0,
						14 if kind == "dragon" else 18, true, 0.0)
					Sfx.play("heavy", 0.8)
			elif atk_t > 66:
				_end_attack(90 if kind == "dragon" else 50)
		"stomp":
			if atk_t < 38:
				rear = lerpf(rear, -0.38, 0.1)
				head_target = Vector2(22, -64)
			elif atk_t < 48:
				telegraph = false
				rear = lerpf(rear, 0.08, 0.5)
				if atk_t == 40:
					stage.area_hit(self, -150.0, 150.0, 44.0, 12, true, 0.0, true)
					stage.shake(7.0, 0.4)
					stage.fx.dust(Vector2(pos.x + facing * 30.0, pos.y), 18)
					stage.fx.dust(Vector2(pos.x - facing * 20.0, pos.y), 12)
					Sfx.play("thunder", 1.4)
			elif atk_t > 80:
				_end_attack(100)


func _end_attack(cool: int) -> void:
	attack = ""
	telegraph = false
	cooldown = cool + randi() % 40


func _local_to_world(v: Vector2) -> Vector2:
	var root := _root_xf()
	return position + root * v


# ---------------------------------------------------------------- ještěr k jízdě

func _beast_tick() -> void:
	if rider != null and not is_instance_valid(rider):
		rider = null
	if rider == null:
		team = 2
		attack = ""
		telegraph = false
		head_target = Vector2(30, -40 + sin(anim * 2.0) * 2.0)
		tail_swing = lerpf(tail_swing, 0.0, 0.1)
		return
	team = rider.team
	if attack != "":
		_run_attack()
	elif rider.team == 1:
		_beast_ai()
	else:
		head_target = Vector2(30, -40 + sin(anim * 3.0) * 2.0)
		tail_swing = lerpf(tail_swing, 0.0, 0.1)
	_sync_rider()


func _beast_ai() -> void:
	var p = stage.player
	head_target = Vector2(30, -40)
	tail_swing = lerpf(tail_swing, 0.0, 0.1)
	cooldown -= 1
	var dx: float = p.pos.x - pos.x
	var dy: float = p.pos.y - pos.y
	facing = 1 if dx > 0.0 else -1
	if not p.alive():
		return
	if cooldown <= 0 and absf(dx) < 110.0 and absf(dy) < 18.0:
		start_attack("tail" if randf() < 0.5 else "bite")
		return
	_walk(Vector2(p.pos.x - facing * 70.0, p.pos.y))


## Jízda hráče: pohyb páčkou.
func drive(dir: Vector2) -> void:
	if attack != "":
		return
	if dir.length() > 0.15:
		pos += Vector2(dir.x * speed.x, dir.y * speed.y) * DT
		moving = true
		if dir.x > 0.2:
			facing = 1
		elif dir.x < -0.2:
			facing = -1
	pos.y = clampf(pos.y, Y_MIN, Y_MAX)


func _sync_rider() -> void:
	if rider == null:
		return
	rider.pos = Vector2(pos.x - facing * 2.0, pos.y + 1.0)
	rider.z = saddle_z() + (absf(sin(anim * 9.0)) * 2.0 if moving else 0.0)
	rider.facing = facing
	rider.position = Vector2(roundf(rider.pos.x), roundf(rider.pos.y - rider.z))
	rider.z_index = int(pos.y) + 1


# ---------------------------------------------------------------- kreslení

func _root_xf() -> Transform2D:
	var pivot := Vector2(-12, -8)
	return Transform2D(0.0, Vector2(facing * body_scale, body_scale), 0.0, Vector2.ZERO) \
		* Transform2D(rear, pivot) * Transform2D(0.0, -pivot)


func _draw() -> void:
	if state == S.DEAD and (state_t / 4) % 2 == 0:
		return
	if not paint.is_empty():
		_draw_painted()
		return
	_ellipse(Vector2(0, z), 30.0 * body_scale, 5.0 * body_scale, Color(0, 0, 0, 0.3))
	var mod := Color.WHITE
	if flash > 0:
		mod = Color(1.0, 0.55, 0.5)
	elif SHOW_HINTS and telegraph and (atk_t / 3) % 2 == 0:
		mod = Color(1.0, 0.85, 0.45)
	var back := Color(0.65, 0.65, 0.72) * mod
	back.a = 1.0
	var root := _root_xf()
	var leg: Texture2D = Art.t(prefix + "_leg")
	var walk := anim * 9.0 if moving else 0.0

	# Vzdálené nohy a křídlo
	_part(root, Vector2(-10, -12), sin(walk + 1.6) * 0.4, leg, Vector2(4, 1), back)
	_part(root, Vector2(9, -12), sin(walk + 4.7) * 0.4, leg, Vector2(4, 1), back)
	if wings:
		_wing(root, Vector2(2, -22), back * Color(0.8, 0.8, 0.8))
	# Ocas
	var seg: Texture2D = Art.t(prefix + "_tail")
	var p := Vector2(-15, -14)
	for i in 6:
		var a := PI - 0.25 + sin(anim * 3.0 - i * 0.7) * 0.18 + tail_swing * (float(i + 1) / 6.0)
		p += Vector2(cos(a), sin(a) * 0.5 + 0.12) * 6.0
		draw_set_transform_matrix(root * Transform2D(0.0, p))
		draw_texture(seg if i < 5 else Art.t(prefix + "_tip"), -Vector2(seg.get_size()) * 0.5, mod)
	# Tělo
	var body: Texture2D = Art.t(prefix + "_body")
	draw_set_transform_matrix(root)
	draw_texture(body, Vector2(-16, -24), mod)
	# Krk
	var neck: Texture2D = Art.t(prefix + "_neck")
	var n0 := Vector2(11, -20)
	var ctrl := Vector2(26, -26)
	for i in 5:
		var tt := float(i + 1) / 6.0
		var q := n0.lerp(ctrl, tt).lerp(ctrl.lerp(head_off, tt), tt)
		draw_set_transform_matrix(root * Transform2D(0.0, q))
		draw_texture(neck, -Vector2(neck.get_size()) * 0.5, mod)
	# Hlava s čelistí
	var head: Texture2D = Art.t(prefix + "_head")
	var jaw_t: Texture2D = Art.t(prefix + "_jaw")
	var hx := root * Transform2D(-jaw * 0.25, head_off)
	draw_set_transform_matrix(hx * Transform2D(jaw * 0.7, Vector2(-2, 3)))
	draw_texture(jaw_t, Vector2(-1, -1), mod)
	draw_set_transform_matrix(hx)
	draw_texture(head, Vector2(-5, -8), mod)
	# Přední nohy a křídlo
	_part(root, Vector2(-8, -12), sin(walk) * 0.4, leg, Vector2(4, 1), mod)
	_part(root, Vector2(11, -12), sin(walk + 3.1) * 0.4, leg, Vector2(4, 1), mod)
	if wings:
		_wing(root, Vector2(4, -24), mod)
	if rideable:
		# Sedlo
		draw_set_transform_matrix(root)
		draw_rect(Rect2(-6, -25, 13, 4), Color("5a3418"))
		draw_rect(Rect2(-6, -25, 13, 1), Color("b07a40"))
		draw_rect(Rect2(-3, -21, 3, 7), Color("8a5428"))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if SHOW_HINTS and telegraph:
		var y := -90.0 * body_scale * 0.6
		draw_rect(Rect2(-3, y, 6, 14), Color("f0d050"))
		draw_rect(Rect2(-3, y + 17, 6, 5), Color("f0d050"))


## Namalovaný drak: dvě pózy (klid / řev), pohyb dělá dýchání, kolébání při chůzi
## a naklánění celého těla kolem zadních nohou (vzpínání, pád).
func _draw_painted() -> void:
	var nm := "roar" if _roaring() else "idle"
	var tex: Texture2D = paint[nm]
	var m: Array = DragonData.POSE[nm]
	var w := float(m[0])
	var h := float(m[1])
	var ax := float(m[2])
	_ellipse(Vector2(0, z), w * 0.42, 9.0, Color(0, 0, 0, 0.35))
	var mod := Color(0.92, 0.9, 0.88)
	if flash > 0:
		mod = Color(1.0, 0.55, 0.5)
	elif SHOW_HINTS and telegraph and (atk_t / 3) % 2 == 0:
		mod = Color(1.0, 0.85, 0.45)
	if state == S.DEAD or state == S.DOWN:
		mod = mod * Color(0.7, 0.66, 0.64)
	var breathe := 1.0 + sin(anim * 2.2) * 0.012
	var bob := absf(sin(anim * 9.0)) * 2.0 if moving else 0.0
	# otáčení kolem zadních nohou (rear < 0 = přední část se zvedá)
	var pivot := Vector2(-float(DragonData.POSE["idle"][0]) * 0.3, 0.0)
	var ang := rear * 0.6 + tail_swing * 0.05
	var xf := Transform2D(0.0, Vector2(facing, 1.0), 0.0, Vector2(0.0, -bob)) \
		* Transform2D(ang, pivot) * Transform2D(0.0, -pivot)
	draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(1.0, breathe), 0.0, Vector2.ZERO))
	draw_texture_rect(tex, Rect2(-ax, -h, w, h), false, mod)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if SHOW_HINTS and telegraph:
		var y := -h - 24.0
		draw_rect(Rect2(-3, y, 6, 14), Color("f0d050"))
		draw_rect(Rect2(-3, y + 17, 6, 5), Color("f0d050"))


func _part(root: Transform2D, at: Vector2, ang: float, tex: Texture2D, pivot: Vector2, mod: Color) -> void:
	draw_set_transform_matrix(root * Transform2D(ang, at))
	draw_texture(tex, -pivot, mod)


func _wing(root: Transform2D, shoulder: Vector2, col: Color) -> void:
	var flap := sin(anim * (6.0 if attack == "stomp" else 2.5)) * 0.45
	if attack == "stomp" and atk_t < 38:
		flap = -0.6
	var r := Transform2D(flap, Vector2.ZERO)
	var elbow := shoulder + r * Vector2(-8, -20)
	var tip := elbow + r * Vector2(-24, -10)
	var f1 := elbow + r * Vector2(-26, 8)
	var f2 := elbow + r * Vector2(-18, 16)
	var f3 := shoulder + Vector2(-14, 2)
	draw_set_transform_matrix(root)
	var membrane := Color("8e2020") * col
	membrane.a = 1.0
	draw_colored_polygon(PackedVector2Array([shoulder, elbow, tip, f1, f2, f3]), membrane)
	var bone := Color("d8402e") * col
	bone.a = 1.0
	draw_line(shoulder, elbow, bone, 2.0)
	draw_line(elbow, tip, bone, 1.5)
	draw_line(elbow, f1, bone, 1.0)
	draw_line(elbow, f2, bone, 1.0)
	draw_polyline(PackedVector2Array([shoulder, elbow, tip, f1, f2, f3, shoulder]), Color("1a120e"), 1.0)
