extends Node
## Bus de signaux global (DESIGN.md § 18 règle 3 : tout passe par Events).
## Les scripts ne se référencent jamais entre eux directement : ils écoutent ici.

## touch_action : le joystick et les TouchButton communiquent leurs actions au jeu.
signal touch_action(action: String, pressed: bool)

## Combat et lecture d'ennemis.
signal perfect_guard(actor: Node)
signal perfect_dodge(actor: Node)
signal guard_broken(actor: Node)
signal enemy_died(enemy: Node)

## Retour visuel du HUD (§ 16) : la joueuse encaisse, ou une action est parfaite.
signal player_damaged(actor: Node, amount: float)
signal special_ready(actor: Node)

## Verrouillage de cible en ARENA (§ 3.2).
signal lock_on_changed(target: Node3D)

## Objectifs de niveau.
signal prisoner_freed(prisoner: Node)
signal objective_completed
signal level_failed(reason: String)
## PHASE 8 : fin de niveau réussie, pour les succès et les objectifs du jour.
signal level_completed(level_id: String, stars: int)

## Sauvetage et escorte (§ 12.2, PHASE 4).
signal prisoner_hurt(prisoner: Node, amount: float)
signal ally_died(ally: Node)
signal interact_target(ally: Node)      ## prisonnier en portée (null : aucun)

## PHASE 7 : une joueuse est à terre en coop (§ 22.3) : l'hôte lance le
## décompte de réanimation de 10 s.
signal player_downed(actor: Node)

## Économie et boss (§ 10, PHASE 6).
signal cauris_changed(total: int)
signal boss_phase_changed(phase: int)
signal boss_spawned(boss: Node)
signal boss_defeated(boss: Node)
signal boss_health_changed(current: float, maximum: float)

## Vecteur du joystick virtuel (gauche de l'écran), consommé par Player3D.
var joystick_vector: Vector2 = Vector2.ZERO
