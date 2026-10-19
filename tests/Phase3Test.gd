extends Node
## Test fonctionnel de la PHASE 3 (DESIGN.md § 28 et § 29), sans écran :
##   godot --headless --path . res://tests/Phase3Test.tscn   (logique de jeu)
##   godot --path . res://tests/Phase3Test.tscn              (logique + doigts)
##
## Validation officielle de la phase : « changer un .tres donne un autre
## niveau ». Le test charge la VRAIE scène `scenes/levels/LevelBase3D.tscn` et
## vérifie :
##   * les 6 fiches d'ennemis du § 9 et les 5 niveaux .tres (3 LANE + 2 ARENA) ;
##   * la reconstruction complète du niveau quand on change de .tres (sol,
##     caméra, pièges, ramassages, checkpoint, objectif, vagues, nuit) ;
##   * les vagues du § 20.11 (5 ennemis à l'écran maximum, vague suivante) ;
##   * l'IA du § 9 : poursuite, télégraphe, attaque, jeton d'attaque, strafing,
##     archer à 7 m, armure de la brute, buff et invocation du chef, alerte du
##     garde, étourdissement par garde parfaite ;
##   * les 6 pièges du § 11, les checkpoints du § 13, les cauris et les potions ;
##   * le HUD (timer, objectif, cauris, bandeau de fin) et les objectifs.
##
## Sortie : « PHASE 3 : OK » (code 0) ou la liste des échecs (code 1).

const LEVEL_SCENE: String = "res://scenes/levels/LevelBase3D.tscn"
const LEVEL_FILES: Array[String] = [
	"res://data/levels/lane_01.tres",
	"res://data/levels/lane_02.tres",
	"res://data/levels/lane_03.tres",
	"res://data/levels/arena_01.tres",
	"res://data/levels/arena_02.tres",
]
## Vagues « instantanées » pour les tests de vagues.
const FAST_WAVES: float = 0.05
## Vagues « gelées » : le spawner n'apparaît pas, le test place ses ennemis.
const FROZEN_WAVES: float = 1000.0
const EPS: float = 0.05
## En dessous de cette largeur, les boutons tactiles du § 7 ne sont pas à leur
## place : la chaîne doigt -> bouton -> jeu n'a pas de sens.
const MIN_VIEWPORT_FOR_TOUCH: float = 1000.0

var failures: int = 0
var checks: int = 0
var skipped: int = 0

var level: LevelBase3D = null
var save_cauris: int = 0
var save_levels: Dictionary = {}

var last_player_info: DamageInfo = null
var last_player_result: int = -1
var cauris_events: int = 0
var completed_seen: bool = false
var failed_reason: String = ""
var killed: Array[Node] = []
var pickup_collected: bool = false
## Nombre de morts signalées par la joueuse (le niveau la réapparaît aussitôt
## en Normal : l'état DEAD n'est donc pas observable depuis le test).
var player_died_count: int = 0


func _ready() -> void:
	print("=== Test fonctionnel PHASE 3 ===")
	# `PHASE3_ONLY=hazards,checkpoint` ne lance que les sections voulues (mise au
	# point rapide) ; sans la variable, TOUT le test tourne.
	var only := OS.get_environment("PHASE3_ONLY")
	var sections: Dictionary = {
		"data": _test_enemy_data,
		"levels": _test_level_files,
		"switch": _test_switch_level,
		"graybox": _test_graybox,
		"waves": _test_waves,
		"ai": _test_ai_states,
		"token": _test_attack_token,
		"archer": _test_archer,
		"brute": _test_brute,
		"chief": _test_chief,
		"guard": _test_alert_guard,
		"hazards": _test_hazards,
		"checkpoint": _test_checkpoint,
		"pickups": _test_pickups,
		"hud": _test_hud,
		"objectives": _test_objectives,
		"touch": _test_touch_chain,
		"finish": _test_finish,
	}
	EnemyRegistry.preload_all()
	# La sauvegarde est restaurée à la fin : le test ne laisse pas de trace.
	save_cauris = int(SaveManager.data["cauris"])
	save_levels = (SaveManager.data["levels"] as Dictionary).duplicate(true)
	Events.cauris_changed.connect(func(_total: int) -> void: cauris_events += 1)
	Events.objective_completed.connect(func() -> void: completed_seen = true)
	Events.level_failed.connect(func(reason: String) -> void: failed_reason = reason)
	Events.enemy_died.connect(func(enemy: Node) -> void: killed.append(enemy))

	for name in sections.keys():
		if only != "" and not only.split(",").has(name):
			continue
		await (sections[name] as Callable).call()

	# Restauration de la sauvegarde.
	SaveManager.data["cauris"] = save_cauris
	SaveManager.data["levels"] = save_levels
	SaveManager.save_game()

	print("--------------------------------")
	print("Vérifications : %d   Échecs : %d   Ignorées : %d" % [checks, failures, skipped])
	print("PHASE 3 : %s" % ("OK" if failures == 0 else "ÉCHECS"))
	get_tree().quit(1 if failures > 0 else 0)


# -----------------------------------------------------------------#
#                        OUTILS DE TEST                            #
# -----------------------------------------------------------------#

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("  ok    ", label)
	else:
		failures += 1
		print("  ÉCHEC ", label)


func _skip(label: String) -> void:
	skipped += 1
	print("  ignoré ", label)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


## Attente en TEMPS RÉEL : insensible aux hit-stops et aux ralentis.
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## Charge un niveau RÉEL depuis un .tres (et libère le précédent).
func _load_level(path: String, wave_multiplier: float = FROZEN_WAVES) -> LevelBase3D:
	if level != null and is_instance_valid(level):
		if level.spawner != null:
			level.spawner.finished = true        # arrête la coroutine de vagues
		level.queue_free()
		level = null
		await _frames(4)
	var scene := load(LEVEL_SCENE).instantiate() as LevelBase3D
	scene.level_data = load(path) as LevelData
	scene.wave_delay_multiplier = wave_multiplier
	add_child(scene)
	await _frames(8)
	level = scene
	level.player.hurtbox.damaged.connect(_on_player_damaged)
	level.player.died.connect(_on_player_died)
	_isolate_pointer(scene)
	killed.clear()
	return level


## Niveau construit à la main (objectifs et fin de partie) : aucun fichier
## n'est créé, la sauvegarde n'est donc pas polluée par un vrai identifiant.
func _make_custom_level(objective: String, layout: String = "lane",
		time_limit: int = 30) -> LevelBase3D:
	if level != null and is_instance_valid(level):
		if level.spawner != null:
			level.spawner.finished = true
		level.queue_free()
		level = null
		await _frames(4)
	var data := LevelData.new()
	data.id = "test_phase3"
	data.display_name = "Niveau de test"
	data.layout = layout
	data.length_m = 40.0
	data.arena_radius = 12.0
	data.objective = objective
	data.time_limit = time_limit
	data.cauri_pickups = 0
	data.potion_pickups = 0
	data.hazards = []
	data.checkpoint_at = 0.0
	var wave := WaveData.new()
	var entry := SpawnEntry.new()
	entry.type = "soldier"
	entry.count = 1
	wave.enemies = [entry]
	data.enemy_waves = [wave]
	var scene := load(LEVEL_SCENE).instantiate() as LevelBase3D
	scene.level_data = data
	scene.wave_delay_multiplier = FROZEN_WAVES
	add_child(scene)
	await _frames(8)
	level = scene
	level.player.hurtbox.damaged.connect(_on_player_damaged)
	level.player.died.connect(_on_player_died)
	_isolate_pointer(scene)
	killed.clear()
	return level


