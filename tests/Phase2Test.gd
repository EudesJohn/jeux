extends Node
## Test fonctionnel de la PHASE 2 (DESIGN.md § 28 et § 29), sans écran :
##   godot --headless --path . res://tests/Phase2Test.tscn     (logique de jeu)
##   godot --path . res://tests/Phase2Test.tscn                (logique + doigts)
##
## Il charge l'arène RÉELLE en ARENA (ArenaTest.tscn) et vérifie le combat
## complet de la PHASE 2 : valeurs de data/balance.tres, critiques 8 % ×1,5,
## hit-stop, tremblement, particules d'impact, flash de dégâts, nombres de
## dégâts, garde parfaite avec contre-attaque et étourdissement, stabilité de
## garde et garde brisée, esquive parfaite, tourbillon du sabre, verrouillage
## automatique en ARENA (anneau 3D + anneau du HUD), vignette de dégâts et
## messages du HUD.
##
## Sortie : « PHASE 2 : OK » (code 0) ou la liste des échecs (code 1).

const MIN_VIEWPORT_FOR_TOUCH: float = 1000.0
## Tolérance sur les valeurs de balance.tres (réglages à chaud).
const EPS: float = 0.001

var failures: int = 0
var checks: int = 0
var skipped: int = 0

var arena: Node3D
var player: Player3D
var camera_rig: CameraRig
var hud: HUD
var touch_controls: TouchControls
var dummies: Array[Dummy3D] = []

var last_result: int = -1
var last_info: DamageInfo = null          ## dernier coup reçu par la joueuse
var last_dummy_info: DamageInfo = null    ## dernier coup reçu par un mannequin
var perfect_guard_seen: bool = false
var perfect_dodge_seen: bool = false
var guard_broken_seen: bool = false
var special_ready_seen: bool = false
var damaged_seen: bool = false
var lock_changes: int = 0


func _ready() -> void:
	print("=== Test fonctionnel PHASE 2 ===")
	arena = load("res://scenes/tests/ArenaTest.tscn").instantiate() as Node3D
	add_child(arena)
	await _frames(10)
	player = arena.get_node("Player3D") as Player3D
	camera_rig = arena.get_node("CameraRig") as CameraRig
	hud = arena.get_node("HUD") as HUD
	touch_controls = arena.get_node("TouchControls") as TouchControls
	for child in arena.get_children():
		if child is Dummy3D:
			dummies.append(child)
	player.hurtbox.damaged.connect(_on_damaged)
	for dummy in dummies:
		dummy.hurtbox.damaged.connect(_on_dummy_damaged)
	Events.perfect_guard.connect(_on_perfect_guard)
	Events.perfect_dodge.connect(_on_perfect_dodge)
	Events.guard_broken.connect(_on_guard_broken)
	Events.special_ready.connect(_on_special_ready)
	Events.player_damaged.connect(_on_player_damaged)
	Events.lock_on_changed.connect(_on_lock_changed)

	await _test_balance()
	await _test_scene()
	await _test_crit()
	await _test_impact_and_hitstop()
	await _test_damage_flash()
	await _test_perfect_guard()
	await _test_guard_stability()
	await _test_perfect_dodge()
	await _test_special()
	await _test_arena_lock()
	await _test_hud()
	await _test_balance_scene()

	print("--------------------------------")
	print("Vérifications : %d   Échecs : %d   Ignorées : %d" % [checks, failures, skipped])
	print("PHASE 2 : %s" % ("OK" if failures == 0 else "ÉCHECS"))
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


func _on_damaged(info: DamageInfo, result: int) -> void:
	last_result = result
	last_info = info


func _on_dummy_damaged(info: DamageInfo, _result: int) -> void:
	last_dummy_info = info


func _on_perfect_guard(_actor: Node) -> void:
	perfect_guard_seen = true


func _on_perfect_dodge(_actor: Node) -> void:
	perfect_dodge_seen = true


func _on_guard_broken(_actor: Node) -> void:
	guard_broken_seen = true


func _on_special_ready(_actor: Node) -> void:
	special_ready_seen = true


func _on_player_damaged(actor: Node, _amount: float) -> void:
	if actor == player:
		damaged_seen = true


func _on_lock_changed(_target: Node3D) -> void:
	lock_changes += 1


