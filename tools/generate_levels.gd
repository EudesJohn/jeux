extends SceneTree
## Générateur du contenu de la PHASE 3 (DESIGN.md § 9, § 11, § 13) : écrit les
## 6 fiches d'ennemis de `data/enemies/` et les 5 niveaux de test de
## `data/levels/` (3 LANE + 2 ARENA) sous forme de Resources.
##
## Lancer :
##   godot --headless --path . --script res://tools/generate_levels.gd
##
## Les .tres obtenus sont du CONTENU : on les modifie à la main ou dans
## l'inspecteur, ce script n'est qu'un moyen pratique de les (re)créer.

const ENEMY_SCRIPT := preload("res://data/resources/EnemyData.gd")
const LEVEL_SCRIPT := preload("res://data/resources/LevelData.gd")
const WAVE_SCRIPT := preload("res://data/resources/WaveData.gd")
const ENTRY_SCRIPT := preload("res://data/resources/SpawnEntry.gd")

const ENEMY_DIR: String = "res://data/enemies"
const LEVEL_DIR: String = "res://data/levels"

var written: int = 0


func _initialize() -> void:
	_ensure_dirs()
	_write_enemies()
	_write_levels()
	print("[generate_levels] %d fichiers .tres écrits (6 ennemis, 5 niveaux)" % written)
	quit()


func _ensure_dirs() -> void:
	for path in [ENEMY_DIR, LEVEL_DIR]:
		DirAccess.make_dir_recursive_absolute(path)


# -----------------------------------------------------------------#
#                     FICHES D'ENNEMIS (§ 9)                       #
# -----------------------------------------------------------------#

func _write_enemies() -> void:
	# Soldat : approche, coup simple, télégraphe 0,4 s. Dès le niveau 1.
	_enemy({
		"id": "soldier", "display_name": "Soldat", "role": "soldier",
		"health": 30.0, "damage": 8.0, "speed": 1.8,
		"attack_range": 1.4, "telegraph_time": 0.4, "attack_duration": 0.5,
		"recover_time": 0.8, "drops_cauris": 3,
		"tint": Color(0.42, 0.40, 0.24), "model_scale": 1.0,
	})
	# Éclaireur : rapide, attaque puis recule, tourne autour.
	_enemy({
		"id": "scout", "display_name": "Éclaireur", "role": "scout",
		"health": 20.0, "damage": 6.0, "speed": 4.0,
		"attack_range": 1.4, "telegraph_time": 0.35, "attack_duration": 0.45,
		"recover_time": 0.5, "retreat_after_attack": 2.5, "drops_cauris": 2,
		"tint": Color(0.72, 0.72, 0.64), "model_scale": 0.92,
	})
	# Archer : reste à 7 m, tire toutes les 2,2 s, ligne rouge de visée.
	_enemy({
		"id": "archer", "display_name": "Archer", "role": "archer",
		"health": 18.0, "damage": 10.0, "speed": 1.4,
		"attack_range": 7.0, "keep_distance": 7.0, "fire_period": 2.2,
		"ranged": true, "telegraph_time": 0.5, "attack_duration": 0.6,
		"recover_time": 0.6, "drops_cauris": 3,
		"tint": Color(0.35, 0.45, 0.30), "model_scale": 1.02,
	})
	# Brute blindée : armure qui bloque les coups légers, vulnérable 0,9 s.
	_enemy({
		"id": "brute", "display_name": "Brute blindée", "role": "brute",
		"health": 90.0, "damage": 16.0, "speed": 1.2,
		"attack_range": 1.7, "telegraph_time": 0.6, "attack_duration": 0.7,
		"recover_time": 1.2, "armor": true, "vulnerable_time": 0.9,
		"drops_cauris": 8, "tint": Color(0.40, 0.32, 0.26), "model_scale": 1.3,
	})
	# Chef : buff +20 % aux alliés proches, invoque 1 soldat / 12 s.
	_enemy({
		"id": "chief", "display_name": "Chef", "role": "chief",
		"health": 70.0, "damage": 14.0, "speed": 2.2,
		"attack_range": 1.6, "telegraph_time": 0.35, "attack_duration": 0.5,
		"recover_time": 0.7, "buff_allies": true, "buff_mult": 1.2,
		"buff_radius": 6.0, "summon_period": 12.0, "summon_type": "soldier",
		"drops_cauris": 12, "tint": Color(0.45, 0.14, 0.12), "model_scale": 1.1,
	})
	# Garde d'alerte : s'il te voit, alerte (+2 ennemis).
	_enemy({
		"id": "guard", "display_name": "Garde d'alerte", "role": "guard",
		"health": 35.0, "damage": 8.0, "speed": 2.0,
		"attack_range": 1.5, "telegraph_time": 0.45, "attack_duration": 0.5,
		"recover_time": 0.8, "alert_reinforcements": 2, "drops_cauris": 4,
		"tint": Color(0.55, 0.50, 0.35), "model_scale": 1.0,
	})