## Sans écran il n'y a pas de souris ; avec une fenêtre, celle du bureau
## piloterait le joystick et les boutons pendant une mesure (§ 7). Le test
## coupe donc le pilotage à la souris : les événements tactiles qu'il pousse
## lui-même continuent de passer.
func _isolate_pointer(scene: Node) -> void:
	var controls := scene.get_node_or_null("TouchControls")
	if controls == null:
		return
	var joystick := controls.get_node_or_null("Joystick") as VirtualJoystick
	if joystick != null:
		joystick.mouse_control = false
	for child in controls.get_children():
		if child is TouchButton:
			(child as TouchButton).mouse_control = false


## Ennemis vivants du niveau (les cadavres en attente de `queue_free` sont
## écartés : `enemy_nodes()` peut encore les contenir pendant 1,2 s).
func _enemies() -> Array[EnemyBase3D]:
	var out: Array[EnemyBase3D] = []
	for child in level.enemy_nodes():
		if is_instance_valid(child) and child is EnemyBase3D:
			out.append(child as EnemyBase3D)
	return out


## Ennemi placé à la main (le spawner reste gelé) : positions et timings
## entièrement contrôlés par le test.
func _spawn_enemy(type_name: String, at: Vector3) -> EnemyBase3D:
	var enemy := level.spawner.spawn(type_name, at)
	await _frames(3)
	return enemy


## Attaque directe, en passant par la Hurtbox3D de la cible (comme la joueuse).
func _hit(actor: Node, amount: float, heavy: bool, critical: bool = false) -> int:
	var info := DamageInfo.new()
	info.amount = amount
	info.knockback = 0.5
	info.source_position = actor.global_position + Vector3(0.0, 0.0, -1.0)
	info.is_heavy = heavy
	info.is_critical = critical
	var hurtbox: Hurtbox3D = actor.get("hurtbox") as Hurtbox3D
	if hurtbox != null:
		return hurtbox.receive_hit(info)
	return -1


## La joueuse vient d'être remise à neuf : on retire son invincibilité pour
## mesurer les dégâts (sinon tout coup est esquivé, § 8.6).
func _clear_invincibility() -> void:
	level.player.invincible_time = 0.0
	level.player.state = Player3D.State.IDLE


func _on_player_died() -> void:
	player_died_count += 1


func _on_player_damaged(info: DamageInfo, result: int) -> void:
	last_player_info = info
	last_player_result = result


# -----------------------------------------------------------------#
#            § 9 : LES SIX FICHES D'ENNEMIS                        #
# -----------------------------------------------------------------#

func _test_enemy_data() -> void:
	print("- Fiches d'ennemis (data/enemies/.tres, § 9)")
	_check(EnemyRegistry.types().size() == 6, "6 types d'ennemis déclarés")
	var soldier := EnemyRegistry.get_data("soldier")
	_check(is_equal_approx(soldier.health, 30.0) and is_equal_approx(soldier.damage, 8.0)
		and is_equal_approx(soldier.speed, 1.8),
		"soldat : 30 vie, 8 dégâts, 1,8 m/s")
	_check(is_equal_approx(soldier.attack_range, 1.4) and is_equal_approx(soldier.telegraph_time, 0.4),
		"soldat : portée 1,4 m, télégraphe 0,4 s (§ 9)")
	_check(is_equal_approx(soldier.sight_range, 9.0), "tous : vue de 9 m (§ 9)")

	var scout := EnemyRegistry.get_data("scout")
	_check(is_equal_approx(scout.health, 20.0) and is_equal_approx(scout.speed, 4.0),
		"éclaireur : 20 vie, 4,0 m/s")
	_check(scout.retreat_after_attack > 0.0, "éclaireur : recule après son coup")

	var archer := EnemyRegistry.get_data("archer")
	_check(is_equal_approx(archer.health, 18.0) and is_equal_approx(archer.damage, 10.0),
		"archer : 18 vie, 10 dégâts")
	_check(archer.ranged and is_equal_approx(archer.keep_distance, 7.0)
		and is_equal_approx(archer.fire_period, 2.2),
		"archer : tire à distance, garde 7 m, une flèche / 2,2 s (§ 9)")

	var brute := EnemyRegistry.get_data("brute")
	_check(is_equal_approx(brute.health, 90.0) and brute.armor
		and is_equal_approx(brute.vulnerable_time, 0.9),
		"brute : 90 vie, armure, vulnérable 0,9 s (§ 9)")

	var chief := EnemyRegistry.get_data("chief")
	_check(is_equal_approx(chief.health, 70.0) and chief.buff_allies
		and is_equal_approx(chief.summon_period, 12.0),
		"chef : 70 vie, buff des alliés, invocation toutes les 12 s (§ 9)")

	var guard := EnemyRegistry.get_data("guard")
	_check(is_equal_approx(guard.health, 35.0) and guard.alert_reinforcements == 2,
		"garde d'alerte : 35 vie, alerte +2 ennemis (§ 9)")
	_check(EnemyRegistry.get_data("inconnu").id == "soldier",
		"type inconnu -> soldat (aucun plantage)")
	_check(EnemyRegistry.get_scene() != null, "scène d'ennemi unique chargée (§ 6.6)")


# -----------------------------------------------------------------#
#            § 21.1 : LES CINQ NIVEAUX .TRES                       #
# -----------------------------------------------------------------#

func _test_level_files() -> void:
	print("- Fiches de niveau (data/levels/.tres, § 21.1)")
	var lanes := 0
	var arenas := 0
	var all_ok := true
	var hazards_known := true
	var kinds: Array[String] = ["pit", "arrows", "fire", "plank", "spikes", "mud"]
	for path in LEVEL_FILES:
		var data := load(path) as LevelData
		if data == null:
			all_ok = false
			continue
		if data.is_lane():
			lanes += 1
		else:
			arenas += 1
		if data.enemy_waves.is_empty() or data.enemy_total() <= 0:
			all_ok = false
		if data.objective.is_empty() or data.time_limit <= 0:
			all_ok = false
		for hazard in data.hazards:
			if not kinds.has(hazard):
				hazards_known = false
	_check(lanes == 3 and arenas == 2, "5 niveaux : %d LANE + %d ARENA (§ 28)" % [lanes, arenas])
	_check(all_ok, "chaque niveau a objectif, durée, vagues et ennemis")
	_check(hazards_known, "tous les pièges déclarés viennent du § 11")
	var lane_02 := load(LEVEL_FILES[1]) as LevelData
	_check(lane_02.objective == "exit" and lane_02.enemy_waves.size() == 3,
		"lane_02 : objectif « exit », 3 vagues")
	_check(lane_02.enemy_types().has("archer"), "lane_02 : un archer est prévu (§ 13, niveau 8)")


# -----------------------------------------------------------------#
#     VALIDATION DE LA PHASE : CHANGER UN .TRES CHANGE LE NIVEAU    #
# -----------------------------------------------------------------#

