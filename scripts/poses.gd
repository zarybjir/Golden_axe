extends RefCounted
## Knihovna póz. Úhly v radiánech:
##   lean = náklon trupu, head = hlava, af/ab = přední/zadní ruka (0 = dolů, -1.57 = dopředu,
##   -3.1 = nahoru), lf/lb = nohy, w = úhel zbraně vůči ruce, dy = přikrčení, rot = celé tělo.
## Útoky jsou časové osy: [[snímek, póza], ...] – mezi pózami se plynule prolíná.

const POSES := {
	"idle": {"lean": 0.04, "af": -0.45, "ab": 0.25, "lf": -0.18, "lb": 0.18, "w": 1.0, "dy": 0.0},
	"walk_a": {"lean": 0.08, "af": -0.75, "ab": 0.55, "lf": -0.55, "lb": 0.45, "w": 1.0, "dy": -1.0},
	"walk_b": {"lean": 0.08, "af": -0.15, "ab": -0.35, "lf": 0.45, "lb": -0.55, "w": 1.0, "dy": -1.0},
	"jump": {"lean": 0.1, "af": -1.2, "ab": 0.9, "lf": -1.1, "lb": 0.7, "w": 1.4, "dy": -3.0},
	"hurt": {"lean": -0.35, "head": -0.3, "af": 0.9, "ab": 0.7, "lf": 0.25, "lb": -0.1, "w": 1.6, "dy": 1.0},
	"down": {"lean": -0.2, "head": -0.2, "af": -2.6, "ab": -2.2, "lf": -0.2, "lb": 0.1, "w": 2.6, "rot": -1.5, "dy": 0.0},
	"getup": {"lean": 0.5, "af": -0.9, "ab": 0.4, "lf": -1.0, "lb": 0.9, "w": 1.2, "dy": 4.0},
	"dodge": {"lean": 0.6, "head": 0.2, "af": 0.6, "ab": 0.9, "lf": -1.0, "lb": 0.9, "w": 1.8, "dy": 5.0},
	"cast": {"lean": -0.2, "head": -0.3, "af": -3.0, "ab": -2.6, "lf": -0.2, "lb": 0.2, "w": 1.6, "dy": 0.0},
	"slam": {"lean": 0.5, "head": 0.2, "af": -0.4, "ab": -0.3, "lf": -0.8, "lb": 0.8, "w": 2.3, "dy": 6.0},
	# Kladivo – 3 údery v kombu
	"a1_wind": {"lean": -0.1, "af": 0.7, "ab": 0.3, "lf": -0.3, "lb": 0.3, "w": 1.3, "dy": 1.0},
	"a1_hit": {"lean": 0.25, "af": -1.55, "ab": 0.6, "lf": -0.6, "lb": 0.5, "w": 1.1, "dy": 1.0},
	"a2_wind": {"lean": -0.15, "af": -2.7, "ab": 0.2, "lf": -0.2, "lb": 0.4, "w": 1.6, "dy": 0.0},
	"a2_hit": {"lean": 0.3, "af": -0.9, "ab": 0.7, "lf": -0.7, "lb": 0.6, "w": 1.8, "dy": 2.0},
	"a3_wind": {"lean": -0.35, "head": -0.2, "af": -3.0, "ab": -2.8, "lf": -0.3, "lb": 0.5, "w": 2.0, "dy": -1.0},
	"a3_hit": {"lean": 0.55, "head": 0.2, "af": -0.5, "ab": -0.4, "lf": -0.9, "lb": 0.8, "w": 2.3, "dy": 6.0},
	"jatk": {"lean": 0.4, "af": -0.7, "ab": 0.6, "lf": -1.2, "lb": 0.6, "w": 2.2, "dy": -2.0},
	# Kopí (kostlivec): bodnutí
	"sp_idle": {"lean": 0.05, "af": -1.2, "ab": -0.9, "lf": -0.2, "lb": 0.2, "w": 1.57, "dy": 0.0},
	"sp_wind": {"lean": -0.2, "af": -0.6, "ab": -0.4, "lf": -0.1, "lb": 0.4, "w": 1.0, "dy": 0.0},
	"sp_hit": {"lean": 0.3, "af": -1.6, "ab": -1.4, "lf": -0.7, "lb": 0.6, "w": 1.57, "dy": 2.0},
	# Útěk zlobra
	"ride": {"lean": 0.12, "af": -0.7, "ab": 0.3, "lf": -1.3, "lb": -1.0, "w": 1.1, "dy": 3.0},
	"charge": {"lean": 0.6, "head": 0.3, "af": -1.4, "ab": 0.9, "lf": -0.8, "lb": 0.8, "w": 1.4, "dy": 3.0},
}

