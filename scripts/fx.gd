extends Node2D
## Jednoduché částice: prach při skoku/dopadu, jiskry při zásahu, třpyt u jídla.

# Každá částice: [pozice, rychlost, zbývá, celkem, barva, velikost, gravitace]
var parts: Array = []


func _ready() -> void:
	z_index = 5


func burst(pos: Vector2, color: Color, count: int, speed: float, life: float = 0.5, grav: float = 300.0, size: float = 2.0) -> void:
	for i in count:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * randf_range(speed * 0.3, speed)
		parts.append([pos, v, life, life, color, size, grav])


func dust(pos: Vector2, count: int = 6) -> void:
	for i in count:
		var v := Vector2(randf_range(-45.0, 45.0), randf_range(-30.0, -5.0))
		parts.append([pos + Vector2(randf_range(-4.0, 4.0), 0.0), v, 0.35, 0.35, Color("e8d8b8"), 2.0, 30.0])


func _process(delta: float) -> void:
	for p in parts:
		p[1] = p[1] + Vector2(0.0, p[6] * delta)
		p[0] = p[0] + p[1] * delta
		p[2] = p[2] - delta
	parts = parts.filter(func(p: Array) -> bool: return p[2] > 0.0)
	queue_redraw()


func _draw() -> void:
	for p in parts:
		var k: float = p[2] / p[3]
		var c: Color = p[4]
		c.a = clampf(k * 1.5, 0.0, 1.0)
		var s: float = maxf(1.0, roundf(p[5] * (0.5 + 0.5 * k)))
		var pos: Vector2 = p[0]
		draw_rect(Rect2(pos.round() - Vector2(s, s) * 0.5, Vector2(s, s)), c)