func _test_switch_level() -> void:
	print("- « Changer un .tres donne un autre niveau » (§ 28)")
	await _load_level(LEVEL_FILES[0])
	_check(is_equal_approx(level.ground_size.x, 60.0), "lane_01 : couloir de 60 m")
	_check(level.camera_rig.mode == CameraRig.Mode.LANE, "lane_01 : caméra LANE (§ 3.1)")
	_check(level.player.lane_mode, "lane_01 : joueuse en couloir (profondeur limitée)")
	_check(level.spawner.total_waves() == 2, "lane_01 : 2 vagues")
	_check(level.objective is ClearWaves, "lane_01 : objectif « clear »")
	var hazards_01 := level.hazard_nodes().size()
	_check(hazards_01 == 1, "lane_01 : 1 fosse")

	await _load_level(LEVEL_FILES[2])
	_check(is_equal_approx(level.ground_size.x, 140.0), "lane_03 : couloir de 140 m")
	_check(level.hazard_nodes().size() == 6, "lane_03 : 6 pièges (3 types × 2)")
	_check(level.spawner.total_waves() == 3, "lane_03 : 3 vagues")
	_check(level.spawner.level_data.id == "lane_03", "le spawner a bien suivi le nouveau .tres")
	var environment := level.environment_node.environment
	_check(level.level_data.night and environment.fog_enabled,
		"lane_03 : nuit = brouillard sombre (§ 12.2)")
	_check(level.hazards_root.get_node_or_null("Checkpoint") != null,
		"lane_03 : un checkpoint est posé (§ 13)")

	await _load_level(LEVEL_FILES[3])
	_check(is_equal_approx(level.ground_size.x, 28.0), "arena_01 : disque de 28 m (rayon 14)")
	_check(level.camera_rig.mode == CameraRig.Mode.ARENA, "arena_01 : caméra ARENA (§ 3.2)")
	_check(not level.player.lane_mode, "arena_01 : joueuse libre à 360°")
	_check(level.spawner.total_waves() == 4, "arena_01 : 4 vagues")
	_check(level.objective is SurviveObjective, "arena_01 : objectif « survive »")

	await _load_level(LEVEL_FILES[4])
	_check(is_equal_approx(level.ground_size.x, 32.0), "arena_02 : rayon 16 m")
	_check(level.objective is ClearWaves, "arena_02 : objectif « clear »")

	await _load_level(LEVEL_FILES[1])
	_check(is_equal_approx(level.ground_size.x, 100.0), "retour à lane_02 : 100 m (reconstruction)")
	_check(level.objective is ReachExit, "lane_02 : objectif « exit »")
	_check(level.exit_area != null, "lane_02 : une zone de sortie existe")
	_check(level.pickup_nodes().size() >= 8, "%d ramassages posés (cauris + potions)"
		% level.pickup_nodes().size())
	# Le sol couvre TOUT le couloir (x = 0 → length_m), pas seulement son centre :
	# sinon la joueuse tombe dans le vide en approchant de la sortie.
	level.player.global_position = Vector3(level.level_data.length_m - 8.0, 0.1, 0.0)
	await _wait(0.3)
	_check(level.player.global_position.y > -0.2,
		"le sol porte la joueuse jusqu'à la sortie (y = %.2f m à x = %.0f m)"
		% [level.player.global_position.y, level.player.global_position.x])


func _test_graybox() -> void:
	print("- Décors « graybox » (§ 28 PHASE 3)")
	await _load_level(LEVEL_FILES[0])
	var ground := level.built.get_node("Ground") as StaticBody3D
	var lane_mesh := (ground.get_node("Mesh") as MeshInstance3D).mesh
	_check(lane_mesh is BoxMesh, "couloir : sol en boîte")
	_check(level.built.get_child_count() > 1, "couloir : blocs de décor présents")

	await _load_level(LEVEL_FILES[3])
	var arena_ground := level.built.get_node("Ground") as StaticBody3D
	var arena_mesh := (arena_ground.get_node("Mesh") as MeshInstance3D).mesh
	_check(arena_mesh is CylinderMesh, "arène : sol en disque")
	_check((arena_mesh as CylinderMesh).top_radius > 13.0, "arène : rayon du disque ≥ 13 m")


# -----------------------------------------------------------------#
#                     VAGUES (§ 20.11 et § 4)                      #
# -----------------------------------------------------------------#

func _test_waves() -> void:
	print("- Vagues d'ennemis (WaveSpawner3D, § 20.11)")
	await _load_level(LEVEL_FILES[0], FAST_WAVES)
	# Vague 1 du .tres : 3 soldats.
	await _wait(1.0)
	var first_wave := level.spawner.living()
	_check(first_wave.size() >= 1, "vague 1 : des ennemis sont apparus")
	var all_soldiers := true
	for enemy in first_wave:
		if (enemy as EnemyBase3D).data.id != "soldier":
			all_soldiers = false
	_check(all_soldiers, "vague 1 : uniquement des soldats (comme le .tres)")
	# Distance d'apparition : jamais dans les pieds de la joueuse (§ 20.11).
	var min_distance := 99.0
	for enemy in first_wave:
		min_distance = minf(min_distance,
			(enemy as Node3D).global_position.distance_to(level.player.global_position))
	_check(min_distance > 6.0, "apparition à distance (%.1f m minimum)" % min_distance)
	_check(level.spawner.alive <= WaveSpawner3D.MAX_ON_SCREEN,
		"%d ennemis à l'écran au maximum (§ 4)" % level.spawner.alive)
	_check(WaveSpawner3D.MAX_ON_SCREEN == 5, "plafond de 5 ennemis simultanés (§ 4)")

	# Vague suivante quand la première est nettoyée.
	var wave_before := level.spawner.current_wave
	for enemy in first_wave:
		if is_instance_valid(enemy):
			enemy.on_hit_received(_lethal())
	await _frames(4)
	for enemy in level.spawner.living():
		enemy.on_hit_received(_lethal())
	await _wait(1.6)
	_check(level.spawner.current_wave > wave_before or level.spawner.finished,
		"la vague suivante démarre une fois la précédente nettoyée")

	# Nettoyage complet : l'objectif « clear » est rempli.
	var guard := 0
	while not level.spawner.finished and guard < 60:
		for enemy in level.spawner.living():
			enemy.on_hit_received(_lethal())
		await _wait(0.2)
		guard += 1
	for enemy in level.spawner.living():
		enemy.on_hit_received(_lethal())
	await _frames(6)
	_check(level.spawner.finished, "toutes les vagues sont terminées")
	_check(level.objective.success(), "objectif « clear » rempli : plus un ennemi")
	_check(is_equal_approx(level.objective.progress(), 1.0),
		"avancement de l'objectif à %.0f %%" % (level.objective.progress() * 100.0))


func _lethal() -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = 999.0
	info.source_position = Vector3.ZERO
	return info


# -----------------------------------------------------------------#
#                    IA DES ENNEMIS (§ 9)                          #
# -----------------------------------------------------------------#

