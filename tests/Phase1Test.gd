extends Node
## Test fonctionnel de la PHASE 1 (DESIGN.md § 28 et § 29), sans écran :
##   godot --headless --path . res://tests/Phase1Test.tscn     (logique de jeu)
##   godot --path . res://tests/Phase1Test.tscn                (logique + tactile)
##
## Il charge l'arène RÉELLE (CombatTest.tscn) et vérifie : mise en place, chaîne
## tactile doigt -> joystick/bouton -> jeu (seulement avec une vraie fenêtre),
## déplacement relatif caméra, limite de couloir, combo de 3 coups avec dégâts
## et énergie, esquive invincible, garde qui réduit les dégâts, riposte du
## mannequin, mort et réapparition.
##
## Sortie : « PHASE 1 : OK » (code 0) ou la liste des échecs (code 1).

## Sans écran (--headless), rien n'achemine les événements poussés dans le
## viewport : le doigt simulé n'atteint ni le joystick ni les boutons. Les tests
## tactiles sont alors annoncés comme ignorés, jamais comme réussis (lancer la
## commande sans --headless pour les exécuter).
const MIN_VIEWPORT_FOR_TOUCH: float = 1000.0
## Délai maximal d'attente de la réapparition du mannequin (s).
const RESPAWN_GUARD: float = 6.0

var failures: int = 0
var checks: int = 0
var skipped: int = 0
var last_result: int = -1
var last_invincible: float = 0.0
var hits: int = 0
var count_hits: bool = false

var combat: Node3D
var player: Player3D
var dummy: Dummy3D
var hud: HUD
var touch_controls: TouchControls


func _ready() -> void:
	print("=== Test fonctionnel PHASE 1 ===")
	combat = load("res://scenes/tests/CombatTest.tscn").instantiate()
	add_child(combat)
	# L'AnimationTree n'accepte start()/travel() qu'après quelques frames : on
	# laisse la machine à états démarrer avant de lire l'état d'animation.
	await _frames(10)
	player = combat.get_node("Player3D") as Player3D
	dummy = combat.get_node("Dummy3D") as Dummy3D
	hud = combat.get_node("HUD") as HUD
	touch_controls = combat.get_node("TouchControls") as TouchControls
	player.hurtbox.damaged.connect(_on_damaged)
	dummy.health_changed.connect(_on_dummy_health_changed)

	await _test_scene()
	await _test_pose_stable()
	await _test_touch_chain()
	await _test_movement()
	await _test_lane_clamp()
	await _test_combo()
	await _test_dodge_iframes()
	await _test_guard()
	await _test_dummy_riposte()
	await _test_player_death()
	await _test_dummy_respawn()

	print("--------------------------------")
	print("Vérifications : %d   Échecs : %d   Ignorées : %d" % [checks, failures, skipped])
	print("PHASE 1 : %s" % ("OK" if failures == 0 else "ÉCHECS"))
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


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _on_damaged(_info: DamageInfo, result: int) -> void:
	last_result = result
	# Relevé AU MOMENT du coup : l'invincibilité (§ 8.6) dure 0,8 s, donc la
	# vérifier après 1,2 s d'attente mesurerait surtout la chance.
	last_invincible = player.invincible_time if player != null else 0.0


func _on_dummy_health_changed(current: float, _maximum: float) -> void:
	if count_hits:
		hits += 1
	# Journal utile : d'où vient chaque coup encaissé par le mannequin.
	print("        [mannequin] vie = %.1f  (joueuse %s en %.2f,%.2f)"
		% [current, Player3D.State.keys()[player.state], player.global_position.x,
			player.global_position.z])


## Repose la joueuse et le mannequin dans un état connu avant chaque test.
## `dummy_x` place le mannequin (1,6 m = à portée de coup, 6 m = hors de portée).
func _reset_actors(dummy_x: float = 1.6) -> void:
	Events.joystick_vector = Vector2.ZERO
	player.global_position = Vector3(0.0, 0.1, 0.0)
	player.velocity = Vector3.ZERO
	player.health = player.data.max_health
	player.energy = 0.0
	player.invincible_time = 0.0
	player.hurt_time_left = 0.0
	player.dodge_time_left = 0.0
	player.dodge_cooldown = 0.0
	player.attack_step = 0
	player.attack_time = 0.0
	player.queued_next = false
	# PHASE 2 : garde parfaite, stabilité et spécial repartent de zéro.
	player.guard_perfect_left = 0.0
	player.guard_stability = player.balance.guard_stability_max
	player.special_time_left = 0.0
	player.state = Player3D.State.IDLE
	player.facing_dir = Vector3.RIGHT
	player.hitbox.deactivate()
	dummy.global_position = Vector3(dummy_x, 0.1, 0.0)
	dummy.velocity = Vector3.ZERO
	dummy.health = Dummy3D.MAX_HEALTH
	dummy.dead = false
	dummy.damageable = true
	dummy.cooldown_left = 9999.0        ## pas de riposte pendant le test en cours
	dummy.hitbox.deactivate()
	# Le mannequin regarde la joueuse (à -X) : géométrie déterministe.
	dummy.visual.rotation.y = PI * 0.5
	last_result = -1
	last_invincible = 0.0
	await _frames(6)


