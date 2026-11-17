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
	# Zombie: pomalá, vydrží hodně. Po 3 zásazích přijde o ruku, zvedne ji, zrychlí
	# a mlátí s ní; padne po dalších 6 zásazích. Grafika: art/enemy_sprite/zombie_*.png
	"zombie": {"hp": 999, "range": 30.0, "speed": Vector2(24, 14), "reach": 20.0, "attack": "zombie_claw", "cool": 70,
		"parts": "gob", "weapon": "club", "grip": Vector2(3.5, 9.0), "scale": 1.6, "score": 400, "hit_w": 12.0},
	# Kamenný obr (hory): zblízka mlátí pěstí, zdálky vyrve ze země balvan a hodí ho.
	"golem": {"hp": 300, "range": 50.0, "speed": Vector2(30, 20), "reach": 30.0, "attack": "golem_punch", "cool": 60,
		"parts": "ogre", "weapon": "tree_club", "grip": Vector2(4.5, 13.0), "scale": 3.6, "score": 3500, "armor": true,
		"name": "STONE GIANT", "hit_w": 18.0, "depth": 12.0},
	# Démonický kamzík (hory): drží si odstup, vzepne se a rozběhne se, narazí rohama.
	"chamois": {"hp": 40, "range": 22.0, "speed": Vector2(95, 58), "reach": 20.0, "attack": "chamois_charge", "cool": 80,
		"parts": "gob", "weapon": "club", "grip": Vector2(3.5, 9.0), "scale": 1.6, "score": 300, "hit_w": 22.0, "depth": 4.0},
	# Lich (palác): drží si odstup a střílí z hole zelené magické střely.
	"lich": {"hp": 34, "range": 24.0, "speed": Vector2(55, 36), "reach": 20.0, "attack": "lich_cast", "cool": 70,
		"parts": "gob", "weapon": "club", "grip": Vector2(3.5, 9.0), "scale": 1.6, "score": 350, "hit_w": 12.0},
	"lich_king": {"hp": 240, "range": 34.0, "speed": Vector2(50, 32), "reach": 20.0, "attack": "lich_cast", "cool": 50,
		"parts": "gob", "weapon": "club", "grip": Vector2(3.5, 9.0), "scale": 1.6, "score": 5000, "hit_w": 16.0,
		"name": "THE LICH KING", "armor": true},
	# Nekromant (boss hřbitova): drží si odstup, oživuje padlé a vyvolává zombie ze země,
	# zblízka sekne kostěnou dýkou. Když padne, padnou i všichni, které oživil.
	"necro": {"hp": 200, "range": 30.0, "speed": Vector2(45, 30), "reach": 20.0, "attack": "necro_slash", "cool": 50,
		"parts": "gob", "weapon": "club", "grip": Vector2(3.5, 9.0), "scale": 1.6, "score": 5000, "hit_w": 14.0,
		"name": "THE NECROMANCER", "armor": true},
	"skeleton": {"hp": 34, "range": 66.0, "speed": Vector2(70, 42), "reach": 46.0, "attack": "sp_atk", "cool": 64,
		"parts": "skel", "weapon": "spear", "grip": Vector2(4.0, 13.0), "scale": 2.0, "score": 150, "idle": "sp_idle"},
	"ogre": {"hp": 260, "range": 100.0, "speed": Vector2(38, 26), "reach": 30.0, "attack": "ogre_slam", "cool": 56,
		"parts": "ogre", "weapon": "tree_club", "grip": Vector2(4.5, 13.0), "scale": 3.6, "score": 3000, "armor": true,
		"name": "GRUMOR THE OGRE", "hit_w": 7.0, "depth": 10.0},
}

var kind := "goblin"
var cfg: Dictionary = {}
var elite := false        # elitní varianta: vydrží víc, bije silněji, je rychlejší (rudý nádech)
var dmg_mult := 1.0
const ELITE_KINDS := ["ghoul", "skeleton", "native", "spider", "zombie", "chamois", "lich", "bat", "vine"]
var cooldown := 60
var has_token := false
var slot := 0.0
var entered := false
var dead_t := 0
var sprite_tex: Texture2D = null   # nepřítel z jednoho obrázku, pohyb dopočítán kódem
var sprite_h := 100.0
const HOVER_Z := 64.0
const ZombieData := preload("res://scripts/zombie_data.gd")
const GolemData := preload("res://scripts/golem_data.gd")
const ChamoisData := preload("res://scripts/chamois_data.gd")
var l_tex := {}
var n_tex := {}
var summons: Array = []    # nekromant: koho oživil / vyvolal
var summon_cool := 90
var bolt_tex: Array = []
var bolts: Array = []      # [Node2D, pozice (x, zem y), směr, výška, čas]
var lich_scale := 1.0
var c_tex := {}
var g_tex := {}
var throw_cool := 120
var throw_target := Vector2.ZERO
var boulders: Array = []   # [Node2D, pozice na zemi, z, vz, vx, vy, textura]

# zombie
const Z_ARM_HITS := 3      # po tolika zásazích přijde o ruku
const Z_TOTAL_HITS := 9    # a po dalších 6 padne
var z_tex := {}
var z_phase := 0           # 0 = obě ruce, 1 = jde pro utrženou ruku, 2 = mlátí s ní
var z_hits := 0
var pickup_t := 0
var arm_node: Node2D = null
var arm_pos := Vector2.ZERO
var arm_z := 0.0
var arm_vz := 0.0
var arm_vx := 0.0
var arm_dir := 1          # směr utržené ruky (pevný od useknutí)


