extends Node
## État de la partie en cours (mode, niveau, difficulté) et multiplicateurs
## de difficulté du DOSSIER.md § 9 : Facile = vie et dégâts ×0,7 ; Difficile = ×1,3.

enum GameMode { NONE, ADVENTURE, RESCUE, SURVIVAL, BOSS_RUSH, DAILY, ARENA, COOP }

var mode: GameMode = GameMode.NONE
var current_level_data: Resource = null   ## LevelData en PHASE 3 (type dur alors)
var difficulty: String = "normal"          ## "easy" / "normal" / "hard"
## ANNEXE §7 : palier choisi pour la partie ("recit", "guerriere", "legende",
## "eternelle"). `null` = ancien réglage à trois valeurs, conservé pour les
## sauvegardes et les tests existants.
var tier: DifficultyTier = null
## Dernier coup encaissé : l'écran de mort dit quoi et comment l'éviter (§7.2).
var last_hit_danger: int = 0
var last_hit_source: String = ""
## § 12.5 : modificateur du jour (« damage », « night », « fast », « one_life »).
var modifier: String = ""
var cauris_this_run: int = 0               ## cauris gagnés pendant CE niveau (ajoutés en fin)


func reset_run() -> void:
	## À appeler au chargement de chaque niveau : repart à zéro.
	cauris_this_run = 0
	# §7.2 règle 8 : le coup fatal ne doit pas venir du niveau précédent.
	last_hit_danger = 0
	last_hit_source = ""


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


## Charge un palier et aligne l'ancienne difficulté à trois valeurs pour
## les règles qui la lisent encore (réapparitions, temps).
func use_tier(tier_id: String) -> bool:
	var loaded := DifficultyTier.load_tier(tier_id)
	if loaded == null:
		return false
	tier = loaded
	difficulty = tier_legacy_name(tier_id)
	return true


func clear_tier() -> void:
	tier = null
	difficulty = "normal"


func tier_id() -> String:
	return tier.id if tier != null else ""


## Correspondance palier -> ancienne difficulté (les règles de temps et de
## réapparition n'ont pas encore de champ dédié dans DifficultyTier).
static func tier_legacy_name(tier_id: String) -> String:
	match tier_id:
		"recit":
			return "easy"
		"legende", "eternelle":
			return "hard"
		_:
			return "normal"


## §7.6 : nombre de potions emportées dans le niveau.
func max_potions() -> int:
	return tier.max_potions if tier != null else 5


func checkpoints_in_boss() -> bool:
	return tier.checkpoints_in_boss if tier != null else false


func one_life_per_chapter() -> bool:
	return tier.one_life_per_chapter if tier != null else false


func elite_chance() -> float:
	return tier.elite_chance if tier != null else 0.10


func max_elite_affixes() -> int:
	return tier.max_elite_affixes if tier != null else 0


func boss_phase_count() -> int:
	return tier.boss_phase_count if tier != null else 3


func aggression() -> float:
	return tier.aggression if tier != null else 0.5


## §7.2 règle 8 : mémorise la couleur et l'origine du coup qui a blessé.
func register_player_hit(danger: int, source_name: String) -> void:
	last_hit_danger = danger
	last_hit_source = source_name


func hit_advice() -> String:
	return DifficultyTier.advice_for(last_hit_danger)


func difficulty_health_mult() -> float:
	if tier != null:
		return tier.enemy_health_mult
	match difficulty:
		"easy":
			return 0.7
		"hard":
			return 1.3
		_:
			return 1.0


func difficulty_damage_mult() -> float:
	if tier != null:
		return tier.enemy_damage_mult
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
