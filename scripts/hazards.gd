extends Node2D
## Nástrahy prostředí v džungli:
##  - klády porostlé mechem přes celou cestu – hrdina je musí přeskočit,
##  - nášlapné pasti – po šlápnutí cvakne, bez varování
##    v tom pruhu cesty proletí smrtelná šipka. Uhnout jde krokem nahoru/dolů,
##    výskokem nebo úskokem. Past spouští i zraňuje jen hrdinu.

const Fighter := preload("res://scripts/fighter.gd")
const BgData := preload("res://scripts/bg_data.gd")
const R := BgData.RES

var LOG_HALF := 18.0       # polovina šířky klády (px), kterou nejde projít
const LOG_JUMP_Z := 26.0   # nad touto výškou se kláda přeskočí (pořádný skok)
const DART_SPEED := 340.0
const WARN_TIME := 0.5
const REARM := 3.0

var stage: Node2D
var biome := "jungle"
var logs: Array = []       # x pozice klád
var traps: Array = []      # [Vector2 pozice, stav 0=nabito 1=spuštěno 2=dobíjí, čas, směr šipky]
var darts: Array = []      # [Vector2, směr]
var plate_tex: Array = []
var top_layer: Node2D
var log_nodes: Array = []
const LOG_BANDS := 14       # kláda rozdělená na vodorovné pásy kvůli překrývání
const LOG_TOP := 168.0      # horní konec klády (za cestou)
const LOG_SLANT := 0.3      # sklon klády (posun x na 1 px hloubky), sedí k šikmému pohledu hry
var log_w := 36.0
var log_h := 140.0
var logp_tex: Texture2D

# Padající kameny (hory): shora občas spadne balvan; zasáhne jen hrdinu.
var rocks_on := false
var rock_tex: Array = []
var rocks: Array = []       # [Node2D, x, y zem, z výška, vz, textura, šířka, čas po dopadu]
var rock_wait := 2.0
const ROCK_DMG := 12


## x klády v dané hloubce (kláda leží přes cestu lehce našikmo – vzadu víc vpravo)
func log_x(lx: float, y: float) -> float:
	return lx + (243.0 - y) * LOG_SLANT


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	z_index = 197          # pasti leží na zemi pod postavami
	for i in int(BgData.OBJS.get(biome + "_plate", 0)):
		plate_tex.append(load("res://art/bg/%s/plate_%d.png" % [biome, i]))
	var lp: Array = BgData.OBJS.get(biome + "_logp", [])
	if lp.size() == 2:
		logp_tex = load("res://art/bg/%s/logp_0.png" % biome)
		log_h = lp[0]
		log_w = lp[1]
		LOG_HALF = log_w * 0.5 + 6.0
	# klády: každá rozdělená na vodorovné pásy; pás má hloubku podle své výšky,
	# takže postava vzadu je za kládou a vpředu před ní
	for k in logs.size():
		for bi in LOG_BANDS:
			var n := Node2D.new()
			var yb := LOG_TOP + log_h * (bi + 1.0) / LOG_BANDS
			n.z_as_relative = false   # absolutní hloubka, stejná jako u postav
			n.z_index = clampi(int(yb) + 2, 150, 700)
			n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			n.draw.connect(_draw_log_band.bind(n, k, bi))
			add_child(n)
			log_nodes.append(n)
	if rocks_on:
		for i in 5:
			var path := "res://art/props/rock_%d.png" % i
			if ResourceLoader.exists(path):
				rock_tex.append(load(path))
	# šipky a varování nad vším
	top_layer = Node2D.new()
	top_layer.z_as_relative = false
	top_layer.z_index = 800
	top_layer.draw.connect(_draw_top)
	add_child(top_layer)


## Volá stage každý snímek po pohybu postav. prev_x = poloha hrdiny před pohybem.
func step(prevs: Dictionary) -> void:
	for p in stage.players:
		_block_logs(p, float(prevs.get(p, p.pos.x)))
		_update_traps(p, true)
	_update_traps(null, false)
	_update_darts()
	if rocks_on and not rock_tex.is_empty():
		_update_rocks()
	queue_redraw()
	top_layer.queue_redraw()
	for n in log_nodes:
		n.queue_redraw()


func _block_logs(p, prev_x: float) -> void:
	if p.z >= LOG_JUMP_Z or p.drown_t > 0:
		return
	for l in logs:
		var lx: float = log_x(l, p.pos.y)
		var inside: bool = absf(p.pos.x - lx) < LOG_HALF
		var crossed: bool = (prev_x - lx) * (p.pos.x - lx) < 0.0
		if inside or crossed:
			var from_left: bool = prev_x < lx if absf(prev_x - lx) >= LOG_HALF * 0.5 else p.pos.x < lx
			p.pos.x = lx - LOG_HALF if from_left else lx + LOG_HALF
			p.vel.x = 0.0