func _ready() -> void:
	team = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cfg = KINDS[kind].duplicate()
	max_hp = int(cfg["hp"])
	if max_hp < 999:
		max_hp = int(round(max_hp * Settings.hp_mult()))
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
	if kind == "zombie":
		for n in ZombieData.POSE.keys():
			z_tex[n] = load("res://art/enemy_sprite/zombie_%s.png" % n)
		sprite_tex = z_tex["walk"]
		# animace z videí (chůze, útok rukama; s utrženou rukou chůze a úder)
		if ResourceLoader.exists("res://scripts/zombie_anims.gd"):
			var za = load("res://scripts/zombie_anims.gd")
			setup_anims(za.ANIMS, za.K)
		sprite_h = float(ZombieData.POSE["walk"][1])
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if kind == "necro":
		var ND = load("res://scripts/necro_data.gd")
		for n in ND.POSE.keys():
			n_tex[n] = load("res://art/enemy_sprite/necro_%s.png" % n)
		sprite_tex = n_tex["idle"]
		sprite_h = 100.0
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if kind == "lich" or kind == "lich_king":
		var LD = load("res://scripts/lich_data.gd")
		for n in LD.POSE.keys():
			l_tex[n] = load("res://art/enemy_sprite/lich_%s.png" % n)
		for i in 4:
			bolt_tex.append(load("res://art/fx/bolt_%d.png" % i))
		lich_scale = 1.35 if kind == "lich_king" else 1.0
		sprite_tex = l_tex["idle"]
		sprite_h = 104.0 * lich_scale
		if ResourceLoader.exists("res://scripts/lich_anims.gd"):
			var lan = load("res://scripts/lich_anims.gd")
			setup_anims(lan.ANIMS, lan.K * lich_scale)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if kind == "chamois":
		for n in ChamoisData.POSE.keys():
			c_tex[n] = load("res://art/enemy_sprite/kamzik_%s.png" % n)
		sprite_tex = c_tex["idle"]
		sprite_h = 76.0
		if ResourceLoader.exists("res://scripts/chamois_anims.gd"):
			var ca = load("res://scripts/chamois_anims.gd")
			setup_anims(ca.ANIMS, ca.K)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if kind == "golem":
		for n in GolemData.POSE.keys():
			g_tex[n] = load("res://art/enemy_sprite/golem_%s.png" % n)
		sprite_tex = g_tex["idle"]
		sprite_h = 150.0
		if ResourceLoader.exists("res://scripts/golem_anims.gd"):
			var ga = load("res://scripts/golem_anims.gd")
			setup_anims(ga.ANIMS, ga.K)
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
	_maybe_elite()


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
		stage.fx.burst(Vector2(pos.x + anim_cx + randf_range(-14, 14), pos.y - 4.0), Color("4a3a2a"), 4, 80.0, 0.5, 380.0, 2.5)
	if rise_t % 9 == 0 and stage != null:
		stage.fx.dust(Vector2(pos.x + randf_range(-10, 10), pos.y), 3)
	if rise_t == RISE_LEN - 1:
		Sfx.play("land", 0.5)
	if rise_t <= 0:
		sink = 0.0
		if stage != null and stage.has_method("leave_mound"):
			stage.leave_mound(pos + Vector2(anim_cx, 0.0), rise_dirt)


var charge_pending := 0   # obr: za kolik snímků vyrazí do útoku po odhození hrdiny


## Obr odstrčí hrdinu (odletí kus dál) a po krátké chvíli na něj vyrazí –
## hrdina má čas se zvednout z dosahu nebo uskočit.
func _ogre_retaliate() -> void:
	var p = stage.nearest_player(pos)
	facing = 1 if p.pos.x > pos.x else -1
	hurt_len = 10
	set_state(S.HURT)
	if p.alive() and absf(p.pos.x - pos.x) < 90.0 and absf(p.pos.y - pos.y) < 20.0:
		p.take_hit(0, facing, false, 190.0)   # jen odstrčí, bez zranění
		stage.shake(3.0, 0.15)
		Sfx.play("heavy", 0.6)
	charge_pending = 34


func tick() -> void:
	physics_step()
	if charge_pending > 0 and state != S.DOWN and state != S.DEAD:
		charge_pending -= 1
		if charge_pending == 0 and state != S.ATTACK:
			var pl = stage.nearest_player(pos)
			facing = 1 if pl.pos.x > pos.x else -1
			pos.y = move_toward(pos.y, pl.pos.y, 6.0)
			start_move("ogre_charge")
			Sfx.play("roar")
	if arm_node != null:
		_arm_step()
	if not boulders.is_empty():
		_boulder_step()
	if not bolts.is_empty():
		_bolt_step()
	if rise_t > 0:
		_rise_step()
		position = Vector2(roundf(pos.x), roundf(pos.y - z + sink))
		return
	if drown_t > 0 and state != S.DEAD:
		return
	if state == S.DEAD:
		dead_t += 1
		_release()
		if kind == "necro" and dead_t == 1:
			_necro_release_dead()
		return
	match state:
		S.RIDE:
			pass # Pohyb řídí ještěr.
		S.IDLE, S.WALK:
			_ai()
		S.ATTACK:
			if kind == "golem" and move_name == "golem_throw":
				_golem_throw_step()
			if move_name == "necro_summon":
				_necro_summon_step()
			if move_name == "lich_smash" and state_t == 2:
				Sfx.play("roar", 1.5)
			if move_name == "lich_cast" and state_t == 34:
				_shoot_bolts()
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


## Občas se objeví elitní nepřítel (častěji na vyšší obtížnost).
func _maybe_elite() -> void:
	if not ELITE_KINDS.has(kind):
		return
	var chance := {"easy": 0.12, "hard": 0.2, "hell": 0.3}.get(Settings.difficulty, 0.12) as float
	if randf() >= chance:
		return
	elite = true
	dmg_mult = 1.5
	if max_hp < 999:
		max_hp = int(max_hp * 2.0)
		hp = max_hp
	cfg["speed"] = (cfg["speed"] as Vector2) * 1.15
	cfg["score"] = int(cfg["score"]) * 2
	self_modulate = Color(1.3, 0.72, 0.66)


