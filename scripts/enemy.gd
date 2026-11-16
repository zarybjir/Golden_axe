extends "res://scripts/fighter.gd"
## Nepřátelé. Útočit smějí jen dva najednou (ostatní čekají opodál), každý útok
## má čitelný nápřah (postava zežloutne a nad hlavou se ukáže "!").

const KINDS := {
	"goblin": {"hp": 26, "speed": Vector2(84, 50), "reach": 28.0, "attack": "gob_atk", "cool": 46,
		"parts": "gob", "weapon": "club", "grip": Vector2(3.5, 9.0), "scale": 1.7, "score": 100},
	"skeleton": {"hp": 34, "speed": Vector2(70, 42), "reach": 46.0, "attack": "sp_atk", "cool": 64,
		"parts": "skel", "weapon": "spear", "grip": Vector2(4.0, 13.0), "scale": 2.0, "score": 150, "idle": "sp_idle"},
	"ogre": {"hp": 260, "speed": Vector2(56, 34), "reach": 30.0, "attack": "ogre_slam", "cool": 56,
		"parts": "ogre", "weapon": "tree_club", "grip": Vector2(4.5, 13.0), "scale": 3.6, "score": 3000, "armor": true,
		"name": "OBR GRUMOR", "hit_w": 7.0, "depth": 10.0},
}

var kind := "goblin"
var cfg: Dictionary = {}
var cooldown := 60
var has_token := false
var slot := 0.0
var entered := false
var dead_t := 0


func _ready() -> void:
	team = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cfg = KINDS[kind]
	max_hp = int(cfg["hp"])
	hp = max_hp
	setup_parts(cfg["parts"], cfg["weapon"], cfg["grip"])
	body_scale = float(cfg["scale"])
	armor = bool(cfg.get("armor", false))
	idle_pose = String(cfg.get("idle", "idle"))
	display_name = String(cfg.get("name", ""))
	hit_w = float(cfg.get("hit_w", 9.0))
	hit_depth = float(cfg.get("depth", 0.0))
	cooldown = 30 + randi() % 50
	slot = randf_range(-40.0, 40.0)


func tick() -> void:
	physics_step()
	if state == S.DEAD:
		dead_t += 1
		_release()
		return
	match state:
		S.RIDE:
			pass # Pohyb řídí ještěr.
		S.IDLE, S.WALK:
			_ai()
		S.HURT, S.DOWN, S.GETUP:
			_release()


func _ai() -> void:
	cooldown -= 1
	var p = stage.player
	if p == null:
		return
	var dx: float = p.pos.x - pos.x
	var dy: float = p.pos.y - pos.y
	facing = 1 if dx > 0.0 else -1
	if not p.alive() or p.state == S.DOWN or p.state == S.DEAD:
		_release()
		_walk_to(Vector2(p.pos.x - facing * 160.0, clampf(p.pos.y + slot, Y_MIN, Y_MAX)))
		return
	if not has_token:
		has_token = stage.request_token(self)
	var reach: float = float(cfg["reach"]) * body_scale
	if has_token:
		if kind == "ogre" and cooldown <= 0 and absf(dy) < 12.0 and absf(dx) > 130.0 and absf(dx) < 260.0:
			start_move("ogre_charge")
			Sfx.play("roar")
			return
		if absf(dx) <= reach and absf(dy) <= 6.0 and cooldown <= 0:
			start_move(cfg["attack"])
			return
		_walk_to(Vector2(p.pos.x - facing * reach * 0.75, p.pos.y))
	else:
		_walk_to(Vector2(p.pos.x - facing * 150.0, clampf(p.pos.y + slot, Y_MIN, Y_MAX)))


func _walk_to(target: Vector2) -> void:
	var sp: Vector2 = cfg["speed"]
	var d := target - pos
	if d.length() < 2.0:
		if state != S.IDLE:
			set_state(S.IDLE)
		walk_t += DT * 0.5
		return
	pos.x += clampf(d.x, -sp.x * DT, sp.x * DT)
	pos.y += clampf(d.y, -sp.y * DT, sp.y * DT)
	walk_t += DT * 0.8
	if state != S.WALK:
		set_state(S.WALK)


func _move_finished() -> void:
	set_state(S.IDLE)
	cooldown = int(cfg["cool"]) + randi() % 40
	_release()


func _release() -> void:
	if has_token:
		stage.release_token(self)
		has_token = false


func _draw_extra() -> void:
	if telegraph and state == S.ATTACK:
		var y := -44.0 * body_scale
		draw_rect(Rect2(-2, y, 4, 9), Color("f0d050"))
		draw_rect(Rect2(-2, y + 11, 4, 3), Color("f0d050"))
		draw_rect(Rect2(-3, y - 1, 6, 1), Color("1a120e"))
