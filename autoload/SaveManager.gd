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
	## ANNEXE §3 : affixes tirés à l'obtention, ascensions et maîtrise.
	"weapon_affixes": {},
	"weapon_ascensions": {},
	"weapon_mastery": {},
	"weapon_hits": {},
	"armor": 0,
	"costumes_owned": ["default"],
	"equipped_costume": "default",
	"skills": {},
	## ANNEXE §4.1-4.4 : niveau, XP cumulée, attributs et talents.
	"level": 1,
	"xp": 0,
	"attribute_points": 0,
	"skill_points": 0,
	"attributes": {},
	"skill_ranks": {},
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


## ----------------------------------------------------------------#
##           PROGRESSION (ANNEXE §4, PHASE 6C)                     #
## ----------------------------------------------------------------#

func player_level() -> int:
	return clampi(int(data.get("level", 1)), 1, Progression.MAX_LEVEL)


func player_xp() -> int:
	return maxi(0, int(data.get("xp", 0)))


func attribute_points_left() -> int:
	return maxi(0, int(data.get("attribute_points", 0)))


func skill_points_left() -> int:
	return maxi(0, int(data.get("skill_points", 0)))


func attribute_value(attribute: String) -> int:
	if attribute not in Progression.ATTRIBUTES:
		return 0
	return maxi(0, int(data.get("attributes", {}).get(attribute, 0)))


func skill_rank(id: String) -> int:
	return clampi(int(data.get("skill_ranks", {}).get(id, 0)), 0, SkillTree.max_rank(id))


## Ajoute de l'XP et attribue les points des niveaux franchis (§4.1).
## Renvoie le nombre de niveaux gagnés. Les points ne sont jamais perdus.
func add_xp(amount: int) -> int:
	if amount <= 0 or player_level() >= Progression.MAX_LEVEL:
		return 0
	var before := player_level()
	data["xp"] = player_xp() + amount
	var reached := Progression.level_for_xp(player_xp())
	data["level"] = reached
	var gained := reached - before
	if gained <= 0:
		save_game()
		return 0
	data["attribute_points"] = attribute_points_left() + Progression.POINTS_PER_LEVEL * gained
	var skills_before := Progression.skill_points_for(before)
	var skills_after := Progression.skill_points_for(reached)
	data["skill_points"] = skill_points_left() + (skills_after - skills_before)
	save_game()
	return gained


## Place un point d'attribut. `false` si le nom est inconnu ou sans point.
func spend_attribute(attribute: String) -> bool:
	if attribute not in Progression.ATTRIBUTES or attribute_points_left() <= 0:
		return false
	var attributes: Dictionary = data.get("attributes", {})
	attributes[attribute] = int(attributes.get(attribute, 0)) + 1
	data["attributes"] = attributes
	data["attribute_points"] = attribute_points_left() - 1
	save_game()
	return true


## Apprend un rang de talent (§4.4). `false` si le coût dépasse les points ou
## si le rang maximum est atteint.
func learn_skill(id: String) -> bool:
	var rank := skill_rank(id)
	var price := SkillTree.cost(id, rank)
	if price < 0 or price > skill_points_left():
		return false
	var ranks: Dictionary = data.get("skill_ranks", {})
	ranks[id] = rank + 1
	data["skill_ranks"] = ranks
	data["skill_points"] = skill_points_left() - price
	save_game()
	return true


## Bonus de critique des attributs (au-dessus des 8 % de base).
func attribute_crit_bonus() -> float:
	return 0.005 * float(attribute_value("agilite")) \
		+ 0.004 * float(attribute_value("chance"))


func skill_stat(stat: String) -> float:
	return SkillTree.stat_total(data.get("skill_ranks", {}), stat)


func has_skill_unlock(unlock: String) -> bool:
	return SkillTree.has_unlock(data.get("skill_ranks", {}), unlock)


## ----------------------------------------------------------------#
##              ARMES (ANNEXE §3, PHASE 6B)                        #
## ----------------------------------------------------------------#

func owns_weapon(id: String) -> bool:
	return id in data.get("weapons_owned", [])


func equipped_weapon() -> String:
	var id := str(data.get("equipped_weapon", "sabre"))
	return id if owns_weapon(id) else "sabre"