func _ai() -> void:
	cooldown -= 1
	var p = stage.nearest_player(pos)
	if p == null:
		return
	if kind == "zombie" and z_phase == 1:
		_zombie_fetch_arm()
		return
	if kind == "chamois":
		_chamois_ai(p)
		return
	if kind == "lich" or kind == "lich_king":
		_lich_ai(p)
		return
	if kind == "necro":
		_necro_ai(p)
		return
	if kind == "golem":
		throw_cool -= 1
		var ddx: float = absf(p.pos.x - pos.x)
		if throw_cool <= 0 and ddx > 170.0 and ddx < 380.0 and p.alive():
			facing = 1 if p.pos.x > pos.x else -1
			throw_target = p.pos
			start_move("golem_throw")
			throw_cool = 200 + randi() % 120
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
		# role: první útočník drží hrdinu zepředu, druhý ho obchází a útočí zezadu
		var side := -float(facing)
		var tk: Array = stage.tokens
		if tk.size() >= 2 and tk[1] == self and is_instance_valid(tk[0]) and tk[0] != self:
			var other_side := signf(tk[0].pos.x - p.pos.x)
			if other_side != 0.0:
				side = -other_side
			if signf(pos.x - p.pos.x) != side and absf(dx) < reach * 2.5:
				# oklikou kolem hrdiny (v hloubce mimo jeho řadu)
				var dy_off := 26.0 if pos.y >= p.pos.y else -26.0
				_walk_to(Vector2(p.pos.x + side * reach, clampf(p.pos.y + dy_off, Y_MIN, Y_MAX)))
				return
		if absf(dx) <= reach and absf(dy) <= 10.0 and cooldown <= 0:
			start_move(cfg["attack"])
			return
		_walk_to(Vector2(p.pos.x + side * reach * 0.85, p.pos.y))
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
		var w := rise_dirt.get_width() / 3.0 * 1.2
		var h := rise_dirt.get_height() / 3.0 * 1.2 * clampf(0.55 + k * 0.9, 0.55, 1.0)
		var jx := sin(float(rise_t) * 2.3) * 1.5
		draw_texture_rect(rise_dirt, Rect2(anim_cx - w * 0.5 + jx, -sink - h + 5.0, w, h), false, Color(1.25, 1.18, 1.08))
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
	if kind == "ogre" and knock and hp - dmg > 0 and incoming_move != "magic" \
			and state != S.DOWN and state != S.DEAD:
		# obr po úderu ze skoku nebo po třetí ráně komba nepadá: odhodí hrdinu a vyrazí na něj
		hp -= dmg
		flash = 6
		Sfx.play("hit", 0.55)
		stage.fx.burst(Vector2(pos.x - dir * 14.0, pos.y - 120.0), Color("fff4c0"), 10, 120.0, 0.25, 0.0, 2.0)
		_ogre_retaliate()
		return
	if kind == "zombie" and state != S.DOWN and state != S.DEAD:
		_zombie_hit(dir)
		return
	if kind == "golem" and state != S.DOWN and state != S.DEAD:
		# kámen: nepadá a útok se nepřeruší, jen se zachvěje
		hp = maxi(hp - dmg, 0)
		flash = 6
		Sfx.play("hit", 0.5)
		stage.fx.burst(Vector2(pos.x - dir * 10.0, pos.y - 90.0), Color("6a5e50"), 8, 120.0, 0.4, 400.0, 2.5)
		if hp <= 0:
			super.take_hit(0, dir, true, 0.0)
		elif state != S.ATTACK and incoming_move == "jatk":
			hurt_len = 14
			set_state(S.HURT)
		return
	if _wants_block(knock):
		blocking = true
		hurt_len = 40   # krytí se přehraje celé
		set_state(S.HURT)
		facing = -dir
		vel = Vector2(dir * 40.0, 0.0)
		Sfx.play("hit", 0.55 if kind == "ogre" else 0.8)
		var hy := 120.0 if kind == "ogre" else 60.0
		stage.fx.burst(Vector2(pos.x - dir * 14.0, pos.y - hy), Color("fff4c0"), 10, 120.0, 0.25, 0.0, 2.0)
		stage.popup("BLOCK", pos + Vector2(-10, -hy - 10.0), Color("c8c8d0"))
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
	if kind == "necro":
		_draw_necro()
		return
	if kind == "lich" or kind == "lich_king":
		_draw_lich()
		return
	if kind == "chamois":
		_draw_chamois()
		return
	if kind == "golem":
		_draw_golem()
		return
	if kind == "zombie":
		_draw_zombie()
		return
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


# ---------------------------------------------------------------- hřbitov: zombie

func _zombie_hit(dir: int) -> void:
	z_hits += 1
	flash = 6
	facing = -dir
	Sfx.play("hit", 0.7)
	stage.fx.burst(Vector2(pos.x, pos.y - 60.0), Color("4a2a1a"), 8, 110.0, 0.4, 300.0, 2.0)
	# těžší obtížnost: zombie vydrží víc (Easy 3+6, Hard 4+8, Hell 6+12)
	var mult := Settings.hp_mult() * (1.5 if elite else 1.0)
	var arm_hits := int(round(Z_ARM_HITS * mult))
	var total_hits := int(round(Z_TOTAL_HITS * mult))
	if incoming_move == "magic" or z_hits >= total_hits:
		blocking = false
		hurt_len = 16
		super.take_hit(999, dir, true, 0.0)
		return
	if z_phase == 0 and z_hits >= arm_hits:
		_sever_arm(dir)
	pickup_t = 0
	# zombie se jen zapotácí, nepadá
	hurt_len = 14
	set_state(S.HURT)
	vel = Vector2(dir * 30.0, 0.0)


## Hrdina odsekne zombii ruku – odletí a spadne na zem.
func _sever_arm(dir: int) -> void:
	z_phase = 1
	_release()
	cfg["speed"] = Vector2(30, 18)
	arm_pos = Vector2(pos.x + facing * 8.0, pos.y + 2.0)
	arm_z = 62.0
	arm_vz = 160.0
	arm_vx = dir * 70.0
	arm_dir = facing
	arm_node = Node2D.new()
	arm_node.z_as_relative = false
	arm_node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	arm_node.draw.connect(_draw_arm.bind(arm_node))
	stage.add_child(arm_node)
	stage.fx.burst(Vector2(pos.x + facing * 6.0, pos.y - 66.0), Color("5a1a14"), 22, 160.0, 0.6, 400.0, 3.0)
	Sfx.play("heavy", 0.9)


func _arm_step() -> void:
	if arm_z > 0.0 or arm_vz > 0.0:
		arm_vz -= 900.0 * DT
		arm_z = maxf(arm_z + arm_vz * DT, 0.0)
		arm_pos.x += arm_vx * DT
		if arm_z == 0.0:
			arm_vz = 0.0
			stage.fx.dust(arm_pos, 4)
	arm_node.z_index = int(arm_pos.y)
	arm_node.queue_redraw()


