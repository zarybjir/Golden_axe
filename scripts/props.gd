extends Node2D
## Sud (dá se rozbít) nebo předmět na zemi (maso = zdraví, runa = magie).

var kind := "barrel"   # barrel / meat / rune
var content := "meat"  # co vypadne ze sudu
var stage: Node2D
var pos := Vector2.ZERO
var z := 0.0
var team := 1
var body_scale := 2.0
var hit_w := 7.0
var hit_depth := 0.0
var t := 0.0
var broken := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func alive() -> bool:
	return not broken


func can_be_hit() -> bool:
	return kind == "barrel" and not broken


func take_hit(_dmg: int, _dir: int, _knock: bool, _push: float) -> void:
	if broken:
		return
	broken = true
	stage.spawn_pickup(content, pos + Vector2(0, 2))
	stage.fx.burst(Vector2(pos.x, pos.y - 10), Color("3e3022"), 14, 120.0, 0.5, 400.0, 3.0)
	Sfx.play("break")
	queue_free()


func _process(delta: float) -> void:
	t += delta
	position = pos.round()
	z_index = int(pos.y)
	queue_redraw()


var paint: Texture2D = null   # namalovaný sud podle prostředí


func _draw() -> void:
	if kind == "barrel" and paint == null and stage != null:
		var path := "res://art/props/barrel_%s.png" % str(stage.get("biome"))
		if ResourceLoader.exists(path):
			paint = load(path)
			texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if paint != null:
		var w := paint.get_width() / 3.0
		var h := paint.get_height() / 3.0
		var sh := PackedVector2Array()
		for i in 16:
			var an := TAU * i / 16.0
			sh.append(Vector2(cos(an) * w * 0.6, sin(an) * 4.0))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.35))
		draw_texture_rect(paint, Rect2(-w * 0.5, -h + 2.0, w, h), false, Color(0.9, 0.88, 0.86))
		return
	var tex: Texture2D
	var lift := 0.0
	match kind:
		"barrel":
			tex = Art.t("barrel")
		"rune":
			tex = Art.t("rune")
			lift = 6.0 + sin(t * 4.0) * 2.0
		_:
			tex = Art.t("meat")
			lift = 2.0 + sin(t * 3.0) * 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2, 2))
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		pts.append(Vector2(cos(a) * 8.0, sin(a) * 2.5))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.28))
	draw_texture(tex, Vector2(-floorf(tex.get_width() * 0.5), -tex.get_height() + 1 - roundf(lift)))
	if kind == "rune":
		draw_circle(Vector2(0, -6 - lift), 7.0 + sin(t * 6.0), Color(0.3, 0.8, 1.0, 0.2))
