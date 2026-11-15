extends Node
## Grafika: díly postav ("panáčci" skládaní z hlavy, trupu, rukou, nohou a zbraně)
## nakreslené jako ASCII pixel art. Každé písmeno = barva z PAL, tečka = průhledná.
## Postavy se animují otáčením dílů, takže stačí málo kreseb a pohyb je plynulý.

const OUTLINE := Color("1a120e")

const PAL := {
	"k": Color("2b1d14"),
	"s": Color("e0a070"), "x": Color("f6c896"), "S": Color("b07040"),
	"h": Color("4a2c18"), "H": Color("7a4a28"),
	"o": Color("d8742a"), "O": Color("a04a18"), # zrzavý vous
	"i": Color("4a6aa8"), "I": Color("2e4678"), "J": Color("6a8ac8"), # modrá tunika
	"b": Color("5a3418"), "B": Color("8a5428"), "j": Color("b07a40"), # kůže/dřevo
	"w": Color("f4f0e0"), "y": Color("f0d050"), "Y": Color("b89830"),
	"p": Color("8a8a96"), "P": Color("55555f"), "q": Color("b8b8c4"), "Q": Color("e4e4ec"),
	"g": Color("6aa84a"), "G": Color("3e7a32"), "l": Color("9ad870"), # goblin
	"r": Color("d8402e"), "R": Color("8e2020"),
	"n": Color("ece4cc"), "N": Color("b8ae94"), "m": Color("7a7266"), # kosti
	"v": Color("7a8aa0"), "V": Color("4e5a70"), "z": Color("a4b4c8"), # zlobr
	"c": Color("6a4a8a"), "C": Color("3e2a58"),
	"e": Color("40d8ff"), "E": Color("1a7ab8"), # runa
	"f": Color("c06a2a"), "F": Color("7a3a14"),
}

# ---------------------------------------------------------------- hrdina: kovář Mirek
const HERO_HEAD := [
	"...hhhh...",
	"..hhHHhhh.",
	".hhhHhhhh.",
	".hhssssshk",
	".hssssswk.",
	".hsxsssss.",
	"..ssssSSs.",
	"..oooooOo.",
	"..ooookoO.",
	"...oooOO..",
	"....oO....",
]
const HERO_TORSO := [
	"...iiiiii...",
	"..iJJiiiii..",
	".iJiiiiiiIi.",
	".iiiBBBBiII.",
	".iiBBjBBBII.",
	".iiBBBBBBII.",
	".iiBBBBBBII.",
	"..iBBBBBBI..",
	"..kkkkkkkk..",
	"..kkyYkkkk..",
	"..BBBBBBBB..",
	"..BBBjBBBB..",
	"..BBBBBBBB..",
]
const HERO_ARM := [
	"iiii",
	"iJii",
	"isss",
	"ssss",
	"sxss",
	"ssSs",
	"BBBB",
	"BjBB",
	"ssss",
	"sxss",
	".ss.",
]
const HERO_LEG := [
	"IIIII",
	"IIIII",
	"iIIII",
	"IIIII",
	"IIII.",
	"bbbb.",
	"bBBb.",
	"bBBb.",
	"bBBb.",
	"bBBbb.",
	"bbbbbb",
	"kkkkkk",
]
const HAMMER := [
	"PPPPPPPPPP",
	"PqQQqqqqpP",
	"PqQqqqqqpP",
	"PpppppppPP",
	"PPPPPPPPPP",
	"....jB....",
	"....jB....",
	"....BB....",
	"....jB....",
	"....jB....",
	"....BB....",
	"....jB....",
	"....jb....",
	"....bb....",
]

# ---------------------------------------------------------------- goblin
const GOB_HEAD := [
	"g.........g",
	"gg.gggg..gg",
	".ggglgggGg.",
	"..ggggggG..",
	"..ggyRggg..",
	"..gggggGgk.",
	"..gwgwgGg..",
	"...GGGGG...",
]
const GOB_TORSO := [
	"..FFFFFF..",
	".FffffffF.",
	".FffFfffF.",
	".FfffffFF.",
	"..ggggGG..",
	"..fFfFfF..",
	"..F.F.F...",
]
const GOB_ARM := [
	"ggg",
	"glg",
	"ggg",
	"gGg",
	"ggg",
	"ggg",
	"GG.",
]
const GOB_LEG := [
	"ggg.",
	"gGg.",
	"ggg.",
	"gGg.",
	"ggg.",
	"gggg",
	"GGGG",
]
const CLUB := [
	".jBBB.",
	"jBBbBB",
	"BBBBBb",
	"BbBBBb",
	".BBBb.",
	"..Bb..",
	"..Bb..",
	"..Bb..",
	"..Bb..",
	"..bb..",
]