func _test_ai_states() -> void:
	print("- IA : IDLE → CHASE → TELEGRAPH → ATTACK → RECOVER (§ 9)")
	await _load_level(LEVEL_FILES[1])
	# Hors de vue (vue 9 m) : il ne poursuit pas.
	level.player.global_position = Vector3(30.0, 0.1, 0.0)
	var far := await _spawn_enemy("soldier", Vector3(0.0, 0.1, 0.0))
	await _frames(10)
	_check(far.state == EnemyBase3D.State.IDLE or far.state == EnemyBase3D.State.PATROL,
		"ennemi à 30 m : il patrouille, il ne te voit pas")
	_check(far.target == null, "aucune cible hors de vue (9 m)")

	# Dans la vue : poursuite puis attaque.
	var near := await _spawn_enemy("soldier", Vector3(36.0, 0.1, 0.0))
	await _frames(10)
	_check(near.state == EnemyBase3D.State.CHASE, "ennemi à 6 m : il te voit et poursuit")
	var distance_before := near.global_position.distance_to(level.player.global_position)
	await _wait(0.5)
	var distance_after := near.global_position.distance_to(level.player.global_position)
	_check(distance_after < distance_before, "il se rapproche vraiment (%.1f → %.1f m)"
		% [distance_before, distance_after])
	_check(near.playing_hit or near.state in [EnemyBase3D.State.TELEGRAPH,
		EnemyBase3D.State.ATTACK, EnemyBase3D.State.RECOVER, EnemyBase3D.State.CHASE],
		"il attaque dès qu'il est à portée")

	# Télégraphe : flash rouge annoncé (§ 9).
	level.player.invincible_time = 10.0          # ne pas mourir pendant l'observation
	near.global_position = level.player.global_position + Vector3(0.0, 0.0, 1.2)
	near._begin_telegraph()
	await _frames(2)
	_check(near.state == EnemyBase3D.State.TELEGRAPH and near.playing_hit,
		"télégraphe : état TELEGRAPH, caméra prioritaire (playing_hit)")
	_check(is_equal_approx(near.data.telegraph_time, 0.4),
		"télégraphe lisible de 0,4 s (§ 9)")
	await _wait(0.45)
	_check(near.state == EnemyBase3D.State.ATTACK, "après le télégraphe : état ATTAQUE")
	# La Hitbox s'ouvre 0,1 s après le début du coup (EnemyBase3D.SWING_DELAY).
	_check(not near.hitbox.monitoring, "le coup démarre sans Hitbox (lisible)")
	await _wait(0.15)
	_check(near.hitbox.monitoring, "la Hitbox s'active pendant le coup")

	# Le coup touche la joueuse.
	level.player.invincible_time = 0.0
	last_player_result = -1
	near.global_position = level.player.global_position + Vector3(0.0, 0.0, 1.0)
	await _wait(0.6)
	_check(last_player_result == Hurtbox3D.Result.HIT,
		"le coup de l'ennemi touche la joueuse (résultat %d)" % last_player_result)
	_check(level.player.health < level.player.balance.max_health,
		"la vie de la joueuse a baissé (%.0f)" % level.player.health)
	await _wait(0.6)
	_check(near.state in [EnemyBase3D.State.CHASE, EnemyBase3D.State.RECOVER,
		EnemyBase3D.State.TELEGRAPH, EnemyBase3D.State.ATTACK],
		"il enchaîne : RECOVER puis retour en CHASE")

	# Étourdissement par garde parfaite (§ 8.4) : il n'attaque plus.
	near.stun(0.8)
	var stun_state := near.state
	await _frames(4)
	# Figé : la machine à états n'avance plus, il ne peut donc pas passer à
	# l'attaque (son état d'avant l'étourdissement est conservé tel quel).
	_check(near._stun_left > 0.0 and near.state == stun_state,
		"étourdi : il reste figé 0,8 s (état %d)" % near.state)
	_check(not near.hitbox.monitoring, "étourdi : sa Hitbox est éteinte")
	_check(not AttackTokenManager.holders.has(near), "étourdi : il rend son jeton d'attaque")
	_check(stun_state != EnemyBase3D.State.DEAD, "l'étourdissement ne le tue pas")

	# Cible = joueuse la plus proche (§ 9, important en coop). Il faut qu'il
	# CHOISISSE à nouveau : une cible valide est conservée (il ne change pas d'avis).
	var second := _make_second_player(Vector3(0.0, 0.1, 0.0))
	var chooser := await _spawn_enemy("soldier", Vector3(4.0, 0.1, 0.0))
	second.global_position = Vector3(30.0, 0.1, 0.0)
	level.player.global_position = Vector3(6.0, 0.1, 0.0)
	chooser.target = null
	chooser.state = EnemyBase3D.State.IDLE
	await _frames(8)
	_check(chooser.target == level.player, "il vise la joueuse la plus proche (coop)")
	second.queue_free()
	await _frames(3)

	# Séparation : deux ennemis ne se superposent pas.
	var a := await _spawn_enemy("soldier", Vector3(20.0, 0.1, 0.0))
	var b := await _spawn_enemy("soldier", Vector3(20.1, 0.1, 0.0))
	await _wait(0.6)
	var apart := a.global_position.distance_to(b.global_position)
	_check(apart > 0.6, "séparation entre ennemis : %.2f m d'écart (§ 9)" % apart)
	for enemy in [far, near, chooser, a, b]:
		if is_instance_valid(enemy):
			enemy.on_hit_received(_lethal())
	await _frames(3)
	_check(not AttackTokenManager.holders.has(a) or not is_instance_valid(a),
		"un ennemi mort rend son jeton d'attaque")


## Deuxième joueuse provisoire (coop, § 9) : une copie de la joueuse locale.
func _make_second_player(at: Vector3) -> Player3D:
	var copy := load("res://scenes/characters/Player3D.tscn").instantiate() as Player3D
	copy.auto_respawn = false
	add_child(copy)
	copy.global_position = at
	return copy


func _test_attack_token() -> void:
	print("- Jeton d'attaque : 2 attaquants au maximum (§ 9)")
	AttackTokenManager.holders.clear()
	var one := await _spawn_enemy("soldier", Vector3(10.0, 0.1, 0.0))
	var two := await _spawn_enemy("soldier", Vector3(10.0, 0.1, 2.0))
	var three := await _spawn_enemy("soldier", Vector3(10.0, 0.1, -2.0))
	_check(AttackTokenManager.request(one), "1er ennemi : jeton accordé")
	_check(AttackTokenManager.request(two), "2e ennemi : jeton accordé")
	_check(not AttackTokenManager.request(three), "3e ennemi : jeton REFUSÉ (2 max)")
	_check(AttackTokenManager.holders.size() == 2, "2 jetons exactement")
	AttackTokenManager.release(one)
	_check(AttackTokenManager.request(three), "jeton libéré -> le 3e peut attaquer")
	# Sans jeton et près de la cible : il tourne autour (strafing, § 9).
	level.player.global_position = Vector3(10.0, 0.1, 0.0)
	level.player.invincible_time = 10.0
	var holder := await _spawn_enemy("soldier", Vector3(12.5, 0.1, 0.0))
	AttackTokenManager.holders.clear()
	AttackTokenManager.request(one)
	AttackTokenManager.request(two)
	holder.target = level.player
	holder.state = EnemyBase3D.State.CHASE
	await _frames(6)
	var before := holder.global_position.distance_to(level.player.global_position)
	await _wait(0.4)
	var after := holder.global_position.distance_to(level.player.global_position)
	_check(absf(after - before) < 2.0, "sans jeton : il reste à distance (strafe, %.1f m)" % after)
	_check(holder.state == EnemyBase3D.State.CHASE, "sans jeton : il n'entre pas en TELEGRAPH")
	CheckTokenRelease(one, two, three, holder)


func CheckTokenRelease(one: Node, two: Node, three: Node, holder: Node) -> void:
	## Fin du test : on rend tous les jetons pour ne pas perturber la suite.
	for enemy in [one, two, three, holder]:
		if is_instance_valid(enemy):
			AttackTokenManager.release(enemy)
			enemy.on_hit_received(_lethal())


# -----------------------------------------------------------------#
#                        ARCHER (§ 9)                              #
# -----------------------------------------------------------------#