func _draw_arm(n: Node2D) -> void:
	if n == null or not is_instance_valid(n):
		return
	var tex: Texture2D = z_tex["arm"]
	var m: Array = ZombieData.POSE["arm"]
	var w := float(m[0])
	var h := float(m[1])
	n.draw_set_transform(Vector2(arm_pos.x, arm_pos.y - arm_z - h * 0.4), 0.0, Vector2(float(arm_dir), 1.0))
	n.draw_texture_rect(tex, Rect2(-w * 0.5, -h * 0.5, w, h), false, Color(0.9, 0.88, 0.86))


## Bez ruky: dobelhá se k ní, shýbne se a zvedne ji druhou rukou.
func _zombie_fetch_arm() -> void:
	if pickup_t > 0:
		pickup_t -= 1
		if pickup_t == 0:
			_take_arm()
		return
	if arm_z > 0.0:
		return
	var target := Vector2(arm_pos.x - facing * 10.0, arm_pos.y)
	facing = 1 if arm_pos.x > pos.x else -1
	if pos.distance_to(target) < 4.0 or absf(pos.x - arm_pos.x) < 12.0 and absf(pos.y - arm_pos.y) < 4.0:
		pickup_t = 40
		set_state(S.IDLE)
		return
	_walk_to(target)


func _take_arm() -> void:
	z_phase = 2
	if arm_node != null:
		arm_node.queue_free()
		arm_node = null
	cfg["speed"] = Vector2(80, 48)
	cfg["attack"] = "zombie_club"
	cfg["cool"] = 26
	cfg["range"] = 40.0
	cooldown = 10
	Sfx.play("roar", 1.7)


func _exit_tree() -> void:
	if arm_node != null and is_instance_valid(arm_node):
		arm_node.queue_free()
	for b in boulders:
		if is_instance_valid(b[0]):
			b[0].queue_free()
	boulders.clear()
	for b in bolts:
		if is_instance_valid(b[0]):
			b[0].queue_free()
	bolts.clear()


func _zombie_pose() -> String:
	if rise_t > 0:
		return "reach" if sink > 40.0 else "walk"
	if state == S.DOWN or state == S.DEAD or state == S.GETUP:
		return "onearm" if z_phase > 0 else "walk"
	if z_phase == 0:
		return "walk"
	if z_phase == 1:
		return "onearm"
	# s utrženou rukou vždy póza "club_up" (drží ji správnou, vzdálenější rukou);
	# úder dělá předklon celého trupu
	return "club_up"


## Snímek animace zombie: [animace, index] nebo [] = statický obrázek póz.
func _zombie_frame() -> Array:
	if anim_tex.is_empty() or state == S.DOWN or state == S.DEAD or state == S.GETUP:
		return []
	if rise_t > 0:
		return [] if sink > 40.0 else ["walk", 0]
	if z_phase == 1:
		return []
	var w := "walk" if z_phase == 0 else "walk2"
	var a := "attack" if z_phase == 0 else "attack2"
	match state:
		S.WALK:
			return [w, int(anim_clock * (6.0 if z_phase == 0 else 16.0))]
		S.ATTACK:
			if not move.is_empty():
				return [a, _move_frame(a)]
	return [w, 0]


func _draw_zombie() -> void:
	if state == S.DEAD and (state_t / 4) % 2 == 0:
		return
	var fr := _zombie_frame()
	if not fr.is_empty():
		_draw_zombie_anim(fr[0], int(fr[1]))
		return
	var nm := _zombie_pose()
	var tex: Texture2D = z_tex[nm]
	var m: Array = ZombieData.POSE[nm]
	var w := float(m[0])
	var h := float(m[1])
	var ax := float(m[2])
	anim_cx = (w * 0.5 - ax) * facing
	if sink == 0.0 and drown_t == 0:
		_ellipse(Vector2(0, z), 20.0, 5.0, Color(0, 0, 0, 0.3))
	var mod := Color(0.92, 0.9, 0.88)
	if flash > 0:
		mod = Color(1.0, 0.55, 0.5)
	var rot := 0.0
	var off := Vector2.ZERO
	var t := anim_clock
	var fast := z_phase == 2
	match state:
		S.WALK:
			var f := 9.0 if fast else 4.5
			rot = sin(t * f) * (0.05 if fast else 0.08)
			off.y = -absf(sin(t * f)) * 2.0
		S.IDLE:
			if pickup_t > 0:
				rot = 0.55 * sin(float(40 - pickup_t) / 40.0 * PI)   # shýbne se pro ruku
			else:
				rot = sin(t * 1.8) * 0.03
		S.ATTACK:
			var hh: Array = move["hit"]
			var club := z_phase == 2
			if state_t < int(hh[0]):
				rot = (-0.22 if club else -0.14) * clampf(float(state_t) / float(hh[0]), 0.0, 1.0)
			else:
				var r := 1.0 - clampf(float(state_t - int(hh[1])) / 12.0, 0.0, 1.0)
				# s rukou jako kyjem: prudký předklon, ruka seká shora dopředu dolů
				rot = (0.55 if club else 0.22) * r
				off.x = (8.0 if club else 10.0) * r
		S.HURT:
			rot = -0.16
			off.x = -3.0
		S.DOWN, S.DEAD:
			rot = -minf(float(state_t) / 12.0, 1.0) * 1.45
	# otáčení kolem boků, ne kolem chodidel
	var hip := Vector2(0.0, -h * 0.42)
	if state == S.DOWN or state == S.DEAD:
		hip = Vector2.ZERO   # pád: kolem chodidel
	draw_set_transform_matrix(Transform2D(0.0, Vector2(float(facing), 1.0), 0.0, Vector2.ZERO) \
		* Transform2D(0.0, off + hip) * Transform2D(rot, Vector2.ZERO) * Transform2D(0.0, -hip))
	if sink > 0.0:
		# vylézá ze země: kreslí se jen to, co je nad zemí
		var vis := clampf(h - sink, 0.0, h)
		if vis > 0.0:
			draw_texture_rect_region(tex, Rect2(-ax, -h, w, vis), Rect2(0, 0, tex.get_width(), tex.get_height() * vis / h), mod)
	else:
		draw_texture_rect(tex, Rect2(-ax, -h, w, h), false, mod)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_extra()


