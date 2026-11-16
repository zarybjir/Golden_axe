extends Node2D
## Základ všech bojovníků: pozice ve 2.5D (x, hloubka y, výška z), stavy, zásahy
## a kreslení "panáčka" z dílů. Vše běží po pevných snímcích (60 za sekundu).

const Poses := preload("res://scripts/poses.gd")
const HeroRig := preload("res://scripts/hero_rig.gd")
const HeroAnims := preload("res://scripts/hero_anims.gd")

const GRAVITY := 1200.0
const DT := 1.0 / 60.0
const Y_MIN := 196.0
const Y_MAX := 290.0
const BACK := Color(0.68, 0.68, 0.76)

enum S { IDLE, WALK, ATTACK, JUMP, DODGE, HURT, DOWN, GETUP, DEAD, RIDE }

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
var body_scale := 2.0
var hit_w := 9.0
var hit_depth := 0.0
var display_name := ""
var mount: Node2D = null
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
# Malovaná loutka (vysoké rozlišení) – když je vyplněná, kreslí se místo pixelových dílů.
var rig_tex := {}
# Snímkové animace z videa (název -> pole textur). Mají přednost před loutkou.
var anim_tex := {}
var anim_clock := 0.0
var anim_set: Dictionary = {}
var down_len := 40      # jak dlouho leží (snímky)
var getup_len := 18     # jak dlouho vstává
var flying := false     # létající nepřítel (netopýr) – bez gravitace
var incoming_move := ""  # tah, kterým nás právě zasahují (kvůli krytí)
var anim_k := 1.0


func setup_parts(prefix: String, weapon: String, grip: Vector2) -> void:
	p_head = Art.t(prefix + "_head")
	p_torso = Art.t(prefix + "_torso")
	p_arm = Art.t(prefix + "_arm")
	p_leg = Art.t(prefix + "_leg")
	p_weapon = Art.t(weapon)
	weapon_grip = grip


func is_foe() -> bool:
	return team == 1


## Snímkové animace (výchozí sada je hrdina; nepřátelé předávají vlastní).
func setup_anims(aset: Dictionary = HeroAnims.ANIMS, k: float = HeroAnims.K) -> void:
	anim_set = aset
	anim_k = k
	for n in aset:
		var arr: Array = []
		for path in aset[n]["frames"]:
			arr.append(load(path))
		anim_tex[n] = arr
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func setup_rig() -> void:
	for n in ["head", "torso", "uarm", "farm", "thigh", "shin", "hammer"]:
		rig_tex[n] = load("res://art/hero/%s.png" % n)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


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
	anim_clock += DT
	if invuln > 0:
		invuln -= 1
	if flash > 0:
		flash -= 1
	if state != S.RIDE and not flying and (z > 0.0 or vz > 0.0):
		vz -= GRAVITY * DT
		z += vz * DT
		if z <= 0.0:
			z = 0.0
			vz = 0.0
			_landed()
	pos += vel * DT
	var fr := 900.0 if z <= 0.0 else 120.0
	vel = vel.move_toward(Vector2.ZERO, fr * DT)
	pos.y = clampf(pos.y, Y_MIN, Y_MAX + 1.0)

	match state:
		S.HURT:
			if state_t >= 16:
				set_state(S.IDLE)
		S.DOWN:
			if z <= 0.0:
				down_t += 1
				if down_t > down_len:
					if hp <= 0:
						set_state(S.DEAD)
					else:
						set_state(S.GETUP)
		S.GETUP:
			invuln = maxi(invuln, 2)
			if state_t >= getup_len:
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
	if state == S.RIDE:
		dismount()
		knock = true
	hp = maxi(hp - dmg, 0)
	flash = 6
	telegraph = false
	facing = -dir
	if hp <= 0 or knock:
		set_state(S.DOWN)
		down_t = 0
		if anim_tex.has("fall") and not flying:
			# pád je celý ve videoanimaci – nevyhazovat do vzduchu (jinak "visí")
			vz = 0.0
			z = 0.0
			vel = Vector2(dir * 90.0, 0.0)
		else:
			vz = 300.0
			z = maxf(z, 1.0)
			vel = Vector2(dir * 170.0, 0.0)
	elif armor and state == S.ATTACK:
		pass # Zlobr se při nápřahu nenechá přerušit.
	else:
		set_state(S.HURT)
		vel = Vector2(dir * push * 1.6, 0.0)


func dismount() -> void:
	if mount != null and is_instance_valid(mount):
		mount.rider = null
	mount = null
	if state == S.RIDE:
		set_state(S.IDLE)


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
		S.RIDE:
			return Poses.blend(Poses.POSES["ride"], Poses.POSES["ride"], 0.0)
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
	# blikání (nezranitelnost) jen ve stoji a chůzi – ne při úskoku, skoku a útoku
	if invuln > 0 and (state == S.IDLE or state == S.WALK) and (invuln / 3) % 2 == 0:
		return
	# Stín na zemi
	if state != S.RIDE:
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

	if not anim_tex.is_empty():
		_draw_anim(mod)
		_draw_extra()
		return
	if not rig_tex.is_empty():
		_draw_rig(p, mod, back)
		_draw_extra()
		return
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


