extends SceneTree
## Générateur du mode SAUVETAGE (DESIGN.md § 12.2, PHASE 4) : écrit les 12
## premiers niveaux de `data/levels/rescue/`, les 5 niveaux de NUIT (13-17) et un
## niveau d'ESCORTE, sous forme de Resources.
##
## Lancer :
##   godot --headless --path . --script res://tools/generate_rescue_levels.gd
##
## Table du § 12.2 :
##   1-3   : 1 prisonnier, 3-4 soldats, aucun piège, 150 s
##   4-7   : 2-3 prisonniers, + éclaireurs en patrouille, fosses + flèches, 130 s
##   8-12  : 3-4 prisonniers dispersés, + archers et gardes d'alerte, + feu, 110 s
##   13-17 : 4 prisonniers, + brutes, tous les pièges, 100 s, NUIT
##   18+   : chefs et boss gardien -> PHASE 6
##
## Les .tres obtenus sont du CONTENU : on les modifie à la main ou dans
## l'inspecteur, ce script n'est qu'un moyen pratique de les (re)créer.

const LEVEL_SCRIPT := preload("res://data/resources/LevelData.gd")
const WAVE_SCRIPT := preload("res://data/resources/WaveData.gd")
const ENTRY_SCRIPT := preload("res://data/resources/SpawnEntry.gd")

const LEVEL_DIR: String = "res://data/levels/rescue"

## Chaque ligne : id, nom, longueur, prisonniers, pièges, vagues, temps, nuit.
const LEVELS: Array = [
	["rescue_01", "Chaumières", 70.0, 1, [], 150, false],
	["rescue_02", "Sentier de latérite", 80.0, 1, [], 150, false],
	["rescue_03", "Porte du marché", 90.0, 1, [], 150, false],
	["rescue_04", "Puits empoisonné", 90.0, 2, ["pit"], 130, false],
	["rescue_05", "Rempart est", 100.0, 2, ["pit", "arrows"], 130, false],
	["rescue_06", "Grenier du chef", 100.0, 2, ["pit", "arrows"], 130, false],
	["rescue_07", "Ruelle des teinturiers", 110.0, 3, ["pit", "arrows"], 130, false],
	["rescue_08", "Camp de toile", 110.0, 3, ["pit", "fire"], 110, false],
	["rescue_09", "Place des tambours", 120.0, 3, ["arrows", "fire"], 110, false],
	["rescue_10", "Col des termitières", 120.0, 3, ["pit", "arrows", "fire"], 110, false],
	["rescue_11", "Bord du fleuve", 130.0, 4, ["pit", "arrows", "fire"], 110, false],
	["rescue_12", "Avant-poste", 130.0, 4, ["pit", "arrows", "fire"], 110, false],
	["rescue_13", "Nuit au fort", 120.0, 4, ["pit", "fire", "spikes"], 100, true],
	["rescue_14", "Nuit dans la brousse", 125.0, 4, ["arrows", "fire", "mud"], 100, true],
	["rescue_15", "Nuit au puits", 130.0, 4, ["pit", "arrows", "spikes"], 100, true],
	["rescue_16", "Nuit sur le rempart", 135.0, 4, ["arrows", "fire", "spikes"], 100, true],
	["rescue_17", "Nuit au camp", 140.0, 4, ["pit", "arrows", "fire", "spikes"], 100, true],
]

var written: int = 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(LEVEL_DIR)
	for row in LEVELS:
		_write_rescue(row)
	_write_escort()
	print("[generate_rescue_levels] %d niveaux écrits dans %s" % [written, LEVEL_DIR])
	quit()


func _write_rescue(row: Array) -> void:
	var id := String(row[0])
	var number := int(id.get_slice("_", 1))
	var name := String(row[1])
	var length := float(row[2])
	var prisoners := int(row[3])
	var hazards: Array = row[4]
	var time_limit := int(row[5])
	var night := bool(row[6])
	_level({
		"id": id, "number": number, "display_name": name,
		"chapter": 1 + (number - 1) / 5,
		"layout": "lane", "length_m": length, "objective": "rescue",
		"time_limit": time_limit, "night": night,
		"prisoners": prisoners, "hazards": hazards, "hazards_per_kind": 2,
		"cauri_pickups": 6 + number / 2, "potion_pickups": 1,
		"checkpoint_at": 0.5,
		"reward_cauris": 40 + number * 4,
		"star_time_silver": time_limit / 2, "star_time_gold": time_limit / 3,
		"waves": _waves_for(number),
	})


