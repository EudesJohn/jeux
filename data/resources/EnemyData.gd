extends Resource
class_name EnemyData
## Fiche d'un ennemi (DESIGN.md § 9 et § 21.2). Toutes les valeurs sont ici :
## `EnemyBase3D` ne décide rien en dur, il lit cette ressource.
## Le .tres livré pour chaque type est dans `data/enemies/`.

## Identifiant de fichier et de vague (« soldier ») — voir SpawnEntry.
@export var id: String = "soldier"
## Nom affiché (HUD, écran de victoire).
@export var display_name: String = "Soldat"

## ----------------------------------------------------------------#
## § 9 : vie, dégâts, vitesse                                    #
## ----------------------------------------------------------------#
@export var health: float = 30.0
@export var damage: float = 8.0
@export var speed: float = 1.8              ## m/s
@export var sight_range: float = 9.0        ## m : il te voit
@export var attack_range: float = 1.4       ## m : portée d'un coup
@export var telegraph_time: float = 0.4     ## télégraphe lisible (§ 9)
@export var attack_duration: float = 0.5    ## durée de l'attaque
@export var recover_time: float = 0.8       ## récupération après le coup
@export var drops_cauris: int = 3           ## cauris lâchés à la mort

## ----------------------------------------------------------------#
## Comportement par type (§ 9)                                   #
## ----------------------------------------------------------------#
@export_enum("soldier", "scout", "archer", "brute", "chief", "guard")
var role: String = "soldier"

## Éclaireur : après son coup, il recule avant de revenir (§ 9).
@export var retreat_after_attack: float = 0.0     ## m de recul (0 = jamais)
## Archer : distance qu'il garde et période de tir (§ 9 : 7 m, 2,2 s).
@export var keep_distance: float = 0.0            ## 0 = pas de distance à garder
@export var fire_period: float = 0.0              ## 0 = pas de tir à distance
@export var ranged: bool = false                  ## attaque à distance (ligne de visée)
## Brute : armure. Les coups LÉGERS sont bloqués ; une fenêtre de vulnérabilité
## s'ouvre après son attaque lourde (§ 9 : 0,9 s).
@export var armor: bool = false
@export var vulnerable_time: float = 0.9
## Chef : buff +20 % de vitesse aux alliés proches et invoque un soldat / 12 s.
@export var buff_allies: bool = false
@export var buff_mult: float = 1.2
@export var buff_radius: float = 6.0
@export var summon_period: float = 0.0            ## 0 = pas d'invocation
@export var summon_type: String = "soldier"
## Garde d'alerte : s'il te voit, il alerte (+2 ennemis) (§ 9).
@export var alert_reinforcements: int = 0

## ----------------------------------------------------------------#
## Rendu (graybox de PHASE 3, § 15.2 : silhouette et couleur uniques)#
## ----------------------------------------------------------------#
@export var tint: Color = Color(0.55, 0.45, 0.30)
@export var model_scale: float = 1.0
## Modèle .glb remplaçable (§ 6.6). Vide = poupée de test (graybox).
@export var model_scene: PackedScene


## Vitesse effective, buffs du chef compris (§ 9 : « +20 % vitesse aux alliés »).
func speed_with_buff(buff_multiplier: float) -> float:
	return speed * buff_multiplier


## Un coup est-il bloqué par l'armure de la brute ? (§ 9)
func blocks_hit(is_heavy: bool, vulnerable: bool) -> bool:
	if not armor or vulnerable:
		return false
	return not is_heavy
