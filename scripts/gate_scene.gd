extends Node2D
## Scéna po poražení kamenného obra: hrdina dojde k obrovské bráně temného paláce,
## vystoupá po schodech a zmizí ve tmě za pootevřenými dveřmi.
## Přeskočit jde úderem nebo skokem.

signal finished

var frames: Array = []       # snímky chůze hrdiny
var offsets: Array = []
var k := 0.3
var tex: Texture2D
var t := 0.0
var done := false

const GROUND_Y := 268.0
const STAIRS_X := 205.0      # pata schodů
const DOOR := Vector2(347.0, 224.0)   # škvíra mezi dveřmi (práh)
const WALK_END := 3.4        # konec chůze po zemi
const CLIMB_END := 5.6       # hrdina u dveří
const END := 7.0


func setup(hero_frames: Array, hero_offsets: Array, hero_k: float) -> void:
	frames = hero_frames
	offsets = hero_offsets
	k = hero_k


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tex = load("res://art/gate.jpg")


func _process(delta: float) -> void:
	t += delta
	if not done and (t > END or (t > 1.0 and (Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("jump")))):
		done = true
		finished.emit()
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
	# hrdina: chůze po zemi, pak do schodů ke dveřím (zmenšuje se – vzdaluje se)
	var p: Vector2
	var sc := 1.0
	if t < WALK_END:
		p = Vector2(lerpf(-30.0, STAIRS_X, t / WALK_END), GROUND_Y)
	else:
		var u := clampf((t - WALK_END) / (CLIMB_END - WALK_END), 0.0, 1.0)
		p = Vector2(STAIRS_X, GROUND_Y).lerp(DOOR, u)
		sc = lerpf(1.0, 0.72, u)
	var a := 1.0 - clampf((t - CLIMB_END) / 0.9, 0.0, 1.0)   # zmizí ve tmě za dveřmi
	if a > 0.0 and not frames.is_empty():
		var i := int(t * 12.0) % frames.size()
		if t >= CLIMB_END:
			i = 0
		var fr: Texture2D = frames[i]
		var off: Vector2 = offsets[i]
		draw_set_transform(p, 0.0, Vector2(k * sc, k * sc))
		draw_texture(fr, off, Color(0.8, 0.8, 0.78, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# ztmavení na konci
	var fade := clampf((t - (END - 0.8)) / 0.8, 0.0, 1.0)
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, fade))