## Vagues du § 9 : une nouveauté à la fois (§ 13, courbe de difficulté).
func _waves_for(number: int) -> Array:
	var waves: Array = []
	if number <= 3:
		waves.append(_floor([["soldier", 3]], 1.3))
		if number == 3:
			waves.append(_floor([["soldier", 3], ["scout", 1]], 1.2))
		return waves
	if number <= 7:
		waves.append(_floor([["soldier", 3], ["scout", 1]], 1.3))
		waves.append(_floor([["soldier", 2], ["scout", 2]], 1.2))
		if number >= 6:
			waves.append(_floor([["archer", 1], ["soldier", 3]], 1.2))
		return waves
	if number <= 12:
		waves.append(_floor([["soldier", 3], ["guard", 1]], 1.2))
		waves.append(_floor([["archer", 2], ["soldier", 2]], 1.2))
		waves.append(_floor([["guard", 2], ["scout", 2]], 1.1))
		return waves
	waves.append(_floor([["brute", 1], ["soldier", 3]], 1.2))
	waves.append(_floor([["guard", 2], ["archer", 1]], 1.2))
	waves.append(_floor([["brute", 1], ["soldier", 2], ["scout", 1]], 1.1))
	return waves


## Niveau d'ESCORTE du § 12.2 : « villageois (40 vie) qui suit la joueuse ».
func _write_escort() -> void:
	# Chapitre 4 et numéro 18 : l'Escorte se range APRÈS les 17 Sauvetages,
	# comme la fin du mode dans la liste (le tri lit chapitre puis numéro).
	_level({
		"id": "escort_01", "chapter": 4, "number": 18, "display_name": "Convoi de sel",
		"layout": "lane", "length_m": 90.0, "objective": "escort",
		"time_limit": 130, "escorts": 2,
		"hazards": ["pit", "arrows"], "hazards_per_kind": 2,
		"cauri_pickups": 6, "potion_pickups": 2, "checkpoint_at": 0.5,
		"reward_cauris": 60, "star_time_silver": 60, "star_time_gold": 40,
		"waves": [
			_floor([["soldier", 3], ["scout", 1]], 1.3),
			_floor([["archer", 1], ["soldier", 3]], 1.2),
			_floor([["guard", 2], ["soldier", 2]], 1.1),
		],
	})


## Une vague : `groups` = [["soldier", 2], …], puis le délai entre apparitions.
func _floor(groups: Array, delay: float) -> Variant:
	var wave = WAVE_SCRIPT.new()
	var entries: Array[SpawnEntry] = []
	for group in groups:
		var entry = ENTRY_SCRIPT.new()
		entry.type = String(group[0])
		entry.count = int(group[1])
		entries.append(entry)
	wave.enemies = entries
	wave.delay = delay
	wave.start_delay = 0.5
	return wave


func _level(values: Dictionary) -> void:
	var data = LEVEL_SCRIPT.new()
	data.chapter = 1
	data.number = 1
	for key in values.keys():
		# Les tableaux TYPÉS se construisent explicitement : `set()` avec un
		# Array non typé laisserait `Array[String]` / `Array[WaveData]` vide.
		if key == "waves":
			var waves: Array[WaveData] = []
			for wave in values[key]:
				waves.append(wave)
			data.enemy_waves = waves
		elif key == "hazards":
			var kinds: Array[String] = []
			for kind in values[key]:
				kinds.append(String(kind))
			data.hazards = kinds
		else:
			data.set(key, values[key])
	_save(data, "%s/%s.tres" % [LEVEL_DIR, data.id])


func _save(resource: Resource, path: String) -> void:
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		printerr("[generate_rescue_levels] échec d'écriture %s (erreur %d)" % [path, error])
		return
	written += 1
	print("  écrit %s" % path)