## trigger = jen šlápnutí daného hrdiny na past; jinak běh časovačů (jednou za snímek).
func _update_traps(p, trigger: bool) -> void:
	for t in traps:
		var pos: Vector2 = t[0]
		if trigger != (int(t[1]) == 0):
			continue
		match int(t[1]):
			0:
				if p.alive() and p.z < 4.0 and p.drown_t == 0 \
						and absf(p.pos.x - pos.x) < 18.0 and absf(p.pos.y - pos.y) < 9.0:
					t[1] = 1
					t[2] = 0.0
					# šipka letí od vzdálenějšího okraje obrazovky
					t[3] = 1 if p.pos.x > stage.cam_x else -1
					Sfx.play("select", 0.5)
			1:
				t[2] += Fighter.DT
				if t[2] >= WARN_TIME:
					var dir: int = t[3]
					var sx: float = stage.cam_x - dir * (stage.HALF_W + 10.0)
					darts.append([Vector2(sx, pos.y), dir])
					Sfx.play("dodge", 1.6)
					t[1] = 2
					t[2] = 0.0
			2:
				t[2] += Fighter.DT
				if t[2] >= REARM:
					t[1] = 0


func _update_darts() -> void:
	for d in darts.duplicate():
		var dp: Vector2 = d[0]
		var dir: int = d[1]
		dp.x += dir * DART_SPEED * Fighter.DT
		d[0] = dp
		var hit := false
		for f in stage.players:   # šipka zraní jen hrdiny
			if not f.alive() or f.state == Fighter.S.DOWN or f.drown_t > 0:
				continue
			if absf(f.pos.y - dp.y) < 9.0 and f.z < 20.0 and absf(f.pos.x - dp.x) < 10.0 and f.can_be_hit():
				f.set("incoming_move", "magic")
				f.take_hit(999, dir, true, 0.0)
				stage.fx.burst(Vector2(f.pos.x, f.pos.y - 30.0), Color("8e2020"), 14, 120.0, 0.5, 300.0, 2.0)
				Sfx.play("heavy", 1.3)
				hit = true
				break
		if hit or absf(dp.x - stage.cam_x) > stage.HALF_W + 40.0:
			darts.erase(d)


func _update_rocks() -> void:
	rock_wait -= Fighter.DT
	if rock_wait <= 0.0 and not stage.finished:
		rock_wait = randf_range(1.0, 2.6)
		var p = stage.players[randi() % stage.players.size()]
		# občas přímo na hrdinu, jinak kamkoli na obrazovce
		var x: float = p.pos.x + randf_range(-30.0, 30.0) if randf() < 0.45 else stage.cam_x + randf_range(-stage.HALF_W + 20.0, stage.HALF_W - 20.0)
		var y: float = p.pos.y + randf_range(-8.0, 8.0) if randf() < 0.45 else randf_range(Fighter.Y_MIN + 4.0, Fighter.Y_MAX - 4.0)
		var tex: Texture2D = rock_tex[randi() % rock_tex.size()]
		var n := Node2D.new()
		n.z_as_relative = false
		n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var r := [n, x, y, 330.0 + randf_range(0.0, 60.0), 0.0, tex, tex.get_width() / R, 0.0]
		n.draw.connect(_draw_rock.bind(r))
		add_child(n)
		rocks.append(r)
	for r in rocks.duplicate():
		var n: Node2D = r[0]
		if float(r[3]) > 0.0:
			r[4] = float(r[4]) - 900.0 * Fighter.DT
			r[3] = float(r[3]) + float(r[4]) * Fighter.DT
			if float(r[3]) <= 0.0:
				r[3] = 0.0
				_rock_impact(r)
		else:
			r[7] = float(r[7]) + Fighter.DT
			if float(r[7]) > 1.4:
				n.queue_free()
				rocks.erase(r)
				continue
		n.z_index = int(float(r[2])) + 1
		n.queue_redraw()


func _rock_impact(r: Array) -> void:
	var at := Vector2(float(r[1]), float(r[2]))
	var half := float(r[6]) * 0.5
	stage.shake(4.0, 0.2)
	stage.fx.dust(at, 12)
	stage.fx.burst(at + Vector2(0, -6), Color("5a4a3a"), 10, 110.0, 0.5, 400.0, 3.0)
	Sfx.play("heavy", 0.6)
	for p in stage.players:
		if p.alive() and p.state != Fighter.S.DOWN and p.drown_t == 0 and p.z < 24.0 \
				and absf(p.pos.x - at.x) < half + 6.0 and absf(p.pos.y - at.y) < 10.0 and p.can_be_hit():
			p.take_hit(ROCK_DMG, 1 if p.pos.x >= at.x else -1, true, 0.0)