## Vybere animaci a snímek podle stavu: [název, snímek, náklon].
func _anim_pick() -> Array:
	match state:
		S.WALK:
			return ["walk", int(anim_clock * 14.0), 0.0]
		S.ATTACK:
			var nm := move_name if anim_set.has(move_name) else "atk1"
			return [nm, _move_frame(nm), 0.0]
		S.JUMP:
			if move_name == "jatk":
				# ze skoku plynule navazuje úder sekerou shora
				return ["atk3", _move_frame("atk3"), 0.0]
			var n: int = anim_tex["jump"].size()
			var f := clampf(0.5 - vz / 880.0, 0.0, 1.0)
			return ["jump", 1 + int(f * float(n - 3)), 0.0]
		S.DODGE:
			return ["dodge", state_t * 6 / 15, 0.0]
		S.HURT:
			return ["idle", 0, -0.18]
		S.DOWN:
			return ["down", state_t / 3, 0.0]
		S.DEAD:
			return ["down", 99, 0.0]
		S.GETUP:
			return ["getup", state_t * 14 / 18, 0.0]
		S.RIDE:
			return ["ride", 0, 0.0]
	return ["idle", int(anim_clock * 6.0), 0.0]


## Snímek útoku tak, aby úder ve videu padl přesně na aktivní snímky útoku ve hře.
func _move_frame(nm: String) -> int:
	var a: Dictionary = anim_set[nm]
	var n: int = anim_tex[nm].size()
	var impact: int = a["impact"]
	if impact < 0:
		impact = n / 2
	var h: Array = move["hit"]
	var hit0 := maxf(float(h[0]), 1.0)
	var ln := float(move["len"])
	var t := float(state_t)
	if t < hit0:
		return int(t / hit0 * float(impact))
	return mini(n - 1, impact + int((t - hit0) / maxf(ln - hit0, 1.0) * float(n - impact)))


func _draw_anim(mod: Color) -> void:
	var pick := _anim_pick()
	var nm: String = pick[0]
	var arr: Array = anim_tex[nm]
	var a: Dictionary = anim_set[nm]
	var i: int = pick[1]
	if a["loop"]:
		i = posmod(i, arr.size())
	else:
		i = clampi(i, 0, arr.size() - 1)
	var off: Vector2 = a["offsets"][i]
	draw_set_transform(Vector2.ZERO, float(pick[2]) * facing, Vector2(facing * anim_k, anim_k))
	draw_texture(arr[i], off, mod)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_rig(p: Dictionary, mod: Color, back: Color) -> void:
	var k := HeroRig.K
	var root := Transform2D(0.0, Vector2(facing * k, k), 0.0, Vector2.ZERO)
	var rot := float(p["rot"])
	if rot != 0.0:
		root = root * Transform2D(rot, Vector2(0, -2.0 / k))
	var hip := Vector2(0, -HeroRig.LEG_LEN + float(p["dy"]) * 1.5 / k)
	var torso := root * Transform2D(float(p["lean"]), hip)
	_rig_leg(root, hip + HeroRig.HIP_B, float(p["lb"]), back)
	var ua_b := _rig_seg(torso, HeroRig.SHOULDER_B, float(p["ab"]), HeroRig.UARM_A0, HeroRig.UARM_PIVOT, "uarm", back)
	_rig_seg(ua_b, HeroRig.UARM_END, -0.3, HeroRig.FARM_A0, HeroRig.FARM_PIVOT, "farm", back)
	_rig_leg(root, hip + HeroRig.HIP_F, float(p["lf"]), mod)
	_rig_draw(torso, "torso", -HeroRig.TORSO_PIVOT, mod)
	_rig_draw(torso * Transform2D(float(p["head"]), HeroRig.NECK), "head", -HeroRig.HEAD_PIVOT, mod)
	var ua := torso * Transform2D(float(p["af"]), HeroRig.SHOULDER_F) * Transform2D(-HeroRig.UARM_A0, Vector2.ZERO)
	_rig_draw(ua, "uarm", -HeroRig.UARM_PIVOT, mod)
	var el := ua * Transform2D(-0.3, HeroRig.UARM_END) * Transform2D(-HeroRig.FARM_A0, Vector2.ZERO)
	_rig_draw(el * Transform2D(float(p["w"]) + 0.3, HeroRig.FARM_END), "hammer", -HeroRig.HAMMER_GRIP, mod)
	_rig_draw(el, "farm", -HeroRig.FARM_PIVOT, mod)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _rig_seg(parent: Transform2D, at: Vector2, ang: float, a0: float, pivot: Vector2, part: String, mod: Color) -> Transform2D:
	var m := parent * Transform2D(ang, at) * Transform2D(-a0, Vector2.ZERO)
	_rig_draw(m, part, -pivot, mod)
	return m


func _rig_leg(root: Transform2D, at: Vector2, l: float, mod: Color) -> void:
	var th := _rig_seg(root, at, l, HeroRig.THIGH_A0, HeroRig.THIGH_PIVOT, "thigh", mod)
	_rig_seg(th, HeroRig.THIGH_END, 0.12 + absf(l) * 0.6, HeroRig.SHIN_A0, HeroRig.SHIN_PIVOT, "shin", mod)


func _rig_draw(m: Transform2D, part: String, offset: Vector2, mod: Color) -> void:
	draw_set_transform_matrix(m)
	draw_texture(rig_tex[part], offset, mod)


func _limb(xf: Transform2D, at: Vector2, ang: float, tex: Texture2D, mod: Color) -> void:
	draw_set_transform_matrix(xf * Transform2D(ang, at))
	draw_texture(tex, Vector2(-floorf(tex.get_width() * 0.5), -1), mod)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)
