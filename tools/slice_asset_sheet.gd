extends SceneTree
## Découpe une planche d'assets en images séparées (PHASE 8 / mission A).
##
##     godot --headless --path . --script res://tools/slice_asset_sheet.gd
##     godot --headless --path . --script res://tools/slice_asset_sheet.gd -- \
##         --source=res://assets/ui/source/planche_assets.webp \
##         --out=res://assets/ui/sliced --min-area=400 --padding=4
##
## La planche est supposée posée sur un fond uni (ici le magenta de la planche
## générée). Le fond est retiré par **remplissage depuis les bords** : un motif
## magenta *à l'intérieur* d'un dessin (drapé, bijou) est donc conservé.
##
## Chaque objet détecté donne un PNG détouré (`asset_01.png`, …) et une entrée
## dans `manifest.json` (fichier, boîte d'origine, taille). L'ordre de nommage
## suit la lecture : de haut en bas, puis de gauche à droite.
##
## Options :
##   --source=PATH     planche à découper (défaut : la planche du projet)
##   --out=DIR         dossier des PNG (défaut : res://assets/ui/sliced)
##   --prefix=NAME     préfixe des fichiers (défaut : asset)
##   --min-area=N      aire minimale d'un objet en pixels (défaut : 400)
##   --padding=N       marge gardée autour de l'objet (défaut : 4)
##   --tolerance=F     écart de couleur admis pour le fond (défaut : 0,12)
##   --keep-background garde le fond uni au lieu de le rendre transparent
##   --gallery=PATH    écrit une planche-contact HTML (pour nommer les pièces)
##   --names=PATH      fichier de noms « 12=reine_dahomey » (un par ligne)
##   --clean           vide le dossier de sortie (PNG et manifeste) avant
##                     d'écrire, pour ne pas garder les anciens noms
##   --dry-run         analyse seulement : rien n'est écrit
##
## Fichier de noms : une ligne par pièce, `numéro=nom` (ou `numéro nom`), les
## lignes vides et celles commençant par # sont ignorées. Les pièces sans nom
## gardent `asset_NN`. Les accents et espaces deviennent `_` : un nom de
## fichier Godot ne doit contenir ni accent ni espace.

const DEFAULT_SOURCE := "res://assets/ui/source/planche_assets.webp"
const DEFAULT_OUT := "res://assets/ui/sliced"
const DEFAULT_PREFIX := "asset"
const DEFAULT_MIN_AREA := 400
const DEFAULT_PADDING := 4
const DEFAULT_TOLERANCE := 0.12
## Au-delà, un pixel de bord est considéré comme un reste de fond (halo).
const HALO_DISTANCE := 0.45

var source_path := DEFAULT_SOURCE
var out_dir := DEFAULT_OUT
var prefix := DEFAULT_PREFIX
var min_area := DEFAULT_MIN_AREA
var padding := DEFAULT_PADDING
var tolerance := DEFAULT_TOLERANCE
var keep_background := false
var gallery_path := ""
var names_path := ""
var clean := false
var dry_run := false
var _names: Dictionary = {}          ## { index (1-based): nom de fichier }


func _init() -> void:
	_parse_args()
	var image := _load_image(source_path)
	if image == null:
		push_error("Planche introuvable ou illisible : %s" % source_path)
		quit(1)
		return
	var background := image.get_pixel(0, 0)
	print("Planche : %s (%d×%d), fond %s" % [
		source_path, image.get_width(), image.get_height(), background])
	var mask := _background_mask(image, background)
	var regions := _regions(mask, image.get_width(), image.get_height())
	print("Objets détectés : %d (aire ≥ %d px²)" % [regions.size(), min_area])
	if regions.is_empty():
		push_warning("Aucun objet : vérifier --tolerance ou --min-area.")
		quit(0)
		return
	if not dry_run:
		DirAccess.make_dir_recursive_absolute(out_dir)
		if clean:
			_clean_output()
		elif not names_path.is_empty() and not _existing_pngs().is_empty():
			push_warning("Le dossier %s contient déjà des PNG : utiliser --clean pour éviter les doublons." % out_dir)
	if not names_path.is_empty():
		_read_names(regions.size())
	var manifest: Array[Dictionary] = []
	for index in regions.size():
		var region: Rect2i = regions[index]
		var name: String = _names.get(index + 1, "%s_%02d" % [prefix, index + 1])
		var tile := _cut(image, mask, region, background)
		var relative := "%s/%s.png" % [out_dir.trim_suffix("/"), name]
		if not dry_run:
			var error := tile.save_png(relative)
			if error != OK:
				push_error("Écriture impossible : %s (erreur %d)" % [relative, error])
				continue
		manifest.append({
			"file": relative.get_file(),
			"rect": {"x": region.position.x, "y": region.position.y,
				"w": region.size.x, "h": region.size.y},
		})
		print("  %s  %d×%d  (x=%d, y=%d)" % [
			name, region.size.x, region.size.y, region.position.x, region.position.y])
	if not dry_run:
		_write_manifest(manifest)
		print("Écrit : %d PNG + manifest.json dans %s" % [manifest.size(), out_dir])
		if not gallery_path.is_empty():
			_write_gallery(manifest)
	quit(0)


