extends "res://scripts/fighter.gd"
## Hrdina – kovář Mirek s kladivem.
## Odezva: vstup se čte na začátku snímku a hned se použije. Každý stisk si hra pamatuje
## 8 snímků (input buffer), takže stisk těsně před koncem úderu se nikdy neztratí.
## Údery jdou řetězit do komba a rušit úskokem nebo skokem.

const SPEED := Vector2(150.0, 84.0)
const BUF := 8

var buf := {"attack": 0, "jump": 0, "dodge": 0, "magic": 0}
var runes := 0
var magic_power := 0
var jump_vx := 0.0
var air_attacked := false
var controls := true


func _ready() -> void:
	team = 0
	max_hp = 100
	hp = max_hp
	setup_parts("hero", "hammer", Vector2(5.5, 12.0))


func read_input() -> void:
	for k in buf.keys():
		if controls and Input.is_action_just_pressed(k):
			buf[k] = BUF
		elif buf[k] > 0 and stage.hitstop <= 0:
			buf[k] -= 1


func _take(k: String) -> bool:
	if buf[k] > 0:
		buf[k] = 0
		return true
	return false


func _dir() -> Vector2:
	if not controls:
		return Vector2.ZERO
	return Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down"))


func tick() -> void:
	physics_step()
	var dir := _dir()
	match state:
		S.IDLE, S.WALK:
			_neutral(dir)
		S.ATTACK:
			if move_name == "magic":
				if state_t == 24:
					stage.magic_blast(self, magic_power)
			elif state_t >= int(move["cancel"]):
				var nxt: String = move["next"]
				if nxt != "" and _take("attack"):
					_face(dir)
					start_move(nxt)
					Sfx.play("swing", 1.0 + randf() * 0.15)
				elif _take("dodge"):
					_dodge(dir)
				elif _take("jump"):
					_jump(dir)
		S.JUMP:
			vel.x = jump_vx
			if not air_attacked and _take("attack"):
				air_attacked = true
				move_name = "jatk"
				move = Poses.MOVES["jatk"]
				hit_done.clear()
				state_t = 0
				Sfx.play("swing", 0.9)
			if move_name == "jatk":
				var h: Array = move["hit"]
				if state_t >= int(h[0]) and state_t <= int(h[1]):
					stage.do_hits(self)
		S.RIDE:
			_ride(dir)
		S.DODGE:
			# Úskok lze po 9 snímcích přerušit útokem.
			if state_t >= 9 and _take("attack"):
				start_move("atk1")
				Sfx.play("swing")
			elif state_t >= 15:
				set_state(S.IDLE)


func _neutral(dir: Vector2) -> void:
	if runes > 0 and _take("magic"):
		magic_power = runes
		runes = 0
		start_move("magic")
		invuln = 60
		Sfx.play("magic")
		return
	if _take("dodge"):
		_dodge(dir)
		return
	if _take("jump"):
		var b = stage.find_mount(self)
		if b != null:
			mount_beast(b)
		else:
			_jump(dir)
		return
	if _take("attack"):
		_face(dir)
		start_move("atk1")
		Sfx.play("swing")
		return
	if dir.length() > 0.15:
		pos += Vector2(dir.x * SPEED.x, dir.y * SPEED.y) * DT
		_face(dir)
		walk_t += DT
		if state != S.WALK:
			set_state(S.WALK)
	else:
		walk_t += DT * 0.5
		if state != S.IDLE:
			set_state(S.IDLE)


func _face(dir: Vector2) -> void:
	if dir.x > 0.2:
		facing = 1
	elif dir.x < -0.2:
		facing = -1


func _jump(dir: Vector2) -> void:
	_face(dir)
	set_state(S.JUMP)
	move = {}
	move_name = ""
	air_attacked = false
	vz = 440.0
	z = 0.5
	jump_vx = dir.x * SPEED.x * 1.1
	Sfx.play("jump")
	stage.fx.dust(pos, 4)


func _dodge(dir: Vector2) -> void:
	var dx := float(facing)
	if absf(dir.x) > 0.2:
		dx = signf(dir.x)
		facing = int(dx)
	set_state(S.DODGE)
	vel = Vector2(dx * 360.0, dir.y * 170.0)
	invuln = 12
	Sfx.play("dodge")
	stage.fx.dust(pos, 5)


func _landed() -> void:
	if state == S.JUMP:
		set_state(S.IDLE)
		move = {}
		move_name = ""
		stage.fx.dust(pos, 5)
		Sfx.play("land")
	else:
		super._landed()


# ---------------------------------------------------------------- jízda na ještěrovi

func mount_beast(b: Node2D) -> void:
	mount = b
	b.rider = self
	b.cooldown = 0
	set_state(S.RIDE)
	invuln = 20
	Sfx.play("roar", 1.4)
	stage.popup("NA KONĚ!", pos + Vector2(-20, -60), Color("9ad870"))


func _ride(dir: Vector2) -> void:
	var b = mount
	if b == null or not is_instance_valid(b):
		dismount()
		return
	if _take("jump") or _take("dodge"):
		dismount()
		_jump(dir)
		return
	if b.attack == "" and _take("attack"):
		b.start_attack("tail" if absf(dir.x) < 0.2 else "bite")
		b.telegraph = false
		b.atk_t = 20
		return
	b.drive(dir)
