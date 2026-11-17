extends Node2D
## Úvodní obrazovka: malba cesty od bažiny přes hřbitov a džungli až k temnému
## paláci na hoře. Obraz se pomalu přibližuje a vzdaluje, nízko se valí mlha.

var tex: Texture2D
var t := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tex = load("res://art/title.jpg")


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	# pomalé "dýchání" záběru: přiblížení k paláci a zpět (40 s)
	var k := 0.5 - 0.5 * cos(t * TAU / 40.0)
	var zoom := 1.0 + 0.08 * k
	var w := size.x * zoom
	var h := size.y * zoom
	var focus := Vector2(0.62, 0.18)   # palác na vrcholu
	var pos := Vector2((size.x - w) * focus.x, (size.y - h) * focus.y)
	draw_texture_rect(tex, Rect2(pos, Vector2(w, h)), false)
	# valící se mlha: několik průsvitných pruhů, každý jinou rychlostí
	for i in 4:
		var y := size.y * (0.55 + i * 0.1)
		var off := fmod(t * (6.0 + i * 3.0), size.x)
		for j in 3:
			var x := -size.x + off + j * size.x
			var c0 := Color(0.6, 0.6, 0.58, 0.0)
			var c1 := Color(0.6, 0.6, 0.58, 0.07 + 0.02 * sin(t * 0.7 + i))
			draw_polygon(PackedVector2Array([Vector2(x, y - 14), Vector2(x + size.x, y - 10), Vector2(x + size.x, y + 4), Vector2(x, y)]),
				PackedColorArray([c0, c0, c1, c1]))
			draw_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + size.x, y + 4), Vector2(x + size.x, y + 18), Vector2(x, y + 14)]),
				PackedColorArray([c1, c1, c0, c0]))
