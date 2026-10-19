extends Node
class_name WaveSpawner3D
## Apparition des vagues (DESIGN.md § 20.11 et § 4 : « ennemis à l'écran : 5 max,
## 6 en coop »). Lit `LevelData.enemy_waves` : la vague suivante démarre quand la
## précédente est nettoyée.
##
## Le spawner gère aussi les renforts du § 9 :
##  * garde d'alerte qui te voit -> +2 ennemis ;
##  * chef -> invoque un soldat toutes les 12 s.

const MAX_ON_SCREEN: int = 5               ## porté à 6 en coop (§ 22.3)
const SPAWN_DISTANCE: float = 12.0     ## m devant la joueuse (lane)
const SPAWN_LATERAL: float = 4.0

signal wave_started(index: int, total: int)
signal wave_cleared(index: int)
signal all_waves_cleared
## § 12.3 : toutes les 10 vagues, un boss entre dans l'arène.
signal boss_wave(index: int)

@export var delay_multiplier: float = 1.0   ## < 1 = plus rapide (tests)

var level_data: LevelData = null
var entities_root: Node3D = null
var level: Node3D = null                   ## LevelBase3D (position des joueuses)

var current_wave: int = 0                  ## index de la vague en cours
var alive: int = 0
var finished: bool = false
## § 12.3 (Survie) : vagues sans fin et compteur de vagues nettoyées.
var waves_cleared: int = 0
## § 12.3 : le niveau suspend le flux le temps du choix de bonus.
var flow_paused: bool = false

var _total_waves: int = 0
var _wave_alive: Array[Node] = []
var _rng := RandomNumberGenerator.new()


func setup(data: LevelData, root: Node3D, level_node: Node3D) -> void:
	# § 22.1 : l'hôte simule les vagues. Chez l'invitée, les ennemis arrivent par
	# le réseau : son spawner ne fait rien (sinon deux vagues indépendantes).
	if Network.is_coop() and not Network.is_host():
		finished = true
		level_data = data
		return
	level_data = data
	entities_root = root
	level = level_node
	_total_waves = data.enemy_waves.size()
	# Graine fixée par le niveau : deux parties du même .tres se ressemblent.
	_rng.seed = hash(data.id)
	Events.enemy_died.connect(_on_enemy_died)
	_run_waves()


func _run_waves() -> void:
	# § 12.3 : Survie = vagues sans fin, difficulté croissante, boss tous les 10.
	if level_data != null and level_data.endless:
		await _run_endless()
		return
	for wave in level_data.enemy_waves:
		if finished:
			return
		await _spawn_wave(_scaled(wave), current_wave)
		while _wave_alive.size() > 0:
			await get_tree().create_timer(0.25 * delay_multiplier).timeout
		wave_cleared.emit(current_wave)
		current_wave += 1
	finished = true
	all_waves_cleared.emit()


## Survie (§ 12.3) : la même boucle, mais les vagues sont FABRIQUÉES à la volée
## et la difficulté monte toutes les 5 vagues.
func _run_endless() -> void:
	_total_waves = 0
	while not finished:
		var index := current_wave
		var wave := _endless_wave(index)
		await _spawn_wave(wave, index)
		while _wave_alive.size() > 0 and not finished:
			await get_tree().create_timer(0.25 * delay_multiplier).timeout
		waves_cleared += 1
		wave_cleared.emit(index)
		current_wave += 1
		# § 12.3 : bonus entre les vagues — rien ne démarre avant le choix.
		await _wait_flow()
		# § 12.3 : « Boss toutes les 10 vagues ».
		if current_wave % 10 == 0:
			boss_wave.emit(current_wave)
		if finished:
			return
		await get_tree().create_timer(1.4 * delay_multiplier).timeout


## Attend la fin d'un choix de bonus (§ 12.3) sans bloquer la boucle.
func _wait_flow() -> void:
	while flow_paused and not finished:
		await get_tree().create_timer(0.1 * delay_multiplier).timeout


## Composition d'une vague de Survie : une nouveauté toutes les quelques vagues,
## puis des effectifs qui montent (plafonnés par § 4 : 5 ennemis à l'écran).
func _endless_wave(index: int) -> WaveData:
	var step := index / 5                     # palier de difficulté
	var wave := WaveData.new()
	var entries: Array[SpawnEntry] = []
	entries.append(_entry("soldier", mini(2 + step, 5)))
	if index >= 1:
		entries.append(_entry("scout", mini(1 + step / 2, 3)))
	if index >= 2:
		entries.append(_entry("archer", mini(1 + step / 3, 2)))
	if index >= 4:
		entries.append(_entry("brute", 1))
	if index >= 6:
		entries.append(_entry("guard", 1))
	if index >= 8:
		entries.append(_entry("chief", 1))
	wave.enemies = entries
	wave.delay = maxf(0.6, 1.3 - 0.05 * float(step))
	wave.start_delay = 0.6
	return wave


## § 22.3 : en coop, 6 ennemis à l'écran au lieu de 5.
func _max_on_screen() -> int:
	return Network.coop_max_on_screen()


## § 22.3 : « nombre d'ennemis ×1,3 » (arrondi au supérieur).
func _count_for(count: int) -> int:
	var mult := Network.coop_count_mult()
	if is_equal_approx(mult, 1.0):
		return count
	return int(ceil(float(count) * mult))


func _entry(type_name: String, count: int) -> SpawnEntry:
	var entry := SpawnEntry.new()
	entry.type = type_name
	entry.count = _count_for(count)
	return entry


