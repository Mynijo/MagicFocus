extends SceneTree
## Bereitet die generierten Bilder fürs Spiel auf: schneidet den leeren Rand ab
## (zentriert, damit die Bildmitte die Objektmitte bleibt) und verkleinert sie.
## Originale in assets/<ordner>/ bleiben unverändert, Ergebnisse landen in assets/sprites/.
##   godot --headless --path . -s res://tools/prepare_assets.gd
## Danach einmal importieren:  godot --headless --path . --import

const OUT_DIR := "res://assets/sprites/"

## [Quelle, Ziel, Kantenlänge in px]
const JOBS := [
	["res://assets/gems/gem_haupt_grob.png", "gem_haupt_grob.png", 256],
	["res://assets/gems/gem_haupt_spitz.png", "gem_haupt_spitz.png", 256],
	["res://assets/gems/gem_neben_grob.png", "gem_neben_grob.png", 256],
	["res://assets/gems/gem_neben_spitz.png", "gem_neben_spitz.png", 256],
	["res://assets/essences/essenz_neutral.png", "essenz_neutral.png", 64],
	["res://assets/essences/essenz_element.png", "essenz_element.png", 64],
	["res://assets/essences/essenz_fire.png", "essenz_fire.png", 64],
	["res://assets/essences/essenz_water.png", "essenz_water.png", 64],
	["res://assets/essences/essenz_earth.png", "essenz_earth.png", 64],
	["res://assets/essences/essenz_air.png", "essenz_air.png", 64],
	["res://assets/essences/essenz_lightning.png", "essenz_lightning.png", 64],
]

## Pixel mit weniger Deckkraft zählen nicht zum Objekt (z. B. schwacher Schein).
const ALPHA_THRESHOLD := 0.15
## Für die Randsuche wird das Bild verkleinert (schneller als jeden Pixel zu prüfen).
const SCAN_SIZE := 314
const MARGIN := 0.04


## Gravur-Symbole: alle PNGs in diesem Ordner (Dateiname = Gravur-ID, z. B. feuerball.png)
## werden zu sprites/engraving_<id>.png.
const ENGRAVING_DIR := "res://assets/engravings/"
const ENGRAVING_SIZE := 128
const ELEMENT_DIR := "res://assets/elements/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var jobs := JOBS.duplicate()
	if DirAccess.dir_exists_absolute(ENGRAVING_DIR):
		for file in DirAccess.get_files_at(ENGRAVING_DIR):
			if file.ends_with(".png"):
				jobs.append([ENGRAVING_DIR + file, "engraving_" + file, ENGRAVING_SIZE])
	# Element-Symbole (element_<id>.png, element_neutral.png) für Tooltips und Oberfläche
	if DirAccess.dir_exists_absolute(ELEMENT_DIR):
		for file in DirAccess.get_files_at(ELEMENT_DIR):
			if file.ends_with(".png"):
				jobs.append([ELEMENT_DIR + file, file, ENGRAVING_SIZE])
	for job: Array in jobs:
		var image := Image.load_from_file(ProjectSettings.globalize_path(job[0]))
		if image == null:
			push_error("Nicht gefunden: %s" % job[0])
			continue
		image.convert(Image.FORMAT_RGBA8)
		var half := _half_extent(image)
		var center := Vector2i(image.get_width() / 2, image.get_height() / 2)
		var cropped := image.get_region(Rect2i(center - Vector2i(half, half), Vector2i(half * 2, half * 2)))
		cropped.resize(job[2], job[2], Image.INTERPOLATE_LANCZOS)
		var path: String = OUT_DIR + job[1]
		cropped.save_png(ProjectSettings.globalize_path(path))
		print("%s -> %s (Ausschnitt %d px)" % [job[0], path, half * 2])
	quit()


## Halbe Kantenlänge eines um die Bildmitte zentrierten Quadrats, das das Objekt enthält.
func _half_extent(image: Image) -> int:
	var small := image.duplicate() as Image
	small.resize(SCAN_SIZE, SCAN_SIZE, Image.INTERPOLATE_BILINEAR)
	var c := SCAN_SIZE / 2.0
	var extent := 0.0
	for y in SCAN_SIZE:
		for x in SCAN_SIZE:
			if small.get_pixel(x, y).a >= ALPHA_THRESHOLD:
				extent = maxf(extent, maxf(absf(x + 0.5 - c), absf(y + 0.5 - c)))
	var scale := float(image.get_width()) / SCAN_SIZE
	var half := int(ceil(extent * scale * (1.0 + MARGIN)))
	return clampi(half, 8, mini(image.get_width(), image.get_height()) / 2)