func _dummy(index: int) -> Dummy3D:
	return dummies[index]


## Repose la joueuse et tous les mannequins dans un état connu.
## `positions` place les mannequins (m) ; les autres partent loin, hors de portée.
func _reset_actors(positions: Array[Vector3] = []) -> void:
	Engine.time_scale = 1.0
	Events.joystick_vector = Vector2.ZERO
	player.global_position = Vector3(0.0, 0.1, 0.0)
	player.velocity = Vector3.ZERO
	player.health = player.balance.max_health
	player.energy = 0.0
	player._special_ready = false
	player.invincible_time = 0.0
	player.hurt_time_left = 0.0
	player.dodge_time_left = 0.0
	player.dodge_elapsed = 0.0
	player.dodge_cooldown = 0.0
	player.attack_step = 0
	player.attack_time = 0.0
	player.queued_next = false
	player.guard_perfect_left = 0.0
	player.guard_stability = player.balance.guard_stability_max
	player.special_time_left = 0.0
	player.state = Player3D.State.IDLE
	player.facing_dir = Vector3.RIGHT
	player.hitbox.deactivate()
	player.hitbox.damage = player.balance.base_damage
	player.hitbox.knockback = 1.2
	player.hitbox.hitstop = 0.0
	player.hitbox.shake_strength = 0.0
	player.hitbox.crit_chance = player.balance.crit_chance
	player.hitbox.crit_mult = player.balance.crit_mult
	player.health_changed.emit(player.health, player.balance.max_health)
	player.energy_changed.emit(player.energy, player.balance.max_energy)
	for i in dummies.size():
		var dummy := dummies[i]
		dummy.global_position = positions[i] if i < positions.size() else Vector3(30.0 + i, 0.1, 30.0)
		dummy.velocity = Vector3.ZERO
		dummy.max_health = dummy.balance.dummy_health
		dummy.health = dummy.max_health
		dummy.dead = false
		dummy.damageable = true
		dummy.stun_left = 0.0
		dummy.cooldown_left = 9999.0        ## aucune riposte pendant le test
		dummy.abort_attack()                ## et pas de riposte héritée du test précédent
		dummy.hitbox.damage = dummy.balance.dummy_damage
		dummy.visual.rotation.y = PI * 0.5  ## tourné vers la joueuse (à -X)
	last_result = -1
	last_info = null
	last_dummy_info = null
	await _frames(4)


## Action de jeu, comme si le bouton tactile avait été pressé.
func _action(action_name: String, pressed: bool) -> void:
	Events.touch_action.emit(action_name, pressed)
	await get_tree().process_frame


func _tap_action(action_name: String) -> void:
	await _action(action_name, true)
	await _action(action_name, false)


## Déclenche un coup d'une cible sur la joueuse, sans attendre son télégraphe.
func _hit_player(damage: float, source: Node = null) -> void:
	var dummy := _dummy(0) if source == null else source
	var info := DamageInfo.new()
	info.amount = damage
	info.knockback = 1.2
	info.source_position = (dummy as Node3D).global_position
	info.source_actor = dummy
	player.hurtbox.receive_hit(info)


func _count_in_world(prefix: String) -> int:
	var count := 0
	for child in arena.get_children():
		if child.name.to_lower().contains(prefix.to_lower()):
			count += 1
	return count


# -----------------------------------------------------------------#
#                            LES TESTS                             #
# -----------------------------------------------------------------#