func _draw_zombie_anim(nm: String, i: int, shadow: float = 20.0) -> void:
	var arr: Array = anim_tex[nm]
	if anim_set[nm]["loop"]:
		i = posmod(i, arr.size())
	else:
		i = clampi(i, 0, arr.size() - 1)
	var tex: Texture2D = arr[i]
	var off: Vector2 = anim_set[nm]["offsets"][i]
	anim_cx = (off.x + tex.get_width() * 0.5) * anim_k * facing
	if sink == 0.0 and drown_t == 0:
		_ellipse(Vector2(0, z), shadow, shadow * 0.22, Color(0, 0, 0, 0.32))
	var mod := Color(0.92, 0.9, 0.88)
	if flash > 0:
		mod = Color(1.0, 0.55, 0.5)
	var rot := 0.0
	if state == S.HURT and kind == "zombie":
		rot = -0.12
	var hip := Vector2(0.0, -40.0)
	draw_set_transform_matrix(Transform2D(0.0, Vector2(float(facing), 1.0), 0.0, Vector2.ZERO) \
		* Transform2D(0.0, hip) * Transform2D(rot, Vector2.ZERO) * Transform2D(0.0, -hip) \
		* Transform2D(0.0, Vector2(anim_k, anim_k), 0.0, Vector2.ZERO))
	if sink > 0.0:
		var hv := clampf((-sink + 2.0) / anim_k - off.y, 0.0, float(tex.get_height()))
		if hv > 0.0:
			draw_texture_rect_region(tex, Rect2(off, Vector2(tex.get_width(), hv)), Rect2(0, 0, tex.get_width(), hv), mod)
	else:
		draw_texture(tex, off, mod)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_extra()


# ---------------------------------------------------------------- hory: kamenný obr

func _golem_throw_step() -> void:
	match state_t:
		12:
			# vyrve balvan ze země
			stage.shake(5.0, 0.3)
			stage.fx.burst(Vector2(pos.x + facing * 40.0, pos.y - 6.0), Color("4a3a2a"), 18, 140.0, 0.6, 420.0, 3.0)
			stage.fx.dust(Vector2(pos.x + facing * 40.0, pos.y), 14)
			Sfx.play("heavy", 0.5)
		60:
			_throw_boulder()


const BOULDER_G := 600.0    # gravitace balvanu
const BOULDER_X0 := 143.0   # kde obr balvan pustí (podle videa): před sebou
const BOULDER_Z0 := 188.0   # a vysoko nad hlavou (střed balvanu)
const BOULDER_HIT_Z := 36.0 # střed balvanu u hrdiny = výška jeho trupu


func _throw_boulder() -> void:
	# balvan vystřižený z videa – stejná velikost i vzhled jako v obrových rukou
	var tex: Texture2D = load("res://art/fx/golem_boulder.png")
	var tp = stage.nearest_player(pos)
	var x0 := minf(BOULDER_X0, absf(tp.pos.x - pos.x) - 40.0)
	var start := Vector2(pos.x + facing * maxf(x0, 30.0), pos.y)
	# míří tam, kde hrdina stojí teď (ne kde stál při vyrvání balvanu)
	var tgt: Vector2 = tp.pos + Vector2(randf_range(-6.0, 6.0), 0.0)
	var t := clampf(absf(tgt.x - start.x) / 340.0, 0.4, 0.8)   # doba letu k hrdinovi – plochý oblouk
	var n := Node2D.new()
	n.z_as_relative = false
	n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var b := [n, start, BOULDER_Z0, 0.0, (tgt.x - start.x) / t, (tgt.y - start.y) / t, tex, 0.0]
	# z = výška nad zemí; vz tak, aby balvan byl u hrdiny ve výšce jeho trupu
	b[3] = (0.5 * BOULDER_G * t * t - (BOULDER_Z0 - BOULDER_HIT_Z)) / t
	n.draw.connect(_draw_boulder.bind(b))
	stage.add_child(n)
	boulders.append(b)
	Sfx.play("dodge", 0.6)


func _boulder_step() -> void:
	for b in boulders.duplicate():
		var n: Node2D = b[0]
		var p: Vector2 = b[1]
		b[3] = float(b[3]) - BOULDER_G * DT
		b[2] = float(b[2]) + float(b[3]) * DT
		p += Vector2(float(b[4]), float(b[5])) * DT
		b[1] = p
		b[7] = float(b[7]) + DT
		var hit := false
		for pl in stage.players:
			if hit:
				break
			if pl.alive() and pl.can_be_hit() and absf(pl.pos.x - p.x) < 16.0 and absf(pl.pos.y - p.y) < 10.0 \
					and float(b[2]) - pl.z < 55.0 and float(b[2]) - pl.z > -10.0:
				pl.take_hit(14, 1 if float(b[4]) > 0.0 else -1, true, 0.0)
				hit = true
		if hit or float(b[2]) <= 26.0:   # spodek balvanu dopadl na zem
			stage.shake(4.0, 0.25)
			stage.fx.burst(p + Vector2(0, -8), Color("5a4a3a"), 16, 150.0, 0.6, 420.0, 3.0)
			stage.fx.dust(p, 10)
			Sfx.play("heavy", 0.7)
			n.queue_free()
			boulders.erase(b)
			continue
		n.z_index = int(p.y) + 1
		n.queue_redraw()


func _draw_boulder(b: Array) -> void:
	var n: Node2D = b[0]
	var tex: Texture2D = b[6]
	var p: Vector2 = b[1]
	var w := tex.get_width() / 3.0
	var h := tex.get_height() / 3.0
	var pts := PackedVector2Array()
	for i in 12:
		var an := TAU * i / 12.0
		pts.append(Vector2(p.x + cos(an) * w * 0.45, p.y + sin(an) * 3.5))
	n.draw_colored_polygon(pts, Color(0, 0, 0, 0.3))
	n.draw_set_transform(Vector2(p.x, p.y - float(b[2])), float(b[7]) * 3.0 * signf(float(b[4])), Vector2.ONE)
	n.draw_texture_rect(tex, Rect2(-w * 0.5, -h * 0.5, w, h), false, Color(0.9, 0.88, 0.86))


func _golem_pose() -> String:
	if state == S.ATTACK and not move.is_empty():
		if move_name == "golem_throw":
			if state_t < 34:
				return "tear"
			return "hold"
		var h: Array = move["hit"]
		return "wind" if state_t < int(h[0]) else "punch"
	if state == S.WALK:
		return "walk" if fmod(anim_clock * 1.6, 1.0) < 0.5 else "idle"
	return "idle"


