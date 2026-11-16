extends Node2D
## Pozadí s paralaxou: obloha při západu, hory, jehličnaté lesy.

var t := 0.0
## Malované pozadí prostředí (art/bg/<biome>_far.webp); prázdné = kreslené pozadí.
var biome := ""
var level_len := 2000.0
var far_tex: Texture2D = null


func _ready() -> void:
	if biome != "":
		far_tex = load("res://art/bg/%s_far.webp" % biome)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	if far_tex != null:
		_draw_far()
		return
	var size := get_viewport_rect().size
	var cx := t * 20.0
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		cx = cam.get_screen_center_position().x
	draw_texture(Art.sky, Vector2.ZERO)
	# Měsíc
	draw_circle(Vector2(90, 56), 20.0, Color(1, 0.95, 0.85, 0.15))
	draw_circle(Vector2(90, 56), 14.0, Color("f4ecd8"))
	draw_circle(Vector2(95, 52), 12.0, Color("d8cdb4"))
	draw_circle(Vector2(84, 60), 3.0, Color("c8bca0"))
	# Hory
	_ridge(cx * 0.08, 520.0, Color("5a5a7e"), Color("7a7aa0"), 120.0, 55.0, 3.0)
	_ridge(cx * 0.16, 400.0, Color("44506e"), Color("5e6a88"), 140.0, 30.0, 5.0)
	# Lesy
	_forest(cx * 0.3, 150.0, 26.0, Color("2e4a3a"), 22.0)
	_forest(cx * 0.5, 162.0, 34.0, Color("223a2e"), 30.0)


func _ridge(off: float, period: float, col: Color, rim: Color, base: float, amp: float, waves: float) -> void:
	var size := get_viewport_rect().size
	var start := -fposmod(off, period)
	var pts := PackedVector2Array([Vector2(0, size.y)])
	var top := PackedVector2Array()
	var x := 0.0
	while x <= size.x + 8.0:
		var px := fposmod(x - start, period) / period
		var h := base - amp * absf(sin(px * PI * waves)) - amp * 0.3 * sin(px * TAU * waves * 2.0)
		pts.append(Vector2(x, h))
		top.append(Vector2(x, h))
		x += 6.0
	pts.append(Vector2(size.x + 8.0, size.y))
	draw_colored_polygon(pts, col)
	draw_polyline(top, rim, 2.0)


func _forest(off: float, base: float, tree_h: float, col: Color, spacing: float) -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(0, base, size.x, size.y - base), col)
	var start := -fposmod(off, spacing)
	var i := int(floorf(off / spacing))
	var x := start - spacing
	while x < size.x + spacing:
		var h := tree_h + float((i * 37) % 11)
		var cx := x + float((i * 13) % 7)
		for layer in 3:
			var w := (8.0 + layer * 4.0) * (h / 30.0)
			var top := base - h + layer * h * 0.28
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx, top), Vector2(cx - w, top + h * 0.42), Vector2(cx + w, top + h * 0.42)]), col)
		x += spacing
		i += 1


func _draw_far() -> void:
	var size := get_viewport_rect().size
	var cam := get_viewport().get_camera_2d()
	var left := 0.0
	if cam != null:
		left = cam.get_screen_center_position().x - size.x * 0.5
	# Obrázek pokryje horní část obrazu; posouvá se pomaleji (paralaxa) tak,
	# aby právě vyšel na celou délku úrovně.
	var h := 236.0
	var w := float(far_tex.get_width()) * h / float(far_tex.get_height())
	var factor := clampf((w - size.x) / maxf(level_len - size.x, 1.0), 0.0, 1.0)
	var x := -left * factor
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.07))
	draw_texture_rect(far_tex, Rect2(x, 0.0, w, h), false)
