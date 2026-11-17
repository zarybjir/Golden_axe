extends Node2D
## Vyprávění příběhu (úvod a závěr) přes malbu z úvodní obrazovky.
## Každý odstavec se postupně objeví; úder / skok / potvrzení přeskočí na další.

signal finished

const Snacks := preload("res://scripts/snacks.gd")

var pages: Array = []        # [text, [ikony svačiny k zobrazení]]
var page := 0
var t := 0.0
var tex: Texture2D
var font: Font
var done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tex = load("res://art/title.jpg")
	font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	t += delta
	var skip := Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("jump") \
		or Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("pause")
	if not done and t > 0.35 and (skip or t > 7.0):
		page += 1
		t = 0.0
		if page >= pages.size():
			done = true
			finished.emit()
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false, Color(0.55, 0.52, 0.5))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	if page >= pages.size():
		return
	var p: Array = pages[page]
	var text: String = p[0]
	var a := clampf(t / 0.6, 0.0, 1.0)
	# text po řádcích, uprostřed obrazovky
	var lines := text.split("\n")
	var fs := 13
	var y := size.y * 0.5 - lines.size() * 9.0
	for ln in lines:
		var w := font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2((size.x - w) * 0.5, y)
		draw_string_outline(font, pos, ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, a))
		draw_string(font, pos, ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.9, 0.8, a))
		y += 18.0
	# kousky svačiny
	var icons: Array = p[1]
	for i in icons.size():
		var c := Vector2(size.x * 0.5 + (i - (icons.size() - 1) * 0.5) * 34.0, y + 22.0)
		Snacks.draw_icon(self, icons[i], c, 26.0, clampf((t - 0.3 - i * 0.25) / 0.4, 0.0, 1.0))
	var hint := "X / J  continue"
	var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	draw_string(font, Vector2(size.x - hw - 10.0, size.y - 10.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.5))
