extends "res://scripts/fighter.gd"

const EnemyAnims := preload("res://scripts/enemy_anims.gd")
## Nepřátelé. Útočit smějí jen dva najednou (ostatní čekají opodál), každý útok
## má čitelný nápřah (postava zežloutne a nad hlavou se ukáže "!").

const KINDS := {
	"goblin": {"hp": 26, "speed": Vector2(84, 50), "reach": 28.0, "attack": "gob_atk", "cool": 46,
		"parts": "gob", "weapon": "club", "grip": Vector2(3.5, 9.0), "scale": 1.7, "score": 100},
	"ghoul": {"hp": 30, "speed": Vector2(88, 52), "reach": 20.0, "attack": "ghoul_atk", "cool": 40,
		"parts": "gob", "weapon": "club", "grip": Vector2(3.5, 9.0), "scale": 1.6, "score": 120,
		"sprite": "lidojed", "h": 100.0},
	"bat": {"hp": 16, "speed": Vector2(120, 70), "reach": 20.0, "attack": "bat_swoop", "cool": 50,
		"parts": "gob", "weapon": "club", "grip": Vector2(3.5, 9.0), "scale": 1.6, "score": 140,
		"sprite": "netopyr", "h": 62.0, "fly": true, "hit_w": 14.0},
	"skeleton": {"hp": 34, "speed": Vector2(70, 42), "reach": 46.0, "attack": "sp_atk", "cool": 64,
		"parts": "skel", "weapon": "spear", "grip": Vector2(4.0, 13.0), "scale": 2.0, "score": 150, "idle": "sp_idle"},
	"ogre": {"hp": 260, "speed": Vector2(38, 26), "reach": 30.0, "attack": "ogre_slam", "cool": 56,
		"parts": "ogre", "weapon": "tree_club", "grip": Vector2(4.5, 13.0), "scale": 3.6, "score": 3000, "armor": true,
		"name": "OBR GRUMOR", "hit_w": 7.0, "depth": 10.0},
}

var kind := "goblin"
var cfg: Dictionary = {}
var cooldown := 60
var has_token := false
var slot := 0.0
var entered := false
var dead_t := 0
var sprite_tex: Texture2D = null   # nepřítel z jednoho obrázku, pohyb dopočítán kódem
var sprite_h := 100.0
const HOVER_Z := 64.0


func _ready() -> void:
	team = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cfg = KINDS[kind]
	max_hp = int(cfg["hp"])
	hp = max_hp
	setup_parts(cfg["parts"], cfg["weapon"], cfg["grip"])
	body_scale = float(cfg["scale"])
	armor = bool(cfg.get("armor", false))
	idle_pose = String(cfg.get("idle", "idle"))
	display_name = String(cfg.get("name", ""))
	hit_w = float(cfg.get("hit_w", 9.0))
	hit_depth = float(cfg.get("depth", 0.0))
	cooldown = 30 + randi() % 50
	if cfg.has("sprite"):
		sprite_tex = load("res://art/enemy_sprite/%s.webp" % cfg["sprite"])
		sprite_h = float(cfg["h"])
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if cfg.get("fly", false):
		flying = true
		z = HOVER_Z
	if EnemyAnims.SETS.has(kind):
		setup_anims(EnemyAnims.SETS[kind]["anims"], EnemyAnims.SETS[kind]["k"])
	slot = randf_range(-40.0, 40.0)


func tick() -> void:
	physics_step()
	if state == S.DEAD:
		dead_t += 1
		_release()
		return
	match state:
		S.RIDE:
			pass # Pohyb řídí ještěr.
		S.IDLE, S.WALK:
			_ai()
		S.ATTACK:
			if kind == "bat":
				# střemhlavý útok: sletí dolů k hrdinovi a zase vzlétne
				var k := float(state_t) / float(move["len"])
				z = HOVER_Z - 50.0 * sin(k * PI)
				pos.x += facing * 70.0 * DT * sin(k * PI)
		S.HURT, S.DOWN, S.GETUP:
			_release()
	if kind == "bat":
		if state == S.DOWN or state == S.DEAD:
			flying = false
		elif state == S.IDLE or state == S.WALK:
			flying = true
			z = lerpf(z, HOVER_Z + sin(anim_clock * 3.0) * 6.0, 0.08)