# ---------------------------------------------------------------- kostlivec
const SKEL_HEAD := [
	"..nnnnn..",
	".nnnnnnN.",
	"nnnnnnnN.",
	"nnkknkkN.",
	"nnkknkkN.",
	".nnnnnN..",
	"..nkknN..",
	"..NnnN...",
]
const SKEL_TORSO := [
	"..nnnnn..",
	".nmnnnmn.",
	".nNnNnNn.",
	"..nmnmn..",
	"..nNnNn..",
	"...nNn...",
	"...nNn...",
	"..nnnnn..",
	"..NNnNN..",
]
const SKEL_ARM := [
	"nN",
	"nN",
	"nN",
	"NN",
	"nN",
	"nN",
	"nN",
	"NN",
	"nn",
]
const SKEL_LEG := [
	"nnN",
	".nN",
	".nN",
	".nN",
	".NN",
	".nN",
	".nN",
	".nN",
	"nnnN",
	"NNNN",
]
const SPEAR := [
	"...Q...",
	"..QqQ..",
	"..qqp..",
	"..qqp..",
	"...p...",
	"..PPP..",
	"...B...",
	"...B...",
	"...b...",
	"...B...",
	"...B...",
	"...b...",
	"...B...",
	"...B...",
	"...b...",
	"...B...",
	"...B...",
	"...b...",
	"...B...",
	"...b...",
]

# ---------------------------------------------------------------- zlobr (boss)
const OGRE_HEAD := [
	"...vvvvvv...",
	"..vvvvvvvvv.",
	".vvzvvvvvvV.",
	".vvvvrvvvrV.",
	".vvvvvvvvvVk",
	"vvvvvvvvvVV.",
	".vvwvvvwvV..",
	".vVwVVVwVV..",
	"..VVVVVVV...",
]
const OGRE_TORSO := [
	"...vvvvvvvv...",
	"..vvzzvvvvvV..",
	".vvzvvvvvvvVV.",
	".vvvvvvvvvvVV.",
	".vvvvvvvvvVVV.",
	".FFFFFFFFFFFF.",
	".FfffFfffFffF.",
	".FffffffffffF.",
	"..vvvvvvvvVV..",
	"..vvvvvvvVVV..",
	"..FFFFFFFFFF..",
	"..FfFfFfFfFF..",
	"..F.F.F.F.F...",
]
const OGRE_ARM := [
	"vvvvv",
	"vzvvV",
	"vvvvV",
	"vvvVV",
	"vvvvV",
	"FFFFF",
	"vvvvV",
	"vvvvV",
	"vvvVV",
	"vvvv.",
]
const OGRE_LEG := [
	"vvvvv.",
	"vvvvV.",
	"vvvvV.",
	"vvvVV.",
	"vvvvV.",
	"vvvVV.",
	"FFFFF.",
	"vvvvvv",
	"VVVVVV",
]
const TREE_CLUB := [
	"..jBBBB..",
	".jBBbBBBB",
	"jBBBBBBbB",
	"BBbBBpBBB",
	"BBBBBBBbB",
	".BBBbBBB.",
	"..BBBBB..",
	"...BBb...",
	"...BBb...",
	"...Bbb...",
	"...BBb...",
	"...BBb...",
	"...bBb...",
	"...BBb...",
	"...bbb...",
]