## Snímek animace obra: [animace, index] nebo [] = statická póza.
func _golem_frame() -> Array:
	if anim_tex.is_empty() or state == S.DOWN or state == S.DEAD or state == S.GETUP:
		return []
	match state:
		S.WALK:
			return ["walk", int(anim_clock * 8.0)]
		S.ATTACK:
			if move_name == "golem_punch":
				return ["punch", _move_frame("punch")]
			if move_name == "golem_throw":
				# odhození balvanu ve videu = snímek, kdy balvan ve hře vyletí (state_t 60)
				var n: int = anim_tex["throw"].size()
				var imp: int = anim_set["throw"]["impact"]
				var t := float(state_t)
				if t < 60.0:
					return ["throw", int(t / 60.0 * float(imp))]
				return ["throw", mini(n - 1, imp + int((t - 60.0) / 36.0 * float(n - imp)))]
	return ["punch", 0]


func _draw_golem() -> void:
	if state == S.DEAD and (state_t / 4) % 2 == 0:
		return
	var gf := _golem_frame()
	if not gf.is_empty():
		_draw_zombie_anim(gf[0], int(gf[1]), 34.0)
		return
	var nm := _golem_pose()
	var tex: Texture2D = g_tex[nm]
	var m: Array = GolemData.POSE[nm]
	var w := float(m[0])
	var h := float(m[1])
	var ax := float(m[2])
	_ellipse(Vector2(0, z), 34.0, 7.0, Color(0, 0, 0, 0.35))
	var mod := Color(0.92, 0.9, 0.88)
	if flash > 0:
		mod = Color(1.0, 0.7, 0.62)
	var rot := 0.0
	var off := Vector2.ZERO
	match state:
		S.WALK:
			off.y = -absf(sin(anim_clock * PI * 1.6)) * 2.0
			rot = sin(anim_clock * PI * 1.6) * 0.025
		S.ATTACK:
			if move_name == "golem_throw" and state_t >= 56 and state_t < 76:
				rot = 0.28 * sin(float(state_t - 56) / 20.0 * PI)   # hod: předklon
			elif move_name == "golem_punch":
				var hh: Array = move["hit"]
				if state_t >= int(hh[0]):
					off.x = 8.0 * (1.0 - clampf(float(state_t - int(hh[1])) / 14.0, 0.0, 1.0))
		S.HURT:
			off.x = -3.0
		S.DOWN, S.DEAD:
			rot = -minf(float(state_t) / 16.0, 1.0) * 1.4
	var hip := Vector2(0.0, -h * 0.45)
	if state == S.DOWN or state == S.DEAD:
		hip = Vector2.ZERO
	draw_set_transform_matrix(Transform2D(0.0, Vector2(float(facing), 1.0), 0.0, Vector2.ZERO) \
		* Transform2D(0.0, off + hip) * Transform2D(rot, Vector2.ZERO) * Transform2D(0.0, -hip))
	draw_texture_rect(tex, Rect2(-ax, -h, w, h), false, mod)
	draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------------------------------------------------------------- hory: démonický kamzík

func _chamois_ai(p) -> void:
	var dx: float = p.pos.x - pos.x
	var dy: float = p.pos.y - pos.y
	facing = 1 if dx > 0.0 else -1
	if not p.alive():
		_walk_to(Vector2(p.pos.x - facing * 160.0, pos.y))
		return
	# z odstupu, ve stejné řadě: vzepne se a vyrazí
	if cooldown <= 0 and absf(dx) > 70.0 and absf(dx) < 250.0 and absf(dy) < 8.0:
		start_move("chamois_charge")
		Sfx.play("roar", 1.9)
		return
	_walk_to(Vector2(p.pos.x - facing * 160.0, p.pos.y))


func _chamois_pose() -> String:
	match state:
		S.ATTACK:
			if state_t < 30:
				return "rear"
			if state_t < 74:
				return "charge"
			return "idle"
		S.WALK:
			return "run1" if fmod(anim_clock * 7.0, 1.0) < 0.5 else "run2"
		S.DOWN, S.DEAD:
			return "down"
	return "idle"


## Snímek animace kamzíka: [animace, index] nebo [] = statická póza.
func _chamois_frame() -> Array:
	if anim_tex.is_empty() or state == S.DOWN or state == S.DEAD or state == S.GETUP:
		return []
	match state:
		S.WALK:
			# první snímek je stoj, cval začíná od druhého
			return ["walk", 1 + posmod(int(anim_clock * 14.0), anim_tex["walk"].size() - 1)]
		S.ATTACK:
			var t := state_t
			if t < 30:
				return ["rear", t * anim_tex["rear"].size() / 30]
			if t < 74:
				var n: int = anim_tex["ram"].size()
				var i := (t - 30) / 2
				return ["ram", i if i < n else n - 6 + posmod(i - n, 6)]
			return ["back", (t - 74) * anim_tex["back"].size() / 12]
	return ["walk", 0]


func _draw_chamois() -> void:
	if state == S.DEAD and (state_t / 4) % 2 == 0:
		return
	var cf := _chamois_frame()
	if not cf.is_empty():
		_draw_zombie_anim(cf[0], int(cf[1]), 26.0)
		return
	var nm := _chamois_pose()
	var tex: Texture2D = c_tex[nm]
	var m: Array = ChamoisData.POSE[nm]
	var w := float(m[0])
	var h := float(m[1])
	var ax := float(m[2])
	if drown_t == 0:
		_ellipse(Vector2(0, z), 26.0, 5.0, Color(0, 0, 0, 0.3))
	var mod := Color(0.92, 0.9, 0.88)
	if flash > 0:
		mod = Color(1.0, 0.55, 0.5)
	var off := Vector2.ZERO
	var rot := 0.0
	if nm == "run1" or nm == "run2":
		off.y = -4.0 - absf(sin(anim_clock * 14.0)) * 4.0   # v cvalu nad zemí
	elif nm == "charge":
		off.y = -absf(sin(float(state_t) * 0.5)) * 4.0
		rot = sin(float(state_t) * 0.5) * 0.04
	elif state == S.HURT:
		rot = -0.15
	draw_set_transform_matrix(Transform2D(0.0, Vector2(float(facing), 1.0), 0.0, Vector2.ZERO) * Transform2D(rot, off))
	draw_texture_rect(tex, Rect2(-ax, -h, w, h), false, mod)
	draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------------------------------------------------------------- palác: lich