## Action de jeu, comme si le bouton tactile avait été pressé (Events est le
## bus que les boutons utilisent déjà : voir _test_touch_chain).
func _action(action_name: String, pressed: bool) -> void:
	Events.touch_action.emit(action_name, pressed)
	await get_tree().process_frame


func _tap_action(action_name: String) -> void:
	await _action(action_name, true)
	await _action(action_name, false)


# --- Entrées tactiles réelles (nécessitent une vraie fenêtre) ---------#

func _touch_available() -> bool:
	return DisplayServer.get_name() != "headless" \
		and get_viewport().get_visible_rect().size.x >= MIN_VIEWPORT_FOR_TOUCH


func _button_center(button_name: String) -> Vector2:
	var button := touch_controls.get_node_or_null(button_name) as TouchButton
	if button == null:
		return Vector2.ZERO
	return button.get_global_rect().get_center()


func _touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	get_viewport().push_input(event)
	await get_tree().process_frame


func _drag(index: int, position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = relative
	get_viewport().push_input(event)
	await get_tree().process_frame


# -----------------------------------------------------------------#
#                            LES TESTS                             #
# -----------------------------------------------------------------#

func _test_scene() -> void:
	print("- Scène et HUD")
	_check(player != null and dummy != null, "arène chargée : joueuse + mannequin")
	_check(player.is_in_group("players"), "joueuse dans le groupe players")
	_check(dummy.is_in_group("enemies"), "mannequin dans le groupe enemies")
	_check(player.health == 100.0, "vie initiale = 100 (%.1f)" % player.health)
	_check(dummy.health == Dummy3D.MAX_HEALTH, "vie du mannequin = %.0f" % dummy.health)
	_check(player.anim_tree != null and player.playback != null, "AnimationTree de la joueuse actif")
	_check(player.playback.get_current_node() == &"idle",
		"état d'animation initial = idle ('%s')" % player.playback.get_current_node())
	_check(dummy.playback != null and dummy.playback.get_current_node() == &"idle",
		"AnimationTree du mannequin sur idle")
	_check(hud.player == player, "HUD lié à la joueuse")
	_check(touch_controls != null, "contrôles tactiles présents")
	_check(touch_controls.get_node_or_null("Joystick") is VirtualJoystick, "joystick virtuel présent")
	_check(touch_controls.get_node_or_null("Attack") is TouchButton, "bouton Attaque présent")
	_check(touch_controls.get_node_or_null("Guard") is TouchButton, "bouton Garde présent")
	_check(touch_controls.get_node_or_null("Dodge") is TouchButton, "bouton Esquive présent")
	_check(touch_controls.get_node_or_null("Special") is TouchButton, "bouton Spécial présent")
	_check(touch_controls.get_node_or_null("Pause") is TouchButton, "bouton Pause présent")


## § 6.4 : pendant un fondu, Godot met à l'échelle la piste d'une animation par
## le poids de celle-ci ; une piste absente du clip d'arrivée tend donc vers 0.
## C'est ainsi que le torse, respiré par l'idle, tombait à hauteur des pieds
## dès le premier coup. On vérifie que chaque état garde le buste à sa hauteur.
func _test_pose_stable() -> void:
	print("- Stabilité de la pose pendant les fondus (§ 6.4)")
	await _reset_actors(6.0)
	var torso := player.get_node_or_null("Visual/Puppet/Pivot/Torso") as Node3D
	_check(torso != null, "torse de la poupée trouvé")
	if torso == null:
		return
	_check(absf(torso.position.y - 1.05) < 0.05,
		"buste au repos à %.2f m (attendu 1,05)" % torso.position.y)
	for state_name in ["run", "attack1", "attack2", "attack3", "dodge", "guard", "hurt"]:
		player.playback.travel(state_name)
		await _wait(0.25)
		_check(torso.position.y > 0.5,
			"buste debout en '%s' (y = %.2f m)" % [state_name, torso.position.y])
	player.playback.travel("idle")
	await _wait(0.25)


## Chaîne tactile complète : doigt -> joystick / bouton -> Events -> gameplay.
## Ignorée en --headless (viewport 64×64) : à lancer sans --headless.
func _test_touch_chain() -> void:
	print("- Chaîne tactile (doigt -> joystick / bouton -> jeu)")
	if not _touch_available():
		_skip("tests tactiles : viewport %s en headless, relancer sans --headless"
			% get_viewport().get_visible_rect().size)
		return
	await _reset_actors()
	var size := get_viewport().get_visible_rect().size
	# Joystick : appui dans la moitié gauche, puis glissement vers la droite.
	var origin := Vector2(size.x * 0.2, size.y * 0.75)
	await _touch(0, origin, true)
	await _drag(0, origin + Vector2(90.0, 0.0), Vector2(90.0, 0.0))
	await get_tree().physics_frame
	_check(Events.joystick_vector.x > 0.5,
		"glissement à droite -> joystick x = %.2f" % Events.joystick_vector.x)
	await _touch(0, origin + Vector2(90.0, 0.0), false)
	await get_tree().physics_frame
	_check(Events.joystick_vector == Vector2.ZERO, "doigt levé -> joystick remis à zéro")
	# Bouton Attaque : appui au centre réel du bouton (§ 7).
	var attack := _button_center("Attack")
	_check(attack.x > 0.0, "bouton Attaque positionné (%s)" % attack)
	await _touch(1, attack, true)
	await get_tree().physics_frame
	_check(player.state == Player3D.State.ATTACK, "appui sur Attaque -> état ATTAQUE")
	await _touch(1, attack, false)
	await _wait(0.8)
	# Bouton Pause : on vérifie le branchement (un appui réel changerait de scène,
	# ce qui détruirait l'arbre du test en cours).
	_check(touch_controls.pause_pressed.get_connections().size() > 0,
		"Pause branché sur la scène de niveau")


func _test_movement() -> void:
	print("- Déplacement relatif à la caméra (§ 3.3)")
	await _reset_actors(6.0)
	var start := player.global_position
	Events.joystick_vector = Vector2(1.0, 0.0)          ## écran vers la droite
	await _frames(30)
	_check(player.global_position.x - start.x > 0.5,
		"joystick à droite -> x avance de %.2f m" % (player.global_position.x - start.x))
	_check(player.state == Player3D.State.RUN, "état de course pendant le déplacement")
	Events.joystick_vector = Vector2.ZERO
	await _frames(15)
	_check(player.state == Player3D.State.IDLE, "retour à l'arrêt sans joystick")
	_check(absf(player.global_position.z) < 0.2, "poussée horizontale : profondeur conservée")
	Events.joystick_vector = Vector2(0.0, -1.0)         ## écran vers le haut (-Z)
	var z_before := player.global_position.z
	await _frames(25)
	_check(player.global_position.z - z_before < -0.4,
		"joystick vers le haut -> profondeur -%.2f m" % (z_before - player.global_position.z))
	Events.joystick_vector = Vector2.ZERO
	await _frames(5)


func _test_lane_clamp() -> void:
	print("- Couloir (§ 3.1 : profondeur limitée à ±3 m)")
	await _reset_actors(6.0)
	Events.joystick_vector = Vector2(0.0, 1.0)          ## écran vers le bas (+Z)
	await _frames(150)
	_check(player.global_position.z <= 3.01 and player.global_position.z > 2.5,
		"profondeur bloquée à %.2f m" % player.global_position.z)
	Events.joystick_vector = Vector2.ZERO
	await _frames(5)


func _test_combo() -> void:
	print("- Combo de 3 coups (§ 8.2)")
	await _reset_actors()
	var health_before := dummy.health
	var energy_before := player.energy
	hits = 0
	count_hits = true

	await _tap_action("attack")                         ## coup 1
	await _wait(0.20)                                   ## fondu terminé, coup en cours
	_check(player.state == Player3D.State.ATTACK, "coup 1 déclenché")
	_check(player.playback.get_current_node() == &"attack1",
		"animation = attack1 (%s)" % player.playback.get_current_node())
	await _wait(0.16)                                   ## t = 0,36 : fenêtre ouverte
	await _tap_action("attack")                         ## coup 2 (enchaîné)
	await _wait(0.45)                                   ## t = 0,81 : fenêtre du coup 2
	await _tap_action("attack")                         ## coup 3 (finisseur)
	await _wait(0.16)
	_check(player.playback.get_current_node() == &"attack3",
		"coup 3 (finisseur) joué : %s" % player.playback.get_current_node())
	await _wait(1.0)
	count_hits = false

	_check(hits == 3, "3 coups portés au mannequin (%d)" % hits)
	_check(dummy.health < health_before, "vie du mannequin en baisse (%.0f -> %.0f)"
		% [health_before, dummy.health])
	_check(player.energy > energy_before, "énergie gagnée en frappant (%.0f)" % player.energy)
	_check(player.state == Player3D.State.IDLE, "retour à l'arrêt après le combo")


func _test_dodge_iframes() -> void:
	print("- Esquive et invincibilité (§ 8.3)")
	await _reset_actors()
	var start_x := player.global_position.x
	await _tap_action("dodge")
	await get_tree().physics_frame
	_check(player.state == Player3D.State.DODGE, "état ESQUIVE après l'appui")
	_check(player.invincible_time > 0.0, "invincibilité active pendant l'esquive")
	var health_before := player.health
	dummy.hitbox.activate()                             ## coup du mannequin pendant l'esquive
	await _frames(6)
	_check(last_result == Hurtbox3D.Result.DODGED, "coup esquivé (résultat DODGED)")
	_check(player.health == health_before, "aucun dégât pendant l'invincibilité")
	dummy.hitbox.deactivate()
	# On relève la position au moment précis où l'état d'esquive se termine.
	var guard_frames := 0
	while player.state == Player3D.State.DODGE and guard_frames < 90:
		await get_tree().physics_frame
		guard_frames += 1
	var dodged_distance := absf(player.global_position.x - start_x)
	_check(player.state == Player3D.State.IDLE, "retour à l'arrêt après l'esquive")
	_check(dodged_distance > 3.0 and dodged_distance < 4.2,
		"distance d'esquive = %.2f m (§ 8.3 : 3,6 m)" % dodged_distance)


func _test_guard() -> void:
	print("- Garde simple (§ 8.4 : −70 %)")
	await _reset_actors()
	await _action("guard", true)                        ## bouton Garde maintenu
	await get_tree().physics_frame
	_check(player.state == Player3D.State.GUARD, "état GARDE tant que le bouton est tenu")
	# PHASE 2 : une garde levée moins de 0,18 s avant l'impact est PARFAITE (0
	# dégât). On attend la fin de cette fenêtre pour tester la garde ordinaire
	# (−70 %) ; la garde parfaite est vérifiée dans tests/Phase2Test.gd.
	await _wait(0.32)
	# Et les critiques (8 %, ×1,5, § 8.7) sont testées dans Phase2Test : ici on
	# veut la valeur exacte de la réduction de garde.
	dummy.hitbox.crit_chance = 0.0
	dummy.hitbox.activate()
	await _frames(6)
	_check(last_result == Hurtbox3D.Result.BLOCKED, "coup bloqué (résultat BLOCKED)")
	_check(absf(player.health - 96.4) < 0.05, "dégâts réduits de 70 %% : vie = %.1f" % player.health)
	dummy.hitbox.deactivate()
	await _action("guard", false)
	await _frames(3)
	_check(player.state == Player3D.State.IDLE, "garde relâchée -> retour à l'arrêt")


func _test_dummy_riposte() -> void:
	print("- Riposte du mannequin (boucle complète, sans forcer la Hitbox)")
	await _reset_actors()
	dummy.cooldown_left = 0.0
	await _wait(1.2)                                     ## télégraphe 0,4 s + coup
	_check(player.health < 100.0, "la joueuse a été touchée : vie = %.1f" % player.health)
	_check(last_result == Hurtbox3D.Result.HIT, "coup encaissé (résultat HIT)")
	_check(last_invincible > 0.7,
		"invincibilité 0,8 s au moment du coup reçu (§ 8.6) : %.2f" % last_invincible)
	_check(hud.life.value == player.health, "HUD à jour (%.1f)" % hud.life.value)


func _test_player_death() -> void:
	print("- Mort et réapparition de la joueuse")
	await _reset_actors()
	var info := DamageInfo.new()
	info.amount = 999.0
	info.source_position = dummy.global_position
	player.on_hit_received(info)
	_check(player.state == Player3D.State.DEAD, "état MORT à 0 vie")
	_check(player.health == 0.0, "vie à 0")
	_check(hud.life.value == 0.0, "barre de vie vide")
	await _wait(3.0)
	_check(player.health == 100.0 and player.state == Player3D.State.IDLE,
		"réapparition automatique (PHASE 1)")
	_check(hud.life.value == 100.0, "barre de vie restaurée")


func _test_dummy_respawn() -> void:
	print("- Mort et réapparition du mannequin")
	await _reset_actors()
	var info := DamageInfo.new()
	info.amount = 999.0
	info.source_position = player.global_position
	dummy.on_hit_received(info)
	_check(dummy.dead, "mannequin mort après un coup fatal")
	# On attend la réapparition en surveillant la frame exacte (aucune fenêtre
	# pendant laquelle un coup pourrait fausser la vérification).
	var waited := 0.0
	while dummy.dead and waited < RESPAWN_GUARD:
		await get_tree().physics_frame
		waited += 1.0 / 60.0
	_check(not dummy.dead, "mannequin réapparu après %.1f s" % waited)
	_check(dummy.health == Dummy3D.MAX_HEALTH,
		"vie restaurée à la réapparition (%.0f)" % dummy.health)
	_check(dummy.global_position.distance_to(Vector3(2.4, dummy.global_position.y, 0.0)) < 0.2,
		"mannequin revenu à sa position de départ")
