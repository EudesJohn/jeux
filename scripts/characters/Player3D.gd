extends CharacterBody3D
class_name Player3D
## Joueuse (DESIGN.md § 20.4, valeurs § 8). Déplacement relatif à la caméra,
## rotation du modèle, combo de 3 coups (ComboController), aimant d'attaque,
## esquive avec invincibilité, garde.
##
## PHASE 2 — combat complet et « game feel » :
##  * garde parfaite (0,18 s) : 0 dégât, ennemi étourdi 0,8 s, contre-attaque,
##    +15 énergie, ralenti ;
##  * stabilité de garde (30, −5 par coup bloqué, +5/s) : à 0, garde brisée ;
##  * esquive parfaite (< 0,12 s avant l'impact) : ralenti 0,3 s, +10 énergie ;
##  * spécial du sabre : tourbillon 360° (coût 100, dégâts ×3, invincible) ;
##  * flash de dégâts, hit-stop, tremblement et particules via FX.
##
## Les valeurs de combat viennent de `data/balance.tres` (§ 8) ; `PlayerData`
## reste la fiche du personnage (modèle remplaçable, vitesse de secours).
## Tactile : Events.touch_action + Events.joystick_vector (§ 7).
## Clavier PC de secours : WASD/flèches + J attaque, K esquive, L garde, I spécial.

enum State { IDLE, RUN, ATTACK, DODGE, GUARD, SPECIAL, HURT, DEAD }

const DEFAULT_BALANCE: String = "res://data/balance.tres"
const PUPPET_FEET_OFFSET: float = -0.42   ## poupée de test : pieds à +0,42 m
const FLASH_TIME: float = 0.08            ## durée du flash de dégâts
const FLASH_COLOR: Color = Color(1.0, 0.5, 0.45)
const SPECIAL_SPIN: float = TAU           ## tour complet du tourbillon (§ 8.5)
const COUNTER_ANIM_TIME: float = 0.35     ## durée de l'animation de contre

signal health_changed(current: float, maximum: float)
signal energy_changed(current: float, maximum: float)
signal died

@export var data: PlayerData
@export var balance: Balance
@export var lane_mode: bool = true                 ## § 3.1 : profondeur limitée
@export var lane_depth: float = 3.0
@export var lane_center_z: float = 0.0
@export var auto_respawn: bool = true              ## PHASE 1 : test sans niveau

@onready var visual: Node3D = $Visual
@onready var hurtbox: Hurtbox3D = $Hurtbox3D
@onready var hitbox: Hitbox3D = $Visual/Hitbox3D
@onready var combo: ComboController = $ComboController

## PHASE 7 : à quelle joueuse appartient ce nœud (§ 22). 1 = l'hôte.
var peer_id: int = 1
## PHASE 7 : à terre, en attente de réanimation (§ 22.3) — ce n'est pas la mort.
var downed: bool = false
## PHASE 7 : position publiée sur le réseau. Les copies distantes glissent vers
## elle (`_follow_network`) : Godot 4.3 n'interpole pas les synchroniseurs, et
## 20 Hz sans lissage se voit tout de suite.
var net_position: Vector3 = Vector3.ZERO

var _remote_state: State = State.IDLE

var state: State = State.IDLE
var health: float
var energy: float = 0.0
var facing_dir: Vector3 = Vector3.BACK             ## face à la caméra au départ
var lock_target: Node3D = null                     ## ARENA (§ 3.2)
## § 7 / § 12.2 : bouton « Interaction » maintenu 2 s près d'une cage.
var interact_held: bool = false
var invincible_time: float = 0.0
var dodge_cooldown: float = 0.0
var guard_pressed_time: float = -1.0               ## horloge murale (relevé)
var guard_perfect_left: float = 0.0                ## fenêtre de garde parfaite
var guard_stability: float = 30.0
var input_buffer: String = ""
var input_buffer_time: float = 0.0
var hurt_time_left: float = 0.0
var dodge_time_left: float = 0.0
var dodge_elapsed: float = 0.0
var dodge_dir: Vector3 = Vector3.ZERO
var attack_step: int = 0
var attack_time: float = 0.0
var queued_next: bool = false
var special_time_left: float = 0.0
## Ralentissement (boue du § 11 : −40 %). 1,0 = vitesse normale.
var speed_mult: float = 1.0
## § 12.3 : bonus de dégâts cumulés pendant une Survie (choisi entre les vagues).
var run_damage_mult: float = 1.0
var anim_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback

var _special_hit: Array[Node] = []
var _materials: Array[ShaderMaterial] = []
var _tints: Array[Color] = []
var _flash_left: float = 0.0
var _slow_left: float = 0.0
var _special_ready: bool = false
var _anim_ready: bool = false
var _anim_tries: int = 0


# -----------------------------------------------------------------#
#                          INITIALISATION                          #
# -----------------------------------------------------------------#

func _ready() -> void:
	add_to_group("players")
	if data == null:
		data = load("res://data/player_default.tres") as PlayerData
	if balance == null:
		balance = load(DEFAULT_BALANCE) as Balance
	if balance == null:
		balance = Balance.new()
	health = max_health_value()
	guard_stability = balance.guard_stability_max
	hurtbox.owner_actor = self
	hitbox.owner_actor = self
	hitbox.crit_chance = balance.crit_chance
	hitbox.crit_mult = balance.crit_mult
	hitbox.hit_landed.connect(_on_hit_landed)
	combo.configure(balance)
	Events.touch_action.connect(_on_touch_action)
	Events.lock_on_changed.connect(_on_lock_on_changed)
	_setup_model()
	health_changed.emit(health, max_health_value())
	energy_changed.emit(energy, balance.max_energy)


## § 6.6 : le modèle est remplaçable sans toucher au code. Sans `model_scene`,
## on utilise la poupée de test (mêmes noms d'animations que Mixamo, § 6.4).
func _setup_model() -> void:
	var model: Node = null
	if data.model_scene:
		model = data.model_scene.instantiate()
		visual.add_child(model)
	else:
		var puppet := TestPuppet.new()
		puppet.name = "Puppet"
		puppet.position.y = PUPPET_FEET_OFFSET
		visual.add_child(puppet)
		model = puppet
	_cache_tints(model)
	anim_tree = CharacterAnimation.build_state_machine(self, model)
	playback = CharacterAnimation.playback_of(anim_tree)
	# L'état idle est démarré dans _physics_process (voir _ensure_anim_idle) :
	# tout de suite après sa création, l'AnimationTree ignore start().


## Mémorise les matériaux du modèle pour le flash de dégâts (§ 28). Chaque
## maillage de la poupée a son propre ShaderMaterial : la teinte n'affecte que
## cette joueuse.
func _cache_tints(model: Node) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var material := (node as MeshInstance3D).material_override as ShaderMaterial
		if material == null:
			continue
		_materials.append(material)
		_tints.append(material.get_shader_parameter("tint") as Color)


# -----------------------------------------------------------------#
#                           BOUCLE                                 #
# -----------------------------------------------------------------#

## Ce nœud est-il le nôtre ? Les copies distantes n'écoutent ni le tactile ni le
## clavier : leur position vient du réseau (§ 22.1).
func is_local_authority() -> bool:
	# Hors coop il n'y a aucun pair : `is_multiplayer_authority()` n'aurait pas
	# de sens (et Godot le signale). Une joueuse = un téléphone.
	if not Network.is_coop():
		return true
	return is_multiplayer_authority()


