extends Control
## Ukazatele: zdraví, runy, skóre, zdraví bosse a šipka "VPŘED".

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
	go_label.text = "VPŘED ►"
	go_label.add_theme_color_override("font_color", Color("f0d050"))
	boss_label = _label(Vector2(120, 270), 9)
	boss_label.text = "ZLOBR GRUMOR"


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
	score_label.text = "Skóre %d" % st.score
	go_label.visible = st.go_sign and fmod(t, 0.6) < 0.4
	boss_label.visible = st.boss != null and is_instance_valid(st.boss)
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
	# Boss
	if st.boss != null and is_instance_valid(st.boss):
		var b = st.boss
		_bar(Rect2(120, 283, 240, 8), float(b.hp) / float(b.max_hp), Color("8a5aa8"), Color("b080d0"))


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