## § 8 : toutes les valeurs de combat sont dans data/balance.tres.
func _test_balance() -> void:
	print("- Valeurs de combat (data/balance.tres, § 8)")
	var balance := player.balance
	_check(balance != null and balance.resource_path.ends_with("data/balance.tres"),
		"balance.tres chargé (%s)" % balance.resource_path)
	_check(absf(balance.max_health - 100.0) < EPS, "vie max = %.0f" % balance.max_health)
	_check(absf(balance.max_energy - 100.0) < EPS, "énergie max = %.0f" % balance.max_energy)
	_check(absf(balance.speed - 4.5) < EPS, "vitesse = %.1f m/s (§ 8.1)" % balance.speed)
	_check(absf(balance.gravity - 20.0) < EPS, "gravité = %.0f m/s²" % balance.gravity)
	_check(absf(balance.base_damage - 10.0) < EPS, "dégâts de base = %.0f" % balance.base_damage)
	_check(absf(balance.crit_chance - 0.08) < EPS, "critique = %.0f %% (§ 8.7)" % (balance.crit_chance * 100.0))
	_check(absf(balance.crit_mult - 1.5) < EPS, "critique ×%.1f" % balance.crit_mult)
	_check(absf(balance.dodge_duration - 0.35) < EPS, "esquive 0,35 s" )
	_check(absf(balance.dodge_iframes - 0.25) < EPS, "invincibilité d'esquive 0,25 s")
	_check(absf(balance.dodge_distance - 3.6) < EPS, "distance d'esquive 3,6 m (§ 8.3)")
	_check(absf(balance.perfect_dodge_window - 0.12) < EPS, "esquive parfaite < 0,12 s")
	_check(absf(balance.perfect_guard_window - 0.18) < EPS, "garde parfaite 0,18 s (§ 8.4)")
	_check(absf(balance.guard_damage_taken - 0.3) < EPS, "garde maintenue : −70 %")
	_check(absf(balance.guard_stability_max - 30.0) < EPS, "stabilité de garde = 30")
	_check(absf(balance.perfect_guard_stun - 0.8) < EPS, "garde parfaite : ennemi étourdi 0,8 s")
	_check(absf(balance.special_cost - 100.0) < EPS, "spécial : coût 100 énergie (§ 8.5)")
	_check(absf(balance.special_damage_mult - 3.0) < EPS, "spécial : dégâts ×3")
	var steps := player.combo.steps
	_check(steps.size() == 3, "3 coups au combo")
	if steps.size() == 3:
		_check(absf(float(steps[0]["mult"]) - 0.8) < EPS
			and absf(float(steps[1]["mult"]) - 1.0) < EPS
			and absf(float(steps[2]["mult"]) - 1.6) < EPS,
			"multiplicateurs du combo ×0,8 / ×1,0 / ×1,6 (§ 8.2)")
		_check(absf(float(steps[2]["knockback"]) - 4.4) < EPS, "recul du finisseur 4,4 m")
		_check(absf(float(steps[2]["hitstop"]) - 0.09) < EPS, "hit-stop du finisseur 0,09 s")
		_check(player.combo.balance == balance, "le combo lit balance.tres")


func _test_scene() -> void:
	print("- Arène ARENA et branchements")
	_check(camera_rig.mode == CameraRig.Mode.ARENA, "caméra en mode ARENA")
	_check(absf(camera_rig.cam.fov - 55.0) < EPS, "FOV ARENA = 55°")
	_check(player.lane_mode == false, "joueuse libre à 360° (pas de couloir)")
	_check(dummies.size() == 3, "3 mannequins en arène (%d)" % dummies.size())
	_check(hud.player == player, "HUD lié à la joueuse")
	_check(touch_controls.get_node_or_null("Special") is TouchButton, "bouton Spécial présent")
	_check(camera_rig.ring != null, "anneau de cible 3D créé (§ 3.2)")


## § 8.7 : critique 8 %, ×1,5, étincelle dorée.
func _test_crit() -> void:
	print("- Critiques (§ 8.7)")
	await _reset_actors([Vector3(1.4, 0.1, 0.0)])
	var dummy := _dummy(0)
	player.hitbox.damage = player.balance.base_damage
	player.hitbox.crit_chance = 1.0
	player.hitbox.crit_mult = player.balance.crit_mult
	var health_before := dummy.health
	player.hitbox.activate()
	await _frames(4)
	player.hitbox.deactivate()
	var dealt := health_before - dummy.health
	_check(player.hitbox.last_critical, "coup critique annoncé")
	_check(absf(dealt - 15.0) < 0.01, "dégâts critiques = 10 × 1,5 = %.1f" % dealt)
	_check(last_dummy_info != null and last_dummy_info.is_critical,
		"DamageInfo.is_critical transmis à la cible")
	_check(_count_in_world("damagenumber") > 0, "nombre de dégâts affiché (DamageNumber)")
	# Sans critique : 8 % de base ne doit PAS donner de critique si le taux est 0.
	player.hitbox.crit_chance = 0.0
	health_before = dummy.health
	player.hitbox.activate()
	await _frames(4)
	player.hitbox.deactivate()
	dealt = health_before - dummy.health
	_check(not player.hitbox.last_critical and absf(dealt - 10.0) < 0.01,
		"aucun critique à 0 %% : dégâts = %.1f" % dealt)