const BOLT_SPEED := 190.0
const BOLT_Z := 42.0       # výška letu střely nad zemí (trup hrdiny)
const STAFF_TIP := Vector2(58.0, 95.0)   # špička hole při výstřelu (podle animace)


func _lich_ai(p) -> void:
	var dx: float = p.pos.x - pos.x
	var dy: float = p.pos.y - pos.y
	facing = 1 if dx > 0.0 else -1
	if not p.alive():
		return
	# Král lichů zblízka mlátí holí
	if kind == "lich_king" and absf(dx) < 50.0:
		if cooldown <= 0 and absf(dy) < 10.0:
			start_move("lich_smash")
			return
		_walk_to(Vector2(p.pos.x - facing * 34.0, p.pos.y))
		return
	# blízko u hrdiny ustupuje, jinak drží odstup ve stejné řadě
	var want := 170.0 if kind == "lich" else 150.0
	if absf(dx) < 70.0:
		_walk_to(Vector2(p.pos.x - facing * want, pos.y + signf(pos.y - p.pos.y + 0.01) * 10.0))
		return
	if cooldown <= 0 and absf(dy) < 10.0 and absf(dx) < 300.0:
		start_move("lich_cast")
		return
	_walk_to(Vector2(p.pos.x - facing * want, p.pos.y))


## Z hole vyletí zelená střela (Král lichů pálí tři naráz v různých řadách).
func _shoot_bolts() -> void:
	for ly in [0.0]:
		var n := Node2D.new()
		n.z_as_relative = false
		n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		n.material = mat
		var gy := clampf(pos.y + ly, Y_MIN, Y_MAX)
		var b := [n, Vector2(pos.x + facing * STAFF_TIP.x * lich_scale, gy), facing, STAFF_TIP.y * lich_scale, 0.0]
		n.draw.connect(_draw_bolt.bind(b))
		stage.add_child(n)
		bolts.append(b)
	Sfx.play("magic" if kind == "lich_king" else "dodge", 1.4)


func _bolt_step() -> void:
	for b in bolts.duplicate():
		var n: Node2D = b[0]
		var p: Vector2 = b[1]
		var dir: int = b[2]
		p.x += dir * BOLT_SPEED * DT
		b[1] = p
		# ze špičky hole klesá šikmo dolů do výšky trupu
		b[3] = move_toward(float(b[3]), BOLT_Z, 200.0 * DT)
		b[4] = float(b[4]) + DT
		var hit := false
		for pl in stage.players:
			if not hit and pl.alive() and pl.can_be_hit() and pl.drown_t == 0 and absf(pl.pos.x - p.x) < 12.0 \
					and absf(pl.pos.y - p.y) < 9.0 and pl.z < float(b[3]) - 10.0:
				if kind == "lich_king":
					pl.take_hit(18, dir, true, 0.0)   # silnější střela Krále lichů srazí k zemi
				else:
					pl.take_hit(int(10 * dmg_mult), dir, false, 70.0)
				hit = true
		if hit or absf(p.x - stage.cam_x) > stage.HALF_W + 60.0:
			if hit:
				stage.fx.burst(Vector2(p.x, p.y - float(b[3])), Color("8aff60"), 16, 120.0, 0.45, 60.0, 2.5)
				Sfx.play("hit", 1.4)
			n.queue_free()
			bolts.erase(b)
			continue
		n.z_index = int(p.y) + 1
		n.queue_redraw()


func _draw_bolt(b: Array) -> void:
	var n: Node2D = b[0]
	var p: Vector2 = b[1]
	var dir: int = b[2]
	var t := float(b[4])
	var tex: Texture2D = bolt_tex[int(t * 15.0) % bolt_tex.size()]
	var w := tex.get_width() / 3.0 * lich_scale
	var h := tex.get_height() / 3.0 * lich_scale
	var c := Vector2(p.x, p.y - float(b[3]))
	# stín a záře na zemi
	n.draw_circle(Vector2(p.x, p.y), 6.0, Color(0.2, 0.6, 0.15, 0.18))
	n.draw_circle(c, 9.0 + sin(t * 30.0) * 1.5, Color(0.25, 0.8, 0.2, 0.22))
	n.draw_set_transform(c, 0.0, Vector2(float(dir), 1.0))
	n.draw_texture_rect(tex, Rect2(-w * 0.62, -h * 0.5, w, h), false, Color(1, 1, 1, 0.95))


func _lich_pose() -> String:
	match state:
		S.ATTACK:
			return "raise" if state_t < 30 else "thrust"
		S.WALK:
			return "walk" if fmod(anim_clock * 1.5, 1.0) < 0.5 else "idle"
		S.HURT:
			return "hurt"
		S.DOWN, S.DEAD:
			return "down"
	return "idle"


## Snímek animace liche: [animace, index] nebo [] = statická póza.
func _lich_frame() -> Array:
	if anim_tex.is_empty() or state == S.DOWN or state == S.DEAD or state == S.GETUP or state == S.HURT:
		return []
	match state:
		S.WALK:
			return ["walk", int(anim_clock * 10.0)]
		S.ATTACK:
			# výstřel ve videu (snímek "impact") = chvíle, kdy hra vypustí střelu (state_t 34)
			var n: int = anim_tex["cast"].size()
			var imp: int = anim_set["cast"]["impact"]
			var t := float(state_t)
			if move_name == "lich_smash":
				# úder holí: rychlý nápřah, švih dopředu a návrat
				if t < 22.0:
					return ["cast", int(t / 22.0 * float(imp))]
				if t < 34.0:
					return ["cast", imp]
				return ["cast", mini(n - 1, imp + int((t - 34.0) / 10.0 * float(n - imp)))]
			if t < 34.0:
				return ["cast", int(t / 34.0 * float(imp))]
			return ["cast", mini(n - 1, imp + int((t - 34.0) / 24.0 * float(n - imp)))]
	return ["walk", 0]


