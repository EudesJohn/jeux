extends Node
class_name AudioDirector
## Branchement de l'audio sur le combat (§ 17). Un seul nœud à poser dans un
## niveau : il écoute `Events` (règle 3 du § 18) et traduit en sons, au lieu de
## parsemer des `play_sfx()` dans six scripts.
##
## * intensité musicale : nombre d'ennemis vivants + vie de la joueuse + gardien ;
## * bruits de combat 2D : coups, garde parfaite, esquive parfaite, cauris… ;
## * bruits d'ennemis en 3D positionnel (§ 17), portée courte ;
## * voix + sous-titres aux moments clés (début de niveau, vie basse, victoire).

const INTENSITY_LERP: float = 1.2          ## vitesse de montée du morceau
const STEP_INTERVAL: float = 0.42          ## pas de la joueuse (§ 17)
const LOW_HEALTH_RATIO: float = 0.3

## Le directeur du niveau en cours : les scripts de combat (joueuse) s'y
## accrochent sans connaître la scène (§ 18 règle 3).
static var current: AudioDirector = null

var level: LevelBase3D = null
var player: Player3D = null

var _target_intensity: float = 0.0
var _step_timer: float = 0.0
var _last_position: Vector3 = Vector3.ZERO
var _low_health_warned: bool = false


func setup(level_node: LevelBase3D, player_node: Player3D) -> void:
	current = self
	level = level_node
	_connect_events()
	AudioManager.play_music_set(&"level")
	AudioManager.set_intensity(0.0)
	AudioManager.play_voice(&"level_start")
	attach_player(player_node)


## En coop, la joueuse locale de l'invitée arrive après le décor (§ 22.2) :
## on la branche plus tard, sans relancer la musique ni la voix d'intro.
func attach_player(player_node: Player3D) -> void:
	player = player_node
	_last_position = player_node.global_position if player_node != null else Vector3.ZERO


func _connect_events() -> void:
	Events.enemy_died.connect(_on_enemy_died)
	Events.perfect_guard.connect(_on_perfect_guard)
	Events.perfect_dodge.connect(_on_perfect_dodge)
	Events.guard_broken.connect(_on_guard_broken)
	Events.player_damaged.connect(_on_player_damaged)
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.boss_defeated.connect(_on_boss_defeated)


func _exit_tree() -> void:
	if current == self:
		current = null
	if Events.enemy_died.is_connected(_on_enemy_died):
		Events.enemy_died.disconnect(_on_enemy_died)
		Events.perfect_guard.disconnect(_on_perfect_guard)
		Events.perfect_dodge.disconnect(_on_perfect_dodge)
		Events.guard_broken.disconnect(_on_guard_broken)
		Events.player_damaged.disconnect(_on_player_damaged)
		Events.boss_spawned.disconnect(_on_boss_spawned)
		Events.boss_defeated.disconnect(_on_boss_defeated)


# -----------------------------------------------------------------#
#                        INTENSITÉ MUSICALE                        #
# -----------------------------------------------------------------#

func _process(delta: float) -> void:
	_target_intensity = _compute_intensity()
	AudioManager.intensity = lerpf(AudioManager.intensity, _target_intensity,
		1.0 - exp(-INTENSITY_LERP * delta))
	AudioManager.set_intensity(AudioManager.intensity)
	_tick_footsteps(delta)


## § 17 : l'intensité monte avec le nombre d'ennemis, la baisse de vie et la
## présence d'un gardien.
func _compute_intensity() -> float:
	var alive := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node3D and (enemy as Node3D).get("dead") != true:
			alive += 1
	var crowd := clampf(float(alive) / 4.0, 0.0, 1.0)
	var hurt := 0.0
	if player != null and is_instance_valid(player) and player.balance != null:
		var ratio := clampf(player.health / maxf(player.max_health_value(), 0.001), 0.0, 1.0)
		hurt = clampf(1.0 - ratio, 0.0, 1.0)
	var boss := 0.0
	if level != null and is_instance_valid(level) and level.boss != null:
		boss = 0.35
	return clampf(crowd * 0.55 + hurt * 0.45 + boss, 0.0, 1.0)


## § 17 : « pas (selon le sol) ». Un pas tous les ~0,4 s en courant, plus lent
## à l'arrêt (aucun pas à l'arrêt).
func _tick_footsteps(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.state == Player3D.State.DEAD:
		return
	var moved := player.global_position.distance_to(_last_position)
	_last_position = player.global_position
	if moved < 0.02:
		_step_timer = 0.0
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = STEP_INTERVAL
		AudioManager.play_sfx(&"step", randf_range(0.92, 1.08), -12.0)


# -----------------------------------------------------------------#
#                         SONS DU COMBAT                           #
# -----------------------------------------------------------------#

## La joueuse frappe : sifflement au départ, impact géré par la Hitbox.
func swing(pitch: float = 1.0) -> void:
	AudioManager.play_sfx(&"swing", pitch, -8.0)


func hit_landed(critical: bool) -> void:
	AudioManager.play_sfx(&"crit" if critical else &"hit", randf_range(0.95, 1.06))


func _on_enemy_died(enemy: Node) -> void:
	AudioManager.play_sfx_at(enemy as Node3D, &"death_enemy", randf_range(0.9, 1.1))


func _on_perfect_guard(_actor: Node) -> void:
	AudioManager.play_sfx(&"guard_perfect")


func _on_perfect_dodge(_actor: Node) -> void:
	AudioManager.play_sfx(&"dodge")


func _on_guard_broken(_actor: Node) -> void:
	AudioManager.play_sfx(&"block", 0.7)


func _on_player_damaged(_actor: Node, _amount: float) -> void:
	AudioManager.play_sfx(&"hurt", randf_range(0.95, 1.05))
	_check_low_health()


func _on_boss_spawned(boss: Node) -> void:
	AudioManager.play_sfx_at(boss as Node3D, &"boss_roar")
	AudioManager.set_intensity(1.0)


func _on_boss_defeated(_boss: Node) -> void:
	AudioManager.play_sfx(&"victory", 0.8)


## Voix d'alerte quand la joueuse passe sous 30 % de vie (une fois par vie
## basse : pas de répétition à chaque coup).
func _check_low_health() -> void:
	if player == null or not is_instance_valid(player) or player.balance == null:
		return
	var ratio := player.health / maxf(player.max_health_value(), 0.001)
	if ratio <= LOW_HEALTH_RATIO and not _low_health_warned:
		_low_health_warned = true
		AudioManager.play_voice(&"low_health")
	elif ratio > LOW_HEALTH_RATIO + 0.15:
		_low_health_warned = false


func revive_call() -> void:
	AudioManager.play_voice(&"revive")


func victory() -> void:
	AudioManager.play_sfx(&"victory")
	AudioManager.play_voice(&"victory")


func defeat() -> void:
	AudioManager.play_sfx(&"defeat")
	AudioManager.play_voice(&"defeat")
