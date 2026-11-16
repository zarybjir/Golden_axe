extends Node2D
## Vrstvené retro pozadí s paralaxou (art/bg/<biome>/):
##   "back"  – obloha (pomalu) + prostřední vrstva strašidelných objektů (rychleji),
##   "front" – tmavé siluety v popředí (rychleji než postavy).
## Všechny vrstvy se při pohybu po mapě posouvají každá jinou rychlostí.

const BgData := preload("res://scripts/bg_data.gd")

var biome := "swamp"
var mode := "back"
var sky: Texture2D
var objs: Array = []
var ground: Texture2D

const SKY_SPEED := 0.15
const MID_SPEED := 0.55
const FRONT_SPEED := 1.35
const MID_STEP := 150.0
const FAR_SPEED := 0.32
const FAR_STEP := 85.0
const HORIZON_Y := 150.0
const FAR_BASE_Y := 166.0
const NEAR_BASE_Y := 184.0
const FRONT_STEP := 520.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sky = load("res://art/bg/%s/sky.png" % biome)
	ground = load("res://art/bg/%s/ground.png" % biome)
	var n: int = BgData.OBJS.get(biome, 0)
	for i in n:
		objs.append(load("res://art/bg/%s/obj_%d.png" % [biome, i]))


static func has_biome(b: String) -> bool:
	return BgData.OBJS.has(b)


func _process(_delta: float) -> void:
	queue_redraw()


func _cam_left() -> float:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return 0.0
	return cam.get_screen_center_position().x - get_viewport_rect().size.x * 0.5


## Pseudonáhodné číslo 0..1 pro i-tý objekt (pokaždé stejné).
func _rnd(i: int, salt: int) -> float:
	var h := (i * 73856093) ^ (salt * 19349663)
	return float(absi(h) % 1000) / 1000.0


func _draw() -> void:
	var size := get_viewport_rect().size
	var left := _cam_left()
	if mode == "back":
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.03, 0.04))
		# 1) Nebe a obzor – nejpomaleji
		var sw := float(sky.get_width())
		var sx := -fposmod(left * SKY_SPEED, sw)
		while sx < size.x:
			draw_texture(sky, Vector2(roundf(sx), 0.0))
			sx += sw
		# 2) Vzdálená země (perspektivně zploštělá) – na ní stojí vzdálené objekty
		_draw_far_ground(left * FAR_SPEED, HORIZON_Y, NEAR_BASE_Y + 4.0)
		# 3) Vzdálená řada objektů v mlze
		_draw_objects(left * FAR_SPEED, FAR_STEP, FAR_BASE_Y, 0.8, Color(0.62, 0.62, 0.64), 11)
		_fog(HORIZON_Y - 26.0, NEAR_BASE_Y - 6.0, 0.30)
		# 4) Bližší řada objektů
		_draw_objects(left * MID_SPEED, MID_STEP, NEAR_BASE_Y, 1.5, Color(0.86, 0.84, 0.82), 0)
	else:
		_draw_objects(left * FRONT_SPEED, FRONT_STEP, size.y + 18.0, 1.5, Color(0.06, 0.04, 0.05, 0.92), 7)


func _draw_far_ground(offset: float, y0: float, y1: float) -> void:
	if ground == null:
		return
	var h := y1 - y0
	var w := float(ground.get_width()) * 0.7
	var x := -fposmod(offset, w)
	while x < get_viewport_rect().size.x:
		draw_texture_rect(ground, Rect2(roundf(x), y0, w, h), false, Color(0.72, 0.7, 0.68))
		x += w


## Svislý přechod mlhy (od průhledné nahoře k mlze uprostřed a zpět).
func _fog(y0: float, y1: float, strength: float) -> void:
	var w := get_viewport_rect().size.x
	var c := Color(0.42, 0.42, 0.40, 0.0)
	var mid := (y0 + y1) * 0.5
	var steps := 8
	for k in steps:
		var a := y0 + (mid - y0) * k / steps
		var b := y0 + (mid - y0) * (k + 1) / steps
		c.a = strength * float(k + 1) / steps
		draw_rect(Rect2(0, a, w, b - a + 1), c)
	for k in steps:
		var a2 := mid + (y1 - mid) * k / steps
		var b2 := mid + (y1 - mid) * (k + 1) / steps
		c.a = strength * float(steps - k) / steps
		draw_rect(Rect2(0, a2, w, b2 - a2 + 1), c)


func _draw_objects(offset: float, step: float, base_y: float, scale: float, mod: Color, salt: int) -> void:
	if objs.is_empty():
		return
	var size := get_viewport_rect().size
	var first := int(floorf((offset - 200.0) / step))
	var last := int(ceilf((offset + size.x + 200.0) / step))
	for i in range(first, last + 1):
		if mode == "front" and _rnd(i, salt + 3) < 0.45:
			continue
		var tex: Texture2D = objs[int(_rnd(i, salt) * objs.size()) % objs.size()]
		var x := i * step + _rnd(i, salt + 1) * step * 0.6 - offset
		var flip := _rnd(i, salt + 2) < 0.5
		var w := tex.get_width() * scale
		var h := tex.get_height() * scale
		var r := Rect2(roundf(x), roundf(base_y - h), w, h)
		if flip:
			r = Rect2(r.position.x + w, r.position.y, -w, h)
		draw_texture_rect(tex, r, false, mod)