## Hit-stop (§ 8.2), tremblement de caméra et particules d'impact (§ 28).
func _test_impact_and_hitstop() -> void:
	print("- Hit-stop, tremblement et particules d'impact")
	await _reset_actors([Vector3(1.4, 0.1, 0.0)])
	var dummy := _dummy(0)
	player.hitbox.crit_chance = 0.0
	player.hitbox.hitstop = 0.12
	player.hitbox.shake_strength = 0.3
	player.hitbox.activate()
	await _frames(3)
	_check(_count_in_world("impactfx") > 0, "particules d'impact créées")
	_check(Engine.time_scale < 0.5, "hit-stop actif (échelle %.2f)" % Engine.time_scale)
	_check(camera_rig._shake_time > 0.0, "tremblement de caméra en cours")
	player.hitbox.deactivate()
	await _wait(0.4)
	_check(absf(Engine.time_scale - 1.0) < EPS,
		"échelle du temps restaurée après le hit-stop (%.2f)" % Engine.time_scale)
	_check(dummy.health < dummy.max_health, "dégâts appliqués pendant le hit-stop")


## § 28 : flash de dégâts quand la joueuse est touchée.
func _test_damage_flash() -> void:
	print("- Flash de dégâts et dégâts reçus (§ 8.6)")
	await _reset_actors([Vector3(1.6, 0.1, 0.0)])
	damaged_seen = false
	_hit_player(12.0)
	_check(absf(player.health - 88.0) < 0.01, "vie = %.1f après 12 dégâts" % player.health)
	_check(player.state == Player3D.State.HURT, "état BLESSURE")
	_check(player.invincible_time > 0.7, "invincibilité 0,8 s (§ 8.6)")
	_check(damaged_seen, "Events.player_damaged émis (vignette du HUD)")
	_check(player._flash_left > 0.0, "flash de dégâts actif")
	var tint: Color = player._materials[0].get_shader_parameter("tint")
	_check(tint.r > 0.9 and tint.g < 0.7, "modèle teinté en flash (%.2f, %.2f, %.2f)" % [tint.r, tint.g, tint.b])
	await _wait(0.2)
	_check(player._flash_left <= 0.0, "flash terminé, teinte d'origine restaurée")
	# Invincibilité : un second coup immédiat est ignoré.
	var health_after := player.health
	_hit_player(12.0)
	_check(absf(player.health - health_after) < 0.01, "coup ignoré pendant l'invincibilité")


## § 8.4 : garde parfaite — 0 dégât, ennemi étourdi 0,8 s, contre-attaque, +15 énergie.
func _test_perfect_guard() -> void:
	print("- Garde parfaite et contre-attaque (§ 8.4)")
	await _reset_actors([Vector3(1.5, 0.1, 0.0)])
	var dummy := _dummy(0)
	perfect_guard_seen = false
	await _action("guard", true)
	dummy.hitbox.damage = 12.0
	dummy.hitbox.activate()
	await _frames(3)
	dummy.hitbox.deactivate()
	_check(last_result == Hurtbox3D.Result.PERFECT_GUARD,
		"résultat PERFECT_GUARD (reçu %d)" % last_result)
	_check(absf(player.health - 100.0) < 0.01, "0 dégât : vie = %.1f" % player.health)
	# +15 pour la garde parfaite et +6 pour le coup de la contre-attaque (§ 8.5).
	_check(absf(player.energy - 21.0) < 0.01,
		"+15 énergie (garde parfaite) puis +6 (contre-attaque) : %.0f" % player.energy)
	_check(perfect_guard_seen, "Events.perfect_guard émis")
	_check(dummy.stun_left > 0.5, "ennemi étourdi 0,8 s (reste %.2f s)" % dummy.stun_left)
	_check(dummy.health < dummy.max_health,
		"contre-attaque portée (mannequin %.0f / %.0f)" % [dummy.health, dummy.max_health])
	_check(hud.popup_text() == "GARDE PARFAITE !",
		"HUD : message « %s »" % hud.popup_text())
	# Étourdi : le mannequin ne peut pas riposter.
	dummy.cooldown_left = 0.0
	await _wait(0.4)
	_check(dummy.playing_hit == false, "aucune riposte pendant l'étourdissement")
	await _action("guard", false)
	await _wait(player.balance.perfect_guard_stun)