func _physics_process(delta: float) -> void:
	_ensure_anim_idle()
	if not is_local_authority():
		_follow_network(delta)
		return
	net_position = global_position
	invincible_time = maxf(0.0, invincible_time - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	input_buffer_time = maxf(0.0, input_buffer_time - delta)
	hurt_time_left = maxf(0.0, hurt_time_left - delta)
	guard_perfect_left = maxf(0.0, guard_perfect_left - delta)
	# Ralentissement (§ 11 boue) : une fois le délai écoulé, vitesse normale.
	if _slow_left > 0.0:
		_slow_left -= delta
		if _slow_left <= 0.0:
			speed_mult = 1.0
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_restore_tints()
	# Stabilité de garde (§ 8.4) : régénère 5/s dès qu'on ne bloque pas.
	if state != State.GUARD and guard_stability < balance.guard_stability_max:
		guard_stability = minf(balance.guard_stability_max,
			guard_stability + balance.guard_stability_regen * delta)

	if not is_on_floor():
		velocity.y -= balance.gravity * delta

	match state:
		State.IDLE, State.RUN:
			_state_move(delta)
		State.ATTACK:
			_state_attack(delta)
		State.DODGE:
			_state_dodge(delta)
		State.GUARD:
			_state_guard(delta)
		State.HURT:
			_state_hurt(delta)
		State.SPECIAL:
			_state_special(delta)
		State.DEAD:
			return

	move_and_slide()
	if lane_mode:
		# § 3.1 : couloir = axe X (gauche/droite), profondeur Z limitée à ±3 m.
		global_position.z = clampf(global_position.z, lane_center_z - lane_depth, lane_center_z + lane_depth)
	net_position = global_position


## Copie distante (§ 22.1) : elle ne simule rien, elle glisse vers la position
## reçue de l'autre téléphone et rejoue l'animation d'état.
func _follow_network(delta: float) -> void:
	global_position = global_position.lerp(net_position, 1.0 - exp(-14.0 * delta))
	if state != _remote_state:
		_remote_state = state
		_play("death" if state == State.DEAD else "idle")


# -----------------------------------------------------------------#
#                     DÉPLACEMENT ET ROTATION                      #
# -----------------------------------------------------------------#

## Direction du joystick convertie dans le repère de la caméra (§ 3.3 et § 20.4).
func _camera_relative_dir() -> Vector3:
	var j: Vector2 = Events.joystick_vector
	if j == Vector2.ZERO:
		# Clavier PC de secours (téléphone : tout passe par le joystick).
		j.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)) \
			+ float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT))
		j.y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)) \
			+ float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP))
		if j == Vector2.ZERO:
			return Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	var forward: Vector3 = -cam.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = cam.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var dir: Vector3 = right * j.x + forward * -j.y
	return dir.limit_length(1.0)


func _state_move(delta: float) -> void:
	var dir := _camera_relative_dir()
	var target_vel := dir * balance.speed * speed_mult
	velocity.x = move_toward(velocity.x, target_vel.x, balance.accel * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, balance.accel * delta)

	if dir.length() > 0.1:
		facing_dir = dir.normalized()
		if state != State.RUN:
			state = State.RUN
			_play("run")
	else:
		if state != State.IDLE:
			state = State.IDLE
			_play("idle")
		# ARENA : à l'arrêt, la joueuse fait face à sa cible verrouillée (§ 3.2).
		elif is_instance_valid(lock_target):
			var to_target := lock_target.global_position - global_position
			to_target.y = 0.0
			if to_target.length() > 0.1:
				facing_dir = to_target.normalized()
	_rotate_visual(delta)
	_consume_buffer()


func _rotate_visual(delta: float) -> void:
	var angle := atan2(-facing_dir.x, -facing_dir.z)  # l'avant du modèle est -Z
	visual.rotation.y = lerp_angle(visual.rotation.y, angle, balance.turn_speed * delta)


func _play(state_name: String) -> void:
	if playback and anim_tree and anim_tree.tree_root.has_node(state_name):
		playback.travel(state_name)


func _ensure_anim_idle() -> void:
	if _anim_ready:
		return
	_anim_ready = CharacterAnimation.start_when_ready(playback, "idle", _anim_tries)
	_anim_tries += 1


# -----------------------------------------------------------------#
#                       ENTRÉES (§ 7 et § 8)                       #
# -----------------------------------------------------------------#

func _on_touch_action(action: String, pressed: bool) -> void:
	if not is_local_authority():
		return
	# § 7 : Garde et Interaction se MAINTIENNENT (le doigt reste posé) ; les
	# autres actions partent à l'appui.
	if not pressed and action != "guard" and action != "interact":
		return
	match action:
		"attack":
			_try_attack()
		"dodge":
			_try_dodge()
		"guard":
			_guard_input(pressed)
		"special":
			_try_special()
		"interact":
			interact_held = pressed


