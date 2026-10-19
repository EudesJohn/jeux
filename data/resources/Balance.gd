extends Resource
class_name Balance
## Toutes les valeurs de combat du § 8, réglables SANS toucher au code
## (DESIGN.md § 8 : « Toutes les valeurs sont dans data/balance.tres »).
## La scène `scenes/tests/BalanceTest.tscn` modifie cette ressource à chaud.
##
## Le .tres livré s'appelle `data/balance.tres`. S'il manque ou si une liste est
## vide, chaque script retombe sur ses propres valeurs par défaut : le jeu
## reste jouable même avec un balance.tres abîmé.

# ----------------------------------------------------------------#
# § 8.1 Joueuse (niveau 1)                                        #
# ----------------------------------------------------------------#
@export var max_health: float = 100.0
@export var max_energy: float = 100.0
@export var speed: float = 4.5              ## m/s, course
@export var guard_speed: float = 1.4        ## m/s en garde (§ 8.4)
@export var accel: float = 30.0             ## m/s², arrêt net
@export var gravity: float = 20.0           ## m/s²
@export var turn_speed: float = 14.0        ## rad/s, rotation du modèle
@export var base_damage: float = 10.0       ## × multiplicateur du coup (§ 8.2)

# ----------------------------------------------------------------#
# § 8.2 Attaque et combo (3 coups)                                #
# ----------------------------------------------------------------#
## Durée de l'état ATTAQUE (coup + récupération), en s.
@export var combo_len: PackedFloat32Array = [0.44, 0.47, 0.60]
## Dégâts = base_damage × multiplicateur.
@export var combo_mult: PackedFloat32Array = [0.8, 1.0, 1.6]
## Avancée de la joueuse pendant le coup, en m.
@export var combo_advance: PackedFloat32Array = [0.4, 0.5, 0.8]
## Fenêtre (s) où la Hitbox est active.
@export var combo_hit_from: PackedFloat32Array = [0.12, 0.15, 0.20]
@export var combo_hit_to: PackedFloat32Array = [0.28, 0.31, 0.36]
## Ouverture de la fenêtre d'enchaînement (s).
@export var combo_window_from: PackedFloat32Array = [0.30, 0.33, 0.40]
## Recul infligé à la cible, en m.
@export var combo_knockback: PackedFloat32Array = [1.2, 1.6, 4.4]
## Hit-stop par coup (s) : 0,05 / 0,05 / 0,09 (§ 8.2).
@export var combo_hitstop: PackedFloat32Array = [0.05, 0.05, 0.09]
## Amplitude du tremblement de caméra par coup.
@export var combo_shake: PackedFloat32Array = [0.12, 0.16, 0.32]
@export var combo_window_time: float = 0.15 ## buffer d'entrée (§ 7)
@export var attack_magnet_radius: float = 2.5
@export var attack_magnet_cone_deg: float = 30.0

# ----------------------------------------------------------------#
# § 8.3 Esquive                                                   #
# ----------------------------------------------------------------#
@export var dodge_duration: float = 0.35
@export var dodge_iframes: float = 0.25
@export var dodge_distance: float = 3.6     ## m
@export var dodge_cooldown: float = 0.6
@export var perfect_dodge_window: float = 0.12   ## < 0,12 s avant l'impact
@export var perfect_dodge_slow_scale: float = 0.3
@export var perfect_dodge_slow_time: float = 0.3
@export var perfect_dodge_energy: float = 10.0

# ----------------------------------------------------------------#
# § 8.4 Garde                                                     #
# ----------------------------------------------------------------#
@export var guard_damage_taken: float = 0.3   ## −70 % de dégâts
@export var perfect_guard_window: float = 0.18
@export var perfect_guard_stun: float = 0.8   ## ennemi étourdi
@export var perfect_guard_energy: float = 15.0
@export var perfect_guard_counter_mult: float = 1.6  ## contre-attaque (× base)
@export var guard_stability_max: float = 30.0
@export var guard_stability_per_hit: float = 5.0
@export var guard_stability_regen: float = 5.0    ## par seconde
@export var guard_broken_stun: float = 0.6

# ----------------------------------------------------------------#
# § 8.5 Spécial (sabre : tourbillon 360°)                         #
# ----------------------------------------------------------------#
@export var special_cost: float = 100.0
@export var special_duration: float = 0.9     ## durée de l'animation
@export var special_damage_mult: float = 3.0
@export var special_radius: float = 2.5       ## m autour de la joueuse
@export var special_hit_from: float = 0.10    ## fenêtre de la Hitbox (s)
@export var special_hit_to: float = 0.75
@export var special_hitstop: float = 0.15
@export var special_invincible: float = 1.0
@export var special_shake: float = 0.35
@export var energy_per_hit: float = 6.0       ## par coup donné
@export var energy_when_hit: float = 3.0      ## si la joueuse est touchée

# ----------------------------------------------------------------#
# § 8.6 Dégâts reçus                                              #
# ----------------------------------------------------------------#
@export var hurt_iframes: float = 0.8
@export var hurt_stun: float = 0.25
@export var hurt_knockback_mult: float = 4.0
@export var hit_shake: float = 0.22           ## tremblement quand on est touché

# ----------------------------------------------------------------#
# § 8.7 Critiques                                                 #
# ----------------------------------------------------------------#
@export var crit_chance: float = 0.08         ## 8 % de base
@export var crit_mult: float = 1.5

# ----------------------------------------------------------------#
# Mannequin d'entraînement (§ 9 : soldat)                         #
# ----------------------------------------------------------------#
@export var dummy_health: float = 120.0
@export var dummy_damage: float = 12.0
@export var dummy_telegraph: float = 0.4      ## télégraphe lisible
@export var dummy_swing: float = 0.18         ## fenêtre de sa Hitbox
@export var dummy_reach: float = 2.2
@export var dummy_period: float = 2.6         ## temps entre deux ripostes

# ----------------------------------------------------------------#
# Caméra ARENA (§ 3.2)                                            #
# ----------------------------------------------------------------#
@export var lock_radius: float = 8.0          ## cible la plus proche dans 8 m


## Tirage d'un coup : 8 % de chances de critique à ×1,5 (§ 8.7).
## Retourne {amount, critical} — un seul endroit décide des critiques, donc le
## combo, le spécial et la contre-attaque les appliquent de la même façon.
func roll_damage(base_amount: float) -> Dictionary:
	var critical := randf() < crit_chance
	return {"amount": base_amount * (crit_mult if critical else 1.0), "critical": critical}


## Conversion en table de coups, au format attendu par Player3D et
## ComboController : [{len, mult, advance, hit_from, hit_to, win_from,
## knockback, hitstop, shake}, …].
func combo_steps() -> Array[Dictionary]:
	var count := mini(combo_len.size(), combo_mult.size())
	var step_list: Array[Dictionary] = []
	for i in count:
		step_list.append({
			"len": combo_len[i],
			"mult": combo_mult[i],
			"advance": _at(combo_advance, i, 0.0),
			"hit_from": _at(combo_hit_from, i, 0.12),
			"hit_to": _at(combo_hit_to, i, 0.30),
			"win_from": _at(combo_window_from, i, 0.30),
			"knockback": _at(combo_knockback, i, 1.2),
			"hitstop": _at(combo_hitstop, i, 0.05),
			"shake": _at(combo_shake, i, 0.12),
		})
	return step_list


func _at(values: PackedFloat32Array, index: int, fallback: float) -> float:
	return values[index] if index < values.size() else fallback