## Niveau d'amélioration (1 à 10). Une arme inconnue répond 0.
func weapon_level(id: String) -> int:
	var levels: Dictionary = data.get("weapon_levels", {})
	return clampi(int(levels.get(id, 1)), 1, WeaponSystem.MAX_LEVEL)


func equip_weapon(id: String) -> bool:
	if not owns_weapon(id):
		return false
	data["equipped_weapon"] = id
	save_game()
	return true


## Ajoute une arme à l'inventaire et tire ses affixes à l'obtention.
## `false` si l'arme est inconnue ou déjà possédée.
func own_weapon(id: String, rng: RandomNumberGenerator = null) -> bool:
	var weapon := WeaponSystem.load_weapon(id)
	if weapon == null or owns_weapon(id):
		return false
	data["weapons_owned"].append(id)
	data["weapon_levels"][id] = 1
	data["weapon_mastery"][id] = 0
	var generator := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		generator.randomize()
	_set_affixes(id, WeaponSystem.affixes_for(weapon, generator))
	save_game()
	return true


func weapon_affixes(id: String) -> Array[String]:
	var out: Array[String] = []
	var stored: Dictionary = data.get("weapon_affixes", {})
	for affix in stored.get(id, []):
		out.append(str(affix))
	return out


func _set_affixes(id: String, affixes: Array[String]) -> void:
	var stored: Dictionary = data.get("weapon_affixes", {})
	stored[id] = affixes
	data["weapon_affixes"] = stored


## Améliore l'arme d'un niveau (coût 60 × niveau^1,5, §3.4).
## `false` si l'arme n'est pas possédée, déjà au maximum, ou sans cauris.
func upgrade_weapon(id: String) -> bool:
	if not owns_weapon(id):
		return false
	var level := weapon_level(id)
	var cost := WeaponSystem.upgrade_cost(level)
	if cost < 0 or not try_spend(cost):
		return false
	data["weapon_levels"][id] = level + 1
	save_game()
	return true


## Ascension aux niveaux 5 et 10 (matériau rare de boss, §3.4).
## `false` si l'arme n'est pas à un palier, ou si elle est déjà ascendue.
func ascend_weapon(id: String) -> bool:
	if not owns_weapon(id):
		return false
	var level := weapon_level(id)
	if not WeaponSystem.is_ascension_level(level):
		return false
	var done: Dictionary = data.get("weapon_ascensions", {})
	var levels: Array = done.get(id, [])
	if levels.has(level):
		return false
	levels.append(level)
	done[id] = levels
	data["weapon_ascensions"] = done
	save_game()
	return true


func weapon_ascended(id: String, level: int) -> bool:
	var done: Dictionary = data.get("weapon_ascensions", {})
	return (done.get(id, []) as Array).has(level)


func weapon_mastery(id: String) -> int:
	var stored: Dictionary = data.get("weapon_mastery", {})
	return clampi(int(stored.get(id, 0)), 0, WeaponSystem.MAX_MASTERY)


## La maîtrise monte en frappant : 100 coups = 1 point, plafond 20 (§3.4).
## Le total de coups est conservé pour ne rien perdre entre deux appels.
func add_weapon_hits(id: String, hits: int) -> int:
	if not owns_weapon(id) or hits <= 0:
		return weapon_mastery(id)
	var totals: Dictionary = data.get("weapon_hits", {})
	var total := int(totals.get(id, 0)) + hits
	totals[id] = total
	data["weapon_hits"] = totals
	var mastery := WeaponSystem.mastery_after_hits(total)
	var stored: Dictionary = data.get("weapon_mastery", {})
	stored[id] = mastery
	data["weapon_mastery"] = stored
	save_game()
	return mastery


## Bonus de dégâts additif (affixes) de l'arme équipée.
func weapon_bonus(id: String) -> float:
	return AffixData.damage_bonus(weapon_affixes(id))


## Facteur de dégâts de l'arme équipée (ANNEXE §3/§4.3). Le sabre de départ
## au niveau 1 vaut 1,00 : le gameplay de la PHASE 2 ne change pas.
func equipped_damage_mult() -> float:
	var id := equipped_weapon()
	var weapon := WeaponSystem.load_weapon(id)
	if weapon == null:
		return 1.0
	return weapon.rarity_mult() * (1.0 + 0.08 * float(weapon_level(id) - 1)) \
		* (1.0 + weapon_bonus(id))


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
