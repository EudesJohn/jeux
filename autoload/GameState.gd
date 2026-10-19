extends Node
## État de la partie en cours (mode, niveau, difficulté) et multiplicateurs
## de difficulté du DOSSIER.md § 9 : Facile = vie et dégâts ×0,7 ; Difficile = ×1,3.

enum GameMode { NONE, ADVENTURE, RESCUE, SURVIVAL, BOSS_RUSH, DAILY, ARENA, COOP }

var mode: GameMode = GameMode.NONE
var current_level_data: Resource = null   ## LevelData en PHASE 3 (type dur alors)
var difficulty: String = "normal"          ## "easy" / "normal" / "hard"
## § 12.5 : modificateur du jour (« damage », « night », « fast », « one_life »).
var modifier: String = ""
var cauris_this_run: int = 0               ## cauris gagnés pendant CE niveau (ajoutés en fin)


func reset_run() -> void:
	## À appeler au chargement de chaque niveau : repart à zéro.
	cauris_this_run = 0


func add_cauris(amount: int) -> void:
	cauris_this_run += amount
	Events.cauris_changed.emit(SaveManager.data["cauris"] + cauris_this_run)


## § 12.5 : « ennemis rapides » (Défi du jour).
func enemy_speed_mult() -> float:
	return 1.25 if modifier == "fast" else 1.0


## § 12.5 : « dégâts doublés » (Défi du jour).
func enemy_damage_mult() -> float:
	return 2.0 if modifier == "damage" else 1.0


## § 12.5 : « une seule vie » (Défi du jour) : aucune réapparition.
func is_one_life() -> bool:
	return modifier == "one_life"


func difficulty_health_mult() -> float:
	match difficulty:
		"easy":
			return 0.7
		"hard":
			return 1.3
		_:
			return 1.0


func difficulty_damage_mult() -> float:
	match difficulty:
		"easy":
			return 0.7
		"hard":
			return 1.3
		_:
			return 1.0


## Facile : 20 % plus de temps. Difficile : temps strict. (§ 13 / § 12.2)
func time_mult() -> float:
	match difficulty:
		"easy":
			return 1.2
		"hard":
			return 1.0
		_:
			return 1.0


## Ratio de vie des ennemis en coop : ×1,5 (§ 22.3)
func coop_health_mult() -> float:
	return 1.5 if mode == GameMode.COOP else 1.0


## Écran vers lequel revient un niveau terminé (§ 16 : Résultat → Carte).
## La campagne retourne à la carte, le Sauvetage à sa liste ; les scènes de
## test (PHASE 1-4) retournent au menu.
func return_scene_path() -> String:
	match mode:
		GameMode.ADVENTURE:
			return "res://scenes/ui/AdventureMap.tscn"
		GameMode.RESCUE:
			return "res://scenes/ui/RescueSelect.tscn"
		GameMode.SURVIVAL, GameMode.BOSS_RUSH, GameMode.DAILY:
			## § 12.3-12.5 : les modes hors campagne reviennent à leur sélecteur.
			return "res://scenes/ui/ModeSelect.tscn"
		_:
			return "res://scenes/main/MainMenu.tscn"


## Mode avec une carte ou une liste de niveaux (le bouton du résultat dit
## alors « CONTINUER » et non « MENU »).
func is_campaign_mode() -> bool:
	return mode in [GameMode.ADVENTURE, GameMode.RESCUE,
		GameMode.SURVIVAL, GameMode.BOSS_RUSH, GameMode.DAILY]


## Ratio de vie actuelle de la joueuse locale : 2 étoiles si ≥ 50 % (§ 13).
func player_health_ratio() -> float:
	# PHASE 1 : branche le HUD ici. Pour l'instant aucune joueuse n'existe.
	return 1.0