# -----------------------------------------------------------------#
#                          ARGUMENTS                                #
# -----------------------------------------------------------------#

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		var key := parts[0]
		var value := parts[1] if parts.size() > 1 else ""
		match key:
			"--source":
				source_path = value
			"--out":
				out_dir = value
			"--prefix":
				prefix = value
			"--min-area":
				min_area = maxi(value.to_int(), 1)
			"--padding":
				padding = maxi(value.to_int(), 0)
			"--tolerance":
				tolerance = clampf(value.to_float(), 0.01, 1.0)
			"--keep-background":
				keep_background = true
			"--gallery":
				gallery_path = value
			"--names":
				names_path = value
			"--clean":
				clean = true
			"--dry-run":
				dry_run = true
			_:
				if key.begins_with("--"):
					push_warning("Option inconnue : %s" % key)


# -----------------------------------------------------------------#
#                     SORTIE (NETTOYAGE)                            #
# -----------------------------------------------------------------#

func _existing_pngs() -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(out_dir)
	if dir == null:
		return found
	for file in dir.get_files():
		if file.ends_with(".png"):
			found.append(file)
	return found


## Ne supprime que ce que l'outil produit : PNG et manifeste.
func _clean_output() -> void:
	var dir := DirAccess.open(out_dir)
	if dir == null:
		return
	var removed := 0
	for file in dir.get_files():
		# Les .import sont recréés par Godot : les laisser ferait des restes.
		if file.ends_with(".png") or file.ends_with(".png.import") or file == "manifest.json":
			if dir.remove(file) == OK:
				removed += 1
	print("Nettoyage : %d fichier(s) retiré(s) de %s" % [removed, out_dir])


# -----------------------------------------------------------------#
#                       NOMS DES PIÈCES                            #
# -----------------------------------------------------------------#

## Lit le fichier de noms et remplit `_names`. Les numéros hors planche et les
## doublons sont signalés : un nom perdu serait une pièce mal nommée.
func _read_names(count: int) -> void:
	_names.clear()
	var file := FileAccess.open(names_path, FileAccess.READ)
	if file == null:
		push_error("Fichier de noms introuvable : %s" % names_path)
		return
	var used: Dictionary = {}
	var line_number := 0
	while not file.eof_reached():
		line_number += 1
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var separator := line.find("=")
		if separator < 0:
			separator = line.find(" ")
		if separator < 0:
			push_warning("Ligne %d ignorée (attendu « numéro=nom ») : %s" % [line_number, line])
			continue
		var index := line.substr(0, separator).strip_edges().to_int()
		var raw := line.substr(separator + 1).strip_edges()
		if index < 1 or index > count:
			push_warning("Ligne %d : numéro %d hors planche (1..%d)" % [line_number, index, count])
			continue
		if raw.is_empty():
			# Gabarit non rempli : la pièce garde son nom numéroté.
			continue
		var name := _file_name(raw)
		if name.is_empty():
			push_warning("Ligne %d : nom invalide, ignorée" % line_number)
			continue
		if used.has(name):
			var base := name
			var suffix := 2
			while used.has("%s_%d" % [base, suffix]):
				suffix += 1
			name = "%s_%d" % [base, suffix]
			push_warning("Ligne %d : « %s » déjà pris, renommé en « %s »" % [line_number, raw, name])
		used[name] = true
		_names[index] = name
	file.close()
	print("Noms lus : %d / %d" % [_names.size(), count])


