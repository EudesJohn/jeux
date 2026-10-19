extends RefCounted
class_name BossRegistry
## Table des 5 boss du § 10 (même principe que `EnemyRegistry` : les chemins
## sont écrits en clair, pas scannés sur le disque — dans un APK exporté les
## `.tres` deviennent `.tres.remap` et une recherche par nom échouerait).

const FILES: Dictionary = {
	"captain": "res://data/bosses/boss_captain.tres",
	"river_archer": "res://data/bosses/boss_archer.tres",
	"colossus": "res://data/bosses/boss_colossus.tres",
	"shadow_sorcerer": "res://data/bosses/boss_sorcerer.tres",
	"rival_general": "res://data/bosses/boss_general.tres",
}

## Ordre de la chasse aux boss et des fins de chapitre (§ 10).
const ORDER: Array[String] = ["captain", "river_archer", "colossus", "shadow_sorcerer", "rival_general"]

static var _cache: Dictionary = {}


## Les 5 fiches (et la scène de boss) chargées une fois, hors combat.
static func preload_all() -> void:
	for boss_id in FILES.keys():
		get_data(boss_id)


## Fiche d'un boss. Identifiant inconnu -> le capitaine (jamais de crash).
static func get_data(boss_id: String) -> BossData:
	var key := boss_id.strip_edges().to_lower()
	if not FILES.has(key):
		key = "captain"
	if _cache.has(key):
		return _cache[key]
	var path: String = FILES[key]
	var data: BossData = null
	if ResourceLoader.exists(path):
		data = load(path) as BossData
	if data == null:
		data = BossData.new()
		data.id = key
	_cache[key] = data
	return data


static func ids() -> Array[String]:
	var out: Array[String] = []
	for boss_id in ORDER:
		out.append(boss_id)
	return out


## Boss de fin du chapitre `chapter` (§ 10 : un boss tous les 5 niveaux).
static func for_chapter(chapter: int) -> BossData:
	var index := clampi(chapter - 1, 0, ORDER.size() - 1)
	return get_data(ORDER[index])


## Boss débloqués pour la Chasse aux boss : seulement ceux déjà vaincus (§ 12.4).
static func unlocked_for_rush() -> Array[String]:
	var out: Array[String] = []
	for boss_id in ORDER:
		if SaveManager.stars_for("boss_%s" % boss_id) > 0:
			out.append(boss_id)
	if out.is_empty():
		out.append(ORDER[0])       # le premier boss reste jouable pour apprendre
	return out