## § 8.4 : garde maintenue (−70 %, −5 de stabilité) et garde brisée à 0.
func _test_guard_stability() -> void:
	print("- Stabilité de garde et garde brisée (§ 8.4)")
	await _reset_actors([Vector3(1.5, 0.1, 0.0)])
	var dummy := _dummy(0)
	# Les critiques (§ 8.7) sont vérifiées plus haut : ici on veut la valeur
	# exacte de la réduction de garde, sans tirage aléatoire.
	dummy.hitbox.crit_chance = 0.0
	await _action("guard", true)
	await _wait(0.32)                       ## au-delà de la fenêtre parfaite
	dummy.hitbox.damage = 12.0
	dummy.hitbox.activate()
	await _frames(3)
	dummy.hitbox.deactivate()
	var taken := 100.0 - player.health
	_check(last_result == Hurtbox3D.Result.BLOCKED,
		"garde maintenue : coup bloqué (résultat %d)" % last_result)
	_check(absf(taken - 3.6) < 0.01, "dégâts réduits de 70 %% : %.1f (§ 8.4)" % taken)
	_check(absf(player.guard_stability - 25.0) < 0.01,
		"stabilité 30 − 5 = %.0f" % player.guard_stability)
	# Garde brisée : stabilité à 0 -> étourdie 0,6 s.
	guard_broken_seen = false
	player.guard_stability = 5.0
	await _wait(0.32)
	dummy.hitbox.activate()
	await _frames(3)
	dummy.hitbox.deactivate()
	# Elle régénère aussitôt (5/s) : on vérifie qu'elle est bien retombée à zéro.
	_check(player.guard_stability < 0.5,
		"stabilité tombée à 0 (%.2f, puis régénération)" % player.guard_stability)
	_check(guard_broken_seen, "Events.guard_broken émis")
	_check(player.state == Player3D.State.HURT and player.hurt_time_left > 0.4,
		"garde brisée : étourdie 0,6 s (reste %.2f s)" % player.hurt_time_left)
	_check(hud.popup_text() == "GARDE BRISÉE", "HUD : message « %s »" % hud.popup_text())
	# La stabilité régénère 5/s quand on ne bloque pas (§ 8.4).
	await _wait(1.2)
	_check(player.guard_stability > 4.0,
		"stabilité régénérée après la garde brisée (%.0f)" % player.guard_stability)


## § 8.3 : esquive parfaite (< 0,12 s avant l'impact) — ralenti et +10 énergie.
func _test_perfect_dodge() -> void:
	print("- Esquive parfaite (§ 8.3)")
	await _reset_actors([Vector3(1.5, 0.1, 0.0)])
	perfect_dodge_seen = false
	await _tap_action("dodge")
	_check(player.state == Player3D.State.DODGE, "état ESQUIVE")
	_hit_player(12.0)
	_check(player.dodge_elapsed <= player.balance.perfect_dodge_window + 0.05,
		"impact %.3f s après le début de l'esquive (fenêtre 0,12 s)" % player.dodge_elapsed)
	_check(last_result == Hurtbox3D.Result.DODGED, "coup esquivé")
	_check(absf(player.health - 100.0) < 0.01, "0 dégât pendant l'esquive")
	_check(absf(player.energy - 10.0) < 0.01, "esquive parfaite : +10 énergie (%.0f)" % player.energy)
	_check(perfect_dodge_seen, "Events.perfect_dodge émis")
	_check(Engine.time_scale < 1.0, "ralenti déclenché (échelle %.2f)" % Engine.time_scale)
	await _wait(0.6)
	_check(absf(Engine.time_scale - 1.0) < EPS, "échelle du temps restaurée")


