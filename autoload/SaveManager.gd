extends Node
## Sauvegarde JSON locale (DOSSIER.md § 23) : user://save.json + sauvegarde de
## secours user://save.bak. Ne jamais planter sur un fichier corrompu : si le
## fichier principal est illisible, on essaie le secours, puis les défauts.

const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.bak"
const VERSION := 1

## Valeurs par défaut (première partie, ou fichiers illisibles).
const DEFAULT_DATA := {
	"version": VERSION,
	"cauris": 0,
	"levels": {},                      # { "rescue_01": {"stars": 2}, ... }
	"weapons_owned": ["sabre"],
	"weapon_levels": {"sabre": 1},
	"equipped_weapon": "sabre",
	"armor": 0,
	"costumes_owned": ["default"],
	"equipped_costume": "default",
	"skills": {},
	"upgrades": {},                    # armurerie § 14.4 : { "vitalite": 2, ... }
	"achievements": [],                # noms des succès débloqués (PHASE 8)
	"stats": {                       # compteurs des succès et des objectifs du jour
		"kills": 0, "perfect_guards": 0, "rescued": 0, "levels": 0,
		"bosses": 0, "survival_waves": 0, "daily_streak": 0, "coop_levels": 0,
	},
	"daily": {"last_date": 0, "streak": 0},
	"survival_record": 0,
	"settings": {"quality": "medium", "scale_3d": 0.8},
}


var data: Dictionary = {}


func _ready() -> void:
	data = DEFAULT_DATA.duplicate(true)
	load_game()


func save_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		# La sauvegarde précédente ne sert que si la nouvelle écriture échoue.
		DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()


func load_game() -> void:
	for path in [SAVE_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.READ)
			var parsed = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				data.merge(parsed, true)
				_migrate()
				return
	# Aucun fichier (première partie) : data reste aux défauts du dessus.


func add_cauris(amount: int) -> void:
	data["cauris"] = maxi(0, int(data["cauris"]) + amount)
	save_game()


func try_spend(amount: int) -> bool:
	if int(data["cauris"]) < amount:
		return false
	data["cauris"] = int(data["cauris"]) - amount
	save_game()
	return true


## § 12.3 : record local de Survie (nombre de vagues tenues).
func survival_record() -> int:
	return int(data.get("survival_record", 0))


## Enregistre un nouveau record de Survie, s'il est meilleur. Renvoie `true`
## quand le record tombe (le niveau l'annonce alors à l'écran de résultat).
func record_survival(waves: int) -> bool:
	Achievements.set_at_least("survival_waves", waves)
	if waves <= survival_record():
		return false
	data["survival_record"] = waves
	save_game()
	return true


## PHASE 8 : compteur des succès et des objectifs du jour (§ 24).
func stat_value(name: String) -> int:
	var stats: Dictionary = data.get("stats", {})
	return int(stats.get(name, 0))


func record_level_result(id: String, stars: int, cauris_earned: int) -> void:
	## À appeler une seule fois par fin de niveau (écran Résultat en PHASE 4).
	var cur: Dictionary = data["levels"].get(id, {"stars": 0})
	cur["stars"] = maxi(int(cur.get("stars", 0)), stars)
	data["levels"][id] = cur
	data["cauris"] = int(data["cauris"]) + cauris_earned
	save_game()


## Étoiles déjà gagnées sur un niveau (0 = jamais terminé). PHASE 5 : la carte
## et le choix du Sauvetage les affichent.
func stars_for(level_id: String) -> int:
	var entry: Dictionary = data.get("levels", {}).get(level_id, {})
	return int(entry.get("stars", 0))


## ----------------------------------------------------------------#
##        ARMURERIE : AMÉLIORATIONS PERMANENTES (§ 14.4)           #
## ----------------------------------------------------------------#

## Les trois branches utiles tout de suite (les armes et l'arbre complet
## arrivent en PHASE 6/7). Chaque amélioration a 3 niveaux et son prix monte.
const UPGRADES: Dictionary = {
	"vitalite": {
		"name": "Vitalité", "max": 3, "costs": [120, 200, 320],
		"per_level": 10.0, "description": "+10 vie maximale par niveau",
	},
	"force": {
		"name": "Force", "max": 3, "costs": [150, 240, 380],
		"per_level": 0.08, "description": "+8 % de dégâts par niveau",
	},
	"souffle": {
		"name": "Souffle", "max": 3, "costs": [100, 180, 300],
		"per_level": 20.0, "description": "+20 énergie au départ par niveau",
	},
}


func upgrade_level(id: String) -> int:
	var levels: Dictionary = data.get("upgrades", {})
	return int(levels.get(id, 0))


## Prix du prochain niveau, ou -1 si l'amélioration est au maximum.
func upgrade_cost(id: String) -> int:
	if not UPGRADES.has(id):
		return -1
	var info: Dictionary = UPGRADES[id]
	var level := upgrade_level(id)
	var costs: Array = info["costs"]
	if level >= int(info["max"]):
		return -1
	return int(costs[clampi(level, 0, costs.size() - 1)])


## Achète un niveau d'amélioration. `false` si les cauris manquent ou si le
## maximum est atteint : l'armurerie affiche alors le prix en rouge.
func buy_upgrade(id: String) -> bool:
	var cost := upgrade_cost(id)
	if cost < 0 or not try_spend(cost):
		return false
	var levels: Dictionary = data.get("upgrades", {})
	levels[id] = upgrade_level(id) + 1
	data["upgrades"] = levels
	save_game()
	return true


## Bonus cumulé d'une amélioration (vie, énergie) : niveau × valeur.
func upgrade_bonus(id: String) -> float:
	if not UPGRADES.has(id):
		return 0.0
	return float(UPGRADES[id]["per_level"]) * float(upgrade_level(id))


## Multiplicateur de dégâts de la joueuse (« Force »).
func damage_multiplier() -> float:
	return 1.0 + upgrade_bonus("force")


func has_unlocked(level_id: String) -> bool:
	## Verrouillage de la carte (PHASE 5) : un niveau est débloqué si le niveau
	## précédent du même mode a au moins 1 étoile. Squelette, étendu en PHASE 5.
	return data.has("levels") and data["levels"].has(level_id)


func _migrate() -> void:
	## Versement des défauts dans les champs manquants / d'une ancienne version.
	data["version"] = VERSION
	for key in DEFAULT_DATA:
		if not data.has(key):
			data[key] = DEFAULT_DATA[key].duplicate(true)