## Les vagues écrites à la main (campagne) passent aussi par la difficulté coop.
func _scaled(wave: WaveData) -> WaveData:
	if is_equal_approx(Network.coop_count_mult(), 1.0):
		return wave
	var out := WaveData.new()
	var entries: Array[SpawnEntry] = []
	for entry in wave.enemies:
		entries.append(_entry(entry.type, entry.count))
	out.enemies = entries
	out.delay = wave.delay
	out.start_delay = wave.start_delay
	return out


func _spawn_wave(wave: WaveData, index: int) -> void:
	wave_started.emit(index, _total_waves)
	await get_tree().create_timer(wave.start_delay * delay_multiplier).timeout
	for entry in wave.enemies:
		for i in maxi(0, entry.count):
			if finished:
				return
			while alive >= _max_on_screen():
				await get_tree().create_timer(0.3 * delay_multiplier).timeout
			spawn(entry.type, _spawn_point())
			await get_tree().create_timer(wave.delay * delay_multiplier).timeout


## Fait apparaître un ennemi d'un type donné (§ 9). `data` est posée AVANT
## `_ready()` : l'ennemi connaît sa fiche dès sa première frame.
## § 22.1 : en coop, l'ennemi naît sur l'hôte et se réplique ; l'invitée n'a
## rien à créer (son spawner ne tourne pas).
func spawn(type_name: String, at: Vector3) -> EnemyBase3D:
	if Network.is_coop():
		var director: CoopDirector = level.get("coop") if level != null else null
		if director == null:
			return null
		var cooked := director.spawn_enemy(type_name, at)
		if cooked != null:
			_track(cooked)      # `alive` : sans ça la vague ne se croirait jamais pleine
		return cooked
	var scene := EnemyRegistry.get_scene()
	if scene == null:
		push_warning("WaveSpawner3D : scène d'ennemi introuvable")
		return null
	var enemy := scene.instantiate() as EnemyBase3D
	if enemy == null:
		return null
	enemy.data = EnemyRegistry.get_data(type_name)
	enemy.position = at
	if level_data != null:
		enemy.lane_mode = level_data.is_lane()
		enemy.lane_depth = level_data.lane_half_depth
		enemy.lane_center_z = 0.0
	entities_root.add_child(enemy)
	_track(enemy)
	# § 3.1 : en arène, l'ennemi voit la joueuse dès qu'il apparaît.
	if level_data != null and not level_data.is_lane():
		var player := _player_node()
		if player != null:
			enemy.hunt(player)
	return enemy


## Renforts d'un garde d'alerte (§ 9 : « alerte (+2 ennemis) »).
func spawn_reinforcements(type_name: String, count: int, around: Vector3) -> Array[EnemyBase3D]:
	var out: Array[EnemyBase3D] = []
	for i in count:
		var offset := Vector3(_rng.randf_range(-3.0, 3.0), 0.0, _rng.randf_range(-2.0, 2.0))
		out.append(spawn(type_name, around + offset))
	return out


func _track(enemy: EnemyBase3D) -> void:
	if enemy == null:
		return
	alive += 1
	_wave_alive.append(enemy)
	enemy.died.connect(_on_enemy_died_signal)
	enemy.alerted.connect(_on_enemy_alerted)
	enemy.summons.connect(_on_enemy_summons)


func _on_enemy_died_signal(enemy: Node, _cauris: int) -> void:
	_drop(enemy)


func _on_enemy_died(enemy: Node) -> void:
	## Filet de sécurité : un ennemi détruit sans passer par `died`.
	if _wave_alive.has(enemy):
		_drop(enemy)


func _drop(enemy: Node) -> void:
	if not _wave_alive.has(enemy):
		return
	_wave_alive.erase(enemy)
	alive = maxi(0, alive - 1)


## § 9 : « s'il te voit : alerte (+2 ennemis) ».
func _on_enemy_alerted(_enemy: Node, at: Vector3, count: int) -> void:
	if count <= 0 or finished and _wave_alive.is_empty():
		return
	for i in count:
		spawn("soldier", at + Vector3(_rng.randf_range(1.0, 3.0), 0.0, _rng.randf_range(-2.0, 2.0)))


## § 9 : le chef invoque un soldat toutes les 12 s.
func _on_enemy_summons(_enemy: Node, type_name: String, at: Vector3) -> void:
	if finished and _wave_alive.is_empty():
		return
	spawn(type_name, at)


# -----------------------------------------------------------------#
#                       PLACEMENT                                  #
# -----------------------------------------------------------------#

## Point d'apparition : devant la joueuse en couloir (§ 3.1, axe X), sur le bord
## du disque en arène (§ 3.1, rayon 14 m).
func _spawn_point() -> Vector3:
	if level_data == null:
		return Vector3(SPAWN_DISTANCE, 0.0, 0.0)
	var anchor := _player_position()
	if level_data.is_lane():
		var x := anchor.x + SPAWN_DISTANCE + _rng.randf_range(0.0, 4.0)
		x = clampf(x, 4.0, maxf(4.0, level_data.length_m - 2.0))
		var z := _rng.randf_range(-level_data.lane_half_depth, level_data.lane_half_depth)
		return Vector3(x, 0.0, z)
	var angle := _rng.randf() * TAU
	var radius := level_data.arena_radius - 3.0
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


## Joueur local (premier du groupe), pour l'alerte en arène.
func _player_node() -> Player3D:
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return null
	return players[0] as Player3D


func _player_position() -> Vector3:
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return Vector3.ZERO
	return (players[0] as Node3D).global_position


## Ennemis encore vivants de la vague en cours (liste réelle, sans les morts).
func living() -> Array[Node]:
	var out: Array[Node] = []
	for enemy in _wave_alive:
		if is_instance_valid(enemy) and enemy.get("dead") != true:
			out.append(enemy)
	return out


func total_waves() -> int:
	return _total_waves
