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

const SKY_SPEED := 0.15
const MID_SPEED := 0.55
const FRONT_SPEED := 1.35
const MID_STEP := 150.0
const FRONT_STEP := 520.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sky = load("res://art/bg/%s/sky.png" % biome)
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
		var sw := float(sky.get_width())
		var sx := -fposmod(left * SKY_SPEED, sw)
		while sx < size.x:
			draw_texture(sky, Vector2(roundf(sx), 0.0))
			sx += sw
		_draw_objects(left * MID_SPEED, MID_STEP, 160.0, 1.0, Color(0.78, 0.78, 0.82), 0)
	else:
		_draw_objects(left * FRONT_SPEED, FRONT_STEP, size.y + 18.0, 1.5, Color(0.06, 0.04, 0.05, 0.92), 7)


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