func _ai() -> void:
	cooldown -= 1
	var p = stage.player
	if p == null:
		return
	var dx: float = p.pos.x - pos.x
	var dy: float = p.pos.y - pos.y
	facing = 1 if dx > 0.0 else -1
	if not p.alive() or p.state == S.DOWN or p.state == S.DEAD:
		_release()
		_walk_to(Vector2(p.pos.x - facing * 160.0, clampf(p.pos.y + slot, Y_MIN, Y_MAX)))
		return
	if not has_token:
		has_token = stage.request_token(self)
	var reach: float = float(cfg["reach"]) * body_scale
	if has_token:
		if kind == "ogre" and cooldown <= 0 and absf(dy) < 12.0 and absf(dx) > 130.0 and absf(dx) < 260.0:
			start_move("ogre_charge")
			Sfx.play("roar")
			return
		if absf(dx) <= reach and absf(dy) <= 6.0 and cooldown <= 0:
			start_move(cfg["attack"])
			return
		_walk_to(Vector2(p.pos.x - facing * reach * 0.75, p.pos.y))
	else:
		_walk_to(Vector2(p.pos.x - facing * 150.0, clampf(p.pos.y + slot, Y_MIN, Y_MAX)))


func _walk_to(target: Vector2) -> void:
	var sp: Vector2 = cfg["speed"]
	var d := target - pos
	if d.length() < 2.0:
		if state != S.IDLE:
			set_state(S.IDLE)
		walk_t += DT * 0.5
		return
	pos.x += clampf(d.x, -sp.x * DT, sp.x * DT)
	pos.y += clampf(d.y, -sp.y * DT, sp.y * DT)
	walk_t += DT * 0.8
	if state != S.WALK:
		set_state(S.WALK)


func _move_finished() -> void:
	set_state(S.IDLE)
	cooldown = int(cfg["cool"]) + randi() % 40
	_release()


func _release() -> void:
	if has_token:
		stage.release_token(self)
		has_token = false


func _draw_extra() -> void:
	if telegraph and state == S.ATTACK:
		var y := -44.0 * body_scale
		if sprite_tex != null:
			y = -sprite_h - 16.0
		draw_rect(Rect2(-2, y, 4, 9), Color("f0d050"))
		draw_rect(Rect2(-2, y + 11, 4, 3), Color("f0d050"))
		draw_rect(Rect2(-3, y - 1, 6, 1), Color("1a120e"))


# ---------------------------------------------------------------- animace z videa

var blocking := false


## Krytí: obr občas odrazí běžný úder kyjem, kostlivec se kryje štítem skoro pořád.
## Štít prorazí jen úder ve výskoku (povalí ho) a magie.
func _wants_block(knock: bool) -> bool:
	if anim_tex.is_empty() or not anim_tex.has("block"):
		return false
	if state != S.IDLE and state != S.WALK and not (blocking and state == S.HURT):
		return false
	if incoming_move == "jatk" or incoming_move == "magic":
		return false
	if kind == "skeleton":
		return randf() < 0.75
	return not knock and randf() < 0.4



func take_hit(dmg: int, dir: int, knock: bool, push: float) -> void:
	if _wants_block(knock):
		blocking = true
		set_state(S.HURT)
		facing = -dir
		vel = Vector2(dir * 40.0, 0.0)
		Sfx.play("hit", 0.55 if kind == "ogre" else 0.8)
		var hy := 120.0 if kind == "ogre" else 60.0
		stage.fx.burst(Vector2(pos.x - dir * 14.0, pos.y - hy), Color("fff4c0"), 10, 120.0, 0.25, 0.0, 2.0)
		stage.popup("BLOK", pos + Vector2(-8, -hy - 10.0), Color("c8c8d0"))
		return
	blocking = false
	super.take_hit(dmg, dir, knock, push)