# Clavier PC de secours.
func _unhandled_input(event: InputEvent) -> void:
	if not is_local_authority():
		return
	if event is InputEventKey and not event.echo:
		var key := (event as InputEventKey).keycode
		if (event as InputEventKey).pressed:
			match key:
				KEY_J:
					_on_touch_action("attack", true)
				KEY_K:
					_on_touch_action("dodge", true)
				KEY_L:
					_on_touch_action("guard", true)
				KEY_I:
					_on_touch_action("special", true)
				KEY_E:
					_on_touch_action("interact", true)
		elif key == KEY_L:
			_on_touch_action("guard", false)
		elif key == KEY_E:
			_on_touch_action("interact", false)


func _buffer(action: String) -> void:
	input_buffer = action
	input_buffer_time = balance.combo_window_time


func _consume_buffer() -> void:
	if input_buffer != "" and input_buffer_time > 0.0:
		var action := input_buffer
		input_buffer = ""
		_on_touch_action(action, true)


func _on_lock_on_changed(target: Node3D) -> void:
	lock_target = target


# -----------------------------------------------------------------#
#                      ATTAQUE (combo § 8.2)                       #
# -----------------------------------------------------------------#

func _try_attack() -> void:
	if state in [State.IDLE, State.RUN]:
		_magnet_to_nearest_enemy()
		_start_step(0)
	elif state == State.ATTACK:
		var step: Dictionary = combo.steps[attack_step]
		if attack_time >= float(step["win_from"]):
			queued_next = true     # fenêtre d'enchaînement ouverte : on enchaîne
		else:
			_buffer("attack")      # trop tôt : mémorisé 0,15 s (§ 7)
	else:
		_buffer("attack")


func _start_step(step_index: int) -> void:
	# § 17 : sifflement du sabre, un peu plus grave au 3e coup.
	if AudioDirector.current != null:
		AudioDirector.current.swing(1.0 + 0.08 * float(step_index))
	attack_step = step_index
	queued_next = false
	attack_time = 0.0
	state = State.ATTACK
	hitbox.deactivate()
	_play("attack%d" % (step_index + 1))


func _state_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, balance.accel * 2.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, balance.accel * 2.0 * delta)

	var step: Dictionary = combo.steps[attack_step]
	attack_time += delta

	# Avancée de la joueuse pendant le coup (§ 8.2), constante sur la fenêtre.
	var hit_to: float = float(step["hit_to"])
	if attack_time < hit_to:
		var advance_speed: float = float(step["advance"]) / maxf(hit_to, 0.001)
		velocity.x = facing_dir.x * advance_speed
		velocity.z = facing_dir.z * advance_speed

	# Hitbox active seulement pendant la fenêtre du coup.
	var hit_from: float = float(step["hit_from"])
	if attack_time >= hit_from and attack_time < hit_to:
		hitbox.damage = _attack_damage(float(step["mult"]))   # § 8.1 × mult § 8.2
		hitbox.knockback = float(step["knockback"])
		hitbox.is_heavy = attack_step == ComboController.FINISHER_STEP
		hitbox.hitstop = float(step["hitstop"])
		hitbox.shake_strength = float(step["shake"])
		# Relus à chaque coup : les réglages à chaud (§ 28) s'appliquent aussitôt.
		hitbox.crit_chance = balance.crit_chance
		hitbox.crit_mult = balance.crit_mult
		if not hitbox.monitoring:
			hitbox.activate()
	elif hitbox.monitoring:
		hitbox.deactivate()

	_rotate_visual(delta)

	if attack_time >= float(step["len"]):
		if queued_next and attack_step < combo.steps.size() - 1:
			_start_step(attack_step + 1)
		else:
			attack_step = 0
			attack_time = 0.0
			state = State.IDLE
			_play("idle")


## Aimant d'attaque (§ 8.2) : pivote vers l'ennemi le plus proche dans un cône
## de 60° et 2,5 m, pour compenser l'imprécision tactile.
func _magnet_to_nearest_enemy() -> void:
	var best: Node3D = null
	var best_distance: float = balance.attack_magnet_radius
	var cone := deg_to_rad(balance.attack_magnet_cone_deg)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var to_enemy: Vector3 = (enemy as Node3D).global_position - global_position
		to_enemy.y = 0.0
		var distance := to_enemy.length()
		if distance < best_distance and distance > 0.01 \
				and facing_dir.angle_to(to_enemy.normalized()) < cone:
			best_distance = distance
			best = enemy
	if best:
		facing_dir = (best.global_position - global_position).normalized()
		visual.rotation.y = atan2(-facing_dir.x, -facing_dir.z)