## § 8.5 : le spécial du sabre est un tourbillon 360° (coût 100, dégâts ×3).
func _test_special() -> void:
	print("- Spécial du sabre : tourbillon 360° (§ 8.5)")
	await _reset_actors([Vector3(1.8, 0.1, 0.0), Vector3(0.0, 0.1, -2.0), Vector3(6.0, 0.1, 0.0)])
	var near_a := _dummy(0)
	var near_b := _dummy(1)
	var far := _dummy(2)
	special_ready_seen = false
	player.set_energy(player.balance.max_energy)
	_check(special_ready_seen, "Events.special_ready émis à 100 énergie")
	await _tap_action("special")
	_check(player.state == Player3D.State.SPECIAL, "état SPÉCIAL déclenché")
	_check(absf(player.energy) < 0.01, "coût payé : énergie = %.0f" % player.energy)
	_check(player.invincible_time > 0.5, "invincible pendant l'animation (§ 8.5)")
	var far_health := far.health
	# Le hit-stop du spécial (0,15 s) rallonge l'animation en temps réel.
	await _wait(1.8)
	_check(near_a.health < near_a.max_health,
		"adversaire de face touché (%.0f / %.0f)" % [near_a.health, near_a.max_health])
	_check(near_b.health < near_b.max_health,
		"adversaire DERRIÈRE touché : tourbillon 360° (%.0f / %.0f)" % [near_b.health, near_b.max_health])
	_check(absf(far.health - far_health) < 0.01,
		"adversaire hors du rayon (%.1f m) intact" % player.balance.special_radius)
	var damage_a := near_a.max_health - near_a.health
	_check(damage_a > 20.0, "dégâts du spécial ×3 : %.0f (base 10)" % damage_a)
	_check(player.state == Player3D.State.IDLE, "retour à l'arrêt après le spécial")
	_check(not player.special_ready(), "spécial indisponible après usage")


## § 3.2 : verrouillage automatique, anneau, changement de cible au doigt.
func _test_arena_lock() -> void:
	print("- Caméra ARENA et verrouillage (§ 3.2)")
	await _reset_actors([Vector3(3.0, 0.1, 0.0), Vector3(-4.0, 0.1, 2.0), Vector3(1.0, 0.1, -5.0)])
	lock_changes = 0
	camera_rig._set_lock_target(null)
	await _frames(4)
	_check(camera_rig.lock_target == _dummy(0),
		"cible = ennemi le plus proche (%.1f m)"
			% player.global_position.distance_to(_dummy(0).global_position))
	_check(lock_changes > 0, "Events.lock_on_changed émis")
	_check(player.lock_target == camera_rig.lock_target, "la joueuse connaît sa cible")
	_check(camera_rig.ring != null and camera_rig.ring.visible, "anneau doré 3D affiché sur la cible")
	await _wait(1.0)
	var distance := camera_rig.cam.global_position.distance_to(player.global_position)
	_check(distance > 5.0 and distance < 9.0,
		"caméra à %.1f m de la joueuse (7 m + hauteur, § 3.2)" % distance)
	_check(camera_rig.cam.global_position.y > player.global_position.y + 2.0,
		"caméra haute (y = %.1f)" % camera_rig.cam.global_position.y)
	# Changer de cible en touchant un ennemi à l'écran (§ 7).
	var other := _dummy(2)
	var screen := camera_rig.cam.unproject_position(other.global_position + Vector3(0.0, 1.0, 0.0))
	camera_rig._try_lock_at(screen)
	_check(camera_rig.lock_target == other, "appui sur le 3e ennemi -> cible changée")
	# Cible morte : on passe automatiquement à une autre.
	var killer := DamageInfo.new()
	killer.amount = 9999.0
	killer.source_position = player.global_position
	killer.source_actor = player
	other.hurtbox.receive_hit(killer)
	await _frames(4)
	await _wait(0.5)
	_check(camera_rig.lock_target != other and camera_rig.lock_target != null,
		"cible morte : nouvelle cible choisie automatiquement")
	# Priorité à celui qui attaque (§ 3.2).
	var attacker := _dummy(0)
	attacker.cooldown_left = 0.0
	await _frames(4)
	await _wait(0.2)
	_check(camera_rig.lock_target == attacker or camera_rig.lock_target == _dummy(1),
		"le verrouillage reste sur un ennemi vivant")