func _enemy(values: Dictionary) -> void:
	var data = ENEMY_SCRIPT.new()
	for key in values.keys():
		data.set(key, values[key])
	_save(data, "%s/%s.tres" % [ENEMY_DIR, data.id])


# -----------------------------------------------------------------#
#                        NIVEAUX (§ 12-13)                         #
# -----------------------------------------------------------------#

func _write_levels() -> void:
	# LANE 1 — Cour du palais : déplacement, attaque, un éclaireur. (Niv. 1-3)
	_level({
		"id": "lane_01", "number": 1, "display_name": "Cour du palais",
		"layout": "lane", "length_m": 60.0, "objective": "clear",
		"time_limit": 150, "hazards": ["pit"], "hazards_per_kind": 1,
		"cauri_pickups": 6, "potion_pickups": 1, "checkpoint_at": 0.5,
		"reward_cauris": 40, "waves": [
			_floor([["soldier", 3]], 1.4),
			_floor([["soldier", 2], ["scout", 1]], 1.2),
		],
	})
	# LANE 2 — Marché d'Abomey : sortie à atteindre, archer, fosses et flèches.
	_level({
		"id": "lane_02", "number": 3, "display_name": "Marché d'Abomey",
		"layout": "lane", "length_m": 100.0, "objective": "exit",
		"time_limit": 130, "hazards": ["pit", "arrows"], "hazards_per_kind": 2,
		"cauri_pickups": 8, "potion_pickups": 1, "checkpoint_at": 0.5,
		"reward_cauris": 60, "waves": [
			_floor([["soldier", 3]], 1.3),
			_floor([["soldier", 2], ["scout", 2]], 1.2),
			_floor([["soldier", 3], ["archer", 1]], 1.1),
		],
	})
	# LANE 3 — Fort ennemi, de nuit : gardes d'alerte, brute, chef, feu.
	_level({
		"id": "lane_03", "number": 9, "display_name": "Fort ennemi (nuit)",
		"layout": "lane", "length_m": 140.0, "objective": "clear",
		"time_limit": 120, "hazards": ["fire", "spikes", "mud"],
		"hazards_per_kind": 2, "night": true,
		"cauri_pickups": 10, "potion_pickups": 1, "checkpoint_at": 0.45,
		"reward_cauris": 90, "waves": [
			_floor([["guard", 1], ["soldier", 2]], 1.2),
			_floor([["brute", 1], ["soldier", 2]], 1.2),
			_floor([["chief", 1], ["archer", 2]], 1.0),
		],
	})
	# ARENA 1 — Arène d'entraînement : survivre 60 s.
	_level({
		"id": "arena_01", "number": 2, "display_name": "Arène d'entraînement",
		"layout": "arena", "arena_radius": 14.0, "objective": "survive",
		"time_limit": 60, "hazards": ["mud"], "hazards_per_kind": 2,
		"cauri_pickups": 4, "potion_pickups": 1, "checkpoint_at": 0.5,
		"reward_cauris": 50, "waves": [
			_floor([["soldier", 2]], 1.5),
			_floor([["soldier", 3], ["scout", 1]], 1.3),
			_floor([["soldier", 2], ["archer", 1]], 1.2),
			_floor([["brute", 1], ["soldier", 2]], 1.1),
		],
	})
	# ARENA 2 — Disque des Braves, de nuit : pointes, feu, chef et brute.
	_level({
		"id": "arena_02", "number": 10, "display_name": "Disque des Braves (nuit)",
		"layout": "arena", "arena_radius": 16.0, "objective": "clear",
		"time_limit": 110, "hazards": ["spikes", "fire"], "hazards_per_kind": 2,
		"night": true, "cauri_pickups": 6, "potion_pickups": 1,
		"checkpoint_at": 0.5, "reward_cauris": 80, "waves": [
			_floor([["scout", 2]], 1.4),
			_floor([["soldier", 2], ["archer", 2]], 1.2),
			_floor([["chief", 1], ["brute", 1], ["guard", 2]], 1.0),
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
	for key in values.keys():
		# Les tableaux TYPÉS se construisent explicitement : `set()` avec un
		# Array non typé laisse `Array[String]` / `Array[WaveData]` vide.
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
		printerr("[generate_levels] échec d'écriture %s (erreur %d)" % [path, error])
		return
	written += 1
	print("  écrit %s" % path)