## Pohyby: len = délka (snímky), hit = [od, do] aktivní snímky, keys = časová osa póz.
## cancel = od kterého snímku jde pohyb přerušit dalším útokem / úskokem.
const MOVES := {
	"atk1": {"len": 18, "hit": [5, 7], "cancel": 8, "dmg": 6, "reach": 34, "push": 40, "knock": false, "next": "atk2",
		"keys": [[0, "idle"], [3, "a1_wind"], [5, "a1_hit"], [12, "a1_hit"], [18, "idle"]]},
	"atk2": {"len": 22, "hit": [5, 11], "cancel": 12, "dmg": 8, "reach": 36, "push": 50, "knock": false, "next": "atk3",
		"keys": [[0, "a1_hit"], [4, "a2_wind"], [6, "a2_hit"], [14, "a2_hit"], [20, "idle"]]},
	"atk3": {"len": 30, "hit": [10, 12], "cancel": 20, "dmg": 14, "reach": 40, "push": 0, "knock": true, "next": "",
		"keys": [[0, "a2_hit"], [7, "a3_wind"], [10, "a3_hit"], [22, "a3_hit"], [30, "idle"]]},
	"jatk": {"len": 30, "hit": [6, 16], "cancel": 99, "dmg": 12, "reach": 34, "push": 0, "knock": true, "next": "",
		"keys": [[0, "jump"], [3, "jatk"], [30, "jatk"]]},
	"spider_stab": {"len": 46, "hit": [26, 31], "cancel": 99, "dmg": 9, "reach": 30, "push": 60, "knock": false, "next": "",
		"keys": [[0, "idle"], [46, "idle"]]},
	"vine_lash": {"len": 72, "hit": [34, 44], "cancel": 99, "dmg": 10, "reach": 30, "push": 90, "knock": false, "next": "",
		"keys": [[0, "idle"], [72, "idle"]]},
	"zombie_claw": {"len": 58, "hit": [36, 40], "cancel": 99, "dmg": 8, "reach": 26, "push": 50, "knock": false, "next": "",
		"keys": [[0, "idle"], [58, "idle"]]},
	"zombie_club": {"len": 36, "hit": [18, 22], "cancel": 99, "dmg": 12, "reach": 30, "push": 0, "knock": true, "next": "",
		"keys": [[0, "idle"], [36, "idle"]]},
	"golem_punch": {"len": 52, "hit": [28, 32], "cancel": 99, "dmg": 16, "reach": 30, "push": 0, "knock": true, "next": "",
		"keys": [[0, "idle"], [52, "idle"]]},
	"golem_throw": {"len": 96, "hit": [999, 999], "cancel": 99, "dmg": 0, "reach": 0, "push": 0, "knock": false, "next": "",
		"keys": [[0, "idle"], [96, "idle"]]},
	"native_jab": {"len": 26, "hit": [9, 12], "cancel": 99, "dmg": 6, "reach": 30, "push": 40, "knock": false, "next": "",
		"keys": [[0, "idle"], [26, "idle"]]},
	"ghoul_atk": {"len": 34, "hit": [13, 17], "cancel": 99, "dmg": 8, "reach": 30, "push": 60, "knock": false, "next": "",
		"keys": [[0, "idle"], [16, "a2_wind"], [20, "a2_hit"], [30, "a2_hit"], [40, "idle"]]},
	"bat_swoop": {"len": 40, "hit": [12, 22], "cancel": 99, "dmg": 6, "reach": 34, "push": 50, "knock": false, "next": "",
		"keys": [[0, "idle"], [44, "idle"]]},
	"gob_atk": {"len": 44, "hit": [24, 26], "cancel": 99, "dmg": 7, "reach": 26, "push": 50, "knock": false, "next": "",
		"keys": [[0, "idle"], [18, "a2_wind"], [24, "a2_hit"], [34, "a2_hit"], [44, "idle"]]},
	"sp_atk": {"len": 46, "hit": [21, 25], "cancel": 99, "dmg": 10, "reach": 46, "push": 60, "knock": false, "next": "",
		"keys": [[0, "sp_idle"], [24, "sp_wind"], [30, "sp_hit"], [42, "sp_hit"], [54, "sp_idle"]]},
	"ogre_slam": {"len": 62, "hit": [28, 32], "cancel": 99, "dmg": 18, "reach": 56, "push": 0, "knock": true, "next": "",
		"keys": [[0, "idle"], [30, "a3_wind"], [36, "a3_hit"], [56, "a3_hit"], [70, "idle"]]},
	"ogre_charge": {"len": 80, "hit": [54, 62], "cancel": 99, "dmg": 16, "reach": 30, "push": 0, "knock": true, "next": "",
		"dash": 270.0, "dash_from": 22, "dash_to": 60,
		"keys": [[0, "idle"], [24, "a1_wind"], [28, "charge"], [64, "charge"], [80, "idle"]]},
	"magic": {"len": 56, "hit": [24, 24], "cancel": 99, "dmg": 0, "reach": 0, "push": 0, "knock": true, "next": "",
		"keys": [[0, "idle"], [10, "cast"], [20, "cast"], [24, "slam"], [44, "slam"], [56, "idle"]]},
}


static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for k in ["lean", "head", "af", "ab", "lf", "lb", "w", "dy", "rot"]:
		out[k] = lerpf(float(a.get(k, 0.0)), float(b.get(k, 0.0)), t)
	return out


static func at(keys: Array, f: float) -> Dictionary:
	var first: Array = keys[0]
	if f <= float(first[0]):
		return blend(POSES[first[1]], POSES[first[1]], 0.0)
	for i in range(keys.size() - 1):
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if f <= float(b[0]):
			var span := maxf(float(b[0]) - float(a[0]), 0.001)
			return blend(POSES[a[1]], POSES[b[1]], (f - float(a[0])) / span)
	var last: Array = keys[keys.size() - 1]
	return blend(POSES[last[1]], POSES[last[1]], 0.0)
