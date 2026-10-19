extends RefCounted
class_name WeaponSystem
## Règles du système d'armes de l'ANNEXE §3.4 : coût d'amélioration,
## ascension, tirage d'affixes, maîtrise. Fonctions pures + chargement des
## fiches `res://data/weapons/*.tres` (mises en cache une seule fois).

const WEAPON_DIR := "res://data/weapons"
const MAX_LEVEL: int = 10
const MAX_MASTERY: int = 20
## Niveaux où une ascension est possible (matériau rare de boss requis).
const ASCENSION_LEVELS: Array[int] = [5, 10]
## Seuils de maîtrise qui débloquent les enchaînements de 4 puis 5 coups.
const MASTERY_COMBO_4: int = 5
const MASTERY_COMBO_5: int = 12

static var _cache: Dictionary = {}


## Prix pour passer de `level` à `level + 1` (§3.4) : 60 × niveau^1,5.
## -1 signifie « niveau maximum ».
static func upgrade_cost(level: int) -> int:
	if level < 1 or level >= MAX_LEVEL:
		return -1
	return roundi(60.0 * pow(float(level), 1.5))


static func can_upgrade(level: int) -> bool:
	return level >= 1 and level < MAX_LEVEL


static func is_ascension_level(level: int) -> bool:
	return ASCENSION_LEVELS.has(level)


static func affixes_for(weapon: WeaponData, rng: RandomNumberGenerator) -> Array[String]:
	if weapon == null:
		return []
	return AffixData.roll(weapon.affix_count(), rng, weapon.possible_affixes)


## Bonus additif total (dégâts) fourni par les affixes, runes et talismans.
static func total_bonus(affixes: Array[String], rune_bonus: float = 0.0,
		talisman_bonus: float = 0.0) -> float:
	return AffixData.damage_bonus(affixes) + rune_bonus + talisman_bonus


## Maîtrise gagnée en frappant : 100 coups = 1 point, plafonnée à 20.
static func mastery_after_hits(hits: int) -> int:
	return clampi(floori(float(hits) / 100.0), 0, MAX_MASTERY)


static func combo_unlocked(mastery: int, hits: int) -> bool:
	match hits:
		4:
			return mastery >= MASTERY_COMBO_4
		5:
			return mastery >= MASTERY_COMBO_5
		_:
			return true


## Charge une fiche d'arme par identifiant (« sabre », « lance »…).
## Renvoie `null` si le fichier n'existe pas : l'appelant décide du repli.
static func load_weapon(id: String) -> WeaponData:
	if _cache.has(id):
		return _cache[id] as WeaponData
	var path := "%s/%s.tres" % [WEAPON_DIR, id]
	if not ResourceLoader.exists(path):
		return null
	var weapon := load(path) as WeaponData
	if weapon != null:
		_cache[id] = weapon
	return weapon


## Toutes les fiches du dossier, triées par identifiant (stable pour les tests).
static func all_weapons() -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for file in DirAccess.get_files_at(WEAPON_DIR):
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var weapon := load_weapon(name.trim_suffix(".tres"))
		if weapon != null:
			out.append(weapon)
	out.sort_custom(func(a: WeaponData, b: WeaponData) -> bool: return a.id < b.id)
	return out


## Dégâts affichés dans l'inventaire pour une arme possédée.
static func display_damage(id: String, level: int, affixes: Array[String]) -> float:
	var weapon := load_weapon(id)
	if weapon == null:
		return 0.0
	return weapon.damage_at(level, AffixData.damage_bonus(affixes))


## Vérifie qu'un identifiant correspond bien à une fiche existante.
static func exists(id: String) -> bool:
	return load_weapon(id) != null