func _on_hit_landed(_target: Node, _damage: float) -> void:
	add_energy(balance.energy_per_hit)   # § 8.5 : +6 par coup donné
	if AudioDirector.current != null:
		AudioDirector.current.hit_landed(hitbox.last_critical)
	if Settings.vibration:
		Input.vibrate_handheld(15)       # § 7


# -----------------------------------------------------------------#
#                       SPÉCIAL (§ 8.5)                            #
# -----------------------------------------------------------------#

## Sabre : tourbillon 360° autour de la joueuse (§ 14.2). Coût 100 énergie,
## invincible pendant l'animation, dégâts ×3 sur tout ce qui est à portée.
func _try_special() -> void:
	if energy < balance.special_cost or state not in [State.IDLE, State.RUN, State.ATTACK]:
		_buffer("special")
		return
	energy = 0.0
	energy_changed.emit(energy, balance.max_energy)
	special_time_left = balance.special_duration
	_special_hit.clear()
	state = State.SPECIAL
	invincible_time = balance.special_invincible
	hitbox.deactivate()
	_play("attack3" if anim_tree and anim_tree.tree_root.has_node("attack3") else "idle")
	FX.shake(balance.special_shake * 0.5)
	if Settings.vibration:
		Input.vibrate_handheld(30)


func _state_special(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, balance.accel * 2.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, balance.accel * 2.0 * delta)

	var elapsed: float = balance.special_duration - special_time_left
	special_time_left -= delta
	# Tour complet : la lame balaie 360° (§ 8.5 « tourbillon »).
	visual.rotation.y += SPECIAL_SPIN * delta / maxf(balance.special_duration, 0.001)

	if elapsed >= balance.special_hit_from and elapsed <= balance.special_hit_to:
		_hit_all_around(balance.special_radius)

	if special_time_left <= 0.0:
		_special_hit.clear()
		special_time_left = 0.0
		state = State.IDLE
		_play("idle")


