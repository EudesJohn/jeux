extends Resource
class_name DifficultyTier
## Palier de difficulté (ANNEXE §7.6). Le palier est choisi **par partie** :
## `GameState.use_tier()` le charge, tout le reste du jeu lit ses valeurs.
##
## Règle d'or (§1) : la difficulté ne change jamais le télégraphe des attaques.
## Un coup reste annoncé au moins 0,3 s, même en Éternelle.

const PATHS := {
	"recit": "res://data/difficulty/recit.tres",
	"guerriere": "res://data/difficulty/guerriere.tres",
	"legende": "res://data/difficulty/legende.tres",
	"eternelle": "res://data/difficulty/eternelle.tres",
}
const ORDER: Array[String] = ["recit", "guerriere", "legende", "eternelle"]

@export var id: String = "guerriere"
@export var display_name: String = "Guerrière"
@export var description: String = ""
@export var enemy_health_mult: float = 1.0
@export var enemy_damage_mult: float = 1.0
@export var aggression: float = 0.5           ## 0..1 : fréquence des attaques
@export var max_potions: int = 5
@export var checkpoints_in_boss: bool = false
@export var one_life_per_chapter: bool = false
@export var elite_chance: float = 0.10
@export var max_elite_affixes: int = 0
@export var boss_phase_count: int = 3
@export var frame_color: Color = Color(0.72, 0.45, 0.22)


static func load_tier(tier_id: String) -> DifficultyTier:
	var path := str(PATHS.get(tier_id, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as DifficultyTier


static func all_tiers() -> Array[DifficultyTier]:
	var out: Array[DifficultyTier] = []
	for tier_id in ORDER:
		var tier := load_tier(tier_id)
		if tier != null:
			out.append(tier)
	return out


## Écran de mort (§7.2 règle 8) : conseil adapté à la couleur de l'attaque.
static func advice_for(danger: int) -> String:
	match danger:
		1:
			return "Garde parfaite possible : appuie sur Garde juste avant l'impact."
		2:
			return "Attaque imparable : esquive, la garde ne suffit pas."
		_:
			return "Tu peux garder, esquiver ou contre-attaquer."