func _anim_pick() -> Array:
	match state:
		S.IDLE:
			return ["idle", int(anim_clock * 6.0), 0.0]
		S.WALK:
			return ["walk", int(anim_clock * (8.0 if kind == "ogre" else 12.0)), 0.0]
		S.ATTACK:
			if move_name == "ogre_charge":
				if anim_tex.has("run"):
					return ["run", int(anim_clock * 16.0), 0.0]
				return ["walk", int(anim_clock * 24.0), 0.0]
			return ["attack", _move_frame("attack"), 0.0]
		S.HURT:
			if blocking:
				return ["block", state_t * anim_tex["block"].size() / 16, 0.0]
			return ["idle", 0, -0.1]
		S.DOWN:
			return ["fall", state_t * 2 / 3, 0.0]
		S.DEAD:
			return ["fall", 999, 0.0]
		S.GETUP:
			var n: int = anim_tex["fall"].size()
			return ["fall", n - 1 - state_t * n / 18, 0.0]
	return ["idle", int(anim_clock * 6.0), 0.0]


# ---------------------------------------------------------------- nepřítel z jednoho obrázku

## Lidojed a netopýr mají zatím jen jeden obrázek – pohyb se dopočítává
## (kymácení, výpad, záklon, pád, mávání křídly).
func _draw() -> void:
	if sprite_tex == null:
		super._draw()
		return
	if state == S.DEAD and (state_t / 4) % 2 == 0:
		return
	var sc := sprite_h / float(sprite_tex.get_height())
	var w := sprite_tex.get_width() * sc
	# stín na zemi
	var sw := w * (0.35 if flying else 0.3)
	_ellipse(Vector2(0, z), sw, sw * 0.22, Color(0, 0, 0, 0.3 if z < 30.0 else 0.18))
	var mod := Color.WHITE
	if flash > 0:
		mod = Color(1.0, 0.55, 0.5)
	elif telegraph and (state_t / 3) % 2 == 0:
		mod = Color(1.0, 0.85, 0.45)
	var rot := 0.0
	var off := Vector2.ZERO
	var sx := 1.0
	var sy := 1.0
	var t := anim_clock
	if kind == "bat":
		# mávání křídly = rychlé svislé "dýchání" obrázku
		sy = 0.86 + 0.14 * absf(sin(t * 12.0))
		sx = 1.0 + 0.05 * sin(t * 12.0)
		if state == S.ATTACK:
			rot = 0.35 * sin(float(state_t) / float(move["len"]) * PI)
		elif state == S.HURT:
			rot = -0.4
		elif state == S.DOWN or state == S.DEAD:
			rot = -2.6
			sy = 1.0
		var xf := Transform2D(rot * facing, Vector2(facing * sx * sc, sy * sc), 0.0, Vector2.ZERO)
		draw_set_transform_matrix(xf)
		draw_texture(sprite_tex, Vector2(-sprite_tex.get_width() * 0.5, -sprite_tex.get_height() * 0.5), mod)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	else:
		match state:
			S.WALK:
				off.y = -absf(sin(t * 9.0)) * 3.0
				rot = sin(t * 9.0) * 0.05
			S.IDLE:
				sy = 1.0 + sin(t * 2.5) * 0.012
			S.ATTACK:
				var h: Array = move["hit"]
				var k := clampf(float(state_t) / float(h[0]), 0.0, 1.0)
				if state_t < int(h[0]):
					rot = -0.12 * k            # nápřah dozadu
				else:
					var r := 1.0 - clampf(float(state_t - int(h[1])) / 12.0, 0.0, 1.0)
					rot = 0.28 * r             # výpad s noži dopředu
					off.x = 14.0 * r
			S.HURT:
				rot = -0.2
				off.x = -4.0
			S.DOWN, S.DEAD:
				rot = -minf(float(state_t) / 10.0, 1.0) * 1.45
			S.GETUP:
				rot = -1.45 * (1.0 - minf(float(state_t) / 18.0, 1.0))
		var xf2 := Transform2D(0.0, Vector2(facing, 1.0), 0.0, Vector2.ZERO) \
			* Transform2D(rot, off) * Transform2D(0.0, Vector2(sx * sc, sy * sc), 0.0, Vector2.ZERO)
		draw_set_transform_matrix(xf2)
		draw_texture(sprite_tex, Vector2(-sprite_tex.get_width() * 0.5, -sprite_tex.get_height()), mod)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_extra()
