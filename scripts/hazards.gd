extends Node2D
## Nástrahy prostředí v džungli:
##  - klády porostlé mechem přes celou cestu – hrdina je musí přeskočit,
##  - nášlapné pasti – po šlápnutí cvakne, na kraji obrazovky blikne varování
##    a v tom pruhu cesty proletí smrtelná šipka. Uhnout jde krokem nahoru/dolů,
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
var log_w := 36.0
var log_h := 140.0
var logp_tex: Texture2D


## x klády v dané hloubce (kláda leží rovně přes cestu)
func log_x(lx: float, _y: float) -> float:
	return lx


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
	# šipky a varování nad vším
	top_layer = Node2D.new()
	top_layer.z_as_relative = false
	top_layer.z_index = 800
	top_layer.draw.connect(_draw_top)
	add_child(top_layer)


## Volá stage každý snímek po pohybu postav. prev_x = poloha hrdiny před pohybem.
func step(prev_x: float) -> void:
	var p = stage.player
	_block_logs(p, prev_x)
	_update_traps(p)
	_update_darts()
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


func _update_traps(p) -> void:
	for t in traps:
		var pos: Vector2 = t[0]
		match int(t[1]):
			0:
				if p.alive() and p.z < 4.0 and p.drown_t == 0 \
						and absf(p.pos.x - pos.x) < 18.0 and absf(p.pos.y - pos.y) < 9.0:
					t[1] = 1
					t[2] = 0.0
					# šipka letí od vzdálenějšího okraje obrazovky
					t[3] = 1 if p.pos.x > stage.cam_x else -1
					Sfx.play("select", 0.5)
					stage.popup("!", pos + Vector2(-2, -20), Color("ff5040"))
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
		for f in [stage.player]:   # šipka zraní jen hrdinu
			if not f.alive() or f.state == Fighter.S.DOWN or f.drown_t > 0:
				continue
			if absf(f.pos.y - dp.y) < 9.0 and f.z < 20.0 and absf(f.pos.x - dp.x) < 10.0 and f.can_be_hit():
				f.set("incoming_move", "magic")
				f.take_hit(999, dir, true, 0.0)
				stage.fx.burst(Vector2(f.pos.x, f.pos.y - 30.0), Color("8e2020"), 14, 120.0, 0.5, 300.0, 2.0)
				Sfx.play("heavy", 1.3)
				if f == stage.player:
					stage.popup("OTRÁVENÁ ŠIPKA!", f.pos + Vector2(-40, -70), Color("ff5040"))
				hit = true
				break
		if hit or absf(dp.x - stage.cam_x) > stage.HALF_W + 40.0:
			darts.erase(d)


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
	if absf(lx - stage.cam_x) > stage.HALF_W + 80.0:
		return
	var tw := float(logp_tex.get_width())
	var th := float(logp_tex.get_height())
	var bh := log_h / LOG_BANDS
	var y0 := LOG_TOP + bh * bi
	var src := Rect2(0.0, th * bi / LOG_BANDS, tw, th / LOG_BANDS)
	# stín vedle klády na zemi
	n.draw_texture_rect_region(logp_tex, Rect2(lx - log_w * 0.5 + 5.0, y0 + 3.0, log_w, bh + 0.4), src, Color(0, 0, 0, 0.4))
	n.draw_texture_rect_region(logp_tex, Rect2(lx - log_w * 0.5, y0, log_w, bh + 0.4), src, Color(0.86, 0.86, 0.83))


func _draw_top() -> void:
	# varování na okraji obrazovky, odkud vyletí šipka
	for t in traps:
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