## Nom de fichier sûr : minuscules, sans accent, sans espace.
func _file_name(raw: String) -> String:
	var name := raw.strip_edges().to_lower()
	name = name.replace(" ", "_")
	var out := ""
	for i in name.length():
		var c := name[i]
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_":
			out += c
		elif c == "-":
			out += "_"
		# Lettres accentuées : on les remplace par leur équivalent simple.
		else:
			var folded := c.unicode_at(0)
			var map := {
				0xE0: "a", 0xE2: "a", 0xE4: "a", 0xE7: "c", 0xE8: "e", 0xE9: "e",
				0xEA: "e", 0xEB: "e", 0xEE: "i", 0xEF: "i", 0xF4: "o", 0xF6: "o",
				0xF9: "u", 0xFB: "u", 0xFC: "u", 0x101: "a", 0x119: "e",
				0x12B: "e", 0x14D: "o", 0x16B: "u", 0x1D2: "o", 0x1D3: "o",
				0x1D4: "o", 0x1D6: "o", 0x1D8: "o", 0x1DA: "o", 0x1DC: "o",
			}
			if map.has(folded):
				out += map[folded]
			elif c != "_":
				out += "_"
	# Pas de « __ » ni de « _ » en début/fin.
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.trim_prefix("_").trim_suffix("_")


func _load_image(path: String) -> Image:
	var image: Image = null
	if path.begins_with("res://") or path.begins_with("user://"):
		image = Image.load_from_file(ProjectSettings.globalize_path(path))
	else:
		image = Image.load_from_file(path)
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


# -----------------------------------------------------------------#
#                        FOND ET DÉTOURAGE                          #
# -----------------------------------------------------------------#

## Vrai si la couleur est « le fond » à la tolérance près.
func _is_background(color: Color, background: Color) -> bool:
	return absf(color.r - background.r) + absf(color.g - background.g) \
		+ absf(color.b - background.b) <= tolerance * 3.0


## Remplissage depuis les quatre bords : tout le fond extérieur est marqué 1.
## Ce qui est enfermé dans un dessin reste à 0, même si la couleur est proche.
func _background_mask(image: Image, background: Color) -> PackedByteArray:
	var width := image.get_width()
	var height := image.get_height()
	var mask := PackedByteArray()
	mask.resize(width * height)
	var stack: Array[int] = []
	for x in width:
		for y: int in [0, height - 1]:
			var index := y * width + x
			if mask[index] == 0 and _is_background(image.get_pixel(x, y), background):
				mask[index] = 1
				stack.append(index)
	for y in height:
		for x: int in [0, width - 1]:
			var index := y * width + x
			if mask[index] == 0 and _is_background(image.get_pixel(x, y), background):
				mask[index] = 1
				stack.append(index)
	while not stack.is_empty():
		var index: int = stack.pop_back()
		var px := index % width
		var py := index / width
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := px + offset.x
			var ny := py + offset.y
			if nx < 0 or ny < 0 or nx >= width or ny >= height:
				continue
			var neighbour := ny * width + nx
			if mask[neighbour] == 0 and _is_background(image.get_pixel(nx, ny), background):
				mask[neighbour] = 1
				stack.append(neighbour)
	return mask


# -----------------------------------------------------------------#
#                       OBJETS (CONNEXITÉ)                          #
# -----------------------------------------------------------------#

## Composantes connexes du premier plan, triées en ordre de lecture.
func _regions(mask: PackedByteArray, width: int, height: int) -> Array[Rect2i]:
	var labels := PackedByteArray()
	labels.resize(width * height)
	labels.fill(0)
	var regions: Array[Rect2i] = []
	var stack: Array[int] = []
	for y in height:
		for x in width:
			var start := y * width + x
			if mask[start] != 0 or labels[start] != 0:
				continue
			var min_x := x
			var max_x := x
			var min_y := y
			var max_y := y
			var area := 0
			stack.clear()
			stack.append(start)
			labels[start] = 1
			while not stack.is_empty():
				var index: int = stack.pop_back()
				var px := index % width
				var py := index / width
				area += 1
				min_x = mini(min_x, px)
				max_x = maxi(max_x, px)
				min_y = mini(min_y, py)
				max_y = maxi(max_y, py)
				for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0),
						Vector2i(0, 1), Vector2i(0, -1)]:
					var nx := px + offset.x
					var ny := py + offset.y
					if nx < 0 or ny < 0 or nx >= width or ny >= height:
						continue
					var neighbour := ny * width + nx
					if mask[neighbour] == 0 and labels[neighbour] == 0:
						labels[neighbour] = 1
						stack.append(neighbour)
			if area >= min_area:
				regions.append(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))
	# Ordre de lecture : par bandes de la hauteur d'un objet moyen, puis par x.
	regions.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		var band := 48
		var row_a := int(floor(float(a.position.y + a.size.y * 0.5) / band))
		var row_b := int(floor(float(b.position.y + b.size.y * 0.5) / band))
		if row_a != row_b:
			return row_a < row_b
		return a.position.x < b.position.x)
	return regions


