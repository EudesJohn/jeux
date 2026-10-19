extends CharacterBody3D
class_name Dummy3D
## Mannequin d'entraînement (DESIGN.md § 9 : soldat, et § 28). Il encaisse les
## coups (Hurtbox3D + nombres de dégâts), riposte toutes les ~2,6 s quand la
## joueuse est à portée (télégraphe 0,4 s), meurt puis réapparaît.
## PHASE 3 : remplacé par EnemyBase3D piloté par EnemyData.
##
## PHASE 2 : il obéit à `data/balance.tres` (§ 8), s'étourdit 0,8 s sur une garde
## parfaite, flashe quand il est touché et affiche les critiques en doré.

const GRAVITY: float = 20.0
## Valeurs par défaut si `balance` manque (elles sont dans data/balance.tres).
const MAX_HEALTH: float = 120.0
const ATTACK_PERIOD: float = 2.6   ## temps entre deux ripostes
const WINDUP: float = 0.4          ## télégraphe lisible (§ 9 : soldat)
const SWING: float = 0.18          ## durée où la Hitbox est active
const REACH: float = 2.2           ## distance de déclenchement
const RESPAWN_DELAY: float = 3.0
const SWING_DAMAGE: float = 12.0
const SWING_KNOCKBACK: float = 1.2
const DEFAULT_BALANCE: String = "res://data/balance.tres"
const PUPPET_FEET_OFFSET: float = -0.42   ## même décalage que la poupée joueuse
const WOOD: Color = Color(0.45, 0.29, 0.17)          ## teinte bois du mannequin
const FLASH: Color = Color(1.0, 0.85, 0.55)          ## flash quand il est touché
const STUN_COLOR: Color = Color(0.75, 0.75, 0.95)    ## étourdi (§ 8.4)
const TELEGRAPH_COLOR: Color = Color(0.9, 0.25, 0.15)
const RING_COLOR: Color = Color(0.89, 0.66, 0.17)

signal health_changed(current: float, maximum: float)

@export var balance: Balance

@onready var visual: Node3D = $Visual
@onready var hurtbox: Hurtbox3D = $Hurtbox3D
@onready var hitbox: Hitbox3D = $Visual/Hitbox3D

var health: float = MAX_HEALTH
var max_health: float = MAX_HEALTH
var dead: bool = false
var damageable: bool = true
var cooldown_left: float = ATTACK_PERIOD
var playing_hit: bool = false          ## vrai pendant la fenêtre de riposte
var stun_left: float = 0.0             ## étourdissement en cours (garde parfaite)

var _windup_left: float = 0.0
var _swing_left: float = 0.0
var _flash_left: float = 0.0
var _home: Vector3
var _ring_material: StandardMaterial3D
var _materials: Array[ShaderMaterial] = []
var _tints: Array[Color] = []
var anim_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var _anim_ready: bool = false
var _anim_tries: int = 0


func _ready() -> void:
	add_to_group("enemies")
	if balance == null:
		balance = load(DEFAULT_BALANCE) as Balance
	if balance == null:
		balance = Balance.new()
	max_health = balance.dummy_health
	health = max_health
	cooldown_left = balance.dummy_period
	hurtbox.owner_actor = self
	hitbox.owner_actor = self
	hitbox.damage = balance.dummy_damage
	hitbox.knockback = SWING_KNOCKBACK
	hitbox.crit_chance = balance.crit_chance
	hitbox.crit_mult = balance.crit_mult
	_home = global_position
	_setup_model()
	health_changed.emit(health, max_health)


func _setup_model() -> void:
	var puppet := TestPuppet.new()
	puppet.name = "Puppet"
	puppet.position.y = PUPPET_FEET_OFFSET
	visual.add_child(puppet)
	# Mannequin d'entraînement : teinte bois + anneau doré (cible) sur la poitrine.
	# TestPuppet crée un ShaderMaterial par maillage : la teinte ne touche
	# donc que ce mannequin (les matériaux ne sont pas partagés).
	for node in puppet.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var material := mesh_instance.material_override as ShaderMaterial
		if material == null:
			continue
		material.set_shader_parameter("tint", WOOD)
		_materials.append(material)
		_tints.append(WOOD)
	_ring_material = StandardMaterial3D.new()
	_ring_material.albedo_color = RING_COLOR
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring := MeshInstance3D.new()
	ring.name = "TargetRing"
	var ring_mesh := BoxMesh.new()
	ring_mesh.size = Vector3(0.5, 0.5, 0.06)
	ring.mesh = ring_mesh
	ring.material_override = _ring_material
	ring.position = Vector3(0, 1.05, -0.26)
	puppet.add_child(ring)
	anim_tree = CharacterAnimation.build_state_machine(self, puppet)
	playback = CharacterAnimation.playback_of(anim_tree)
	# L'idle est démarré dans _physics_process : juste après sa création,
	# l'AnimationTree ignore start() (_ensure_anim_idle).


