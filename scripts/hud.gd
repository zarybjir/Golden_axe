extends Control

const Snacks := preload("res://scripts/snacks.gd")
## Ukazatele: zdraví, runy, životy, skóre a zdraví bosse.

var stage: Node2D = null
var score_label: Label
var name_label: Label
var go_label: Label
var boss_label: Label
var t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label = _label(Vector2(8, 2), 9)
	name_label.text = "MIREK"
	score_label = _label(Vector2(380, 2), 10)
	go_label = _label(Vector2(392, 120), 16)
	go_label.text = "FORWARD ►"
	go_label.add_theme_color_override("font_color", Color("f0d050"))
	boss_label = _label(Vector2(120, 270), 9)
	boss_label.text = ""


func _label(p: Vector2, fsize: int) -> Label:
	var l := Label.new()
	l.position = p
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	add_child(l)
	return l


func _process(delta: float) -> void:
	t += delta
	visible = stage != null and is_instance_valid(stage)
	if not visible:
		return
	var st = stage
	score_label.text = "Score %d" % st.score if not st.time_attack else Settings.time_text(st.time)
	name_label.text = "MIREK" if st.lives < 0 else "MIREK   x%d" % st.lives
	go_label.visible = false   # bez šipky "VPŘED" – hra nevede za ruku
	boss_label.visible = st.boss != null and is_instance_valid(st.boss)
	if boss_label.visible:
		boss_label.text = st.boss.display_name
	queue_redraw()


func _draw() -> void:
	if stage == null or not is_instance_valid(stage):
		return
	var st = stage
	var p = st.player
	if st.flash_t > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.85, 0.95, 1.0, clampf(st.flash_t * 1.6, 0.0, 0.8)))
	# Zdraví hráče
	_bar(Rect2(8, 16, 104, 8), float(p.hp) / float(p.max_hp), Color("d8402e"), Color("f07050"))
	# Runy
	for i in 4:
		var r := Rect2(120 + i * 14, 12, 11, 12)
		draw_rect(r, Color(0, 0, 0, 0.5))
		if i < p.runes:
			draw_texture(Art.t("rune"), r.position + Vector2(0.5, 1))
		else:
			draw_rect(r.grow(-1), Color(0.2, 0.25, 0.35, 0.6))
	# Hráč 2 (vpravo nahoře, pod skóre)
	var p2 = st.player2
	if p2 != null and is_instance_valid(p2):
		_bar(Rect2(368, 16, 104, 8), float(p2.hp) / float(p2.max_hp), Color("a83028"), Color("e06050"))
		for i in 4:
			var r2 := Rect2(424 + i * 12, 27, 10, 10)
			draw_rect(r2, Color(0, 0, 0, 0.5))
			if i < p2.runes:
				draw_texture_rect(Art.t("rune"), r2, false)
	# Svačinový box: kousky vzaté zpět bossům
	_draw_lunchbox(st)
	# Boss
	if st.boss != null and is_instance_valid(st.boss):
		var b = st.boss
		_bar(Rect2(120, 283, 240, 8), float(b.hp) / float(b.max_hp), Color("8a5aa8"), Color("b080d0"))


func _slot_pos(i: int) -> Vector2:
	return Vector2(206.0 + i * 17.0, 14.0)


func _draw_lunchbox(st) -> void:
	var box := Rect2(196.0, 4.0, 88.0, 20.0)
	draw_rect(box.grow(1), Color("1a120e"))
	draw_rect(box, Color(0.18, 0.12, 0.08, 0.85))
	draw_rect(Rect2(box.position.x + 36.0, box.position.y - 3.0, 16.0, 3.0), Color(0.3, 0.2, 0.12))  # ucho boxu
	var flying: String = st.snack_fly.get("item", "")
	for i in Snacks.ITEMS.size():
		var item: String = Snacks.ITEMS[i]
		var c := _slot_pos(i)
		if st.lunchbox.has(item) and item != flying:
			Snacks.draw_icon(self, item, c, 14.0)
		else:
			draw_circle(c, 5.0, Color(0, 0, 0, 0.35))
	# kousek letící od bosse do boxu
	if flying != "":
		st.snack_fly["t"] = float(st.snack_fly["t"]) + get_process_delta_time()
		var k := clampf(float(st.snack_fly["t"]) / 1.2, 0.0, 1.0)
		var to := _slot_pos(Snacks.ITEMS.find(flying))
		var from: Vector2 = st.snack_fly["from"]
		var p := from.lerp(to, k * k) + Vector2(0, -sin(k * PI) * 40.0)
		Snacks.draw_icon(self, flying, p, lerpf(30.0, 14.0, k))
		if k >= 1.0:
			st.snack_fly = {}


func _bar(r: Rect2, frac: float, col: Color, hi: Color) -> void:
	draw_rect(r.grow(1), Color("1a120e"))
	draw_rect(r, Color(0.15, 0.1, 0.1))
	var w := roundf(r.size.x * clampf(frac, 0.0, 1.0))
	draw_rect(Rect2(r.position, Vector2(w, r.size.y)), col)
	draw_rect(Rect2(r.position, Vector2(w, 2)), hi)
	# Dílky po 10 %
	var x := r.position.x
	while x < r.end.x:
		draw_rect(Rect2(x, r.position.y, 1, r.size.y), Color(0, 0, 0, 0.25))
		x += r.size.x / 10.0