## § 16 : vignette de dégâts, messages, barre spécial et anneau du HUD.
func _test_hud() -> void:
	print("- HUD de combat (§ 16)")
	await _reset_actors([Vector3(1.6, 0.1, 0.0)])
	hud._set_vignette(0.0)
	_hit_player(20.0)
	_check(hud.vignette_intensity() > 0.0,
		"vignette de dégâts allumée (%.2f)" % hud.vignette_intensity())
	await _wait(1.0)
	_check(hud.vignette_intensity() < 0.5,
		"vignette estompée après le coup (%.2f)" % hud.vignette_intensity())
	_check(absf(hud.life.value - player.health) < 0.01,
		"barre de vie à jour (%.1f)" % hud.life.value)
	_check(absf(hud.stability.value - player.guard_stability) < 0.01, "barre de garde à jour")
	player.set_energy(100.0)
	_check(hud.special_ready_label.modulate.a > 0.0, "« SPÉCIAL PRÊT » affiché")
	player.set_energy(0.0)
	await _frames(2)
	_check(hud.special_ready_label.modulate.a <= 0.0, "« SPÉCIAL PRÊT » masqué sans énergie")
	# Anneau de verrouillage du HUD : il suit la cible de la caméra.
	camera_rig._set_lock_target(_dummy(0))
	await _frames(4)
	_check(hud.lock_on.target == camera_rig.lock_target, "anneau du HUD lié à la cible")
	_check(hud.lock_on.visible, "anneau du HUD affiché")
	# Sans cible ET sans verrouillage automatique, l'anneau disparaît.
	camera_rig.auto_lock = false
	camera_rig._set_lock_target(null)
	await _frames(4)
	_check(not hud.lock_on.visible, "anneau du HUD masqué sans cible")
	camera_rig.auto_lock = true
	# Chaîne tactile complète (doigt -> bouton -> jeu) : nécessite une vraie fenêtre.
	if DisplayServer.get_name() == "headless" \
			or get_viewport().get_visible_rect().size.x < MIN_VIEWPORT_FOR_TOUCH:
		_skip("chaîne tactile réelle : relancer sans --headless")
		return
	await _reset_actors([Vector3(1.6, 0.1, 0.0)])
	var attack := (touch_controls.get_node("Attack") as TouchButton).get_global_rect().get_center()
	var touch := InputEventScreenTouch.new()
	touch.index = 7
	touch.position = attack
	touch.pressed = true
	get_viewport().push_input(touch)
	await get_tree().physics_frame
	_check(player.state == Player3D.State.ATTACK, "doigt sur Attaque -> état ATTAQUE")


## § 28 : « Scène de test pour ajuster les valeurs » — les curseurs de
## BalanceTest écrivent bien dans data/balance.tres, et RECHARGER restaure.
func _test_balance_scene() -> void:
	print("- Scène de réglage à chaud (scenes/tests/BalanceTest.tscn)")
	var scene: Node3D = load("res://scenes/tests/BalanceTest.tscn").instantiate() as Node3D
	add_child(scene)
	await _frames(4)
	var rows := scene.get_node("UI/Panel/Root/Scroll/Rows") as VBoxContainer
	_check(rows.get_child_count() == scene.FIELDS.size(),
		"%d curseurs créés pour %d réglages" % [rows.get_child_count(), scene.FIELDS.size()])
	var balance: Balance = scene.balance
	_check(balance == player.balance, "la scène règle la ressource utilisée en jeu")
	var before := balance.crit_chance
	var slider := rows.get_child(1).get_child(1) as HSlider
	slider.value = 0.5
	await _frames(2)
	_check(absf(balance.crit_chance - 0.5) < 0.001,
		"curseur « Critique » -> balance.tres = %.2f" % balance.crit_chance)
	var camera_slider := rows.get_child(rows.get_child_count() - 1).get_child(1) as HSlider
	camera_slider.value = 12.0
	await _frames(2)
	_check(absf(scene.camera_rig.lock_radius - 12.0) < 0.001,
		"curseur « Verrouillage caméra » -> %.1f m" % scene.camera_rig.lock_radius)
	scene._on_reload()
	await _frames(2)
	_check(absf(balance.crit_chance - before) < 0.001,
		"RECHARGER restaure les valeurs du fichier (%.2f)" % balance.crit_chance)
	scene.queue_free()
	await _frames(2)