func _physics_process(delta: float) -> void:
	_ensure_anim_idle()
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_restore_tints()

	if dead:
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		move_and_slide()
		return

	# Étourdi (§ 8.4) : aucune riposte, aucun déplacement.
	if stun_left > 0.0:
		stun_left -= delta
		abort_attack()
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		move_and_slide()
		if stun_left <= 0.0:
			_restore_tints()
			if playback:
				playback.travel("idle")
		return

	cooldown_left = maxf(0.0, cooldown_left - delta)
	var player := _player()
	if player:
		var to_player: Vector3 = player.global_position - global_position
		to_player.y = 0.0
		var distance := to_player.length()
		if distance < balance.dummy_reach + 1.5 and to_player.length() > 0.05:
			# Le mannequin s'aligne lentement sur la joueuse (il te « voit »).
			visual.rotation.y = lerp_angle(visual.rotation.y,
				atan2(-to_player.normalized().x, -to_player.normalized().z), 6.0 * delta)
		if distance <= balance.dummy_reach and cooldown_left <= 0.0 and _windup_left <= 0.0 \
				and _swing_left <= 0.0 and player.state != Player3D.State.DEAD:
			_start_windup()

	_tick_attack(delta)
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	move_and_slide()


# -----------------------------------------------------------------#
#                            RIPOSTE                               #
# -----------------------------------------------------------------#

func _start_windup() -> void:
	_windup_left = balance.dummy_telegraph
	# Relus à chaque attaque : le réglage à chaud (§ 28) s'applique aussitôt.
	hitbox.damage = balance.dummy_damage
	hitbox.crit_chance = balance.crit_chance
	hitbox.crit_mult = balance.crit_mult
	playing_hit = true
	if playback and anim_tree and anim_tree.tree_root.has_node("attack1"):
		playback.travel("attack1")
	if _ring_material:
		_ring_material.albedo_color = TELEGRAPH_COLOR


func _tick_attack(delta: float) -> void:
	if _windup_left > 0.0:
		_windup_left -= delta
		if _windup_left <= 0.0:
			_swing_left = balance.dummy_swing
			hitbox.activate()
			if _ring_material:
				_ring_material.albedo_color = RING_COLOR
		return
	if _swing_left > 0.0:
		_swing_left -= delta
		if _swing_left <= 0.0:
			hitbox.deactivate()
			cooldown_left = balance.dummy_period
			playing_hit = false
			if playback:
				playback.travel("idle")


## Annule une riposte en cours (utilisé par le stun et par les tests) :
## sans cela, un télégraphe commencé avant un étourdissement frapperait
## encore après lui.
## `deferred` : à utiliser quand on vient d'un signal physique (area_entered),
## où Godot refuse un changement immédiat de `monitoring` (« Function blocked
## during in/out signal »).
func abort_attack(deferred: bool = false) -> void:
	_windup_left = 0.0
	_swing_left = 0.0
	if deferred:
		hitbox.set_deferred("monitoring", false)
	else:
		hitbox.deactivate()
	playing_hit = false
	if _ring_material:
		_ring_material.albedo_color = RING_COLOR


## Étourdissement (§ 8.4) : appelé par la joueuse après une garde parfaite.
func stun(duration: float) -> void:
	if dead or duration <= 0.0:
		return
	stun_left = maxf(stun_left, duration)
	abort_attack(true)      ## appelé depuis l'impact (area_entered)
	if playback and anim_tree and anim_tree.tree_root.has_node("hurt"):
		playback.travel("hurt")
	_flash_left = maxf(_flash_left, duration)
	for material in _materials:
		material.set_shader_parameter("tint", STUN_COLOR)


func _player() -> Player3D:
	return get_tree().get_first_node_in_group("players") as Player3D


func _ensure_anim_idle() -> void:
	if _anim_ready:
		return
	_anim_ready = CharacterAnimation.start_when_ready(playback, "idle", _anim_tries)
	_anim_tries += 1


# -----------------------------------------------------------------#
#                        DÉGÂTS REÇUS                              #
# -----------------------------------------------------------------#

func on_hit_received(info: DamageInfo) -> int:
	if dead or not damageable:
		return Hurtbox3D.Result.DODGED
	health = maxf(0.0, health - info.amount)
	health_changed.emit(health, max_health)
	# Nombres de dégâts partagés (§ 16) : critique = plus grand et doré (§ 8.7).
	FX.damage_number(_world(), global_position + Vector3(0.0, 1.6, 0.0), info.amount,
		"crit" if info.is_critical else "normal")
	_flash_tints()
	var away: Vector3 = global_position - info.source_position
	away.y = 0.0
	velocity += away.normalized() * info.knockback * 2.0
	if health <= 0.0:
		_die()
	# PHASE 1-2 : pas de garde ni d'esquive chez le mannequin (il encaisse tout).
	return Hurtbox3D.Result.HIT


func _die() -> void:
	dead = true
	damageable = false
	hitbox.deactivate()
	if playback and anim_tree and anim_tree.tree_root.has_node("death"):
		playback.travel("death")
	_respawn_after_delay()


func _respawn_after_delay() -> void:
	await get_tree().create_timer(RESPAWN_DELAY, true, false, true).timeout
	dead = false
	damageable = true
	# La vie réglée à chaud (§ 28) s'applique à la réapparition.
	max_health = balance.dummy_health
	health = max_health
	global_position = _home
	velocity = Vector3.ZERO
	cooldown_left = balance.dummy_period
	stun_left = 0.0
	health_changed.emit(health, max_health)
	if playback:
		playback.travel("idle")


# -----------------------------------------------------------------#
#                          RETOUR VISUEL                           #
# -----------------------------------------------------------------#

func _flash_tints() -> void:
	if stun_left > 0.0:
		return          # l'étourdissement garde sa propre couleur
	_flash_left = 0.08
	for material in _materials:
		material.set_shader_parameter("tint", FLASH)


func _restore_tints() -> void:
	for i in _materials.size():
		_materials[i].set_shader_parameter("tint", _tints[i])


func _world() -> Node:
	var parent := get_parent()
	return parent if parent != null else get_tree().current_scene
