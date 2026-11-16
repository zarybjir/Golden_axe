extends Node2D
## Nástrahy prostředí v džungli:
##  - klády porostlé mechem přes celou cestu – hrdina je musí přeskočit,
##  - nášlapné pasti – po šlápnutí cvakne, na kraji obrazovky blikne varování
##    a v tom pruhu cesty proletí smrtelná šipka. Uhnout jde krokem nahoru/dolů,
##    výskokem nebo úskokem. Šipka zabije i nepřítele.

const Fighter := preload("res://scripts/fighter.gd")
const BgData := preload("res://scripts/bg_data.gd")
const R := BgData.RES

const LOG_HALF := 13.0     # polovina šířky klády (px), kterou nejde projít
const LOG_JUMP_Z := 26.0   # nad touto výškou se kláda přeskočí (pořádný skok)
const DART_SPEED := 340.0
const WARN_TIME := 0.5
const REARM := 3.0

var stage: Node2D
var biome := "jungle"
var logs: Array = []       # x pozice klád
var traps: Array = []      # [Vector2 pozice, stav 0=nabito 1=spuštěno 2=dobíjí, čas, směr šipky]
var darts: Array = []      # [Vector2, směr]
var log_tex: Array = []
var plate_tex: Array = []
var top_layer: Node2D
var log_nodes: Array = []
const LOG_SEGS := 8
const LOG_Y0 := 188.0      # zadní konec klády (za cestou)
const LOG_Y1 := 300.0      # přední konec (u spodního okraje)
const LOG_SKEW := 0.34     # šikmá perspektiva: zadní konec je víc vpravo


## x osy klády v dané hloubce y
func log_x(lx: float, y: float) -> float:
	return lx + (243.0 - y) * LOG_SKEW


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	z_index = 197          # pasti leží na zemi pod postavami
	for i in int(BgData.OBJS.get(biome + "_log", 0)):
		log_tex.append(load("res://art/bg/%s/log_%d.png" % [biome, i]))
	for i in int(BgData.OBJS.get(biome + "_plate", 0)):
		plate_tex.append(load("res://art/bg/%s/plate_%d.png" % [biome, i]))
	# klády: každá rozdělená na úseky podle hloubky, aby se postavy správně
	# překrývaly (vzadu za kládou, vpředu před ní)
	for k in logs.size():
		for sgi in LOG_SEGS:
			var n := Node2D.new()
			var y_mid := LOG_Y0 + (LOG_Y1 - LOG_Y0) * (sgi + 0.5) / LOG_SEGS
			n.z_index = int(y_mid) + 1
			n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			n.draw.connect(_draw_log_seg.bind(n, k, sgi))
			add_child(n)
			log_nodes.append(n)
	# šipky a varování nad vším
	top_layer = Node2D.new()
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
		for f in stage.fighters:
			if not f.alive() or f.flying or f.state == Fighter.S.DOWN or f.drown_t > 0:
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


## Jeden úsek klády: kláda leží přes celou šířku cesty, šikmo do hloubky,
## vzadu je užší (dál), vpředu širší.
func _draw_log_seg(n: Node2D, k: int, sgi: int) -> void:
	if log_tex.is_empty():
		return
	var lx: float = logs[k]
	if absf(lx - stage.cam_x) > stage.HALF_W + 140.0:
		return
	var tex: Texture2D = log_tex[k % log_tex.size()]
	var a := Vector2(log_x(lx, LOG_Y0), LOG_Y0)
	var b := Vector2(log_x(lx, LOG_Y1), LOG_Y1)
	var axis := b - a
	var len := axis.length()
	var ang := axis.angle()
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var t0 := float(sgi) / LOG_SEGS
	var t1 := float(sgi + 1) / LOG_SEGS
	var depth := lerpf(0.8, 1.2, (t0 + t1) * 0.5)   # perspektiva
	var thick := 26.0 * depth
	var p0 := a + axis * t0
	n.draw_set_transform(p0, ang, Vector2.ONE)
	var shade := lerpf(0.6, 0.85, (t0 + t1) * 0.5)
	n.draw_texture_rect_region(tex, Rect2(0.0, -thick * 0.5, len * (t1 - t0) + 0.6, thick),
		Rect2(tw * t0, 0.0, tw * (t1 - t0), th), Color(shade, shade, shade * 0.97))
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
