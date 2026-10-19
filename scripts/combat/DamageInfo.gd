extends RefCounted
class_name DamageInfo
## Représentation d'un coup (DESIGN.md § 20.1) : dégâts, recul en m, position de
## la source, coup lourd ou léger.
##
## PHASE 2 ajoute l'ACTEUR source : la garde parfaite doit pouvoir étourdir et
## contre-attaquer celui qui frappe (§ 8.4), ce que la seule position permettait
## mal (un ennemi mobile s'éloigne entre le calcul et l'application).

var amount: float = 0.0
var knockback: float = 0.0          # en mètres
var source_position: Vector3 = Vector3.ZERO
var source_actor: Node = null       # qui frappe (garde parfaite : § 8.4)
var is_heavy: bool = false
var is_critical: bool = false       # critiques : 8 %, ×1,5 (§ 8.7)
## ANNEXE §7.2 : couleur de l'attaque (Hitbox3D.Danger). Blanc = gardable,
## jaune = garde parfaite seulement, rouge = imparable (esquive obligatoire).
var danger: int = 0
## Dégâts CONTINUS (§ 11 : le feu brûle 8 vie par seconde). Ils ignorent les
## i-frames de touche (sinon 1 frame sur 60 passe) mais pas l'esquive.
var is_dot: bool = false