## Frappe une seule fois chaque ennemi entré dans le rayon du tourbillon.
func _hit_all_around(radius: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var actor := enemy as Node3D
		if actor == null or _special_hit.has(actor):
			continue
		var to_enemy := actor.global_position - global_position
		to_enemy.y = 0.0
		if to_enemy.length() > radius + 0.6:
			continue
		_special_hit.append(actor)
		if not is_instance_valid(actor):
			continue
		if actor.get("dead") == true:
			continue
		var roll := balance.roll_damage(_attack_damage(balance.special_damage_mult))
		var result := _deal_hit(actor, roll["amount"], 2.6, roll["critical"], "special",
			balance.special_hitstop)
		if result != Hurtbox3D.Result.DODGED:
			FX.shake(balance.special_shake)


## Applique un coup direct (contre-attaque, tourbillon) en passant par la
## Hurtbox3D de la cible quand elle en a une : ses signaux restent émis.
func _deal_hit(actor: Node, amount: float, knockback: float, critical: bool,
		kind: String, hitstop: float) -> int:
	var info := DamageInfo.new()
	info.amount = amount
	info.knockback = knockback
	info.source_position = global_position
	info.source_actor = self
	info.is_critical = critical
	info.is_heavy = true
	var result: int = Hurtbox3D.Result.HIT
	var target_box: Hurtbox3D = actor.get("hurtbox") as Hurtbox3D
	if target_box != null:
		result = target_box.receive_hit(info)
	elif actor.has_method("on_hit_received"):
		result = actor.on_hit_received(info)
	if result == Hurtbox3D.Result.DODGED:
		return result
	var target_position: Vector3 = (actor as Node3D).global_position
	FX.hit_feedback(_world(), target_position + Vector3(0.0, 0.2, 0.0), amount, kind,
		hitstop, 0.0)
	_on_hit_landed(actor, amount)
	return result


# -----------------------------------------------------------------#
#                   ESQUIVE ET GARDE (§ 8.3-8.4)                   #
# -----------------------------------------------------------------#

func _try_dodge() -> void:
	if dodge_cooldown > 0.0:
		_buffer("dodge")
		return
	if state in [State.IDLE, State.RUN, State.ATTACK]:
		state = State.DODGE
		invincible_time = balance.dodge_iframes
		dodge_cooldown = balance.dodge_cooldown
		dodge_time_left = balance.dodge_duration
		dodge_elapsed = 0.0
		hitbox.deactivate()
		var dir := _camera_relative_dir()
		if dir == Vector3.ZERO:
			dir = -facing_dir                # aucune direction : en arrière (§ 8.3)
		dodge_dir = dir.normalized()
		velocity.x = dodge_dir.x * (balance.dodge_distance / balance.dodge_duration)
		velocity.z = dodge_dir.z * (balance.dodge_distance / balance.dodge_duration)
		_play("dodge")


func _state_dodge(delta: float) -> void:
	# 3,6 m en 0,35 s (§ 8.3) : la vitesse est maintenue pendant toute l'esquive.
	dodge_time_left -= delta
	dodge_elapsed += delta
	velocity.x = dodge_dir.x * (balance.dodge_distance / balance.dodge_duration)
	velocity.z = dodge_dir.z * (balance.dodge_distance / balance.dodge_duration)
	if dodge_time_left <= 0.0:
		state = State.IDLE
		_play("idle")


func _guard_input(pressed: bool) -> void:
	if pressed:
		guard_pressed_time = Time.get_ticks_msec() / 1000.0
		# Fenêtre de garde parfaite (§ 8.4) : comptée en temps de jeu, donc
		# insensible aux hit-stops et aux ralentis.
		guard_perfect_left = balance.perfect_guard_window
		if state in [State.IDLE, State.RUN]:
			state = State.GUARD
			_play("guard")
	elif state == State.GUARD:
		state = State.IDLE
		_play("idle")


func _state_guard(delta: float) -> void:
	var dir := _camera_relative_dir()
	var target_vel := dir * balance.guard_speed * speed_mult
	velocity.x = move_toward(velocity.x, target_vel.x, balance.accel * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, balance.accel * delta)
	_rotate_visual(delta)


func _state_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, balance.accel * delta)
	velocity.z = move_toward(velocity.z, 0.0, balance.accel * delta)
	if hurt_time_left <= 0.0:
		state = State.IDLE
		_play("idle")


# -----------------------------------------------------------------#
#                   DÉGÂTS REÇUS (§ 8.4-8.6)                       #
# -----------------------------------------------------------------#

## Appelée par la Hurtbox3D : décide du résultat du coup reçu.
func on_hit_received(info: DamageInfo) -> int:
	if state == State.DEAD:
		return Hurtbox3D.Result.DODGED
	# § 8.3 : l'esquive dure 0,35 s mais n'est invincible que 0,25 s.
	if state == State.DODGE and invincible_time > 0.0:
		if dodge_elapsed <= balance.perfect_dodge_window:
			_perfect_dodge()                            # esquive parfaite
		return Hurtbox3D.Result.DODGED
	# § 11 : le feu brûle en continu. Ses dégâts (is_dot) passent malgré les
	# i-frames de TOUCHE (0,8 s après chaque coup) : sinon une frame sur cinquante
	# passerait et le feu ne ferait presque rien. L'esquive, traitée juste
	# au-dessus, continue de tout annuler (§ 8.3).
	if invincible_time > 0.0 and not info.is_dot:
		return Hurtbox3D.Result.DODGED
	if info.is_dot:
		_apply_damage(info.amount)                 # pas de stun, pas de recul
		return Hurtbox3D.Result.HIT
	if state == State.GUARD:
		if guard_perfect_left > 0.0:
			_perfect_guard(info)                        # § 8.4
			return Hurtbox3D.Result.PERFECT_GUARD
		return _block(info)
	_apply_damage(info.amount)
	if state != State.DEAD:
		state = State.HURT
		invincible_time = balance.hurt_iframes         # § 8.6 : 0,8 s
		hurt_time_left = balance.hurt_stun
		hitbox.deactivate()
		var away: Vector3 = global_position - info.source_position
		away.y = 0.0
		velocity = away.normalized() * info.knockback * balance.hurt_knockback_mult
		_play("hurt")
		FX.impact(_world(), global_position + Vector3(0.0, 1.0, 0.0), "hurt")
		FX.shake(balance.hit_shake)
		_flash_tints()
	return Hurtbox3D.Result.HIT


