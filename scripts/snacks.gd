extends RefCounted
## Svačina kováře Mirka: Král lichů mu ji ukradl a po kouscích rozdal svým zlým kumpánům.
## Každý boss má jeden kousek – po jeho poražení se vrátí do svačinového boxu.
## Ikony jsou kreslené přímo v kódu (draw_icon).

const ITEMS := ["apple", "carrot", "banana", "beer", "sandwich"]
const NAMES := {"apple": "APPLE", "carrot": "CARROT", "banana": "BANANA", "beer": "BOTTLE OF BEER", "sandwich": "SANDWICH"}


## Kousek svačiny, který má boss dané úrovně.
static func for_stage(stage_index: int) -> String:
	return ITEMS[clampi(stage_index, 0, ITEMS.size() - 1)]


## Nakreslí ikonu svačiny se středem v c a velikostí s (px).
static func draw_icon(ci: CanvasItem, item: String, c: Vector2, s: float, alpha: float = 1.0) -> void:
	var a := alpha
	match item:
		"apple":
			ci.draw_circle(c + Vector2(-s * 0.16, s * 0.05), s * 0.33, Color(0.62, 0.1, 0.08, a))
			ci.draw_circle(c + Vector2(s * 0.16, s * 0.05), s * 0.33, Color(0.66, 0.12, 0.09, a))
			ci.draw_circle(c + Vector2(-s * 0.18, -s * 0.05), s * 0.1, Color(1, 0.6, 0.5, 0.5 * a))
			ci.draw_line(c + Vector2(0, -s * 0.22), c + Vector2(s * 0.05, -s * 0.45), Color(0.3, 0.2, 0.1, a), maxf(s * 0.07, 1.0))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.05, -s * 0.38), c + Vector2(s * 0.32, -s * 0.48),
				c + Vector2(s * 0.12, -s * 0.28)]), Color(0.25, 0.5, 0.15, a))
		"carrot":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.18, -s * 0.25), c + Vector2(s * 0.18, -s * 0.25),
				c + Vector2(0, s * 0.48)]), Color(0.85, 0.42, 0.08, a))
			for k in 3:
				var dx := (k - 1) * s * 0.12
				ci.draw_line(c + Vector2(dx, -s * 0.25), c + Vector2(dx * 2.0, -s * 0.5), Color(0.25, 0.55, 0.15, a), maxf(s * 0.08, 1.0))
		"banana":
			var pts := PackedVector2Array()
			for k in 9:
				var an := lerpf(0.35, 2.75, k / 8.0)
				pts.append(c + Vector2(cos(an) * s * 0.42, sin(an) * s * 0.3 - s * 0.12))
			ci.draw_polyline(pts, Color(0.9, 0.78, 0.2, a), maxf(s * 0.18, 2.0))
			ci.draw_circle(pts[0], s * 0.05, Color(0.3, 0.22, 0.1, a))
			ci.draw_circle(pts[8], s * 0.05, Color(0.3, 0.22, 0.1, a))
		"beer":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.16, -s * 0.12), Vector2(s * 0.32, s * 0.58)), Color(0.35, 0.2, 0.06, a))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.07, -s * 0.42), Vector2(s * 0.14, s * 0.32)), Color(0.35, 0.2, 0.06, a))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.08, -s * 0.48), Vector2(s * 0.16, s * 0.07)), Color(0.75, 0.7, 0.55, a))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.16, s * 0.05), Vector2(s * 0.32, s * 0.17)), Color(0.85, 0.78, 0.55, a))
		"sandwich":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.45, s * 0.05), c + Vector2(s * 0.45, s * 0.05),
				c + Vector2(s * 0.38, s * 0.32), c + Vector2(-s * 0.38, s * 0.32)]), Color(0.72, 0.5, 0.25, a))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.44, -s * 0.05), Vector2(s * 0.88, s * 0.1)), Color(0.3, 0.55, 0.2, a))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.42, -s * 0.12), Vector2(s * 0.84, s * 0.08)), Color(0.75, 0.35, 0.3, a))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.45, -s * 0.12), c + Vector2(s * 0.45, -s * 0.12),
				c + Vector2(s * 0.35, -s * 0.35), c + Vector2(-s * 0.35, -s * 0.35)]), Color(0.8, 0.58, 0.3, a))