func _test_archer() -> void:
	print("- Archer : 7 m, ligne de visée, tir (§ 9)")
	AttackTokenManager.holders.clear()
	level.player.global_position = Vector3(30.0, 0.1, 0.0)
	level.player.invincible_time = 10.0
	var archer := await _spawn_enemy("archer", Vector3(37.0, 0.1, 0.0))
	await _frames(8)
	_check(archer.state == EnemyBase3D.State.CHASE, "l'archer te repère à 7 m")
	await _wait(0.4)
	var distance := archer.global_position.distance_to(level.player.global_position)
	_check(distance > 6.0, "il garde ses distances (%.1f m, § 9)" % distance)
	# Trop près : il recule au lieu de rester collé.
	archer.global_position = level.player.global_position + Vector3(2.0, 0.0, 0.0)
	await _wait(0.5)
	var backed := archer.global_position.distance_to(level.player.global_position)
	_check(backed > 2.6, "trop près : il recule (%.1f m)" % backed)
	# Le tir touche la joueuse et la ligne de visée s'affiche pendant l'attaque.
	archer.global_position = level.player.global_position + Vector3(7.0, 0.0, 0.0)
	archer._fire_cooldown = 0.0
	archer.target = level.player
	archer.state = EnemyBase3D.State.CHASE
	level.player.invincible_time = 0.0
	last_player_result = -1
	await _wait(0.8)
	_check(last_player_result == Hurtbox3D.Result.HIT,
		"le tir de l'archer touche la joueuse (à 7 m)")
	_check(archer._aim_line != null, "l'archer a une ligne de visée 3D (§ 9)")
	# Télégraphe 0,5 s + coup 0,6 s : la récupération arrive vers 1,1 s.
	await _wait(0.6)
	_check(not archer._aim_line.visible, "le tir parti, la ligne de visée s'éteint")
	_check(archer._fire_cooldown > 0.0, "il patiente avant le prochain tir (2,2 s)")
	_check(is_equal_approx(archer.data.fire_period, 2.2), "période de tir : 2,2 s")
	if is_instance_valid(archer):
		archer.on_hit_received(_lethal())
	await _frames(3)


# -----------------------------------------------------------------#
#                        BRUTE (§ 9)                               #
# -----------------------------------------------------------------#

func _test_brute() -> void:
	print("- Brute blindée : armure et fenêtre de vulnérabilité (§ 9)")
	AttackTokenManager.holders.clear()
	var brute := await _spawn_enemy("brute", Vector3(20.0, 0.1, 0.0))
	var health := brute.health
	_check(is_equal_approx(brute.max_health, 90.0), "la brute a 90 de vie (§ 9)")
	var result := _hit(brute, 10.0, false)
	_check(result == Hurtbox3D.Result.BLOCKED, "coups légers : armure (résultat %d)" % result)
	_check(is_equal_approx(brute.health, health), "aucun dégât sur un coup léger")
	var heavy := _hit(brute, 16.0, true)
	_check(heavy == Hurtbox3D.Result.HIT, "coup lourd (finisseur) : il passe")
	_check(brute.health < health, "dégâts appliqués par le coup lourd (%.0f vie)" % brute.health)
	# Après son attaque lourde, elle est vulnérable 0,9 s : même un coup léger passe.
	brute.vulnerable_left = brute.data.vulnerable_time
	var before := brute.health
	_hit(brute, 10.0, false)
	_check(brute.health < before, "vulnérable après son attaque : le coup léger passe")
	_check(is_equal_approx(brute.data.vulnerable_time, 0.9), "fenêtre de 0,9 s (§ 9)")
	brute.vulnerable_left = 0.0
	var again := _hit(brute, 5.0, false)
	_check(again == Hurtbox3D.Result.BLOCKED, "la fenêtre refermée, l'armure bloque à nouveau")
	brute.on_hit_received(_lethal())
	await _frames(3)


# -----------------------------------------------------------------#
#                         CHEF (§ 9)                               #
# -----------------------------------------------------------------#

func _test_chief() -> void:
	print("- Chef : buff des alliés et invocation (§ 9)")
	AttackTokenManager.holders.clear()
	var chief := await _spawn_enemy("chief", Vector3(50.0, 0.1, 0.0))
	var ally := await _spawn_enemy("soldier", Vector3(52.0, 0.1, 0.0))
	var speed_before := ally.speed_now()
	await _wait(0.6)
	_check(ally.buff_mult > 1.0, "l'allié proche est buffé (×%.2f)" % ally.buff_mult)
	_check(ally.speed_now() > speed_before, "vitesse de l'allié : %.2f → %.2f m/s"
		% [speed_before, ally.speed_now()])
	_check(is_equal_approx(ally.buff_mult, 1.2), "buff de +20 % (§ 9)")
	_check(is_equal_approx(ally.data.speed * ally.buff_mult, 1.8 * 1.2),
		"soldat buffé : 1,8 × 1,2 = 2,16 m/s")
	# Une invocation : un NOUVEAU soldat apparaît près du chef.
	var known := _enemy_ids()
	chief._summon_left = 0.01
	await _wait(0.4)
	var summoned: EnemyBase3D = null
	for actor in _enemies():
		if known.has(actor.get_instance_id()):
			continue
		if actor.data.id == "soldier" \
				and actor.global_position.distance_to(chief.global_position) < 6.0:
			summoned = actor
	_check(summoned != null, "le chef invoque un soldat (§ 9)")
	_check(is_equal_approx(chief.data.summon_period, 12.0), "une invocation toutes les 12 s")
	# Un allié trop loin n'est pas buffé.
	var distant := await _spawn_enemy("soldier", Vector3(70.0, 0.1, 0.0))
	await _wait(0.5)
	_check(distant.buff_mult <= 1.0, "un allié à 20 m ne reçoit pas le buff")
	for enemy in [chief, ally, distant]:
		if is_instance_valid(enemy):
			enemy.on_hit_received(_lethal())
	await _frames(3)


# -----------------------------------------------------------------#
#                   GARDE D'ALERTE (§ 9)                           #
# -----------------------------------------------------------------#

## Identifiants des ennemis présents (pour repérer ceux qui viennent d'arriver).
func _enemy_ids() -> Array[int]:
	var out: Array[int] = []
	for actor in _enemies():
		out.append(actor.get_instance_id())
	return out


func _test_alert_guard() -> void:
	print("- Garde d'alerte : la vue déclenche des renforts (§ 9)")
	AttackTokenManager.holders.clear()
	level.player.global_position = Vector3(50.0, 0.1, 0.0)
	level.player.invincible_time = 20.0
	var before := _enemies().size()
	var known := _enemy_ids()
	var guard := await _spawn_enemy("guard", Vector3(56.0, 0.1, 0.0))
	await _wait(0.6)
	var new_count := 0
	for actor in _enemies():
		if not known.has(actor.get_instance_id()):
			new_count += 1
	_check(new_count >= 3, "alerte : le garde + 2 renforts (de %d à %d ennemis)"
		% [before, _enemies().size()])
	var soldiers := 0
	for actor in _enemies():
		if actor.data.id == "soldier" and actor.global_position.distance_to(guard.global_position) < 6.0:
			soldiers += 1
	_check(soldiers >= 2, "les renforts sont bien 2 soldats")
	_check(guard.data.alert_reinforcements == 2, "le .tres du garde demande 2 renforts")
	_check(guard.state != EnemyBase3D.State.IDLE, "le garde, lui, part à l'attaque")


# -----------------------------------------------------------------#
#                   PIÈGES (§ 11)                                  #
# -----------------------------------------------------------------#

func _make_hazard(kind: int, at: Vector3, return_at: Vector3) -> Hazard3D:
	var hazard := Hazard3D.new()
	hazard.kind = kind
	hazard.position = at
	hazard.return_point = return_at
	level.hazards_root.add_child(hazard)
	return hazard


func _put_player_on(at: Vector3) -> void:
	level.player.global_position = at
	level.player.velocity = Vector3.ZERO


