extends Node2D
## Základ všech bojovníků: pozice ve 2.5D (x, hloubka y, výška z), stavy, zásahy
## a kreslení "panáčka" z dílů. Vše běží po pevných snímcích (60 za sekundu).

const Poses := preload("res://scripts/poses.gd")

const GRAVITY := 950.0
const DT := 1.0 / 60.0
const Y_MIN := 186.0
const Y_MAX := 286.0
const BACK := Color(0.68, 0.68, 0.76)

enum S { IDLE, WALK, ATTACK, JUMP, DODGE, HURT, DOWN, GETUP, DEAD }

var stage: Node2D
var pos := Vector2.ZERO
var z := 0.0
var vz := 0.0
var vel := Vector2.ZERO
var facing := 1
var hp := 100
var max_hp := 100
var team := 0
var state := S.IDLE
var state_t := 0
var invuln := 0
var flash := 0
var move: Dictionary = {}
var move_name := ""
var hit_done: Array = []
var walk_t := 0.0
var body_scale := 1.0
var down_t := 0
var armor := false
var telegraph := false

# Díly postavy
var p_head: Texture2D
var p_torso: Texture2D
var p_arm: Texture2D
var p_leg: Texture2D
var p_weapon: Texture2D
var weapon_grip := Vector2.ZERO
var idle_pose := "idle"


func setup_parts(prefix: String, weapon: String, grip: Vector2) -> void:
	p_head = Art.t(prefix + "_head")
	p_torso = Art.t(prefix + "_torso")
	p_arm = Art.t(prefix + "_arm")
	p_leg = Art.t(prefix + "_leg")
	p_weapon = Art.t(weapon)
	weapon_grip = grip


func alive() -> bool:
	return state != S.DEAD and hp > 0


func can_be_hit() -> bool:
	return invuln <= 0 and state != S.DOWN and state != S.GETUP and state != S.DEAD


func set_state(s: int) -> void:
	state = s
	state_t = 0


func start_move(name_: String) -> void:
	move_name = name_
	move = Poses.MOVES[name_]
	hit_done.clear()
	set_state(S.ATTACK)


## Fyzika společná pro všechny – volá se jednou za snímek ze stage.gd.
func physics_step() -> void:
	state_t += 1
	if invuln > 0:
		invuln -= 1
	if flash > 0:
		flash -= 1
	if z > 0.0 or vz > 0.0:
		vz -= GRAVITY * DT
		z += vz * DT
		if z <= 0.0:
			z = 0.0
			vz = 0.0
			_landed()
	pos += vel * DT
	var fr := 900.0 if z <= 0.0 else 120.0
	vel = vel.move_toward(Vector2.ZERO, fr * DT)
	pos.y = clampf(pos.y, Y_MIN, Y_MAX)

	match state:
		S.HURT:
			if state_t >= 16:
				set_state(S.IDLE)
		S.DOWN:
			if z <= 0.0:
				down_t += 1
				if down_t > 40:
					if hp <= 0:
						set_state(S.DEAD)
					else:
						set_state(S.GETUP)
		S.GETUP:
			invuln = maxi(invuln, 2)
			if state_t >= 18:
				invuln = 30 if team == 0 else 8
				set_state(S.IDLE)
		S.ATTACK:
			if move.has("dash"):
				if state_t >= int(move["dash_from"]) and state_t <= int(move["dash_to"]):
					vel.x = facing * float(move["dash"])
			var h: Array = move["hit"]
			if state_t >= int(h[0]) and state_t <= int(h[1]):
				stage.do_hits(self)
			telegraph = state_t < int(h[0]) and team == 1
			if state_t >= int(move["len"]):
				telegraph = false
				_move_finished()
	position = Vector2(roundf(pos.x), roundf(pos.y - z))
	z_index = int(pos.y)
	queue_redraw()


func _landed() -> void:
	if state == S.DOWN:
		stage.fx.dust(Vector2(pos.x, pos.y), 6)
		stage.shake(1.5, 0.08)


func _move_finished() -> void:
	set_state(S.IDLE)


## Zásah: dmg = poškození, dir = směr úderu (+1 doprava), knock = srazit k zemi.
func take_hit(dmg: int, dir: int, knock: bool, push: float) -> void:
	hp = maxi(hp - dmg, 0)
	flash = 6
	telegraph = false
	facing = -dir
	if hp <= 0 or knock:
		set_state(S.DOWN)
		down_t = 0
		vz = 230.0
		z = maxf(z, 1.0)
		vel = Vector2(dir * 110.0, 0.0)
	elif armor and state == S.ATTACK:
		pass # Zlobr se při nápřahu nenechá přerušit.
	else:
		set_state(S.HURT)
		vel = Vector2(dir * push, 0.0)


