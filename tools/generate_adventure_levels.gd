extends SceneTree
## Générateur de la CAMPAGNE (DESIGN.md § 12.1 et PHASE 5) : 5 chapitres ×
## 5 niveaux = 25 fiches `data/levels/adventure/chN_lM.tres`.
##
## Lancer :
##   godot --headless --path . --script res://tools/generate_adventure_levels.gd
##
## Progression voulue (§ 13) : une nouveauté à la fois. Le chapitre 1
## n'apprend que les soldats ; les éclaireurs arrivent au chapitre 2, les
## archers et les gardes au 3, les brutes et la nuit au 4 ; le chapitre 5 se
## termine par le gardien du palais (objectif « boss », squelette PHASE 6).
## Le 5e niveau de chaque chapitre est une arène.

const LEVEL_SCRIPT := preload("res://data/resources/LevelData.gd")
const WAVE_SCRIPT := preload("res://data/resources/WaveData.gd")
const ENTRY_SCRIPT := preload("res://data/resources/SpawnEntry.gd")

const LEVEL_DIR: String = "res://data/levels/adventure"

## § 10 : un boss par chapitre, au 5e niveau (ARENA). L'ordre suit le dossier.
const BOSSES: Array[String] = ["captain", "river_archer", "colossus",
	"shadow_sorcerer", "rival_general"]

## Chapitres : titre, pièges, nuit.
const CHAPTERS: Array = [
	["Les collines d'Abomey", [], false],
	["La route du sel", ["pit", "arrows"], false],
	["La forêt sacrée", ["pit", "arrows", "fire"], false],
	["Les remparts de nuit", ["pit", "arrows", "fire", "spikes"], true],
	["Le palais du roi", ["pit", "arrows", "fire", "spikes", "mud"], true],
]

## Noms des cinq niveaux de chaque chapitre.
const NAMES: Array = [
	["La piste rouge", "Le marché aux cauris", "Le bois des tambours",
		"La porte de terre", "L'arène des anciens"],
	["Les marais salants", "Le gué de la rivière", "Les dunes blanches",
		"Le relais des porteurs", "Le cercle de sable"],
	["La lisière", "Les fromagers", "Le sanctuaire",
		"La clairière des masques", "L'autel de la forêt"],
	["La veillée", "La poterne", "Les fossés", "Le bastion", "La cour de nuit"],
	["L'escalier du palais", "La galerie des ancêtres", "La salle du trône",
		"Le parvis", "Le gardien du palais"],
]

var written: int = 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(LEVEL_DIR)
	for chapter in range(1, CHAPTERS.size() + 1):
		for number in range(1, 6):
			_write_level(chapter, number)
	print("[generate_adventure_levels] %d niveaux écrits dans %s" % [written, LEVEL_DIR])
	quit()


func _write_level(chapter: int, number: int) -> void:
	var chapter_info: Array = CHAPTERS[chapter - 1]
	var title := String(chapter_info[0])
	var hazards: Array = chapter_info[1]
	var night := bool(chapter_info[2])
	var arena := number == 5
	var objective := "clear"
	if arena:
		# § 10 : le 5e niveau de CHAQUE chapitre est une arène de boss.
		objective = "boss"
	elif number == 2:
		objective = "exit"
	var time_limit := 130 - chapter * 4 - number * 2
	if arena:
		time_limit += 25
	if objective == "boss":
		time_limit = 150
	var length := 70.0 + float(chapter) * 8.0 + float(number) * 6.0
	_level({
		"id": "ch%d_l%d" % [chapter, number],
		"chapter": chapter,
		"number": number,
		"display_name": String(NAMES[chapter - 1][number - 1]),
		"layout": "arena" if arena else "lane",
		"length_m": length,
		"arena_radius": 14.0,
		"objective": objective,
		"boss_id": BOSSES[chapter - 1] if arena else "",
		"time_limit": time_limit,
		"night": night,
		"hazards": [] if objective == "boss" else hazards,
		"hazards_per_kind": 1 + chapter / 2,
		"cauri_pickups": 4 + number + chapter,
		"cauri_per_pickup": 3,
		"potion_pickups": 2 if chapter >= 4 else 1,
		"checkpoint_at": 0.0 if arena else 0.5,
		"reward_cauris": 25 + chapter * 8 + number * 4,
		"star_time_silver": int(float(time_limit) * 0.55),
		"star_time_gold": int(float(time_limit) * 0.35),
		"music_layer_set": "palace" if chapter >= 4 else "village",
		"waves": _waves_for(chapter, number),
	})
	# `title` documente le chapitre dans le print de progression.
	print("  %s — %s" % [title, String(NAMES[chapter - 1][number - 1])])


## Vagues du § 13 : la difficulté monte par paliers lisibles.
func _waves_for(chapter: int, number: int) -> Array:
	var waves: Array = []
	var soldiers := mini(2 + chapter + number / 2, 5)
	waves.append(_floor([["soldier", soldiers]], 1.3))
	if chapter >= 2:
		waves.append(_floor([["soldier", soldiers], ["scout", mini(1 + number / 2, 3)]], 1.2))
	if chapter >= 3:
		waves.append(_floor([["archer", 1 + chapter / 3], ["soldier", soldiers]], 1.2))
	if chapter >= 4:
		waves.append(_floor([["guard", 1 + chapter / 4], ["scout", 2]], 1.15))
	if chapter >= 5:
		waves.append(_floor([["brute", 1], ["soldier", 3], ["archer", 1]], 1.1))
	if number == 5:
		# Arène de boss : une vague d'escorte, le gardien arrive avec elle.
		waves.append(_floor([["soldier", 3], ["scout", 2]], 1.1))
	return waves


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
		# Les tableaux TYPÉS se construisent explicitement (cf. Sauvetage).
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
		printerr("[generate_adventure_levels] échec d'écriture %s (erreur %d)" % [path, error])
		return
	written += 1