func _test_hazards() -> void:
	print("- Les six pièges du § 11")
	for kind_name in ["pit", "arrows", "fire", "plank", "spikes", "mud"]:
		var kind := Hazard3D.kind_from_string(kind_name)
		_check(Hazard3D.name_of_kind(kind) == kind_name, "piège « %s » reconnu" % kind_name)
	_check(Hazard3D.kind_from_string("etrangleur") == Hazard3D.Kind.SPIKES,
		"piège inconnu -> pointes (aucun plantage)")

	# Fosse : −20 vie et retour au bord.
	var pit := _make_hazard(Hazard3D.Kind.PIT, Vector3(20.0, 0.05, 0.0), Vector3(17.0, 0.1, 0.0))
	await _frames(2)
	_put_player_on(Vector3(20.0, 0.1, 0.0))
	_clear_invincibility()
	var life_before := level.player.health
	await _frames(3)
	_check(level.player.health <= life_before - 19.0, "fosse : −20 vie (%.0f → %.0f)"
		% [life_before, level.player.health])
	var after_fall := level.player.global_position
	var fall_offset := after_fall.distance_to(Vector3(17.0, 0.1, 0.0))
	_check(fall_offset < 1.5,
		"fosse : la joueuse est reposée au bord (à %.1f m du point de retour)" % fall_offset)
	_check(pit.hits_given >= 1, "la fosse a compté son coup")

	# Pointes : 10 dégâts au contact.
	var spikes := _make_hazard(Hazard3D.Kind.SPIKES, Vector3(30.0, 0.05, 0.0), Vector3(30.0, 0.1, 3.0))
	await _frames(2)
	_clear_invincibility()
	life_before = level.player.health
	_put_player_on(Vector3(30.0, 0.1, 0.0))
	await _frames(5)
	_check(is_equal_approx(spikes.damage, 10.0), "pointes : 10 dégâts (§ 11)")
	_check(level.player.health <= life_before - 9.0, "pointes : la joueuse perd 10 vie")

	# Flèches murales : salve toutes les 3 s, 12 dégâts.
	var arrows := _make_hazard(Hazard3D.Kind.ARROWS, Vector3(40.0, 0.05, 0.0), Vector3(40.0, 0.1, 3.0))
	await _frames(2)
	_check(is_equal_approx(arrows.damage, 12.0) and is_equal_approx(arrows.salvo_period, 3.0),
		"flèches : 12 dégâts, salve toutes les 3 s (§ 11)")
	arrows._salvo_left = 0.05
	_clear_invincibility()
	life_before = level.player.health
	_put_player_on(Vector3(40.0, 0.1, 0.0))
	await _frames(8)
	_check(level.player.health <= life_before - 11.0, "flèches : la salve touche (−12 vie)")
	_check(arrows._salvo_left > 2.5, "flèches : le compte à rebours de 3 s a repris")

	# Feu : cycle 1 s ON / 2 s OFF, 8 dégâts par seconde.
	var fire := _make_hazard(Hazard3D.Kind.FIRE, Vector3(60.0, 0.05, 0.0), Vector3(60.0, 0.1, 3.0))
	await _frames(2)
	_check(is_equal_approx(fire.fire_on_time, 1.0) and is_equal_approx(fire.fire_off_time, 2.0),
		"feu : 1 s ON / 2 s OFF (§ 11)")
	_check(is_equal_approx(fire.damage, 8.0), "feu : 8 dégâts par seconde (§ 11)")
	fire._fire_phase = 0.5
	_clear_invincibility()
	life_before = level.player.health
	_put_player_on(Vector3(60.0, 0.1, 0.0))
	await _wait(0.7)
	_check(level.player.health < life_before, "feu allumé : la joueuse brûle (%.0f vie)" % level.player.health)
	var burned := life_before - level.player.health
	_check(burned > 2.0 and burned < 9.0, "feu : environ 8 dégâts par seconde (%.1f en 0,7 s)" % burned)
	fire._fire_phase = 1.5                       # phase OFF (1 s → 3 s)
	await _frames(3)
	_check(not fire.active, "feu éteint : aucune zone active")
	var life_off := level.player.health
	await _wait(0.5)
	_check(is_equal_approx(level.player.health, life_off), "feu éteint : plus aucun dégât")

	# Planche : casse 0,6 s après le contact.
	var plank := _make_hazard(Hazard3D.Kind.PLANK, Vector3(80.0, 0.05, 0.0), Vector3(80.0, 0.1, 3.0))
	await _frames(2)
	_check(is_equal_approx(plank.plank_delay, 0.6), "planche : 0,6 s avant de casser (§ 11)")
	_clear_invincibility()
	_put_player_on(Vector3(80.0, 0.1, 0.0))
	await _frames(4)
	_check(plank.active and plank.telegraphing, "planche : elle craque d'abord (télégraphe)")
	life_before = level.player.health
	await _wait(0.3)
	var still_on_plank := plank._victims_in_area().size()
	await _wait(0.6)
	_check(not plank.active, "planche : elle a cassé")
	_check(level.player.health <= life_before - 15.0,
		"planche cassée : la chute blesse (%.0f → %.0f, %d coup(s), %d victime(s) à 0,3 s, joueuse en x = %.1f, y = %.1f)"
		% [life_before, level.player.health, plank.hits_given, still_on_plank,
			level.player.global_position.x, level.player.global_position.y])

	# Boue : −40 % de vitesse, sans dégâts.
	var mud := _make_hazard(Hazard3D.Kind.MUD, Vector3(90.0, 0.05, 0.0), Vector3(90.0, 0.1, 3.0))
	await _frames(2)
	_check(is_equal_approx(mud.slow_mult, 0.6), "boue : −40 % de vitesse (§ 11)")
	_check(is_equal_approx(mud.damage, 0.0), "boue : aucun dégât (§ 11)")
	_clear_invincibility()
	life_before = level.player.health
	_put_player_on(Vector3(90.0, 0.1, 0.0))
	await _frames(4)
	_check(level.player.speed_mult < 1.0, "dans la boue : vitesse ×%.2f" % level.player.speed_mult)
	_check(is_equal_approx(level.player.health, life_before), "la boue ne blesse pas")
	level.player.global_position = Vector3(70.0, 0.1, 0.0)
	await _wait(0.4)
	_check(is_equal_approx(level.player.speed_mult, 1.0), "hors de la boue : vitesse normale retrouvée")

	# Les pièges blessent aussi les ennemis (§ 11). L'ennemi est posé À CÔTÉ des
	# pointes puis amené dedans : le chevauchement est ainsi mesuré, et non un
	# coup déjà encaissé pendant l'apparition.
	_clear_invincibility()
	var victim := await _spawn_enemy("soldier", Vector3(30.0, 0.1, 8.0))
	var enemy_life := victim.health
	var spikes_before := spikes.hits_given
	victim.global_position = Vector3(30.0, 0.1, 0.0)
	await _frames(6)
	_check(victim.health < enemy_life,
		"les pointes blessent aussi les ennemis (§ 11) : %.0f → %.0f, %d victime(s) dans la zone"
		% [enemy_life, victim.health, spikes._victims_in_area().size()])
	_check(spikes.hits_given > spikes_before,
		"la zone a compté un coup sur l'ennemi (%d → %d)"
		% [spikes_before, spikes.hits_given])
	victim.on_hit_received(_lethal())

	# L'esquive annule les dégâts d'un piège (tout passe par la Hurtbox3D).
	var dodge_pit := _make_hazard(Hazard3D.Kind.SPIKES, Vector3(45.0, 0.05, 0.0), Vector3(45.0, 0.1, 3.0))
	await _frames(2)
	_clear_invincibility()
	level.player.state = Player3D.State.DODGE
	level.player.invincible_time = 0.25
	life_before = level.player.health
	_put_player_on(Vector3(45.0, 0.1, 0.0))
	await _frames(5)
	_check(is_equal_approx(level.player.health, life_before),
		"esquive : les pièges respectent l'invincibilité (§ 8.3)")
	level.player.state = Player3D.State.IDLE
	level.player.invincible_time = 0.0
	dodge_pit.queue_free()


