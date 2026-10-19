extends RefCounted
class_name EnemyRegistry
## Table des ennemis (DESIGN.md § 20.11 `EnemyRegistry.get_scene(type)` et § 18
## règle 6 : « Pas de load() pendant le combat : précharger au chargement »).
##
## Les 6 types du § 9 sont déclarés ici en clair plutôt que scannés sur le
## disque : dans un APK exporté, lister `res://` renvoie des noms remappés
## (`.tres.remap`), ce qui casserait la recherche par type.

## Identifiant -> fichier de données. Le `.tres` porte les valeurs du § 9.
const FILES: Dictionary = {
	"soldier": "res://data/enemies/soldier.tres",
	"scout": "res://data/enemies/scout.tres",
	"archer": "res://data/enemies/archer.tres",
	"brute": "res://data/enemies/brute.tres",
	"chief": "res://data/enemies/chief.tres",
	"guard": "res://data/enemies/guard.tres",
}

## Scène unique de tous les ennemis : c'est `EnemyData` qui les différencie
## (§ 6.6 : remplacer le modèle ne touche pas au code).
const ENEMY_SCENE: String = "res://scenes/enemies/Enemy3D.tscn"

const DEFAULT_TYPE: String = "soldier"

static var _data_cache: Dictionary = {}
static var _scene_cache: PackedScene = null


## Précharge les 6 types et la scène d'ennemi (appelé au chargement du niveau).
static func preload_all() -> void:
	for type_name in FILES.keys():
		get_data(type_name)
	get_scene()


## Fiche d'un type. Type inconnu -> soldat (jamais de crash sur un .tres faux).
static func get_data(type_name: String) -> EnemyData:
	var key := normalize(type_name)
	if _data_cache.has(key):
		return _data_cache[key]
	var data: EnemyData = null
	var path: String = FILES.get(key, "")
	if path != "" and ResourceLoader.exists(path):
		data = load(path) as EnemyData
	if data == null:
		data = EnemyData.new()
		data.id = key
	_data_cache[key] = data
	return data


static func get_scene() -> PackedScene:
	if _scene_cache == null:
		_scene_cache = load(ENEMY_SCENE) as PackedScene
	return _scene_cache


## Types connus, dans l'ordre du § 9.
static func types() -> Array[String]:
	var out: Array[String] = []
	for type_name in FILES.keys():
		out.append(type_name)
	return out


## « Soldier », « SOLDAT »… -> « soldier ».
static func normalize(type_name: String) -> String:
	var key := type_name.strip_edges().to_lower()
	if key.is_empty():
		return DEFAULT_TYPE
	return key if FILES.has(key) else DEFAULT_TYPE