## Garde maintenue : −70 % de dégâts (§ 8.4) et −5 de stabilité. À 0, la garde
## se brise : la joueuse est étourdie et vulnérable.
func _block(info: DamageInfo) -> int:
	guard_stability -= balance.guard_stability_per_hit
	_apply_damage(info.amount * balance.guard_damage_taken)
	var push: Vector3 = global_position - info.source_position
	push.y = 0.0
	velocity += push.normalized() * info.knockback * 0.5
	FX.impact(_world(), global_position + Vector3(0.0, 1.0, 0.0), "block")
	if guard_stability <= 0.0 and state != State.DEAD:
		guard_stability = 0.0
		_break_guard()
	return Hurtbox3D.Result.BLOCKED


func _break_guard() -> void:
	state = State.HURT                       # étourdie 0,6 s (§ 8.4)
	hurt_time_left = balance.guard_broken_stun
	invincible_time = 0.0
	hitbox.deactivate()
	_play("hurt")
	FX.shake(0.4)
	Events.guard_broken.emit(self)


## Garde parfaite (§ 8.4) : 0 dégât, attaquant étourdi 0,8 s, contre-attaque,
## +15 énergie, ralenti.
func _perfect_guard(info: DamageInfo) -> void:
	add_energy(balance.perfect_guard_energy)
	FX.slow_motion(0.25, 0.3)
	FX.impact(_world(), global_position + Vector3(0.0, 1.0, 0.0), "perfect")
	Events.perfect_guard.emit(self)
	var attacker: Node = info.source_actor
	if attacker == null or not is_instance_valid(attacker):
		return
	if attacker.get("dead") == true:
		return
	# Contre-attaque : riposte immédiate sur celui qui frappe.
	var roll := balance.roll_damage(_attack_damage(balance.perfect_guard_counter_mult))
	_deal_hit(attacker, roll["amount"], 2.0, roll["critical"], "perfect", 0.06)
	if attacker.has_method("stun"):
		attacker.stun(balance.perfect_guard_stun)
	_counter_animation()


## La contre-attaque emprunte l'animation du finisseur, puis revient à la
## garde tant que le bouton reste tenu (§ 8.4).
func _counter_animation() -> void:
	_play("attack3")
	await get_tree().create_timer(COUNTER_ANIM_TIME, true, false, true).timeout
	if state == State.GUARD:
		_play("guard")


## Esquive parfaite (§ 8.3) : ralenti 0,3 s à l'échelle 0,3 et +10 énergie.
func _perfect_dodge() -> void:
	add_energy(balance.perfect_dodge_energy)
	FX.slow_motion(balance.perfect_dodge_slow_scale, balance.perfect_dodge_slow_time)
	FX.impact(_world(), global_position + Vector3(0.0, 0.8, 0.0), "perfect")
	Events.perfect_dodge.emit(self)


func _apply_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health_value())
	Events.player_damaged.emit(self, amount)
	_flash_tints()
	add_energy(balance.energy_when_hit)      # § 8.5 : +3 si touchée
	if health <= 0.0:
		# § 22.3 : en coop, tomber n'est pas mourir — l'autre joueuse peut
		# relever sa coéquipière dans les 10 s (l'hôte gère le décompte).
		if Network.is_coop():
			go_down()
			return
		state = State.DEAD
		hitbox.deactivate()
		_play("death")
		died.emit()
		if auto_respawn:
			_respawn_after_delay()


## § 22.3 : la joueuse tombe mais reste réanimable. L'hôte est prévenu ; les
## dégâts suivants ne la touchent plus.
func go_down() -> void:
	if downed:
		return
	downed = true
	state = State.DEAD
	health = 0.0
	velocity = Vector3.ZERO
	hitbox.deactivate()
	_play("death")
	if Network.is_host():
		Events.player_downed.emit(self)