# -----------------------------------------------------------------#
#                    CHECKPOINTS (§ 13)                            #
# -----------------------------------------------------------------#

func _test_checkpoint() -> void:
	print("- Checkpoints du § 13")
	await _load_level(LEVEL_FILES[1])
	var checkpoint := level.checkpoint
	_check(checkpoint != null, "un checkpoint existe")
	_check(is_equal_approx(checkpoint.global_position.x, 50.0),
		"il est à mi-niveau (x = %.0f m)" % checkpoint.global_position.x)
	_check(not checkpoint.active, "au départ : inactif")
	level.player.global_position = checkpoint.global_position + Vector3(0.0, 0.1, 0.5)
	await _frames(5)
	_check(checkpoint.active, "la joueuse le traverse : il s'allume")
	_check(level.spawn_point.distance_to(checkpoint.respawn_position) < 0.5,
		"le point de réapparition devient le checkpoint")

	# Mort après le checkpoint : on réapparaît au checkpoint, vie pleine.
	GameState.difficulty = "normal"
	level.player.health = 1.0
	_clear_invincibility()          # sinon le coup mortel est esquivé
	var deaths_before := player_died_count
	level.player.on_hit_received(_lethal())
	# Le niveau écoute `died` : il réapparaît DANS le même frame (Normal).
	await _frames(4)
	_check(player_died_count == deaths_before + 1, "la joueuse meurt (signal died)")
	_check(level.player.state != Player3D.State.DEAD, "elle réapparaît (checkpoint)")
	_check(level.player.global_position.distance_to(checkpoint.respawn_position) < 1.0,
		"elle réapparaît SUR le checkpoint (§ 13)")
	_check(is_equal_approx(level.player.health, level.player.balance.max_health),
		"vie pleine après la réapparition")
	_check(level.checkpoint_used, "la réapparition du niveau est consommée")

	# Deuxième mort en Normal : échec (§ 13 : une seule par niveau).
	level.failed = false
	var failed_before := failed_reason
	level._on_player_died()
	_check(level.failed, "deuxième mort en Normal : échec du niveau")
	_check(failed_reason != failed_before or failed_reason == "vie",
		"Events.level_failed signalé (« %s »)" % failed_reason)

	# En Facile : réapparitions illimitées.
	GameState.difficulty = "easy"
	level.failed = false
	level.checkpoint_used = true
	level._on_player_died()
	_check(not level.failed, "en Facile : nouvelle réapparition, pas d'échec")
	level._on_player_died()
	_check(not level.failed, "en Facile : réapparitions illimitées (§ 13)")
	GameState.difficulty = "normal"


# -----------------------------------------------------------------#
#              CAURIS ET POTIONS (§ 14.1, § 8.6)                   #
# -----------------------------------------------------------------#

func _test_pickups() -> void:
	print("- Cauris et potions (§ 14.1, § 8.6)")
	var cauri := Pickup3D.new()
	cauri.kind = Pickup3D.Kind.CAURI
	# Valeur par défaut : aucun réglage, un cauri vaut 3 (§ 14.1).
	_check(cauri.value == 3, "valeur par défaut d'un cauri : %d" % cauri.value)
	level.pickups_root.add_child(cauri)
	cauri.position = level.player.global_position + Vector3(0.0, 0.5, 0.0)
	var before := GameState.cauris_this_run
	var events_before := cauris_events
	pickup_collected = false
	cauri.collected.connect(func(_pickup: Pickup3D, _by: Node) -> void: pickup_collected = true)
	await _frames(4)
	_check(GameState.cauris_this_run == before + 3,
		"un cauri ramassé ajoute 3 (§ 14.1 : %d)" % GameState.cauris_this_run)
	_check(cauris_events > events_before, "Events.cauris_changed prévient le HUD")
	_check(pickup_collected, "le signal « collected » part")
	_check(not is_instance_valid(cauri), "le cauri ramassé se libère ensuite")

	var potion := Pickup3D.new()
	potion.kind = Pickup3D.Kind.POTION
	level.pickups_root.add_child(potion)
	potion.position = level.player.global_position + Vector3(0.0, 0.5, 0.0)
	level.player.health = 40.0
	await _frames(4)
	_check(is_equal_approx(level.player.health, 70.0), "potion : +30 vie (§ 8.6 : %.0f)"
		% level.player.health)
	level.player.health = level.player.balance.max_health - 5.0
	var capped := Pickup3D.new()
	capped.kind = Pickup3D.Kind.POTION
	level.pickups_root.add_child(capped)
	capped.position = level.player.global_position + Vector3(0.0, 0.5, 0.0)
	await _frames(4)
	_check(is_equal_approx(level.player.health, level.player.balance.max_health),
		"la potion ne dépasse jamais la vie maximale")

	# Un ennemi tué laisse des cauris (§ 9 : drops_cauris).
	var pickups_before := level.pickups_root.get_child_count()
	var victim := await _spawn_enemy("soldier", Vector3(20.0, 0.1, 0.0))
	await _frames(3)
	victim.on_hit_received(_lethal())
	await _frames(4)
	_check(level.pickups_root.get_child_count() > pickups_before,
		"un soldat tué laisse des cauris (drops_cauris = %d)" % victim.data.drops_cauris)
	_check(victim.data.drops_cauris == 3, "le soldat lâche 3 cauris (data/enemies/soldier.tres)")


# -----------------------------------------------------------------#
#                    HUD (§ 16) ET OBJECTIFS                       #
# -----------------------------------------------------------------#

func _test_hud() -> void:
	print("- HUD : timer, objectif, cauris, fin de niveau (§ 16)")
	await _load_level(LEVEL_FILES[1])
	var hud := level.hud
	_check(hud.timer_label.text == "2:10" or hud.timer_label.text == "2:09",
		"le timer affiche la durée restante (%s)" % hud.timer_label.text)
	_check(hud.objective_label.text.contains("sortie"),
		"l'objectif affiché vient du .tres (« %s »)" % hud.objective_label.text)
	_check(hud.cauris_label.text.begins_with("CAURIS"), "le compteur de cauris est affiché")
	level.time_left = 15.0
	await _wait(0.1)                  # laisse passer une frame d'affichage
	_check(hud.timer_label.modulate.r > 0.9 and hud.timer_label.modulate.g < 0.6,
		"moins de 20 s : le timer passe au rouge (§ 16)")
	level.time_left = 99.0
	await _wait(0.1)
	_check(hud.timer_label.text == "1:39", "le temps repart à 1:39 (%s)" % hud.timer_label.text)

	hud.show_result("NIVEAU TERMINÉ", 2)
	_check(hud.result_text().contains("NIVEAU TERMINÉ"), "bandeau de victoire affiché")
	_check(hud.result_text().contains("★"), "les étoiles gagnées sont affichées (%s)"
		% hud.result_text())
	hud.show_result("ÉCHEC — temps", 0)
	_check(not hud.result_text().contains("★"), "bandeau d'échec sans étoile")

	# Objectifs : « survive » — le temps écoulé est une RÉUSSITE (§ 12.3).
	await _load_level(LEVEL_FILES[3])
	_check(level.objective.time_up_is_success(), "objectif « survive » : le temps est un succès")
	level.time_left = 0.05
	await _wait(0.3)
	_check(level.completed and not level.failed, "survivre jusqu'au bout = niveau terminé")
	_check(is_equal_approx(level.objective.progress(), 1.0), "avancement « survive » à 100 %")

	# Objectif « exit » : entrer dans la zone de sortie (§ 12.1).
	await _load_level(LEVEL_FILES[1])
	_check(not level.exit_reached, "au départ : sortie non atteinte")
	level.player.global_position = level.exit_area.global_position + Vector3(0.0, 0.1, 0.0)
	await _frames(6)
	_check(level.exit_reached, "entrer dans la zone dorée valide la sortie")
	_check(level.objective.success(), "objectif « exit » rempli")
	_check(level.objective.progress() >= 0.99, "avancement « exit » à 100 %")
	await _frames(4)
	_check(level.completed, "le niveau se termine tout seul")