## Découpe un objet, avec marge, et retire le fond (sauf --keep-background).
func _cut(image: Image, mask: PackedByteArray, region: Rect2i, background: Color) -> Image:
	var source_width := image.get_width()
	var source_height := image.get_height()
	var rect := Rect2i(
		maxi(region.position.x - padding, 0),
		maxi(region.position.y - padding, 0),
		0, 0)
	rect.size.x = mini(region.end.x + padding, source_width) - rect.position.x
	rect.size.y = mini(region.end.y + padding, source_height) - rect.position.y
	var tile := image.get_region(rect)
	if keep_background:
		return tile
	for y in tile.get_height():
		for x in tile.get_width():
			var sx := rect.position.x + x
			var sy := rect.position.y + y
			if mask[sy * source_width + sx] != 0:
				tile.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			_clean_halo(tile, x, y, background)
	return tile


## Sur le bord d'un objet, un pixel encore teinté par le fond devient
## progressivement transparent : plus de liseré magenta sur les contours.
func _clean_halo(tile: Image, x: int, y: int, background: Color) -> void:
	var color := tile.get_pixel(x, y)
	var distance := absf(color.r - background.r) + absf(color.g - background.g) \
		+ absf(color.b - background.b)
	if distance >= HALO_DISTANCE:
		return
	# Dépollution : on ramène la teinte vers le vert du pixel, puis on fond.
	color.r = minf(color.r, color.g + distance * 0.5)
	color.b = minf(color.b, color.g + distance * 0.5)
	color.a *= clampf(distance / HALO_DISTANCE, 0.0, 1.0)
	tile.set_pixel(x, y, color)


# -----------------------------------------------------------------#
#                          MANIFESTE                                #
# -----------------------------------------------------------------#

## Planche-contact HTML : chaque vignette est numérotée comme son fichier,
## pour nommer les pièces sans ouvrir 57 images une par une.
func _write_gallery(entries: Array[Dictionary]) -> void:
	# La galerie n'est pas forcément dans le dossier des images : on calcule
	# un chemin relatif pour que les <img> s'affichent où qu'elle soit.
	var folder := _relative_dir(gallery_path.get_base_dir(), out_dir)
	var html := "<!doctype html><meta charset=\"utf-8\">\n<title>Planche découpée</title>\n"
	html += "<style>body{background:#1a1613;color:#e8dcc8;font:14px sans-serif;"
	html += "margin:24px}h1{font-size:18px}div{display:flex;flex-wrap:wrap;gap:12px}"
	html += "figure{margin:0;background:#2a241f;padding:8px;border-radius:6px;"
	html += "text-align:center}img{display:block;max-width:220px;max-height:220px;"
	html += "background:repeating-conic-gradient(#3a322b 0 25%,#2a241f 0 50%) 0 0/16px 16px}"
	html += "figcaption{margin-top:6px;font-size:12px;color:#c8a24a}</style>\n"
	html += "<h1>%d pièces — %s</h1>\n<div>\n" % [entries.size(), source_path.get_file()]
	for entry in entries:
		var file_name := String(entry["file"])
		html += "<figure><img src=\"%s/%s\" alt=\"%s\"><figcaption>%s</figcaption></figure>\n" % [
			folder, file_name, file_name, file_name.get_basename()]
	html += "</div>\n"
	var file := FileAccess.open(gallery_path, FileAccess.WRITE)
	if file == null:
		push_error("Galerie : écriture impossible (%s)" % gallery_path)
		return
	file.store_string(html)
	file.close()
	print("Galerie : %s" % gallery_path)


## Chemin relatif de `to_dir` vu depuis `from_dir` (les deux en res://).
func _relative_dir(from_dir: String, to_dir: String) -> String:
	var from_parts := from_dir.trim_prefix("res://").split("/", false)
	var to_parts := to_dir.trim_prefix("res://").trim_suffix("/").split("/", false)
	var common := 0
	while common < from_parts.size() and common < to_parts.size() \
			and from_parts[common] == to_parts[common]:
		common += 1
	var parts: Array[String] = []
	for _i in from_parts.size() - common:
		parts.append("..")
	for i in range(common, to_parts.size()):
		parts.append(to_parts[i])
	return "." if parts.is_empty() else "/".join(parts)


func _write_manifest(entries: Array[Dictionary]) -> void:
	var payload := {
		"source": source_path,
		"count": entries.size(),
		"assets": entries,
	}
	var file := FileAccess.open(out_dir.trim_suffix("/") + "/manifest.json", FileAccess.WRITE)
	if file == null:
		push_error("manifest.json : écriture impossible")
		return
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
