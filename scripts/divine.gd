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
var body: Texture2D
var bolts: Array = []
var add_mat := CanvasItemMaterial.new()

const STRIKE_LIGHTNING := 0.12
const STRIKE_DRAGON := 0.75
const LIFE_LIGHTNING := 0.95
const LIFE_DRAGON := 1.8


func _ready() -> void:
	z_index = 950
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	head = load("res://art/fx/dragon_head.webp")
	fire = load("res://art/fx/fire.webp")
	body = load("res://art/fx/dragon_body.webp")
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


## Dračí hlava proletí šikmo dolů přes celou obrazovku, za ní se táhne
## dlouhé přízračné tělo až za okraj (konec draka není nikdy vidět).
const DIVE := 0.0           # let vodorovně v horní části obrazovky
const FLY_TIME := 1.7


func _head_s() -> float:
	# vzdálenost hlavy od středu obrazovky po dráze letu
	var k := clampf(t / FLY_TIME, 0.0, 1.0)
	return lerpf(-520.0, 560.0, k)


func _draw_dragon() -> void:
	var cam := get_viewport().get_camera_2d()
	var center := Vector2(240.0, 72.0)
	if cam != null:
		center = Vector2(cam.get_screen_center_position().x, 72.0)
	var dir := Vector2(cos(DIVE), sin(DIVE))
	var nrm := Vector2(-dir.y, dir.x)
	var hp := center + dir * _head_s()
	var fade := clampf((LIFE_DRAGON - t) / 0.25, 0.0, 1.0)
	if mode == "fire":
		# oheň z tlamy šikmo dolů před hlavou, za postavami
		if t > 0.25 and t < FLY_TIME:
			var flick := 1.0 + 0.08 * sin(t * 50.0)
			var mouth := hp + dir * 70.0 + nrm * 18.0
			var ang := 0.62   # oheň šikmo dolů na bojiště
			var fl := 330.0 * flick
			var fh := 170.0 * flick
			draw_set_transform(mouth, ang, Vector2.ONE)
			draw_texture_rect(fire, Rect2(-10.0, -fh * 0.5, fl, fh), false, Color(1, 1, 1, 0.95 * fade))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# tělo – články podél dráhy za hlavou, vlní se
	var bw := float(body.get_width()) * 140.0 / float(body.get_height())
	var seg := bw * 0.55
	for k in range(14, -1, -1):
		var back := 95.0 + seg * k
		var wob := sin(k * 0.9 - t * 7.0) * 12.0
		var c := hp - dir * back + nrm * wob
		var rot := DIVE + cos(k * 0.9 - t * 7.0) * 0.08
		draw_set_transform(c, rot, Vector2.ONE)
		draw_texture_rect(body, Rect2(-bw * 0.5, -70.0 + 14.0, bw, 140.0), false, Color(1, 1, 1, fade))
	# hlava – skloněná ve směru letu
	var hh := 170.0
	var hw := head.get_width() * hh / head.get_height()
	# obrázek hlavy má čumák skloněný dolů – natočíme ji, aby mířila ve směru letu
	draw_set_transform(hp, DIVE - 0.3, Vector2.ONE)
	draw_texture_rect(head, Rect2(-hw * 0.45, -hh * 0.5, hw, hh), false, Color(1, 1, 1, 0.95 * fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