## § 22.3 : relevée par sa coéquipière (30 % de vie par défaut).
func revive_at(health_value: float) -> void:
	downed = false
	health = clampf(health_value, 1.0, max_health_value())
	health_changed.emit(health, max_health_value())
	invincible_time = 1.5
	state = State.IDLE
	_play("idle")


## PHASE 1 : réapparition automatique pour tester sans niveau réel
## (PHASE 4 : écran « Réessayer / Dernier checkpoint »).
func _respawn_after_delay() -> void:
	await get_tree().create_timer(2.5, true, false, true).timeout
	if state != State.DEAD:
		return
	reset_for_level()


# -----------------------------------------------------------------#
#                   ÉTAT DE NIVEAU (PHASE 3)                       #
# -----------------------------------------------------------------#

## Remet la joueuse à neuf pour un niveau ou un checkpoint : vie pleine,
## énergie vide, garde stable. Utilisé par LevelBase3D (et par la
## réapparition automatique de PHASE 1).
func reset_for_level() -> void:
	health = max_health_value()
	# « Souffle » de l'armurerie (§ 14.4) : de l'énergie dès le départ.
	energy = minf(SaveManager.upgrade_bonus("souffle"), balance.max_energy)
	interact_held = false
	downed = false
	_special_ready = false
	guard_stability = balance.guard_stability_max
	invincible_time = balance.hurt_iframes
	hurt_time_left = 0.0
	dodge_time_left = 0.0
	special_time_left = 0.0
	speed_mult = 1.0
	run_damage_mult = 1.0
	_slow_left = 0.0
	state = State.IDLE
	hitbox.deactivate()
	health_changed.emit(health, max_health_value())
	energy_changed.emit(energy, balance.max_energy)
	_play("idle")


## Vie maximale réelle : base du § 8.1 + « Vitalité » de l'armurerie (§ 14.4).
func max_health_value() -> float:
	return balance.max_health + SaveManager.upgrade_bonus("vitalite")


## Dégâts de base × multiplicateur du combo × « Force » de l'armurerie.
func _attack_damage(mult: float) -> float:
	return balance.base_damage * mult * SaveManager.damage_multiplier() * run_damage_mult


## Téléporte la joueuse sur un point de réapparition (checkpoint du § 13).
func respawn_at(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	reset_for_level()


## Potion (§ 8.6 : +30 vie). Ne dépasse jamais la vie maximale.
func heal(amount: float) -> void:
	if state == State.DEAD or amount <= 0.0:
		return
	health = minf(max_health_value(), health + amount)
	health_changed.emit(health, max_health_value())


## Ralentissement (§ 11 boue). Le multiplicateur le plus fort gagne tant qu'il
## reste du temps ; `speed_mult` revient à 1,0 tout seul ensuite.
func apply_slow(multiplier: float, duration: float) -> void:
	speed_mult = minf(speed_mult, clampf(multiplier, 0.1, 1.0))
	_slow_left = maxf(_slow_left, duration)


## Fixe l'énergie d'un coup (chargement d'un niveau, tests) : met à jour le HUD
## et l'état « spécial prêt » comme le ferait un gain normal.
func set_energy(value: float) -> void:
	var was_ready := _special_ready
	energy = clampf(value, 0.0, balance.max_energy)
	energy_changed.emit(energy, balance.max_energy)
	_special_ready = energy >= balance.special_cost
	if _special_ready and not was_ready:
		Events.special_ready.emit(self)


func add_energy(value: float) -> void:
	set_energy(energy + value)               # le HUD signale « SPÉCIAL PRÊT »


## Le spécial est-il disponible ? (HUD et tests.)
func special_ready() -> bool:
	return energy >= balance.special_cost and state in [State.IDLE, State.RUN, State.ATTACK]


# -----------------------------------------------------------------#
#                        RETOUR VISUEL                             #
# -----------------------------------------------------------------#

func _flash_tints() -> void:
	_flash_left = FLASH_TIME
	for material in _materials:
		material.set_shader_parameter("tint", FLASH_COLOR)


func _restore_tints() -> void:
	for i in _materials.size():
		_materials[i].set_shader_parameter("tint", _tints[i])


func _world() -> Node:
	var parent := get_parent()
	return parent if parent != null else get_tree().current_scene