func current_pose() -> Dictionary:
	match state:
		S.WALK:
			var k := (sin(walk_t * 11.0) + 1.0) * 0.5
			return Poses.blend(Poses.POSES["walk_a"], Poses.POSES["walk_b"], k)
		S.ATTACK:
			return Poses.at(move["keys"], float(state_t))
		S.JUMP:
			if not move.is_empty() and move_name == "jatk":
				return Poses.at(move["keys"], float(state_t))
			return Poses.blend(Poses.POSES["jump"], Poses.POSES["jump"], 0.0)
		S.DODGE:
			return Poses.blend(Poses.POSES["dodge"], Poses.POSES["dodge"], 0.0)
		S.HURT:
			return Poses.blend(Poses.POSES["hurt"], Poses.POSES["hurt"], 0.0)
		S.DOWN, S.DEAD:
			return Poses.blend(Poses.POSES["down"], Poses.POSES["down"], 0.0)
		S.GETUP:
			if state_t < 10:
				return Poses.blend(Poses.POSES["down"], Poses.POSES["getup"], state_t / 10.0)
			return Poses.blend(Poses.POSES["getup"], Poses.POSES[idle_pose], minf((state_t - 10) / 8.0, 1.0))
	var idle := Poses.blend(Poses.POSES[idle_pose], Poses.POSES[idle_pose], 0.0)
	idle["dy"] = float(idle["dy"]) + (1.0 if fmod(walk_t * 2.0, 2.0) > 1.0 else 0.0)
	return idle


func _draw() -> void:
	if state == S.DEAD and (state_t / 4) % 2 == 0:
		return
	if invuln > 0 and state != S.GETUP and state != S.DOWN and (invuln / 3) % 2 == 0:
		return
	# Stín na zemi
	var sw := 11.0 * body_scale
	_ellipse(Vector2(0, z), sw, 3.0 * body_scale, Color(0, 0, 0, 0.3))

	var p := current_pose()
	var mod := Color.WHITE
	if flash > 0:
		mod = Color(1.0, 0.55, 0.5)
	elif telegraph and (state_t / 3) % 2 == 0:
		mod = Color(1.0, 0.85, 0.45)
	var back := BACK * mod
	back.a = 1.0

	var leg_len := float(p_leg.get_height() - 2)
	var torso_h := float(p_torso.get_height() - 2)
	var root := Transform2D(0.0, Vector2(facing * body_scale, body_scale), 0.0, Vector2.ZERO)
	var rot := float(p["rot"])
	if rot != 0.0:
		root = root * Transform2D(rot, Vector2(0, -2))
	var hip := Vector2(0, -leg_len + float(p["dy"]))
	var torso_xf := root * Transform2D(float(p["lean"]), hip)
	var shoulder := Vector2(0, -torso_h + 3)

	_limb(torso_xf, shoulder + Vector2(-2, 0), float(p["ab"]), p_arm, back)
	_limb(root, hip + Vector2(-2, 0), float(p["lb"]), p_leg, back)
	_limb(root, hip + Vector2(2, 0), float(p["lf"]), p_leg, mod)
	draw_set_transform_matrix(torso_xf)
	draw_texture(p_torso, Vector2(-floorf(p_torso.get_width() * 0.5), -torso_h - 1), mod)
	draw_set_transform_matrix(torso_xf * Transform2D(float(p["head"]), Vector2(1, -torso_h + 1)))
	draw_texture(p_head, Vector2(-floorf(p_head.get_width() * 0.5), -p_head.get_height() + 2), mod)
	var arm_xf := torso_xf * Transform2D(float(p["af"]), shoulder + Vector2(2, 0))
	var hand := Vector2(0, p_arm.get_height() - 3)
	draw_set_transform_matrix(arm_xf * Transform2D(float(p["w"]), hand))
	draw_texture(p_weapon, -weapon_grip, mod)
	draw_set_transform_matrix(arm_xf)
	draw_texture(p_arm, Vector2(-floorf(p_arm.get_width() * 0.5), -1), mod)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_extra()


func _draw_extra() -> void:
	pass


func _limb(xf: Transform2D, at: Vector2, ang: float, tex: Texture2D, mod: Color) -> void:
	draw_set_transform_matrix(xf * Transform2D(ang, at))
	draw_texture(tex, Vector2(-floorf(tex.get_width() * 0.5), -1), mod)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)