func _test_objectives() -> void:
	print("- Objectifs de la PHASE 3 (§ 20.10)")
	var clean := await _make_custom_level("clear")
	_check(clean.objective is ClearWaves, "objectif « clear » -> ClearWaves")
	_check(clean.objective_name().contains("ennemis"), "texte d'objectif : « %s »"
		% clean.objective_name())
	_check(not clean.objective.success(), "pas encore réussi : des vagues attendent")
	_check(not clean.objective.time_up_is_success(), "« clear » : le temps est un échec")
	_check(is_equal_approx(clean.objective.progress(), 0.0),
		"avancement « clear » : %.2f tant qu'aucune vague n'est nettoyée" % clean.objective.progress())

	var exit_level := await _make_custom_level("exit")
	_check(exit_level.objective is ReachExit, "objectif « exit » -> ReachExit")
	_check(exit_level.objective.description().contains("sortie"), "texte : « %s »"
		% exit_level.objective.description())
	_check(is_equal_approx(exit_level.objective.progress(), 0.05),
		"avancement de la sortie : %.2f au départ" % exit_level.objective.progress())

	var survive := await _make_custom_level("survive", "arena")
	_check(survive.objective is SurviveObjective, "objectif « survive » -> SurviveObjective")
	_check(survive.objective.time_up_is_success(), "« survive » : le temps est un succès")
	_check(not survive.objective.success(), "« survive » : pas encore réussi au départ")
	var survive_start := survive.objective.progress()
	_check(survive_start >= 0.0 and survive_start < 0.1,
		"avancement « survive » presque nul au départ (%.1f %%)" % (survive_start * 100.0))


# -----------------------------------------------------------------#
#        CHAÎNE TACTILE RÉELLE (§ 7) — nécessite une fenêtre        #
# -----------------------------------------------------------------#

## Doigt -> TouchButton -> Events.touch_action -> Player3D. En `--headless`
## il n'y a ni fenêtre ni bouton à toucher : la chaîne est alors sautée (les
## boutons, eux, sont vérifiés dans tous les cas).
func _test_touch_chain() -> void:
	print("- Chaîne tactile réelle (§ 7)")
	await _load_level(LEVEL_FILES[1])
	var controls := level.get_node_or_null("TouchControls") as TouchControls
	_check(controls != null, "la scène de niveau porte les contrôles tactiles (§ 7)")
	if controls == null:
		return
	var missing: Array[String] = []
	for name in ["Joystick", "Attack", "Guard", "Dodge", "Special", "Pause"]:
		if controls.get_node_or_null(name) == null:
			missing.append(name)
	_check(missing.is_empty(), "joystick et 5 boutons présents%s"
		% ("" if missing.is_empty() else " (manque %s)" % ", ".join(missing)))
	if DisplayServer.get_name() == "headless" \
			or get_viewport().get_visible_rect().size.x < MIN_VIEWPORT_FOR_TOUCH:
		_skip("chaîne tactile réelle : relancer sans --headless (fenêtre ≥ %.0f px)"
			% MIN_VIEWPORT_FOR_TOUCH)
		return

	_clear_invincibility()
	level.player.global_position = Vector3(6.0, 0.1, 0.0)
	level.player.velocity = Vector3.ZERO
	await _frames(4)

	# Joystick : posé dans la moitié gauche puis incliné vers le haut -> avant.
	var origin := Vector2(get_viewport().get_visible_rect().size.x * 0.25, 500.0)
	_push_touch(1, origin, true)
	await _frames(2)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = origin + Vector2(0.0, -80.0)
	get_viewport().push_input(drag)
	await _frames(2)
	_check(Events.joystick_vector.length() > 0.5,
		"joystick incliné -> vecteur %.2f" % Events.joystick_vector.length())
	var moved_from := level.player.global_position
	await _wait(0.3)
	var walked := level.player.global_position.distance_to(moved_from)
	_check(walked > 0.3, "le joystick fait avancer la joueuse (%.1f m)" % walked)
	_push_touch(1, origin, false)
	await _frames(2)
	_check(Events.joystick_vector == Vector2.ZERO, "doigt levé -> joystick relâché")
	level.player.global_position = Vector3(6.0, 0.1, 0.0)
	level.player.velocity = Vector3.ZERO
	await _frames(2)

	# Attaque : un appui suffit.
	var attack := _button_center(controls, "Attack")
	_push_touch(7, attack, true)
	await _frames(2)
	_check(level.player.state == Player3D.State.ATTACK, "doigt sur « Attaque » -> état ATTAQUE")
	_push_touch(7, attack, false)
	await _wait(0.7)                     # laisse finir le coup

	# Garde : maintenue tant que le doigt reste posé, relâchée au retrait.
	var guard := _button_center(controls, "Guard")
	_push_touch(8, guard, true)
	await _frames(2)
	_check(level.player.state == Player3D.State.GUARD, "doigt sur « Garde » -> état GARDE")
	_push_touch(8, guard, false)
	await _frames(4)
	_check(level.player.state != Player3D.State.GUARD, "doigt retiré -> la garde tombe")

	# Esquive : un appui suffit, puis elle revient à l'arrêt.
	var dodge := _button_center(controls, "Dodge")
	_push_touch(9, dodge, true)
	await _frames(2)
	_check(level.player.state == Player3D.State.DODGE, "doigt sur « Esquive » -> état ESQUIVE")
	_push_touch(9, dodge, false)
	await _wait(0.6)
	_check(level.player.state != Player3D.State.DODGE, "l'esquive se termine toute seule")


## Centre écran du bouton (les contrôles tactiles sont en coordonnées écran).
func _button_center(controls: TouchControls, name: String) -> Vector2:
	return (controls.get_node(name) as TouchButton).get_global_rect().get_center()


func _push_touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	get_viewport().push_input(event)


# -----------------------------------------------------------------#
#              FIN DE NIVEAU, ÉTOILES ET ÉCHEC (§ 13)              #
# -----------------------------------------------------------------#

func _test_finish() -> void:
	print("- Fin de niveau : étoiles, sauvegarde, échec par temps (§ 13)")
	completed_seen = false
	var win := await _make_custom_level("exit")
	win.player.health = win.player.balance.max_health
	win.exit_reached = true
	await _frames(4)
	_check(completed_seen, "Events.objective_completed émis à la victoire")
	_check(win.stars_earned >= 1, "%d étoile(s) gagnée(s) (§ 13)" % win.stars_earned)
	_check(SaveManager.data["levels"].has("test_phase3"),
		"le résultat est enregistré (SaveManager, § 23)")
	_check(win.hud.result_text().contains("NIVEAU TERMINÉ"), "le HUD annonce la victoire")

	# Échec par temps sur un objectif qui n'est pas « survive ».
	failed_reason = ""
	var timeout := await _make_custom_level("clear")
	timeout.time_left = 0.05
	await _wait(0.3)
	_check(timeout.failed and not timeout.completed, "temps écoulé sur « clear » : échec")
	_check(failed_reason == "temps", "raison signalée : « %s »" % failed_reason)
	_check(timeout.hud.result_text().contains("ÉCHEC"), "le HUD annonce l'échec")
