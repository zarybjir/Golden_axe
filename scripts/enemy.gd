extends "res://scripts/fighter.gd"

const EnemyAnims := preload("res://scripts/enemy_anims.gd")
## Nepřátelé. Útočit smějí jen dva najednou (ostatní čekají opodál), každý útok
## má čitelný nápřah (postava zežloutne a nad hlavou se ukáže "!").

const KINDS := {
	"goblin": {"hp": 26, "range": 40.0, "speed": Vector2(84, 50), "reach": 28.0, "attack": "gob_atk", "cool": 46,
		"parts": "gob", "weapon": "club", "grip": Vector2(3.5, 9.0), "scale": 1.7, "score": 100},
	"ghoul": {"hp": 30, "range": 46.0, "speed": Vector2(88, 52), "reach": 20.0, "attack": "ghoul_atk", "cool": 40,
		"parts": "gob", "weapon": "club", "grip": Vector2(3.5, 9.0), "scale": 1.6, "score": 120,
		"sprite": "lidojed", "h": 100.0},
	"spider": {"hp": 30, "range": 56.0, "speed": Vector2(78, 46), "reach": 20.0, "attack": "spider_stab", "cool": 44,
		"parts": "gob", "weapon": "club", "grip": Vector2(3.5, 9.0), "scale": 1.6, "score": 150,
		"sprite": "pavouk", "h": 64.0, "hit_w": 16.0},
	"vine": {"hp": 70, "range": 140.0, "speed": Vector2(22, 16), "reach": 20.0, "attack": "vine_lash", "cool": 80,
		"parts": "gob", "weapon": "club", "grip": Vector2(3.5, 9.0), "scale": 1.6, "score": 250,
		"sprite": "lianovec", "h": 124.0, "hit_w": 12.0},
	"native": {"hp": 22, "range": 60.0, "speed": Vector2(130, 76), "reach": 20.0, "attack": "native_jab", "cool": 26,
		"parts": "gob", "weapon": "club", "grip": Vector2(3.5, 9.0), "scale": 1.6, "score": 120,
		"sprite": "domorodec", "h": 62.0},
	"bat": {"hp": 16, "range": 38.0, "speed": Vector2(120, 70), "reach": 20.0, "attack": "bat_swoop", "cool": 50,
		"parts": "gob", "weapon": "club", "grip": Vector2(3.5, 9.0), "scale": 1.6, "score": 140,
		"sprite": "netopyr", "h": 62.0, "fly": true, "hit_w": 14.0},
	"skeleton": {"hp": 34, "range": 66.0, "speed": Vector2(70, 42), "reach": 46.0, "attack": "sp_atk", "cool": 64,
		"parts": "skel", "weapon": "spear", "grip": Vector2(4.0, 13.0), "scale": 2.0, "score": 150, "idle": "sp_idle"},
	"ogre": {"hp": 260, "range": 100.0, "speed": Vector2(38, 26), "reach": 30.0, "attack": "ogre_slam", "cool": 56,
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
	if cfg.has("sprite") and not EnemyAnims.SETS.has(kind):
		sprite_tex = load("res://art/enemy_sprite/%s.webp" % cfg["sprite"])
		sprite_h = float(cfg["h"])
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if cfg.get("fly", false):
		flying = true
		z = HOVER_Z
	if EnemyAnims.SETS.has(kind):
		setup_anims(EnemyAnims.SETS[kind]["anims"], EnemyAnims.SETS[kind]["k"])
		if anim_tex.has("fall"):
			# pád ve skutečné rychlosti videa, pak chvíli leží a pomalu vstává
			down_len = anim_tex["fall"].size() * 3 / 2 + 35
			getup_len = 60 if kind == "ogre" else 45
	slot = randf_range(-40.0, 40.0)


## Vylézání ze země (hřbitov): postava se zvedá z hrobu, kolem se hrne hlína.
const RISE_LEN := 80
var rise_t := 0
var rise_dirt: Texture2D = null


func start_rise(dirt: Texture2D) -> void:
	rise_t = RISE_LEN
	rise_dirt = dirt
	sink = 130.0
	set_state(S.IDLE)


func can_be_hit() -> bool:
	if rise_t > 0:
		return false
	return super.can_be_hit()


func _rise_step() -> void:
	rise_t -= 1
	var k := float(rise_t) / float(RISE_LEN)
	# nejdřív se jen hrne hlína, pak se postava trhaně vysouvá ven
	var up := clampf((1.0 - k - 0.2) / 0.8, 0.0, 1.0)
	sink = 130.0 * (1.0 - up * up * (3.0 - 2.0 * up)) + (sin(float(rise_t) * 1.7) * 2.0 if rise_t > 6 else 0.0)
	sink = maxf(sink, 0.0)
	if rise_t % 4 == 0 and stage != null:
		stage.fx.burst(Vector2(pos.x + randf_range(-14, 14), pos.y - 3.0), Color("2e241a"), 3, 70.0, 0.5, 380.0, 2.5)
	if rise_t % 9 == 0 and stage != null:
		stage.fx.dust(Vector2(pos.x + randf_range(-10, 10), pos.y), 3)
	if rise_t == RISE_LEN - 1:
		Sfx.play("land", 0.5)
	if rise_t <= 0:
		sink = 0.0
		if stage != null and stage.has_method("leave_mound"):
			stage.leave_mound(pos, rise_dirt)


func tick() -> void:
	physics_step()
	if rise_t > 0:
		_rise_step()
		position = Vector2(roundf(pos.x), roundf(pos.y - z + sink))
		return
	if drown_t > 0 and state != S.DEAD:
		return
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
	# dosah zbraně (px): útočí, jakmile zbraň/zuby dosáhnou na hrdinu
	var reach: float = float(cfg.get("range", float(cfg["reach"]) * body_scale))
	if has_token:
		if kind == "ogre" and cooldown <= 0 and absf(dy) < 12.0 and absf(dx) > 130.0 and absf(dx) < 260.0:
			start_move("ogre_charge")
			Sfx.play("roar")
			return
		# liánovec útočí, jen když je celý na obrazovce
		var on_screen: bool = absf(pos.x - stage.cam_x) < stage.HALF_W - 40.0
		if kind == "vine" and not on_screen:
			_walk_to(Vector2(stage.cam_x + signf(pos.x - stage.cam_x) * (stage.HALF_W - 60.0), p.pos.y))
			return
		if absf(dx) <= reach and absf(dy) <= 10.0 and cooldown <= 0:
			start_move(cfg["attack"])
			return
		_walk_to(Vector2(p.pos.x - facing * reach * 0.85, p.pos.y))
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
	if rise_t > 0 and rise_dirt != null:
		# hlína před tělem: zvedá se, třese a hrne kolem vylézající postavy
		var k := 1.0 - float(rise_t) / float(RISE_LEN)
		var w := rise_dirt.get_width() / 3.0
		var h := rise_dirt.get_height() / 3.0 * clampf(0.4 + k * 1.2, 0.4, 1.0)
		var jx := sin(float(rise_t) * 2.3) * 1.5
		draw_texture_rect(rise_dirt, Rect2(-w * 0.5 + jx, -sink - h + 4.0, w, h), false, Color(0.85, 0.83, 0.8))
	if SHOW_HINTS and telegraph and state == S.ATTACK:
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
	if kind != "ogre":
		return false   # lidojed se nekryje – "block" je u něj jen cuknutí po zásahu
	return not knock and randf() < 0.4



func take_hit(dmg: int, dir: int, knock: bool, push: float) -> void:
	if _wants_block(knock):
		blocking = true
		hurt_len = 40   # krytí se přehraje celé
		set_state(S.HURT)
		facing = -dir
		vel = Vector2(dir * 40.0, 0.0)
		Sfx.play("hit", 0.55 if kind == "ogre" else 0.8)
		var hy := 120.0 if kind == "ogre" else 60.0
		stage.fx.burst(Vector2(pos.x - dir * 14.0, pos.y - hy), Color("fff4c0"), 10, 120.0, 0.25, 0.0, 2.0)
		stage.popup("BLOK", pos + Vector2(-8, -hy - 10.0), Color("c8c8d0"))
		return
	blocking = false
	hurt_len = 16
	super.take_hit(dmg, dir, knock, push)


func _anim_pick() -> Array:
	match state:
		S.IDLE:
			return ["idle", int(anim_clock * 6.0), 0.0]
		S.WALK:
			return ["walk", int(anim_clock * (8.0 if kind == "ogre" else 12.0)), 0.0]
		S.ATTACK:
			if move_name == "ogre_charge":
				# rozběh, pak výpad skloněným ramenem (náraz na snímcích 54–62)
				if anim_tex.has("ram") and state_t >= 50:
					return ["ram", (state_t - 50) / 3, 0.14]
				if anim_tex.has("run") and state_t >= 18:
					return ["run", int(anim_clock * 16.0), 0.0]
				if anim_tex.has("run"):
					return ["idle", 0, 0.0]
				return ["walk", int(anim_clock * 24.0), 0.0]
			return ["attack", _move_frame("attack"), 0.0]
		S.HURT:
			if not blocking and kind == "ghoul" and anim_tex.has("block"):
				return ["block", state_t * anim_tex["block"].size() / hurt_len, 0.0]
			if blocking:
				return ["block", state_t * anim_tex["block"].size() / hurt_len, 0.0]
			return ["idle", 0, -0.1]
		S.DOWN:
			return ["fall", state_t * 2 / 3, 0.0]
		S.DEAD:
			return ["fall", 999, 0.0]
		S.GETUP:
			var n: int = anim_tex["fall"].size()
			return ["fall", n - 1 - state_t * n / getup_len, 0.0]
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
	if drown_t == 0:
		_ellipse(Vector2(0, z), sw, sw * 0.22, Color(0, 0, 0, 0.3 if z < 30.0 else 0.18))
	var mod := Color.WHITE
	if flash > 0:
		mod = Color(1.0, 0.55, 0.5)
	elif SHOW_HINTS and telegraph and (state_t / 3) % 2 == 0:
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
		var custom := _sprite_pose(t)
		if not custom.is_empty():
			rot = custom[0]
			off = custom[1]
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
		if kind == "vine" and state == S.ATTACK:
			_draw_vine_arm()
	_draw_extra()


# ---------------------------------------------------------------- džungle: pavouk, liánovec, domorodec

## Zvláštní pózy: [rotace, posun] nebo prázdné pole = výchozí.
func _sprite_pose(t: float) -> Array:
	if state == S.ATTACK and not move.is_empty():
		var h: Array = move["hit"]
		var h0 := float(h[0])
		var st := float(state_t)
		match kind:
			"spider":
				# vztyčí se na zadní nohy, pak bodne předními
				if st < h0:
					return [-0.55 * minf(st / (h0 * 0.7), 1.0), Vector2(-6.0, 0.0)]
				var r := 1.0 - clampf((st - float(h[1])) / 12.0, 0.0, 1.0)
				return [0.18 * r, Vector2(20.0 * r, 0.0)]
			"native":
				if st < h0:
					return [-0.1, Vector2(-5.0, 0.0)]
				var r2 := 1.0 - clampf((st - float(h[1])) / 8.0, 0.0, 1.0)
				return [0.06 * r2, Vector2(24.0 * r2, 0.0)]
			"vine":
				return [-0.08 if st < h0 else 0.04, Vector2.ZERO]
	match kind:
		"spider":
			if state == S.WALK:
				return [sin(t * 14.0) * 0.03, Vector2(0.0, -absf(sin(t * 14.0)) * 1.5)]
		"native":
			if state == S.WALK:
				return [sin(t * 16.0) * 0.04, Vector2(0.0, -absf(sin(t * 16.0)) * 4.0)]
		"vine":
			if state == S.WALK or state == S.IDLE:
				return [sin(t * 1.6) * 0.04, Vector2.ZERO]
	return []


## Liánová paže: vystřelí až k hrdinovi a zase se stáhne.
func _draw_vine_arm() -> void:
	var h: Array = move["hit"]
	var st := float(state_t)
	var reach := float(cfg["range"])
	var ext := 0.0
	if st >= 28.0 and st < 36.0:
		ext = (st - 28.0) / 8.0
	elif st >= 36.0 and st < 46.0:
		ext = 1.0
	elif st >= 46.0 and st < 62.0:
		ext = 1.0 - (st - 46.0) / 16.0
	if ext <= 0.0:
		return
	var start := Vector2(facing * 14.0, -sprite_h * 0.55)
	var tip := Vector2(facing * (14.0 + reach * ext), -24.0)
	var pts := PackedVector2Array()
	var n := 18
	for i in n + 1:
		var k := float(i) / n
		var p := start.lerp(tip, k)
		p.y += sin(k * 9.0 + anim_clock * 14.0) * 5.0 * (1.0 - k * 0.6) * ext
		pts.append(p)
	draw_polyline(pts, Color("2a2a18"), 7.0)
	draw_polyline(pts, Color("4a4a2a"), 4.0)
	for i in range(2, n, 3):
		var p2: Vector2 = pts[i]
		draw_colored_polygon(PackedVector2Array([p2 + Vector2(-2, 0), p2 + Vector2(2, 0), p2 + Vector2(facing * 1.0, -6.0)]), Color("1e1e12"))
	draw_circle(tip, 5.0, Color("2a2a18"))
	draw_line(tip, tip + Vector2(facing * 9.0, -4.0), Color("1e1e12"), 2.0)
	draw_line(tip, tip + Vector2(facing * 9.0, 4.0), Color("1e1e12"), 2.0)
