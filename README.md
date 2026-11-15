# Kladivo: Kovářova pomsta

Vlastní fantasy **beat 'em up** v Godotu 4 (žánr klasických bojovek „jdi doprava a mlať“),
dělaný pro **Lenovo Legion Go S / SteamOS**. Kovář Mirek s kladivem čistí lesní stezku
od goblinů a kostlivců a na konci se postaví zlobrovi.

Hlavní důraz je na **okamžitou odezvu ovládání**:

- vstup se čte na začátku snímku a použije se hned (60 snímků/s, pevný krok),
- **input buffer 8 snímků** – stisk těsně před koncem úderu se nikdy neztratí,
- **cancel okna** – kombo, úskok i skok jdou navázat ještě během dokončování úderu,
- **hitstop** a otřes obrazu – zásahy jsou „cítit“,
- nepřátelé mají čitelný nápřah a útočí nanejvýš dva najednou.

## Stažení a instalace

[Releases → nejnovější verze](https://github.com/zarybjir/golden_axe/releases/latest) → `Kladivo-linux.zip`.
Instalace na Legion Go S je stejná jako u Uga: Desktop mód → stáhnout a rozbalit →
Steam → *Přidat hru, která není ze Steamu* → vybrat `Kladivo.x86_64`.

## Ovládání

| Akce | Gamepad | Klávesnice |
|---|---|---|
| Pohyb | levá páčka / D-pad | WASD / šipky |
| Úder (kombo) | X | J |
| Skok | A | K / mezerník |
| Úskok | B | L / Shift |
| Runová magie | Y | I |
| Pauza | Start | Esc |

## Pro vývoj

- Postavy jsou „panáčci“ z dílů (`scripts/art.gd`), animují se pózami a časovými osami v `scripts/poses.gd`.
- Vlny nepřátel a sudy jsou v `scripts/stage.gd`, typy nepřátel v `scripts/enemy.gd`.
- CI spustí automatický test (`-- --smoke`), pořídí screenshoty (`-- --shots=...`) a vydá Linux build.