# ---------------------------------------------------------------- předměty
const MEAT := [
	"......ffff..",
	"....ffffffF.",
	"...ffxfffFff",
	"...fxffffFFf",
	"...ffffFFFF.",
	"....ffFFFF..",
	"...nNfffF...",
	"..nN........",
	"nnN.........",
	"nNN.........",
]
const RUNE := [
	"..EEEE..",
	".EeeeeE.",
	"EeeEEeeE",
	"EeEeeEeE",
	"EeeEEeeE",
	"EeEeeEeE",
	".EeeeeE.",
	"..EEEE..",
]
const BARREL := [
	"..BBBBBBBB..",
	".BjBBBBBBbB.",
	"PPPPPPPPPPPP",
	"BjBBBBBBBBbB",
	"BjBBBBBBBBbB",
	"BjBBBbBBBBbB",
	"PPPPPPPPPPPP",
	"BjBBBBBBBBbB",
	"BjBBBBBBBBbB",
	"PPPPPPPPPPPP",
	".BbBBBBBBbB.",
	"..BBBBBBBB..",
]

# ---------------------------------------------------------------- drak (a ještěr k jízdě – stejné díly, jiné barvy)
const DRG_BODY := [
	".......n...n...n..............",
	"......rrr.rrr.rrr.............",
	"....rrrrrrrrrrrrrrrrrr........",
	"..rrrRrrrrrrrrRrrrrrrrrr......",
	".rrrrrrrrrrrrrrrrrrrrrrrrr....",
	"rrrRrrrrrrRrrrrrrrrRrrrrrrr...",
	"rrrrrrrrrrrrrrrrrrrrrrrrrrrr..",
	"rrrrrrrrrrrrrrrrrrrrrrrrrrrrr.",
	"rRrrrrrrrrrrrrrrrrrrrrrrrrrrr.",
	"rrrooooooooooooooooooooorrrrr.",
	".rroOoOoOoOoOoOoOoOoOoOoorrr..",
	"..rooooooooooooooooooooorr....",
	"...RooOoOoOoOoOoOoOoOoRR......",
	".....RRRRRRRRRRRRRRRRR........",
]
const DRG_HEAD := [
	"..nn..............",
	"...nn.............",
	"..rrrrrr..........",
	".rrrrrrrrrrrr.....",
	"rrrRrrywkrrrrrrr..",
	"rrrrrrrrrrrrrrrrrr",
	"rrrrrrrrrrrrrrrrrk",
	".rrrrrrrrrnrnrnrn.",
	"..RRRRRRRRR.......",
]
const DRG_JAW := [
	".RRRRRRRRRR...",
	"RrrrrrrrrnRnRn",
	".RRRRRRRRRRRR.",
]
const DRG_NECK := [
	"..rrrrr..",
	".rrrrrrr.",
	"rrrRrrrrr",
	"rrrrrrrrr",
	"rrrrrrrrr",
	"oooooooor",
	".ooooooo.",
	"..ooooo..",
]
const DRG_TAIL := [
	".rrrrr.",
	"rrrRrrr",
	"rrrrrrr",
	"ooooooo",
	".ooooo.",
]
const DRG_TIP := [
	"....rr...",
	"..rrrrr..",
	"rrrrrrrrr",
	"..rrrrr..",
	"....rr...",
]
const DRG_LEG := [
	"rrrrrr..",
	"rrrRrrr.",
	"rrrrrrr.",
	".rrrrr..",
	".rrRrr..",
	".rrrrr..",
	"..rrrr..",
	"..rrrr..",
	"..rrrrr.",
	".rrrrrrr",
	"nRnRnRnR",
]
const BEAST_REMAP := {"r": "g", "R": "G", "o": "l", "O": "g", "y": "r"}

const SKY := ["2e4a7a", "3a5e92", "4a74a8", "6a8cb8", "8aa4c0", "aebcc4", "d4ccb4", "e8c89a"]
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

var tex := {}
var sky: Texture2D
var road: Texture2D


