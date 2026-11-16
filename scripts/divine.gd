extends Node2D
## Boží síla (runová magie):
##   1–2 runy: sloupy blesků blikají na všech nepřátelích na obrazovce,
##   3–4 runy: z okraje obrazovky se vynoří obří dračí hlava a chrlí oheň přes celou zem.
## Zásah (on_strike) se zavolá ve chvíli, kdy blesk udeří nebo oheň dosáhne nepřátel.

var mode := "lightning"
var targets: Array = []          # světové pozice nepřátel (Vector2: x, zem y)
var on_strike: Callable
var stage: Node2D
var t := 0.0
var struck := false
var head: Texture2D
var fire: Texture2D
var bolts: Array = []
var add_mat := CanvasItemMaterial.new()

const STRIKE_LIGHTNING := 0.12
const STRIKE_DRAGON := 0.55
const LIFE_LIGHTNING := 0.95
const LIFE_DRAGON := 1.9


func _ready() -> void:
	z_index = 950
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	head = load("res://art/fx/dragon_head.webp")
	fire = load("res://art/fx/fire.webp")
	bolts = [load("res://art/fx/lightning_0.webp"), load("res://art/fx/lightning_1.webp")]
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	if mode == "fire":
		z_index = 150   # oheň za postavami (postavy mají z_index = y >= 196)
		return
	if mode == "dragon":
		Sfx.play("roar", 0.6)
		# oheň jako samostatná vrstva za postavami, hlava zůstává nahoře
		var f := duplicate()
		f.mode = "fire"
		f.stage = stage
		get_parent().add_child.call_deferred(f)
	else:
		Sfx.play("thunder")


func _process(delta: float) -> void:
	t += delta
	if mode == "fire":
		if t > LIFE_DRAGON:
			queue_free()
		queue_redraw()
		return
	var strike_at := STRIKE_DRAGON if mode == "dragon" else STRIKE_LIGHTNING
	if not struck and t >= strike_at:
		struck = true
		if mode == "dragon":
			Sfx.play("fire")
			Sfx.play("thunder", 0.7)
		if on_strike.is_valid():
			on_strike.call()
	# další údery hromu při blikání blesků
	if mode == "lightning" and struck and fmod(t, 0.25) < delta:
		stage.shake(4.0, 0.12)
		stage.flash_t = maxf(stage.flash_t, 0.06)
	if t > (LIFE_DRAGON if mode == "dragon" else LIFE_LIGHTNING):
		queue_free()
	queue_redraw()


func _draw() -> void:
	if mode == "dragon" or mode == "fire":
		_draw_dragon()
	else:
		_draw_lightning()


func _draw_lightning() -> void:
	if t < STRIKE_LIGHTNING:
		return
	var k := t - STRIKE_LIGHTNING
	for i in targets.size():
		var p: Vector2 = targets[i]
		# blikání: každý sloup se rozsvěcí a zhasíná v nepravidelném rytmu
		var on := fmod(k * (9.0 + i * 1.7) + i * 0.37, 1.0) < 0.62
		if not on:
			continue
		var fade := clampf(1.0 - (k - 0.6) / 0.3, 0.0, 1.0)
		var tex: Texture2D = bolts[(i + int(k * 12.0)) % bolts.size()]
		var h := p.y + 30.0
		var w := 70.0 * (0.85 + 0.3 * sin(k * 40.0 + i))
		var r := Rect2(p.x - w * 0.5, -30.0, w, h)
		draw_texture_rect(tex, r, false, Color(1, 1, 1, fade))
		# záře kolem sloupu a v místě dopadu
		draw_circle(Vector2(p.x, p.y - 2.0), 7.0, Color(0.85, 0.95, 1.0, 0.55 * fade))


func _draw_dragon() -> void:
	var size := get_viewport_rect().size
	var cam := get_viewport().get_camera_2d()
	var left := 0.0
	if cam != null:
		left = cam.get_screen_center_position().x - 240.0
	var hh := 200.0
	var hw := head.get_width() * hh / head.get_height()
	# hlava se vysune zleva, pak se při chrlení otřásá, nakonec se rozplyne
	var slide := clampf(t / 0.45, 0.0, 1.0)
	slide = 1.0 - pow(1.0 - slide, 3.0)
	var fade := clampf(1.0 - (t - 1.45) / 0.45, 0.0, 1.0)
	var shake := Vector2.ZERO
	if t > STRIKE_DRAGON and t < 1.45:
		shake = Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
	var hx := left - hw + slide * (hw * 0.62) + shake.x
	var hy := 40.0 + shake.y
	if mode == "dragon":
		draw_texture_rect(head, Rect2(hx, hy, hw, hh), false, Color(1, 1, 1, 0.92 * fade))
		return
	# oheň z tlamy přes celou šířku obrazovky
	if t > STRIKE_DRAGON - 0.05:
		var k := clampf((t - STRIKE_DRAGON + 0.05) / 0.3, 0.0, 1.0)
		var mouth := Vector2(hx + hw * 0.93, hy + hh * 0.62)
		var reach := (left + 480.0 + 60.0 - mouth.x) * k
		var flick := 1.0 + 0.06 * sin(t * 50.0)
		var fh := 190.0 * flick
		# kužel ohně – lehce svažitý k zemi, ve třech vrstvách pro hustotu
		for j in 3:
			var off := float(j) * 0.12
			var rr := Rect2(mouth.x - 12.0 + j * 20.0, mouth.y - fh * 0.32 + j * 10.0,
				reach * (1.0 - off * 0.5), fh * (1.0 - off))
			var c := Color(1, 1, 1, (0.95 - off) * fade)
			draw_texture_rect(fire, rr, false, c)
		# žhnoucí opar nad zemí
		draw_rect(Rect2(left, 180.0, 480.0, 120.0), Color(1.0, 0.45, 0.1, 0.18 * k * fade))
