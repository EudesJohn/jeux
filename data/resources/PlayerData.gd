extends Resource
class_name PlayerData
## Stats de la joueuse (DOSSIER.md § 21.3, valeurs § 8.1). Tout en unités de
## jeu (1 = 1 m). Le .tres de ce Resource est `data/player_default.tres`.

@export var max_health: float = 100.0
@export var max_energy: float = 100.0
@export var speed: float = 4.5          ## m/s, course
@export var accel: float = 30.0         ## m/s², arrêt net / contrôle précis
@export var turn_speed: float = 14.0    ## rad/s, rotation du modèle vers la cible
@export var guard_speed: float = 1.4    ## m/s en garde (§ 8.4)
@export var dodge_duration: float = 0.35
@export var dodge_iframes: float = 0.25
@export var dodge_speed: float = 10.3   ## 3,6 m en 0,35 s (§ 8.3)
@export var dodge_cooldown: float = 0.6
@export var perfect_guard_window: float = 0.18  ## utilisé en PHASE 2
@export var hurt_iframes: float = 0.8   ## § 8.6
@export var model_scene: PackedScene    ## § 6.6 : remplaçable sans toucher au code