func _ready() -> void:
	var src := {
		"hero_head": HERO_HEAD, "hero_torso": HERO_TORSO, "hero_arm": HERO_ARM,
		"hero_leg": HERO_LEG, "hammer": HAMMER,
		"gob_head": GOB_HEAD, "gob_torso": GOB_TORSO, "gob_arm": GOB_ARM,
		"gob_leg": GOB_LEG, "club": CLUB,
		"skel_head": SKEL_HEAD, "skel_torso": SKEL_TORSO, "skel_arm": SKEL_ARM,
		"skel_leg": SKEL_LEG, "spear": SPEAR,
		"ogre_head": OGRE_HEAD, "ogre_torso": OGRE_TORSO, "ogre_arm": OGRE_ARM,
		"ogre_leg": OGRE_LEG, "tree_club": TREE_CLUB,
		"meat": MEAT, "rune": RUNE, "barrel": BARREL,
	}
	for key in src:
		tex[key] = make(src[key])
	var drg := {"body": DRG_BODY, "head": DRG_HEAD, "jaw": DRG_JAW, "neck": DRG_NECK,
		"tail": DRG_TAIL, "tip": DRG_TIP, "leg": DRG_LEG}
	for key in drg:
		tex["drg_" + key] = make(drg[key])
		tex["beast_" + key] = make(drg[key], true, BEAST_REMAP)
	sky = _make_sky(480, 300)
	road = _make_road(64, 132)


func t(key: String) -> Texture2D:
	return tex[key]


## Převede pole řetězců na texturu s 1px tmavým obrysem.
func make(rows: Array, outline: bool = true, remap: Dictionary = {}) -> Texture2D:
	var pad := 1 if outline else 0
	var h: int = rows.size()
	var w: int = 1
	for r in rows:
		w = maxi(w, (r as String).length())
	var img := Image.create_empty(w + pad * 2, h + pad * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var line: String = rows[y]
		for x in line.length():
			var c: String = line[x]
			if remap.has(c):
				c = remap[c]
			if PAL.has(c):
				img.set_pixel(x + pad, y + pad, PAL[c])
	if outline:
		var src_img := img.duplicate() as Image
		var iw := img.get_width()
		var ih := img.get_height()
		for y in ih:
			for x in iw:
				if src_img.get_pixel(x, y).a > 0.0:
					continue
				var near := false
				for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + o.x
					var ny: int = y + o.y
					if nx >= 0 and ny >= 0 and nx < iw and ny < ih and src_img.get_pixel(nx, ny).a > 0.0:
						near = true
						break
				if near:
					img.set_pixel(x, y, OUTLINE)
	return ImageTexture.create_from_image(img)


func _make_sky(w: int, h: int) -> Texture2D:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var cols: Array[Color] = []
	for c in SKY:
		cols.append(Color(c))
	var n := cols.size()
	for y in h:
		var f := clampf(float(y) / (h * 0.6), 0.0, 1.0) * (n - 1)
		var i := mini(int(f), n - 2)
		var frac := f - i
		for x in w:
			var th: float = (BAYER[y % 4][x % 4] + 0.5) / 16.0
			img.set_pixel(x, y, cols[i + 1] if frac > th else cols[i])
	return ImageTexture.create_from_image(img)


## Dlaždice cesty (opakuje se vodorovně): tráva nahoře, pak hliněná cesta s kameny.
func _make_road(w: int, h: int) -> Texture2D:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var grass := [Color("3e7a32"), Color("4e8a3a"), Color("5a9a44")]
	var dirt := [Color("8a6038"), Color("7a5430"), Color("9a6c40"), Color("6e4a2a")]
	for y in h:
		for x in w:
			var c: Color
			var edge := 14 + int(3.0 * sin(x * 0.4) + 2.0 * sin(x * 1.3))
			if y < edge:
				c = grass[rng.randi_range(0, 2)]
				if y < 2:
					c = Color("6aaa4e")
			else:
				var depth := float(y - edge) / float(h - edge)
				c = dirt[rng.randi_range(0, 3)]
				c = c.darkened(depth * 0.25)
				# Koleje od vozů
				if absi(y - 60) <= 1 or absi(y - 96) <= 1:
					c = c.darkened(0.18)
			img.set_pixel(x, y, c)
	# Kamínky
	for i in 14:
		var sx := rng.randi_range(1, w - 4)
		var sy := rng.randi_range(22, h - 4)
		img.set_pixel(sx, sy, Color("b8b0a0"))
		img.set_pixel(sx + 1, sy, Color("a49c8c"))
		img.set_pixel(sx, sy + 1, Color("6a6058"))
		img.set_pixel(sx + 1, sy + 1, Color("5a5048"))
	return ImageTexture.create_from_image(img)