func _draw_lich() -> void:
	if state == S.DEAD and (state_t / 4) % 2 == 0:
		return
	var lf := _lich_frame()
	if not lf.is_empty():
		_draw_zombie_anim(lf[0], int(lf[1]), 18.0 * lich_scale)
		return
	var LD = load("res://scripts/lich_data.gd")
	var nm := _lich_pose()
	var tex: Texture2D = l_tex[nm]
	var m: Array = LD.POSE[nm]
	var sc := lich_scale
	var w := float(m[0]) * sc
	var h := float(m[1]) * sc
	var ax := float(m[2]) * sc
	_ellipse(Vector2(0, z), 18.0 * sc, 4.0 * sc, Color(0, 0, 0, 0.3))
	var mod := Color(0.92, 0.9, 0.88)
	if flash > 0:
		mod = Color(1.0, 0.55, 0.5)
	var off := Vector2.ZERO
	if state == S.WALK or state == S.IDLE:
		off.y = -1.5 - sin(anim_clock * 2.4) * 1.5   # vznáší se nad zemí
	draw_set_transform_matrix(Transform2D(0.0, Vector2(float(facing), 1.0), 0.0, off))
	draw_texture_rect(tex, Rect2(-ax, -h, w, h), false, mod)
	# záře krystalu na holi při kouzlení
	if state == S.ATTACK and state_t > 14 and state_t < 40:
		var gl := 0.25 + 0.2 * sin(float(state_t) * 0.8)
		draw_circle(Vector2(w * 0.25, -h * (0.95 if state_t < 30 else 0.55)), 8.0 * sc, Color(0.4, 1.0, 0.3, gl))
	draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------------------------------------------------------------- hřbitov: nekromant

const MAX_SUMMONS := 4


func _necro_ai(p) -> void:
	summons = summons.filter(func(s) -> bool: return is_instance_valid(s) and s.alive())
	summon_cool -= 1
	var dx: float = p.pos.x - pos.x
	var dy: float = p.pos.y - pos.y
	facing = 1 if dx > 0.0 else -1
	if summon_cool <= 0 and summons.size() < MAX_SUMMONS:
		start_move("necro_summon")
		summon_cool = 330 + randi() % 120
		return
	if not p.alive():
		return
	if absf(dx) < 48.0:
		if cooldown <= 0 and absf(dy) < 10.0:
			start_move("necro_slash")
			return
		_walk_to(Vector2(p.pos.x - facing * 150.0, pos.y))
		return
	_walk_to(Vector2(p.pos.x - facing * 150.0, p.pos.y))


## Vzývání: ruce nahoru, pak klekne a vlije magii do země – mrtví vstanou.
func _necro_summon_step() -> void:
	if state_t % 6 == 0:
		stage.fx.burst(Vector2(pos.x + facing * 10.0, pos.y - 80.0), Color("7a5aa0"), 4, 50.0, 0.7, -40.0, 2.5)
	if state_t == 10:
		Sfx.play("roar", 0.55)
	if state_t == 44:
		stage.shake(3.0, 0.3)
		var spots: Array = []
		# nejdřív oživí padlé, které leží poblíž
		var fallen: Array = stage.get("fallen") if stage.get("fallen") != null else []
		while not fallen.is_empty() and spots.size() < 2:
			var f: Array = fallen.pop_back()
			var fp: Vector2 = f[0]
			if absf(fp.x - stage.cam_x) < stage.HALF_W - 20.0:
				spots.append([fp, f[1]])
		# jinak vyvolá zombie ze země kolem hrdiny
		while spots.size() < 2:
			var pl = stage.nearest_player(pos)
			var sx: float = pl.pos.x + randf_range(70.0, 140.0) * (1.0 if randf() < 0.5 else -1.0)
			sx = clampf(sx, stage.cam_x - stage.HALF_W + 30.0, stage.cam_x + stage.HALF_W - 30.0)
			spots.append([Vector2(sx, randf_range(Y_MIN + 6.0, Y_MAX - 6.0)), "zombie"])
		for sp in spots:
			if summons.size() >= MAX_SUMMONS:
				break
			var e = stage.raise_dead(sp[1], sp[0])
			if e != null:
				summons.append(e)
				stage.fx.burst(Vector2(sp[0].x, sp[0].y - 4.0), Color("6aff70"), 14, 80.0, 0.7, -30.0, 2.5)


## Nekromant padl: všichni, které oživil, padnou s ním.
func _necro_release_dead() -> void:
	for s in summons:
		if is_instance_valid(s) and s.alive():
			s.set("incoming_move", "magic")
			s.take_hit(999, 1, true, 0.0)
	summons.clear()


func _necro_pose() -> String:
	match state:
		S.ATTACK:
			if move_name == "necro_summon":
				return "raise" if state_t < 34 else "kneel"
			return "slash" if state_t >= 12 and state_t < 32 else "idle"
		S.WALK:
			return "walk" if fmod(anim_clock * 1.6, 1.0) < 0.5 else "idle"
		S.DOWN, S.DEAD:
			return "down"
	return "idle"


func _draw_necro() -> void:
	if state == S.DEAD and (state_t / 4) % 2 == 0:
		return
	var ND = load("res://scripts/necro_data.gd")
	var nm := _necro_pose()
	var tex: Texture2D = n_tex[nm]
	var m: Array = ND.POSE[nm]
	var w := float(m[0])
	var h := float(m[1])
	var ax := float(m[2])
	_ellipse(Vector2(0, z), 18.0, 4.0, Color(0, 0, 0, 0.3))
	var mod := Color(0.92, 0.9, 0.88)
	if flash > 0:
		mod = Color(1.0, 0.55, 0.5)
	var rot := 0.0
	var off := Vector2.ZERO
	match state:
		S.WALK:
			rot = sin(anim_clock * 6.0) * 0.03
			off.y = -absf(sin(anim_clock * 6.0)) * 1.5
		S.IDLE:
			rot = sin(anim_clock * 1.7) * 0.02
		S.HURT:
			rot = -0.14
	draw_set_transform_matrix(Transform2D(0.0, Vector2(float(facing), 1.0), 0.0, Vector2.ZERO) * Transform2D(rot, off))
	draw_texture_rect(tex, Rect2(-ax, -h, w, h), false, mod)
	# nekromantská záře v rukou při vzývání
	if state == S.ATTACK and move_name == "necro_summon":
		var gl := 0.22 + 0.15 * sin(float(state_t) * 0.6)
		var hand := Vector2(w * 0.3, -h * 0.95) if state_t < 34 else Vector2(w * 0.55 - ax, -6.0)
		draw_circle(hand, 9.0, Color(0.45, 1.0, 0.45, gl))
	draw_set_transform_matrix(Transform2D.IDENTITY)
