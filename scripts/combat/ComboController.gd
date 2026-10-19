extends Node
class_name ComboController
## Combo de 3 coups de la joueuse (DESIGN.md § 8.2 / § 20.5). Il fournit les
## DONNÉES de chaque coup (durées, multiplicateurs, avancée, fenêtre de hit,
## fenêtre d'enchaînement) ; les timings réels sont pilotés par l'état ATTAQUE
## de Player3D. En PHASE 2, les Call Method Tracks des vraies animations
## remplaceront les fenêtres numériques.
##
## Les valeurs viennent de `data/balance.tres` (§ 8) quand il est fourni :
## `configure(balance)`. Sinon `STEPS` sert de valeurs par défaut.

## Index du coup finisseur (coup 3, ×1,6, hit-stop 0,09 s, § 8.2).
const FINISHER_STEP: int = 2

## Coup 1 ×0,8 · Coup 2 ×1,0 · Coup 3 ×1,6 (finisseur).
## len : durée de l'état ; hit_from/hit_to : fenêtre où la Hitbox est active ;
## advance : avancée de la joueuse (m) ; win_from : ouverture de la fenêtre
## d'enchaînement ; knockback : recul infligé (m) ; hitstop/shake : game feel.
const STEPS: Array[Dictionary] = [
	{"len": 0.44, "mult": 0.8, "advance": 0.4, "hit_from": 0.12, "hit_to": 0.28,
		"win_from": 0.30, "knockback": 1.2, "hitstop": 0.05, "shake": 0.12},
	{"len": 0.47, "mult": 1.0, "advance": 0.5, "hit_from": 0.15, "hit_to": 0.31,
		"win_from": 0.33, "knockback": 1.6, "hitstop": 0.05, "shake": 0.16},
	{"len": 0.60, "mult": 1.6, "advance": 0.8, "hit_from": 0.20, "hit_to": 0.36,
		"win_from": 0.40, "knockback": 4.4, "hitstop": 0.09, "shake": 0.32},
]

## Table de coups effective : celle de `balance` après configure(), sinon STEPS.
var steps: Array[Dictionary] = STEPS
var balance: Balance = null


## Branche la table de coups sur les valeurs réglables (§ 8). Une table
## incomplète est refusée : le jeu garde des coups valides quoi qu'il arrive.
func configure(source: Balance) -> void:
	if source == null:
		return
	var candidate := source.combo_steps()
	if candidate.size() != STEPS.size():
		push_warning("ComboController : table de coups invalide (%d coups) — valeurs par défaut gardées"
			% candidate.size())
		return
	balance = source
	steps = candidate


## Retourne la fenêtre hit-stop d'un coup (§ 8.2 : 0,05/0,05/0,09 s).
static func hitstop_for(step: int) -> float:
	return 0.09 if step == FINISHER_STEP else 0.05