func _draw_rock(r: Array) -> void:
	var n: Node2D = r[0]
	var tex: Texture2D = r[5]
	var w := float(r[6])
	var h := tex.get_height() / R
	var x := float(r[1])
	var y := float(r[2])
	var zz := float(r[3])
	var fade := clampf((1.4 - float(r[7])) / 0.5, 0.0, 1.0)
	# stín na zemi (jen přirozený stín, žádné varování)
	var k := clampf(1.0 - zz / 330.0, 0.0, 1.0)
	if k > 0.35 or zz == 0.0:
		var pts := PackedVector2Array()
		for i in 16:
			var an := TAU * i / 16.0
			pts.append(Vector2(x + cos(an) * w * 0.5 * k, y + sin(an) * 3.5 * k))
		n.draw_colored_polygon(pts, Color(0, 0, 0, 0.3 * k * fade))
	n.draw_texture_rect(tex, Rect2(x - w * 0.5, y - h + 3.0 - zz, w, h), false, Color(0.9, 0.88, 0.86, fade))


# ---------------------------------------------------------------- kreslení

func _draw() -> void:
	if plate_tex.is_empty():
		return
	for i in traps.size():
		var t: Array = traps[i]
		var pos: Vector2 = t[0]
		if absf(pos.x - stage.cam_x) > stage.HALF_W + 60.0:
			continue
		var tex: Texture2D = plate_tex[i % plate_tex.size()]
		var w := tex.get_width() / R
		var h := tex.get_height() / R * 0.55
		var sunk := 2.0 if int(t[1]) != 0 else 0.0
		var mod := Color(0.62, 0.6, 0.56) if int(t[1]) != 0 else Color(0.8, 0.78, 0.74)
		draw_texture_rect(tex, Rect2(pos.x - w * 0.5, pos.y - h * 0.5 + sunk, w, h), false, mod)


## Jeden vodorovný pás klády.
func _draw_log_band(n: Node2D, k: int, bi: int) -> void:
	if logp_tex == null:
		return
	var lx: float = logs[k]
	if absf(lx - stage.cam_x) > stage.HALF_W + 120.0:
		return
	var tw := float(logp_tex.get_width())
	var th := float(logp_tex.get_height())
	var bh := log_h / LOG_BANDS
	var y0 := LOG_TOP + bh * bi
	var src := Rect2(0.0, th * bi / LOG_BANDS, tw, th / LOG_BANDS)
	# zkosení: čím výš (dál), tím víc vpravo; šířka klády zůstává stejná
	n.draw_set_transform_matrix(Transform2D(Vector2(1.0, 0.0), Vector2(-LOG_SLANT, 1.0), Vector2(243.0 * LOG_SLANT, 0.0)))
	# stín vedle klády na zemi
	n.draw_texture_rect_region(logp_tex, Rect2(lx - log_w * 0.5 + 5.0, y0 + 3.0, log_w, bh + 0.4), src, Color(0, 0, 0, 0.4))
	n.draw_texture_rect_region(logp_tex, Rect2(lx - log_w * 0.5, y0, log_w, bh + 0.4), src, Color(0.86, 0.86, 0.83))
	n.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_top() -> void:
	# (varování na okraji obrazovky vypnuto – hra nevede za ruku)
	for t in []:
		if int(t[1]) == 1 and int(t[2] * 12.0) % 2 == 0:
			var dir: int = t[3]
			var pos: Vector2 = t[0]
			var ex: float = stage.cam_x - dir * (stage.HALF_W - 12.0)
			top_layer.draw_colored_polygon(PackedVector2Array([
				Vector2(ex - dir * 8.0, pos.y - 30.0), Vector2(ex + dir * 6.0, pos.y - 24.0), Vector2(ex - dir * 8.0, pos.y - 18.0)]),
				Color(1.0, 0.3, 0.2, 0.9))
	for d in darts:
		var dp: Vector2 = d[0]
		var dir: int = d[1]
		var y := dp.y - 30.0
		top_layer.draw_line(Vector2(dp.x - dir * 60.0, y), Vector2(dp.x - dir * 34.0, y), Color(1, 1, 1, 0.22), 2.0)
		top_layer.draw_line(Vector2(dp.x - dir * 34.0, y), Vector2(dp.x, y), Color("2a1c10"), 3.0)
		top_layer.draw_colored_polygon(PackedVector2Array([
			Vector2(dp.x + dir * 10.0, y), Vector2(dp.x, y - 4.0), Vector2(dp.x, y + 4.0)]), Color("9a9a88"))
		top_layer.draw_line(Vector2(dp.x - dir * 34.0, y - 5.0), Vector2(dp.x - dir * 24.0, y), Color("7a2a1a"), 2.0)
		top_layer.draw_line(Vector2(dp.x - dir * 34.0, y + 5.0), Vector2(dp.x - dir * 24.0, y), Color("7a2a1a"), 2.0)
